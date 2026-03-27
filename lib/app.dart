import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/routes.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/context_extensions.dart';
import 'presentation/industry_specific/realestate/providers/real_estate_provider.dart';
import 'presentation/industry_specific/restaurant/providers/restaurant_provider.dart';
import 'presentation/industry_specific/wholesale/providers/wholesale_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/auto_provider.dart';
import 'providers/business_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/drink_provider.dart';
import 'providers/enhanced_subscription_provider.dart';
import 'providers/pharmacy_provider.dart';
import 'providers/receipt_settings_provider.dart';
import 'providers/retail_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'services/dunning_service.dart';
import 'services/snackbar_service.dart';
import 'services/startup_notifications.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AppRouter _appRouter = AppRouter();
  final DunningService _dunningService = DunningService();

  Timer? _dunningTimer;
  AuthProvider? _authProvider;
  BusinessProvider? _businessProvider;
  VoidCallback? _authListener;
  VoidCallback? _businessListener;
  String? _lastStartupNotificationKey;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachProviderListeners();
    });

    _startDunningPoller();
  }

  void _attachProviderListeners() {
    context.read<ConnectivityProvider>().initialize();

    _authProvider = context.read<AuthProvider>();
    _businessProvider = context.read<BusinessProvider>();

    _authListener = _handleAuthStateChanged;
    _businessListener = _handleBusinessChanged;

    _authProvider?.addListener(_authListener!);
    _businessProvider?.addListener(_businessListener!);

    _handleAuthStateChanged();
    _handleBusinessChanged();
  }

  void _handleAuthStateChanged() {
    if (!mounted || _authProvider == null) return;

    final authProvider = _authProvider!;
    final user = authProvider.currentUser;

    if (!authProvider.isAuthenticated || user == null) {
      _lastStartupNotificationKey = null;
      return;
    }

    final subscriptionProvider = context.read<EnhancedSubscriptionProvider>();
    if (user.isOwner) {
      subscriptionProvider.initializeForUser(
        user.id,
        userRole: user.role,
      );
      debugPrint(
        '[App] Subscription background checking initialized for owner: ${user.id}',
      );
    } else {
      debugPrint(
        '[App] Skipping subscription background checks for non-owner user: ${user.id}',
      );
    }

    _queueStartupNotificationsIfNeeded();
  }

  void _handleBusinessChanged() {
    if (!mounted || _businessProvider == null) return;

    final business = _businessProvider!.currentBusiness;
    if (business == null) return;

    final receiptProvider = context.read<ReceiptSettingsProvider>();
    if (receiptProvider.receiptSettings?.businessId != business.id) {
      unawaited(receiptProvider.fetchReceiptSettings(business.id));
    }
    unawaited(receiptProvider.fetchReceiptPreferences(business.id));

    _queueStartupNotificationsIfNeeded();

    Future.microtask(() async {
      if (!mounted) return;

      final bid = business.id;

      try {
        await context.read<RetailProvider>().initialize(bid);
      } catch (e) {
        debugPrint('[App] RetailProvider init failed: $e');
      }

      try {
        final restaurantProvider = context.read<RestaurantProvider>();
        restaurantProvider.setBusinessId(bid);
        await restaurantProvider.initializeMenu(businessId: bid);
        await restaurantProvider.initializeTables(businessId: bid);
        await restaurantProvider.initializeOrders(businessId: bid);
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
        final realEstateProvider = context.tryRead<RealEstateProvider>();
        if (realEstateProvider == null) {
          debugPrint(
            '[App] RealEstateProvider not yet available (startup timing).',
          );
        } else {
          realEstateProvider.loadProperties();
          realEstateProvider.loadTenants();
        }
      } catch (e) {
        debugPrint('[App] RealEstateProvider init failed: $e');
      }

      try {
        final autoProvider = context.tryRead<AutoProvider>();
        if (autoProvider == null) {
          debugPrint('[App] AutoProvider not available at startup (timing).');
        }
      } catch (e) {
        debugPrint('[App] AutoProvider init check failed: $e');
      }

      try {
        context.read<DrinkProvider>().setBusinessId(bid);
      } catch (_) {
        // Non-critical provider warm-up.
      }
    });
  }

  void _queueStartupNotificationsIfNeeded() {
    if (!mounted || _authProvider == null || _businessProvider == null) return;

    final authProvider = _authProvider!;
    final business = _businessProvider!.currentBusiness;
    final user = authProvider.currentUser;

    if (!authProvider.isAuthenticated || user == null || business == null) {
      return;
    }

    final startupKey = '${user.id}:${business.id}';
    if (_lastStartupNotificationKey == startupKey) return;

    _lastStartupNotificationKey = startupKey;
    unawaited(StartupNotifications.run(context));
  }

  void _startDunningPoller() {
    _dunningTimer = Timer.periodic(
      const Duration(minutes: 30),
      (timer) async {
        if (!mounted) return;

        try {
          final connectivity = context.read<ConnectivityProvider>();
          if (!connectivity.isConnected) return;

          final business = context.read<BusinessProvider>().currentBusiness;
          String? triggerUrl;

          if (business != null) {
            final receiptProvider = context.read<ReceiptSettingsProvider>();
            if (receiptProvider.receiptSettings == null) {
              await receiptProvider.fetchReceiptSettings(business.id);
            }
            triggerUrl = receiptProvider.receiptSettings?.dunningTriggerUrl;
          }

          final effectiveUrl = triggerUrl ??
              'https://www.globalthrivealliance.com/emailtemplate/dunning_trigger.json';

          if (effectiveUrl.isNotEmpty) {
            await _dunningService.checkAndRunRemoteTrigger(effectiveUrl);
          }
        } catch (_) {
          // Ignore background poller failures.
        }
      },
    );
  }

  @override
  void dispose() {
    if (_authProvider != null && _authListener != null) {
      _authProvider!.removeListener(_authListener!);
    }
    if (_businessProvider != null && _businessListener != null) {
      _businessProvider!.removeListener(_businessListener!);
    }

    _appRouter.dispose();
    _dunningTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor:
                isDark ? const Color(0xFF08101D) : Colors.white,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
        );

        return MaterialApp(
          title: 'Manage Care',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 280),
          themeAnimationCurve: Curves.easeOutCubic,
          initialRoute: Routes.splash,
          onGenerateRoute: _appRouter.onGenerateRoute,
          scaffoldMessengerKey: scaffoldMessengerKey,
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return _ConnectivityBanner(child: child);
          },
        );
      },
    );
  }
}

class _ConnectivityBanner extends StatelessWidget {
  const _ConnectivityBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    border: Border(
                      bottom: BorderSide(
                        color: scheme.error.withOpacity(0.18),
                      ),
                    ),
                  ),
                  child: Text(
                    'No Internet Connection - Working Offline',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
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
