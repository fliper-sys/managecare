import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../providers/auth_provider.dart';
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
      // Wait minimum 2 seconds for splash animation
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();

      // If status is still 'initial', wait a bit more for auth initialization
      // This handles slow local storage reads
      int retries = 0;
      while (authProvider.status == AuthStatus.initial && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retries++;
      }

      if (!mounted) return;

      print(
          '[SplashScreen] Auth Status: ${authProvider.status}, User: ${authProvider.currentUser?.email}');

      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        final user = authProvider.currentUser!;
        print(
            '[SplashScreen] User authenticated: ${user.email}, isOwner: ${user.isOwner}');

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
          final subscriptionData = await _fetchUserSubscriptionStatus(user.id);

          if (subscriptionData != null &&
              subscriptionData['subscriptionStatus'] == 'pending_approval') {
            // Owner has pending subscription approval
            print('[SplashScreen] Subscription pending approval (owner)');
            if (mounted) {
              Navigator.of(context).pushReplacementNamed(
                '/subscription-status',
                arguments: {
                  'userId': user.id,
                  'userEmail': user.email,
                  'userName': user.fullName,
                  'subscriptionPlan':
                      subscriptionData['subscriptionPlan'] ?? 'basic',
                  'subscriptionAmount':
                      subscriptionData['subscriptionAmount'] ?? 0.0,
                },
              );
            }
          } else if (!user.hasActiveSubscription || !user.isSubscriptionValid) {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed(
                Routes.subscriptionPayment,
                arguments: {
                  'userId': user.id,
                  'userEmail': user.email,
                  'userName': user.fullName,
                },
              );
            }
          } else {
            Navigator.of(context).pushReplacementNamed(Routes.ownerDashboard);
          }
        } else {
          // Non-owner (worker) — always go to worker dashboard
          Navigator.of(context).pushReplacementNamed(Routes.workerDashboard);
        }
      } else {
        print('[SplashScreen] User not authenticated, navigating to login');
        Navigator.of(context).pushReplacementNamed(Routes.login);
      }
    } catch (e) {
      print('[SplashScreen] Error during auth check: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(Routes.login);
      }
    }
  }

  /// Fetch the latest subscription status from Firestore
  Future<Map<String, dynamic>?> _fetchUserSubscriptionStatus(
      String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'subscriptionStatus': data['subscriptionStatus'],
          'subscriptionPlan': data['subscriptionPlan'],
          'subscriptionAmount': data['subscriptionAmount'],
          'hasActiveSubscription': data['hasActiveSubscription'],
        };
      }
      return null;
    } catch (e) {
      print('[SplashScreen] Error fetching subscription status: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Image.asset(
                              'assets/app_icon.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.store,
                                size: 56,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Manage Care',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All-in-One Business Management',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Lottie.asset(
                            'assets/lottie/loop.json',
                            repeat: true,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const CustomLoadingIndicator(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Loading your workspace...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

