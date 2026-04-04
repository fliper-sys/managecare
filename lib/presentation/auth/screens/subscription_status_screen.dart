import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/subscription_service.dart';
import 'worker_business_assignment_screen.dart';

class SubscriptionStatusScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String userName;
  final String? businessId;
  final String? businessType;
  final String subscriptionPlan;
  final double subscriptionAmount;

  const SubscriptionStatusScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.businessId,
    this.businessType,
    required this.subscriptionPlan,
    required this.subscriptionAmount,
  });

  @override
  State<SubscriptionStatusScreen> createState() =>
      _SubscriptionStatusScreenState();
}

class _SubscriptionStatusScreenState extends State<SubscriptionStatusScreen> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _statusListener;
  bool _subscriptionApproved = false;
  bool _checkingStatus = true;
  String _statusMessage = 'Checking subscription status...';
  String _displayStatus = 'Checking...';
  String? _resolvedBusinessId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      final role = authProvider.currentUser?.role.toLowerCase();
      if (role == 'worker') {
        setState(() {
          _checkingStatus = false;
          _statusMessage = 'Subscription management is handled by the business owner.';
          _displayStatus = 'Not Required';
        });
        return;
      }

      await _startListening();
    });
  }

  String? _resolveBusinessId() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    final explicitBusinessId = widget.businessId?.trim() ?? '';
    if (explicitBusinessId.isNotEmpty) return explicitBusinessId;

    final currentBusinessId = user?.currentBusinessId?.trim() ?? '';
    if (currentBusinessId.isNotEmpty) return currentBusinessId;

    final primaryBusinessId = user?.primaryBusinessId.trim() ?? '';
    if (primaryBusinessId.isNotEmpty) return primaryBusinessId;

    final legacyBusinessId = user?.businessId.trim() ?? '';
    if (legacyBusinessId.isNotEmpty) return legacyBusinessId;

    return null;
  }

  Future<void> _startListening() async {
    final businessId = _resolveBusinessId();
    if (businessId == null || businessId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _checkingStatus = false;
        _displayStatus = 'No Business';
        _statusMessage =
            'No business is linked to this account yet, so we could not check subscription approval.';
      });
      return;
    }

    _resolvedBusinessId = businessId;
    await _statusListener?.cancel();
    _statusListener = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!snapshot.exists) {
          if (!mounted) return;
          setState(() {
            _checkingStatus = false;
            _displayStatus = 'Missing';
            _statusMessage = 'This business record could not be found.';
          });
          return;
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        final reviewStatus =
            (data['subscriptionReviewStatus'] ?? data['subscriptionStatus'])
                ?.toString()
                .toLowerCase();
        final isActive = data['isSubscriptionActive'] as bool? ?? false;

        if (!mounted) return;

        if (isActive || reviewStatus == 'approved' || reviewStatus == 'active') {
          _subscriptionApproved = true;
          setState(() {
            _checkingStatus = false;
            _displayStatus = 'Approved';
            _statusMessage =
                'Subscription approved! Redirecting you to your dashboard...';
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _navigateToDashboard();
          });
          return;
        }

        if (reviewStatus == 'rejected') {
          setState(() {
            _checkingStatus = false;
            _displayStatus = 'Rejected';
            _statusMessage =
                'This subscription request was rejected. Please resubmit a valid payment request.';
          });
          return;
        }

        if (reviewStatus == 'expired') {
          setState(() {
            _checkingStatus = false;
            _displayStatus = 'Expired';
            _statusMessage =
                'This business subscription has expired. Renew it to continue using paid features.';
          });
          return;
        }

        setState(() {
          _checkingStatus = false;
          _displayStatus = 'Pending Approval';
          _statusMessage =
              'Your subscription is pending admin approval. Please check back shortly.';
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _checkingStatus = false;
          _displayStatus = 'Error';
          _statusMessage = 'Error checking status. Please try again.';
        });
      },
    );
  }

  Future<void> _refreshStatus() async {
    final businessId = _resolvedBusinessId ?? _resolveBusinessId();
    if (businessId == null || businessId.isEmpty) {
      await _startListening();
      return;
    }

    setState(() {
      _checkingStatus = true;
      _displayStatus = 'Checking...';
      _statusMessage = 'Checking subscription status...';
    });

    await SubscriptionService(
      firestore: FirebaseFirestore.instance,
    ).validateAndUpdateBusinessSubscriptionStatus(
      businessId,
      userId: widget.userId,
    );

    await _startListening();
  }

  void _navigateToDashboard() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      Navigator.of(context).pushReplacementNamed(Routes.splash);
      return;
    }

    if (user.isOwner) {
      Navigator.of(context).pushReplacementNamed(Routes.ownerDashboard);
      return;
    }

    final primaryBiz = user.primaryBusinessId;
    if (primaryBiz.isEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkerBusinessAssignmentScreen(userId: user.id),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacementNamed(Routes.workerDashboard);
  }

  @override
  void dispose() {
    _statusListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_checkingStatus,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Subscription Status'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: !_checkingStatus,
          actions: _checkingStatus
              ? const []
              : [
                  TextButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushReplacementNamed(Routes.login);
                      }
                    },
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                Text(
                  _subscriptionApproved ? 'Subscription Approved!' : _displayStatus,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
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
                      _buildDetailRow('Email', widget.userEmail),
                      const SizedBox(height: 12),
                      _buildDetailRow('Plan', widget.subscriptionPlan.toUpperCase()),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Amount',
                        widget.subscriptionAmount.toStringAsFixed(0),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Business ID',
                        _resolvedBusinessId ?? widget.businessId ?? 'N/A',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Status', _displayStatus),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
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
                          Icon(Icons.info, color: Colors.blue, size: 20),
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
                            ? 'This business now has active subscription access. You will be redirected shortly.'
                            : 'An admin will review this business subscription request and approve it as soon as possible.',
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
                if (!_subscriptionApproved && !_checkingStatus)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: _refreshStatus,
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
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
