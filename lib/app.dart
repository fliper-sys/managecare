import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'services/dunning_service.dart';
import 'services/startup_notifications.dart';
import 'services/push_service.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/context_extensions.dart';
import 'providers/theme_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/enhanced_subscription_provider.dart';
import 'routes/app_router.dart';
import 'core/constants/routes.dart';
import 'providers/business_provider.dart';
import 'providers/receipt_settings_provider.dart';
// Auto-initialization imports for industry providers
import 'providers/retail_provider.dart';
import 'presentation/industry_specific/restaurant/providers/restaurant_provider.dart';
import 'providers/pharmacy_provider.dart';
import 'presentation/industry_specific/wholesale/providers/wholesale_provider.dart';
import 'providers/auto_provider.dart';
import 'presentation/industry_specific/realestate/providers/real_estate_provider.dart';
import 'providers/drink_provider.dart';
import 'services/snackbar_service.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _appRouter = AppRouter();

  @override
  void initState() {
    super.initState();
    // Initialize connectivity monitoring
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectivityProvider>().initialize();

      // Initialize subscription checking for authenticated users (owners only).
      // Workers and other non-owner users should not trigger background subscription checks
      // on app start to avoid blocking or showing subscription enforcement during auto-login.
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        final user = authProvider.currentUser!;
        final subscriptionProvider = context.read<EnhancedSubscriptionProvider>();
        if (user.isOwner) {
          subscriptionProvider.initializeForUser(
            user.id,
            userRole: user.role,
          );
          print('[App] Subscription background checking initialized for owner: ${user.id}');
        } else {
          // Skip background subscription checks for workers and other non-owner roles
          print('[App] Skipping subscription background checks for non-owner user: ${user.id}');
        }

        // Initialize push notifications for the authenticated user
        try {
          PushService.initialize();
        } catch (e) {
          debugPrint('[App] PushService initialization failed: $e');
        }

          // Also trigger on subsequent sign-ins
          authProvider.addListener(() {
            try {
              if (authProvider.isAuthenticated) {
                StartupNotifications.run(context);
              }
           
        } catch (_) {}
      });

      // Listen for business selection changes and prefetch receipt settings
      // and thermal preferences so receipt generation (print/email) can use
      // them immediately without extra delays.
      final businessProvider = context.read<BusinessProvider>();
      businessProvider.addListener(() {
        try {
          final business = businessProvider.currentBusiness;
          if (business != null) {
            final receiptProvider = context.read<ReceiptSettingsProvider>();
            // Only fetch main settings if they are for a different business
            if (receiptProvider.receiptSettings?.businessId != business.id) {
              receiptProvider.fetchReceiptSettings(business.id);
            }
            // Always refresh thermal preferences (small, cached doc)
            receiptProvider.fetchReceiptPreferences(business.id);

            // --- Auto-initialize common industry providers (best-effort) ---
            // Perform asynchronously to avoid blocking the UI thread
            Future.microtask(() async {
              final bid = business.id;

              try {
                await context.read<RetailProvider>().initialize(bid);
              } catch (e) {
                debugPrint('[App] RetailProvider init failed: $e');
              }

              try {
                final rprov = context.read<RestaurantProvider>();
                rprov.setBusinessId(bid);
                await rprov.initializeMenu(businessId: bid);
                await rprov.initializeTables(businessId: bid);
                await rprov.initializeOrders(businessId: bid);
              } catch (e) {
                debugPrint('[App] RestaurantProvider init failed: $e');
              }

              try {
                context.read<PharmacyProvider>().setBusinessId(bid);
              } catch (e) {
                debugPrint('[App] PharmacyProvider setBusinessId failed: $e');
              }

              try {
                context.read<WholesaleProvider>().initializeWithBusinessId(bid);
              } catch (e) {
                debugPrint('[App] WholesaleProvider init failed: $e');
              }

              try {
                // Use the safe helper to avoid throwing if provider not registered yet.
                final reProv = context.tryRead<RealEstateProvider>();
                if (reProv == null) {
                  debugPrint('[App] RealEstateProvider not yet available (startup timing).');
                } else {
                  reProv.loadProperties();
                  reProv.loadTenants();
                }
              } catch (e) {
                debugPrint('[App] RealEstateProvider init failed: $e');
              }

              try {
                // AutoProvider will be notified via ChangeNotifierProxyProvider when business changes.
                // This avoids duplicating startup loads here and centralizes business wiring in `main.dart`.
                final ap = context.tryRead<AutoProvider>();
                if (ap == null) {
                  debugPrint('[App] AutoProvider not available at startup (timing)');
                }
              } catch (e) {
                debugPrint('[App] AutoProvider init check failed: $e');
              }

              try {
                context.read<DrinkProvider>().setBusinessId(bid);
              } catch (e) {
                // non-critical
              }

              // Workers, Loyalty, Analytics and others are usually initialized via
              // components like BusinessSwitcher when user actively changes context.
            });
          }
        } catch (e) {
          debugPrint('[App] Error prefetching receipt settings: $e');
        }
      });
    }});
    // Start periodic dunning trigger poller (runs in app while open).
    // The poller will use the configured `dunningTriggerUrl` from receipt settings if available.
    final dunningService = DunningService();
    _dunningTimer = Timer.periodic(const Duration(minutes: 30), (timer) async {
      try {
        final conn = context.read<ConnectivityProvider>();
        if (!conn.isConnected) return;

        final business = context.read<BusinessProvider>().currentBusiness;
        String? triggerUrl;
        if (business != null) {
          final receiptProvider = context.read<ReceiptSettingsProvider>();
          if (receiptProvider.receiptSettings == null) {
            await receiptProvider.fetchReceiptSettings(business.id);
          }
          triggerUrl = receiptProvider.receiptSettings?.dunningTriggerUrl;
        }

        // Fallback to repo placeholder if not configured
        final effectiveUrl = triggerUrl ??
            'https://www.globalthrivealliance.com/emailtemplate/dunning_trigger.json';

        if (effectiveUrl.isNotEmpty) {
          await dunningService.checkAndRunRemoteTrigger(effectiveUrl);
        }
      } catch (e) {
        // ignore poll errors
      }
    });
  }

  @override
  void dispose() {
    _appRouter.dispose();
    _dunningTimer?.cancel();
    super.dispose();
  }

  Timer? _dunningTimer;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Update system UI overlays to match the current theme
        final isDark = themeProvider.isDarkMode;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor:
              isDark ? const Color(0xFF121212) : Colors.white,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ));

        return MaterialApp(
          title: 'Manage Care',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          initialRoute: Routes.splash,
          onGenerateRoute: _appRouter.onGenerateRoute,
          // Use a global scaffold messenger so SnackBars are safe across navigation
          scaffoldMessengerKey: scaffoldMessengerKey,
          builder: (context, child) {
            return _ConnectivityBanner(child: child!);
          },
        );
      },
    );
  }
}

class _ConnectivityBanner extends StatelessWidget {
  final Widget child;

  const _ConnectivityBanner({required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        return Stack(
          children: [
            Positioned.fill(child: child),
            if (!connectivity.isConnected)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.red,
                  child: const Text(
                    'No Internet Connection - Working Offline',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

