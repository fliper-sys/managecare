import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../core/constants/routes.dart';
import '../../../core/utils/connectivity_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../services/subscription_service.dart';
import '../../../services/business_restriction_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      final authProvider = context.read<AuthProvider>();

      // Wait for the real auto-login/cached-user check to finish (this is
      // normally a handful of milliseconds — local storage reads), capped
      // by a safety timeout in case something hangs. Run this in parallel
      // with a short minimum splash duration purely for branding, rather
      // than blocking on a fixed delay before we even look at auth state.
      final authReady = authProvider.status == AuthStatus.initial
          ? authProvider.initializationComplete
              .timeout(const Duration(seconds: 3), onTimeout: () {})
          : Future<void>.value();

      await Future.wait([
        authReady,
        Future.delayed(const Duration(milliseconds: 500)),
      ]);

      // Local storage can finish before Supabase has delivered its initial
      // persisted session event. Let that event populate AuthProvider before
      // deciding that a cold start is unauthenticated.
      await authProvider.authRestoreComplete
          .timeout(const Duration(seconds: 2), onTimeout: () {});

      if (!mounted) return;

      print(
          '[SplashScreen] Auth Status: ${authProvider.status}, User: ${authProvider.currentUser?.email}');

      if (authProvider.status == AuthStatus.initial ||
          authProvider.status == AuthStatus.loading) {
        try {
          await authProvider.initializationComplete
              .timeout(const Duration(seconds: 3), onTimeout: () {});
        } catch (_) {
          // Timeout or error during initialization; wait a bit for restore to settle.
        }
        if (!mounted) return;
        if (authProvider.status == AuthStatus.initial) {
          // Still settling during cold start; don't redirect until the restore
          // path has had a chance to populate the cached session.
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      final hasPersistedLogin =
          authProvider.isPersistentLoginEnabled && authProvider.hasCachedUser;
      final shouldNavigateToLogin = shouldNavigateToLoginOnStartup(
        status: authProvider.status,
        isAuthenticated: authProvider.isAuthenticated,
        hasCachedUser: authProvider.hasCachedUser,
        autoLoginEnabled: authProvider.isPersistentLoginEnabled,
      );

      if (hasPersistedLogin && authProvider.currentUser == null) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        if (authProvider.currentUser == null && authProvider.hasCachedUser) {
          // Give the startup restore a brief chance to repopulate the user from
          // the local cached session before forcing a login redirect.
          return;
        }
      }

      if (!shouldNavigateToLogin &&
          authProvider.isAuthenticated &&
          authProvider.currentUser != null) {
        final isOnline = await ConnectivityHelper.hasInternetConnection();
        if (!isOnline) {
          final user = authProvider.currentUser!;
          if (user.email.toLowerCase() == 'mcadmin@mc.c') {
            Navigator.of(context).pushReplacementNamed(Routes.adminDashboard);
          } else if (user.isOwner) {
            Navigator.of(context).pushReplacementNamed(Routes.ownerDashboard);
          } else {
            await _navigateWorkerToDashboard(user);
          }
          return;
        }

        await authProvider.refresh();
        if (!mounted) return;
        if (authProvider.currentUser == null) {
          if (hasPersistedLogin && authProvider.hasCachedUser) {
            return;
          }
          Navigator.of(context).pushReplacementNamed(Routes.login);
          return;
        }

        final user = authProvider.currentUser!;
        print(
            '[SplashScreen] User authenticated: ${user.email}, isOwner: ${user.isOwner}');

        // Platform admin accounts have no business of their own - route
        // straight to the admin dashboard rather than through the regular
        // owner/subscription/business-restriction flow below, which assumes
        // every authenticated user owns or works at a business.
        if (user.email.toLowerCase() == 'mcadmin@mc.c') {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(Routes.adminDashboard);
          }
          return;
        }

        final restrictionState = await BusinessRestrictionService()
            .getRestrictionState(
          userId: user.id,
          businessId:
              user.primaryBusinessId.isNotEmpty ? user.primaryBusinessId : user.businessId,
        );

        if (restrictionState?.isRestricted == true) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(
              Routes.restrictedBusiness,
              arguments: {
                'businessName': restrictionState!.businessName,
                'restrictionReason': restrictionState.restrictionReason,
                'customerCareWhatsapp': restrictionState.customerCareWhatsapp,
              },
            );
          }
          return;
        }

        // Only owners should be redirected to subscription management pages.
        // Workers should be taken straight to their dashboard.
        if (user.isOwner) {
          // Check subscription status in Firestore for real-time updates
          final currentBusinessId = user.primaryBusinessId.isNotEmpty
              ? user.primaryBusinessId
              : user.businessId;
          final subscriptionData =
              await _fetchBusinessSubscriptionStatus(currentBusinessId);
          final hasActiveCurrentBusinessSubscription =
              _hasActiveCurrentBusinessSubscription(subscriptionData);
          final hasLocalActiveSubscription = user.isSubscriptionValid ||
              authProvider.subscriptionValidated;

          final subscriptionStatus =
              (subscriptionData?['subscriptionReviewStatus'] ??
                      subscriptionData?['subscriptionStatus'])
                  ?.toString()
                  .toLowerCase() ??
                  '';

          if (subscriptionStatus == 'pending_approval' &&
              !hasActiveCurrentBusinessSubscription) {
            // Owner has pending subscription approval
            print('[SplashScreen] Subscription pending approval (owner)');
            if (mounted) {
              Navigator.of(context).pushReplacementNamed(
                '/subscription-status',
                arguments: {
                  'userId': user.id,
                  'userEmail': user.email,
                  'userName': user.fullName,
                  'businessId': currentBusinessId,
                  'businessType': user.businessType,
                  'subscriptionPlan':
                      subscriptionData?['subscriptionPlan'] ?? 'tier1',
                  'subscriptionAmount':
                      subscriptionData?['subscriptionAmount'] ?? 0.0,
                },
              );
            }
          } else if (!(hasActiveCurrentBusinessSubscription ||
              hasLocalActiveSubscription)) {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed(
                Routes.subscriptionPayment,
                arguments: {
                  'userId': user.id,
                  'userEmail': user.email,
                  'userName': user.fullName,
                  'businessId': currentBusinessId,
                  'businessType': user.businessType,
                },
              );
            }
          } else {
            Navigator.of(context).pushReplacementNamed(Routes.ownerDashboard);
          }
        } else {
          await _navigateWorkerToDashboard(user);
        }
      } else {
        print('[SplashScreen] User not authenticated, navigating to login');
        if (hasPersistedLogin && authProvider.hasCachedUser) {
          return;
        }
        Navigator.of(context).pushReplacementNamed(Routes.login);
      }
    } catch (e) {
      print('[SplashScreen] Error during auth check: $e');
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        if (authProvider.isPersistentLoginEnabled &&
            authProvider.hasCachedUser) {
          return;
        }
        Navigator.of(context).pushReplacementNamed(Routes.login);
      }
    }
  }

  DateTime? _parseSubscriptionDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  bool _hasActiveCurrentBusinessSubscription(
      Map<String, dynamic>? subscriptionData) {
    if (subscriptionData == null) return false;

    final reviewStatus =
        subscriptionData['subscriptionReviewStatus']?.toString().toLowerCase() ??
            '';
    final status =
        subscriptionData['subscriptionStatus']?.toString().toLowerCase() ?? '';
    final hasActiveFlag =
        subscriptionData['hasActiveSubscription'] == true ||
            subscriptionData['isSubscriptionActive'] == true;
    final statusLooksActive = reviewStatus == 'approved' ||
        reviewStatus == 'active' ||
        status == 'approved' ||
        status == 'active';
    final endDate = _parseSubscriptionDate(subscriptionData['subscriptionEndDate']);
    final isWithinDuration = endDate == null ||
        SubscriptionService.isWithinSubscriptionAccessWindow(endDate);

    return (hasActiveFlag || statusLooksActive) && isWithinDuration;
  }

  /// Fetch the latest subscription status from the backend (Postgres) -
  /// businesses no longer live in Firestore, and admin subscription grants
  /// only ever write to Postgres, so reading Firestore here always found
  /// stale/missing data and bounced owners back to the subscription screen.
  Future<Map<String, dynamic>?> _fetchBusinessSubscriptionStatus(
      String businessId) async {
    try {
      if (businessId.trim().isEmpty) return null;
      final data = await Supabase.instance.client
          .from('businesses')
          .select()
          .eq('id', businessId)
          .maybeSingle();

      if (data != null) {
        return {
          'subscriptionStatus': data['subscription_status'],
          'subscriptionReviewStatus': data['subscription_review_status'],
          'subscriptionPlan': data['subscription_plan'],
          'subscriptionAmount': data['subscription_amount'],
          'hasActiveSubscription': data['is_subscription_active'],
          'isSubscriptionActive': data['is_subscription_active'],
          'subscriptionEndDate': data['subscription_end_date'],
        };
      }
      return null;
    } catch (e) {
      print('[SplashScreen] Error fetching subscription status: $e');
      return null;
    }
  }

  Future<void> _navigateWorkerToDashboard(dynamic user) async {
    final businessProvider = context.read<BusinessProvider>();
    final businessId = user.businessId?.toString() ?? '';

    // These hit Firestore; if connectivity is flaky (reports connected but
    // requests don't actually complete) don't let the splash screen hang —
    // fall back to whatever is already cached and move on.
    const businessLoadTimeout = Duration(seconds: 4);
    if (businessId.isNotEmpty) {
      try {
        await businessProvider
            .loadBusinessById(businessId)
            .timeout(businessLoadTimeout);
      } catch (_) {}
    } else {
      try {
        await businessProvider
            .ensureBusinessForWorker(user.id, workerEmail: user.email)
            .timeout(businessLoadTimeout);
      } catch (_) {}
    }

    if (!mounted) return;

    var industryRoute = businessProvider.getIndustryRouteForCurrentBusiness();
    if (industryRoute == null || industryRoute.isEmpty) {
      industryRoute =
          businessProvider.getIndustryRouteForType(user.businessType);
    }

    Navigator.of(context).pushReplacementNamed(
      industryRoute?.isNotEmpty == true
          ? industryRoute!
          : Routes.workerDashboard,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF081126),
                  Color(0xFF0D2445),
                  Color(0xFF13386A),
                ],
              ),
            ),
          ),
          _buildAccentOrb(
            top: -130,
            right: -80,
            size: 280,
            color: const Color(0xFF27D2A2).withOpacity(0.10),
          ),
          _buildAccentOrb(
            top: 180,
            left: -90,
            size: 240,
            color: const Color(0xFFF3B35C).withOpacity(0.10),
          ),
          _buildAccentOrb(
            bottom: -120,
            right: 40,
            size: 260,
            color: Colors.white.withOpacity(0.05),
          ),
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 34,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.20),
                                  blurRadius: 34,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 112,
                                  height: 112,
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0x33FFFFFF),
                                        Color(0x16FFFFFF),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.14),
                                    ),
                                  ),
                                  child: Image.asset(
                                    'assets/app_icon.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.storefront_rounded,
                                      size: 54,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.10),
                                    ),
                                  ),
                                  child: Text(
                                    'Multi-business operations hub',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.92),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Manage Care',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Operations, sales, staff, and subscription checks are getting your workspace ready.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.82),
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 26),
                                Container(
                                  width: 88,
                                  height: 88,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const CustomLoadingIndicator(),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Loading your workspace...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.88),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Secure sync • Business access checks • Real-time setup',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.64),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccentOrb({
    double? top,
    double? right,
    double? bottom,
    double? left,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}
