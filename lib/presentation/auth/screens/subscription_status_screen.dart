import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../core/theme/colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/constants/routes.dart';
import 'worker_business_assignment_screen.dart';

class SubscriptionStatusScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String userName;
  final String subscriptionPlan;
  final double subscriptionAmount;

  const SubscriptionStatusScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.subscriptionPlan,
    required this.subscriptionAmount,
  });

  @override
  State<SubscriptionStatusScreen> createState() =>
      _SubscriptionStatusScreenState();
}

class _SubscriptionStatusScreenState extends State<SubscriptionStatusScreen> {
  StreamSubscription<DocumentSnapshot>? _statusListener;
  bool _subscriptionApproved = false;
  bool _checkingStatus = true;
  String _statusMessage = 'Checking subscription status...';

  @override
  void initState() {
    super.initState();

    // Defer to a post-frame check to decide whether to start subscription listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final role = authProvider.currentUser?.role;
      if (role != null && role.toLowerCase() == 'worker') {
        _checkingStatus = false;
        _statusMessage = 'Subscription not required for worker accounts.';
        debugPrint('[SubscriptionStatusScreen] Worker account - skipping subscription listener');
        return;
      }

      _listenToSubscriptionStatus();
    });
  }

  void _listenToSubscriptionStatus() {
    print(
        '[SubscriptionStatusScreen] Listening to subscription status for user: ${widget.userId}');

    _statusListener = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!snapshot.exists) {
          print('[SubscriptionStatusScreen] User document not found');
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final subscriptionStatus = data['subscriptionStatus'] as String?;
        final hasActiveSubscription =
            data['hasActiveSubscription'] as bool? ?? false;

        print(
            '[SubscriptionStatusScreen] Subscription Status: $subscriptionStatus');
        print(
            '[SubscriptionStatusScreen] Has Active Subscription: $hasActiveSubscription');

        if (mounted) {
          setState(() {
            _checkingStatus = false;
          });
        }

        // Handle different subscription statuses
        if (subscriptionStatus == 'approved' || hasActiveSubscription) {
          print('[SubscriptionStatusScreen] ✓ Subscription approved!');
          _subscriptionApproved = true;

          if (mounted) {
            setState(() {
              _statusMessage =
                  'Subscription approved! Upgrading your account...';
            });
          }

          // Auto-navigate after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _navigateToDashboard();
            }
          });
        } else if (subscriptionStatus == 'rejected') {
          print('[SubscriptionStatusScreen] ✗ Subscription rejected');
          if (mounted) {
            setState(() {
              _statusMessage = 'Subscription was rejected. Please try again.';
            });
          }
        } else if (subscriptionStatus == 'pending_approval') {
          print(
              '[SubscriptionStatusScreen] ⏳ Subscription still pending approval');
          if (mounted) {
            setState(() {
              _statusMessage =
                  'Your subscription is pending admin approval...\n\nPlease check back shortly.';
            });
          }
        }
      },
      onError: (error) {
        print(
            '[SubscriptionStatusScreen] Error listening to subscription: $error');
        if (mounted) {
          setState(() {
            _checkingStatus = false;
            _statusMessage = 'Error checking status. Please try again.';
          });
        }
      },
    );
  }

  void _navigateToDashboard() {
    print('[SubscriptionStatusScreen] Navigating to dashboard');
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;

      if (user != null) {
        if (user.isOwner) {
          Navigator.of(context).pushReplacementNamed(Routes.ownerDashboard);
        } else {
          // Worker user: ensure they are linked to a business before proceeding
          final primaryBiz = user.primaryBusinessId;
          if (primaryBiz.isEmpty) {
            // Ask worker to provide their owner's id to link to a business
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => WorkerBusinessAssignmentScreen(userId: user.id),
            ));
          } else {
            Navigator.of(context).pushReplacementNamed(Routes.workerDashboard);
          }
        }
      } else {
        Navigator.of(context).pushReplacementNamed(Routes.splash);
      }
    } catch (e) {
      print('[SubscriptionStatusScreen] Error navigating: $e');
      Navigator.of(context).pushReplacementNamed(Routes.splash);
    }
  }

  @override
  void dispose() {
    _statusListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_checkingStatus, // Prevent back during checking
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Subscription Status'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: !_checkingStatus,
          actions: _checkingStatus
              ? []
              : [
                  TextButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushReplacementNamed('/');
                      }
                    },
                    child: const Text('Skip', style: TextStyle(color: Colors.white)),
                  ),
                ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _subscriptionApproved
                        ? Colors.green.withOpacity(0.1)
                        : _checkingStatus
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                  ),
                  child: Center(
                    child: _subscriptionApproved
                        ? const Icon(
                            Icons.check_circle,
                            size: 56,
                            color: Colors.green,
                          )
                        : _checkingStatus
                            ? const SizedBox(
                                width: 56,
                                height: 56,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.primary,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.schedule,
                                size: 56,
                                color: Colors.orange,
                              ),
                  ),
                ),
                const SizedBox(height: 32),

                // Status Text
                Text(
                  _subscriptionApproved
                      ? 'Subscription Approved!'
                      : _checkingStatus
                          ? 'Checking Status...'
                          : 'Awaiting Approval',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Status Message
                Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Subscription Details Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subscription Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Email',
                        widget.userEmail,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Plan',
                        widget.subscriptionPlan.toUpperCase(),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Amount',
                        '${widget.subscriptionAmount}',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Status',
                        _subscriptionApproved
                            ? 'Approved ✓'
                            : _checkingStatus
                                ? 'Checking...'
                                : 'Pending Approval',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Colors.blue,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'What Happens Next?',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _subscriptionApproved
                            ? 'Your subscription has been approved! You now have full access to all features. You will be redirected to your dashboard shortly.'
                            : 'An admin will review your subscription request and approve it as soon as possible. You\'ll be notified once it\'s approved and you\'ll have full access to all features.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                if (!_subscriptionApproved && !_checkingStatus)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _checkingStatus = true;
                            _statusMessage = 'Checking subscription status...';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Check Status Again',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .pushReplacementNamed(Routes.login);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        child: const Text(
                          'Go to Login',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

