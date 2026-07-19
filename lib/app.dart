import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'providers/sync_provider.dart';
import 'providers/drink_provider.dart';
import 'providers/enhanced_subscription_provider.dart';
import 'providers/pharmacy_provider.dart';
import 'providers/receipt_settings_provider.dart';
import 'providers/retail_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'services/dunning_service.dart';
import 'services/business_restriction_service.dart';
import 'services/business_reminder_service.dart';
import 'services/snackbar_service.dart';
import 'services/startup_notifications.dart';
import 'services/subscription_service.dart';
import 'widgets/offline_indicator.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AppRouter _appRouter = AppRouter();
  final DunningService _dunningService = DunningService();
  final BusinessRestrictionService _restrictionService =
      BusinessRestrictionService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  Timer? _dunningTimer;
  Timer? _businessReminderTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _businessRestrictionSub;
  AuthProvider? _authProvider;
  BusinessProvider? _businessProvider;
  VoidCallback? _authListener;
  VoidCallback? _businessListener;
  String? _lastStartupNotificationKey;
  String? _watchedRestrictionBusinessId;
  String? _activeRestrictionBusinessId;
  String? _activeSubscriptionBlockedBusinessId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachProviderListeners();
    });

    _startDunningPoller();
    _startBusinessReminderPoller();
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
    unawaited(_syncBusinessRestrictionWatcher());
  }

  void _handleAuthStateChanged() {
    if (!mounted || _authProvider == null) return;

    final authProvider = _authProvider!;
    final user = authProvider.currentUser;

    if (!authProvider.isAuthenticated || user == null) {
      _lastStartupNotificationKey = null;
      unawaited(_clearBusinessRestrictionWatcher());
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
    unawaited(_syncBusinessReminders());
    unawaited(_syncBusinessRestrictionWatcher());
  }

  void _handleBusinessChanged() {
    if (!mounted || _businessProvider == null) return;

    final business = _businessProvider!.currentBusiness;
    if (business == null) {
      unawaited(_syncBusinessRestrictionWatcher());
      return;
    }

    final receiptProvider = context.read<ReceiptSettingsProvider>();
    if (receiptProvider.receiptSettings?.businessId != business.id) {
      unawaited(receiptProvider.fetchReceiptSettings(business.id));
    }
    unawaited(receiptProvider.fetchReceiptPreferences(business.id));

    _queueStartupNotificationsIfNeeded();
    unawaited(_syncBusinessReminders());
    unawaited(_syncBusinessRestrictionWatcher());

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
        await restaurantProvider.initializeReservations(businessId: bid);
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

  Future<void> _clearBusinessRestrictionWatcher() async {
    await _businessRestrictionSub?.cancel();
    _businessRestrictionSub = null;
    _watchedRestrictionBusinessId = null;
    _activeRestrictionBusinessId = null;
  }

  Future<void> _syncBusinessRestrictionWatcher() async {
    if (!mounted || _authProvider == null) return;

    final authProvider = _authProvider!;
    final user = authProvider.currentUser;
    final businessId = _businessProvider?.currentBusiness?.id ??
        user?.currentBusinessId ??
        user?.businessId;

    if (!authProvider.isAuthenticated ||
        user == null ||
        businessId == null ||
        businessId.isEmpty) {
      await _clearBusinessRestrictionWatcher();
      return;
    }

    if (_watchedRestrictionBusinessId == businessId &&
        _businessRestrictionSub != null) {
      return;
    }

    await _businessRestrictionSub?.cancel();
    _watchedRestrictionBusinessId = businessId;
    _activeRestrictionBusinessId = null;

    _businessRestrictionSub = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .snapshots()
        .listen((_) {
      unawaited(_handleBusinessRestrictionChanged(businessId));
    });

    await _handleBusinessRestrictionChanged(businessId);
  }

  Future<void> _handleBusinessRestrictionChanged(String businessId) async {
    if (!mounted || _authProvider == null) return;
    if (_watchedRestrictionBusinessId != businessId) return;

    final authProvider = _authProvider!;
    final user = authProvider.currentUser;
    if (!authProvider.isAuthenticated || user == null) return;

    final restrictionState = await _restrictionService.getRestrictionState(
      userId: user.id,
      businessId: businessId,
    );

    if (!mounted || _watchedRestrictionBusinessId != businessId) return;

    if (restrictionState == null || !restrictionState.isRestricted) {
      _activeRestrictionBusinessId = null;
      return;
    }

    if (_activeRestrictionBusinessId == restrictionState.businessId) {
      return;
    }

    _activeRestrictionBusinessId = restrictionState.businessId;

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    SnackBarService.showSnackBar(
      message:
          '${restrictionState.businessName} is now restricted. This session has been locked.',
      duration: const Duration(seconds: 4),
    );

    navigator.pushNamedAndRemoveUntil(
      Routes.restrictedBusiness,
      (_) => false,
      arguments: {
        'businessName': restrictionState.businessName,
        'restrictionReason': restrictionState.restrictionReason,
        'customerCareWhatsapp': restrictionState.customerCareWhatsapp,
      },
    );
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

  Future<void> _syncBusinessReminders() async {
    if (!mounted || _authProvider == null || _businessProvider == null) return;

    final authProvider = _authProvider!;
    final user = authProvider.currentUser;
    final business = _businessProvider!.currentBusiness;

    if (!authProvider.isAuthenticated || user == null || business == null) {
      return;
    }

    await BusinessReminderService.instance.syncBusinessReminders(
      businessId: business.id,
      businessName: business.name,
      businessType: business.businessType,
      currentUserId: user.id,
      ownerUserId: business.ownerId,
    );

    await _enforceSubscriptionAccessIfNeeded(
      userId: user.id,
      businessId: business.id,
      businessType: business.businessType,
      userEmail: user.email,
      userName: user.fullName,
    );
  }

  Future<void> _enforceSubscriptionAccessIfNeeded({
    required String userId,
    required String businessId,
    required String? businessType,
    required String userEmail,
    required String userName,
  }) async {
    if (!mounted || _authProvider == null) return;
    final user = _authProvider!.currentUser;
    if (user == null || !user.isOwner) return;

    final restrictionState = await _restrictionService.getRestrictionState(
      userId: userId,
      businessId: businessId,
    );

    if (!mounted) return;

    if (restrictionState != null && restrictionState.isRestricted) {
      _activeSubscriptionBlockedBusinessId = null;
      _activeRestrictionBusinessId = restrictionState.businessId;
      final navigator = _navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushNamedAndRemoveUntil(
          Routes.restrictedBusiness,
          (_) => false,
          arguments: {
            'businessName': restrictionState.businessName,
            'restrictionReason': restrictionState.restrictionReason,
            'customerCareWhatsapp': restrictionState.customerCareWhatsapp,
          },
        );
      }
      return;
    }

    final valid = await SubscriptionService(
      firestore: FirebaseFirestore.instance,
    ).validateAndUpdateBusinessSubscriptionStatus(
      businessId,
      userId: userId,
    );

    if (!mounted) return;

    if (valid) {
      _activeSubscriptionBlockedBusinessId = null;
      return;
    }

    if (_activeSubscriptionBlockedBusinessId == businessId) {
      return;
    }
    _activeSubscriptionBlockedBusinessId = businessId;

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    SnackBarService.showSnackBar(
      message:
          'This subscription is past its renewal grace period. Please renew to continue.',
      duration: const Duration(seconds: 4),
    );

    navigator.pushNamedAndRemoveUntil(
      Routes.subscriptionPayment,
      (_) => false,
      arguments: {
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'businessId': businessId,
        'businessType': businessType,
      },
    );
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

  void _startBusinessReminderPoller() {
    _businessReminderTimer = Timer.periodic(
      const Duration(minutes: 20),
      (_) async {
        try {
          await _syncBusinessReminders();
        } catch (e) {
          debugPrint('[App] Business reminder poller failed: $e');
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
    _businessReminderTimer?.cancel();
    _businessRestrictionSub?.cancel();
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
          navigatorKey: _navigatorKey,
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

    return Consumer2<ConnectivityProvider, SyncProvider>(
      builder: (context, connectivity, sync, _) {
        // Priority: no connection > actively syncing pending sales > sales
        // still waiting to sync (e.g. sync attempt failed) > nothing to show.
        // This is the persistent, app-wide counterpart to the one-time
        // "Sale recorded offline" snackbar shown right at checkout — it
        // keeps reassuring the cashier that pending offline sales exist and
        // haven't been lost, until they're confirmed synced.
        final scheme = Theme.of(context).colorScheme;
        String? message;
        Color backgroundColor = scheme.errorContainer;
        Color foregroundColor = scheme.onErrorContainer;
        Color borderColor = scheme.error.withOpacity(0.18);

        if (!connectivity.isConnected) {
          message = 'No Internet Connection - Working Offline';
        } else if (sync.isSyncing) {
          message = 'Syncing ${sync.pendingItems} offline sale'
              '${sync.pendingItems == 1 ? '' : 's'}...';
          backgroundColor = scheme.tertiaryContainer;
          foregroundColor = scheme.onTertiaryContainer;
          borderColor = scheme.tertiary.withOpacity(0.18);
        } else if (sync.hasPendingItems) {
          message = '${sync.pendingItems} offline sale'
              '${sync.pendingItems == 1 ? '' : 's'} waiting to sync';
          backgroundColor = scheme.tertiaryContainer;
          foregroundColor = scheme.onTertiaryContainer;
          borderColor = scheme.tertiary.withOpacity(0.18);
        }

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
