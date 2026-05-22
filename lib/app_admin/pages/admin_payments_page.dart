import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../services/subscription_service.dart';
import '../../core/utils/datetime_utils.dart';
import '../../providers/marketer_provider.dart';
import '../admin_theme.dart';

/// Model for subscription payment
class SubscriptionPayment {
  final String requestId;
  final String userId;
  final String userName;
  final String userEmail;
  final String businessId;
  final String businessName;
  final String planId;
  final String planName;
  final double amount;
  final String currency;
  final String receiptUrl;
  final DateTime requestDate;
  final String status; // pending, approved, declined
  final String? receiptPath;
  final String? businessTier; // pro/basic
  final String? businessClass; // tier1/tier2/tier3
  final String? paymentMethod; // kora, bank_transfer, legacy gateways, etc.
  final String? transactionId; // Gateway transaction/reference
  final bool isLegacyGatewayPayment;
  final bool isKoraPayment;

  SubscriptionPayment({
    this.requestId = '',
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.businessId,
    required this.businessName,
    required this.planId,
    required this.planName,
    required this.amount,
    this.currency = 'NGN',
    required this.receiptUrl,
    required this.requestDate,
    required this.status,
    this.receiptPath,
    this.businessTier,
    this.businessClass,
    this.paymentMethod,
    this.transactionId,
    this.isLegacyGatewayPayment = false,
    this.isKoraPayment = false,
  });

  bool get isGatewayPayment => isKoraPayment || isLegacyGatewayPayment;

  String get providerLabel {
    if (isKoraPayment) return 'Kora';
    if (isLegacyGatewayPayment) return 'Legacy Gateway';
    final method = (paymentMethod ?? '').trim();
    if (method.isEmpty) return 'Manual';
    return method
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  factory SubscriptionPayment.fromFirestore(
    DocumentSnapshot doc,
    Map<String, dynamic> userData,
    Map<String, dynamic> businessData,
  ) {
    final isLegacyGateway = (doc['subscriptionReceiptUrl'] ?? '')
        .toString()
        .toLowerCase()
        .startsWith('flutterwave:');
    final isKora = (doc['subscriptionReceiptUrl'] ?? '')
        .toString()
        .toLowerCase()
        .startsWith('kora:');
    
    return SubscriptionPayment(
      requestId: doc.id,
      userId: doc.id,
      userName: userData['fullName'] ?? userData['name'] ?? 'Unknown',
      userEmail: userData['email'] ?? '',
      businessId: userData['currentBusinessId'] ?? '',
      businessName: businessData['name'] ?? 'Unknown Business',
      planId: doc['subscriptionPlan'] ?? '',
      planName: _getPlanName(doc['subscriptionPlan'] ?? ''),
      amount: (doc['subscriptionAmount'] ?? 0).toDouble(),
      currency: (doc['currency'] ?? 'NGN').toString(),
      receiptUrl: doc['subscriptionReceiptUrl'] ?? '',
      requestDate: parseTimestamp(doc['subscriptionRequestDate'] ?? doc['createdAt']),
      status: doc['subscriptionStatus'] ?? 'pending',
      receiptPath: doc['receiptPath'],
      businessTier: businessData['tier'],
      businessClass: businessData['businessClass'],
      paymentMethod: doc['paymentMethod'],
      transactionId: isLegacyGateway
          ? (doc['subscriptionReceiptUrl'] as String)
              .replaceFirst('flutterwave:', '')
          : isKora
              ? (doc['subscriptionReceiptUrl'] as String).replaceFirst('kora:', '')
              : null,
      isLegacyGatewayPayment: isLegacyGateway,
      isKoraPayment: isKora,
    );
  }

  static String _getPlanName(String planId) {
    // Handle new tier-based plan IDs (t1/t2/t3 with basic/pro and duration)
    if (planId.toLowerCase().startsWith('t')) {
      final plan = SubscriptionService.getPlanById(planId.toLowerCase());
      if (plan != null) {
        return plan.name;
      }
      // Parse ID format: t{class}_{type}_{duration}
      try {
        final parts = planId.toLowerCase().split('_');
        if (parts.length >= 3) {
          final tierClass = parts[0]; // t1, t2, t3
          final planType = parts[1]; // basic, pro
          final duration = parts[2]; // 3m, 6m, 12m
          return '$tierClass.${tierClass[1].toUpperCase()} — ${planType.toUpperCase()} ($duration months)';
        }
      } catch (e) {
        // Fallback below
      }
    }
    
    // Legacy plan names (for backward compatibility)
    switch (planId.toLowerCase()) {
      case 'basic':
        return 'Basic (₦10,000/month)';
      case 'pro':
        return 'Pro (₦20,000/month)';
      case 'enterprise':
        return 'Enterprise (₦100,000/month)';
      default:
        return 'Plan: $planId';
    }
  }
}

/// Model for recorded payment transaction
class PaymentTransaction {
  final String id;
  final String transactionId;
  final String businessId;
  final String? businessName;
  final double amount;
  final String currency;
  final String email;
  final String method;
  final String status;
  final Map<String, dynamic>? processorResponse;
  final DateTime? createdAt;

  PaymentTransaction({
    required this.id,
    required this.transactionId,
    required this.businessId,
    this.businessName,
    required this.amount,
    required this.currency,
    required this.email,
    required this.method,
    required this.status,
    this.processorResponse,
    this.createdAt,
  });

  factory PaymentTransaction.fromFirestore(
      String id, Map<String, dynamic> data) {
    DateTime? created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      created = DateTime.tryParse(data['createdAt']);
    }

    return PaymentTransaction(
      id: id,
      transactionId: data['transactionId'] ?? id,
      businessId: data['businessId'] ?? '',
      businessName: data['businessName'] ?? data['businessId'] ?? 'Unknown',
      amount: (data['amount'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'NGN',
      email: data['email'] ?? '',
      method: data['method'] ?? '',
      status: data['status'] ?? 'pending',
      processorResponse: data['processorResponse'] != null
          ? Map<String, dynamic>.from(data['processorResponse'])
          : null,
      createdAt: created,
    );
  }

  String get createdAtFormatted {
    if (createdAt == null) return 'Unknown date';
    return DateFormat('MMM d, yyyy - h:mm a').format(createdAt!);
  }
}

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<SubscriptionPayment> _pendingPayments = [];
  final List<SubscriptionPayment> _approvedPayments = [];
  final List<SubscriptionPayment> _declinedPayments = [];
  StreamSubscription<QuerySnapshot>? _subscriptionRequestsSub;
  StreamSubscription<QuerySnapshot>? _approvalsSub;
  bool _isLoading = true;
  int _selectedTabIndex = 0;
  String _paymentsSearch = '';
  final List<PaymentTransaction> _transactions = [];
  String _transactionsSearch = '';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  bool _isHeaderExpanded = true;

  /// Helper method to safely format timestamps for display
  String _formatRequestDate(DateTime date) {
    try {
      return DateFormat('MMM d, yyyy - h:mm a').format(date);
    } catch (e) {
      print('[AdminPayments] Error formatting date: $e');
      return 'N/A';
    }
  }

  double _sumPaymentAmounts(List<SubscriptionPayment> payments) {
    return payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
  }

  bool _isTransactionRecognized(PaymentTransaction tx) {
    final status = tx.status.toLowerCase();
    return status == 'approved' ||
        status == 'recognized' ||
        status == 'processed';
  }

  Widget _buildAmountChip({
    required String label,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'NGN ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPayments();

    // Listen for realtime changes to subscription requests and approvals
    _subscriptionRequestsSub = _firestore
        .collection('subscription_requests')
        .snapshots()
        .listen((_) => _loadPayments());

    _approvalsSub = _firestore
        .collection('subscription_approvals')
        .snapshots()
        .listen((_) => _loadPayments());
  }

  @override
  void dispose() {
    _subscriptionRequestsSub?.cancel();
    _approvalsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);

    try {
      _pendingPayments.clear();
      _approvedPayments.clear();
      _declinedPayments.clear();

      // PRIMARY SOURCE: Load all subscription_requests documents (this is the source of truth)
      final allReqSnapshot = await _firestore
          .collection('subscription_requests')
          .get();

      print('[AdminPaymentsPage] Found ${allReqSnapshot.docs.length} subscription_requests documents');

      for (final reqDoc in allReqSnapshot.docs) {
        try {
          final data = reqDoc.data();
          final uid = data['userId'] as String? ?? '';
          final status = (data['status'] as String? ?? 'pending').toLowerCase();
          
          if (uid.isEmpty) {
            print('[AdminPaymentsPage] Skipping subscription_requests ${reqDoc.id} - no userId');
            continue;
          }

          // Fetch user document for fuller context
          final userDoc = await _firestore.collection('users').doc(uid).get();
          if (!userDoc.exists) {
            print('[AdminPaymentsPage] User ${uid} not found for subscription_requests ${reqDoc.id}');
            continue;
          }
          
          final userData = userDoc.data() ?? {};
          final businessId = (data['businessId'] as String? ??
              userData['currentBusinessId'] as String? ??
              '').trim();

          // Fetch business document for tier and class information
          String businessName = 'Unknown Business';
          String? businessTier;
          String? businessClass;
          
          if (businessId.isNotEmpty) {
            try {
              final bdoc = await _firestore.collection('businesses').doc(businessId).get();
              if (bdoc.exists) {
                final bdata = bdoc.data() ?? {};
                businessName = (bdata['name'] as String?) ?? 'Unknown Business';
                businessTier = bdata['subscriptionTier'] as String? ?? bdata['tier'] as String?;
                businessClass = bdata['businessClass'] as String?;
              }
            } catch (e) {
              print('[AdminPaymentsPage] Error fetching business $businessId: $e');
            }
          }

          // Extract plan information from subscription_requests document
          final planId = (data['planId'] as String? ?? '').trim();
          final planName = (data['planName'] as String?) ?? 
              (planId.isNotEmpty ? SubscriptionPayment._getPlanName(planId) : 'Unknown Plan');
          final amount = (data['amount'] ?? 0).toDouble();
          final receiptUrl = (data['receiptUrl'] as String? ?? '').trim();

          // Check if it is a gateway-backed payment.
          final normalizedReceiptUrl = receiptUrl.toLowerCase();
          final isFlutterwave = normalizedReceiptUrl.startsWith('flutterwave:');
          final isKora = normalizedReceiptUrl.startsWith('kora:');

          // Determine status for display
          String displayStatus = 'pending';
          if (status == 'approved') {
            displayStatus = 'approved';
          } else if (status == 'rejected' || status == 'declined') {
            displayStatus = 'declined';
          }

          final payment = SubscriptionPayment(
            requestId: reqDoc.id,
            userId: uid,
            userName: (userData['fullName'] as String?) ?? 
                (userData['name'] as String?) ?? 
                'Unknown',
            userEmail: (userData['email'] as String?) ?? '',
            businessId: businessId,
            businessName: businessName,
            planId: planId,
            planName: planName,
            amount: amount,
            currency: (data['currency'] as String?) ?? 'NGN',
            receiptUrl: receiptUrl,
            requestDate: data['createdAt'] != null
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
            status: displayStatus,
            businessTier: businessTier,
            businessClass: businessClass,
            paymentMethod: data['paymentMethod'] as String?,
            transactionId: isFlutterwave
                ? receiptUrl.replaceFirst('flutterwave:', '')
                : isKora
                    ? receiptUrl.replaceFirst('kora:', '')
                    : ((data['processorTransactionId'] ??
                            data['transactionId']) as String?),
            isLegacyGatewayPayment: isFlutterwave,
            isKoraPayment: isKora,
          );

          // Add payment to appropriate list
          if (displayStatus == 'pending') {
            _pendingPayments.add(payment);
          } else if (displayStatus == 'approved') {
            _approvedPayments.add(payment);
          } else if (displayStatus == 'declined') {
            _declinedPayments.add(payment);
          }

          print('[AdminPaymentsPage] ✓ Loaded ${payment.userName} - ${payment.planName} (${displayStatus})');
        } catch (e) {
          print('[AdminPaymentsPage] Error processing subscription_requests ${reqDoc.id}: $e');
          continue;
        }
      }

      print('[AdminPaymentsPage] Loaded ${_pendingPayments.length} pending, ${_approvedPayments.length} approved, ${_declinedPayments.length} declined');

      // Also load last payment transactions for admin view
      await _loadTransactions();

      // Sort by request date (newest first)
      _pendingPayments.sort((a, b) => b.requestDate.compareTo(a.requestDate));
      _approvedPayments.sort((a, b) => b.requestDate.compareTo(a.requestDate));
      _declinedPayments.sort((a, b) => b.requestDate.compareTo(a.requestDate));
    } catch (e) {
      print('Error loading payments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payments: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTransactions({int limit = 100}) async {
    try {
      _transactions.clear();
      Query query = _firestore.collection('payment_transactions');
      if (_filterStartDate != null)
        query =
            query.where('createdAt', isGreaterThanOrEqualTo: _filterStartDate);
      if (_filterEndDate != null)
        query = query.where('createdAt', isLessThanOrEqualTo: _filterEndDate);
      final snapshot =
          await query.orderBy('createdAt', descending: true).limit(limit).get();
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tx = PaymentTransaction.fromFirestore(doc.id, data);
        // Apply simple client-side search. If search empty, include all.
        if (_transactionsSearch.isEmpty) {
          _transactions.add(tx);
          continue;
        }
        final searchLower = _transactionsSearch.toLowerCase();
        if (tx.transactionId.toLowerCase().contains(searchLower) ||
            tx.email.toLowerCase().contains(searchLower)) {
          _transactions.add(tx);
        }
      }
    } catch (e) {
      print('[AdminPaymentsPage] Error loading transactions: $e');
    }
  }

  Future<void> _approveSubscription(SubscriptionPayment payment) async {
    try {
      // Update user subscription status
      final plan = SubscriptionService.getPlanById(payment.planId);
      final now = DateTime.now();
      final endDate = now.add(Duration(days: plan?.durationInDays ?? 30));
      final updatedRequestIds = <String>[];
      
      // 1. Update user document with subscription details
      await _firestore.collection('users').doc(payment.userId).update({
        'subscriptionStatus': 'approved',
        'hasActiveSubscription': true,
        'subscriptionApprovedAt': now.toIso8601String(),
        'subscriptionApprovedBy': 'admin',
        'subscriptionPlan': payment.planId,
        'subscriptionStartDate': now.toIso8601String(),
        'subscriptionEndDate': endDate.toIso8601String(),
        'subscriptionAmount': payment.amount,
        'subscriptionReceiptUrl': payment.receiptUrl,
        'paymentMethod': payment.paymentMethod,
        'updatedAt': now.toIso8601String(),
      });

      // 2. Update subscription_requests document to mark as approved
      if (payment.transactionId != null || payment.planId.isNotEmpty) {
        try {
          if (payment.requestId.isNotEmpty) {
            await _firestore
                .collection('subscription_requests')
                .doc(payment.requestId)
                .set({
              'status': 'approved',
              'subscriptionStatus': 'approved',
              'approvedAt': now.toIso8601String(),
              'approvedBy': 'admin',
              'revenueRecognized': true,
              'revenueRecognizedAt': now.toIso8601String(),
              'revenueRecognizedBy': 'admin',
              'updatedAt': now.toIso8601String(),
            }, SetOptions(merge: true));
            updatedRequestIds.add(payment.requestId);
          } else {
            final reqQuery = await _firestore
                .collection('subscription_requests')
                .where('userId', isEqualTo: payment.userId)
                .where('planId', isEqualTo: payment.planId)
                .where('status', isEqualTo: 'pending')
                .get();

            for (final doc in reqQuery.docs) {
              await doc.reference.update({
                'status': 'approved',
                'subscriptionStatus': 'approved',
                'approvedAt': now.toIso8601String(),
                'approvedBy': 'admin',
                'revenueRecognized': true,
                'revenueRecognizedAt': now.toIso8601String(),
                'revenueRecognizedBy': 'admin',
                'updatedAt': now.toIso8601String(),
              });
              updatedRequestIds.add(doc.id);
            }
          }
        } catch (e) {
          print('[AdminPaymentsPage] Warning: Could not update subscription_requests: $e');
        }
      }

      // 3. Log the approval action to audit trail
      await _firestore.collection('subscription_approvals').add({
        'userId': payment.userId,
        'userName': payment.userName,
        'userEmail': payment.userEmail,
        'businessId': payment.businessId,
        'businessName': payment.businessName,
        'planId': payment.planId,
        'planName': payment.planName,
        'amount': payment.amount,
        'currency': payment.currency,
        'receiptUrl': payment.receiptUrl,
        'transactionId': payment.transactionId,
        'paymentMethod': payment.paymentMethod,
        'isFlutterwavePayment': payment.isLegacyGatewayPayment,
        'isKoraPayment': payment.isKoraPayment,
        'businessTier': payment.businessTier,
        'businessClass': payment.businessClass,
        'approvedAt': now.toIso8601String(),
        'approvedBy': 'admin',
        'subscriptionStartDate': now.toIso8601String(),
        'subscriptionEndDate': endDate.toIso8601String(),
        'subscriptionDurationDays': plan?.durationInDays ?? 30,
        'approvalSource':
            payment.isGatewayPayment ? 'gateway_transaction' : 'subscription_request',
        'revenueRecognized': true,
        'revenueRecognizedAt': now.toIso8601String(),
        'status': 'approved',
      });

      if (payment.transactionId != null && payment.transactionId!.isNotEmpty) {
        final matchingTransactions = await _firestore
            .collection('payment_transactions')
            .where('transactionId', isEqualTo: payment.transactionId)
            .get();

        for (final doc in matchingTransactions.docs) {
          await doc.reference.update({
            'status': 'processed',
            'approvalStatus': 'approved',
            'approvedAt': now.toIso8601String(),
            'approvedBy': 'admin',
            'revenueRecognized': true,
            'revenueRecognizedAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          });
        }
      }

      // 4. Apply subscription details to the related business(es)
      await _applySubscriptionToBusiness(payment);

      // 5. Credit the referring marketer for new activations and renewals.
      await context.read<MarketerProvider>().creditMarketerRewardForSubscription(
            userId: payment.userId,
            businessId: payment.businessId,
            businessName: payment.businessName,
            userEmail: payment.userEmail,
            planId: payment.planId,
            amount: payment.amount,
            requestId: updatedRequestIds.isNotEmpty
                ? updatedRequestIds.first
                : payment.requestId,
            transactionId: payment.transactionId,
            approvedAt: now,
            approvedBy: 'admin',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Subscription approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // 6. Reload payments to refresh the UI
      await _loadPayments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving subscription: $e')),
        );
      }
    }
  }

  Future<void> _applySubscriptionToBusiness(SubscriptionPayment payment) async {
    try {
      final subscriptionService =
          SubscriptionService(firestore: FirebaseFirestore.instance);
      final plan = SubscriptionService.getPlanById(payment.planId);
      final now = DateTime.now();
      final endDate = now.add(Duration(days: plan?.durationInDays ?? 30));

      // Update the business subscription fields
      final synced = await subscriptionService.syncSubscriptionToBusiness(
        businessId: payment.businessId,
        planId: payment.planId,
        startDate: now,
        endDate: endDate,
      );

      if (!synced) {
        print(
            '[AdminPaymentsPage] Warning: Failed to sync subscription to business ${payment.businessId}');
      }

      await _firestore.collection('businesses').doc(payment.businessId).set({
        'subscriptionStatus': 'approved',
        'subscriptionReviewStatus': 'approved',
        'subscriptionApprovedAt': now.toIso8601String(),
        'subscriptionApprovedBy': 'admin',
        'subscriptionDeclineReason': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('[AdminPaymentsPage] Error applying subscription to business: $e');
    }
  }

  Future<void> _declineSubscription(
    SubscriptionPayment payment,
    String reason,
  ) async {
    try {
      // Update user subscription status
      await _firestore.collection('users').doc(payment.userId).update({
        'subscriptionStatus': 'declined',
        'hasActiveSubscription': false,
        'subscriptionDeclinedAt': DateTime.now().toIso8601String(),
        'subscriptionDeclinedBy': 'admin',
        'subscriptionDeclineReason': reason,
      });

      await _firestore.collection('businesses').doc(payment.businessId).set({
        'isSubscriptionActive': false,
        'subscriptionStatus': 'declined',
        'subscriptionReviewStatus': 'declined',
        'subscriptionDeclinedAt': DateTime.now().toIso8601String(),
        'subscriptionDeclineReason': reason,
        'subscriptionDeclinedBy': 'admin',
      }, SetOptions(merge: true));

      // Log the decline action
      await _firestore.collection('subscription_approvals').add({
        'userId': payment.userId,
        'userName': payment.userName,
        'userEmail': payment.userEmail,
        'planId': payment.planId,
        'amount': payment.amount,
        'currency': payment.currency,
        'receiptUrl': payment.receiptUrl,
        'declinedAt': DateTime.now().toIso8601String(),
        'declinedBy': 'admin',
        'declineReason': reason,
        'revenueRecognized': false,
        'status': 'declined',
      });

      // Also update any matching pending subscription_requests to rejected
      final query = await _firestore
          .collection('subscription_requests')
          .where('userId', isEqualTo: payment.userId)
          .where('planId', isEqualTo: payment.planId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in query.docs) {
        await doc.reference.update({
          'status': 'rejected',
          'rejectedAt': DateTime.now().toIso8601String(),
          'rejectedBy': 'admin',
          'rejectedReason': reason,
          'revenueRecognized': false,
        });
      }

      if (payment.transactionId != null && payment.transactionId!.isNotEmpty) {
        final matchingTransactions = await _firestore
            .collection('payment_transactions')
            .where('transactionId', isEqualTo: payment.transactionId)
            .get();
        for (final doc in matchingTransactions.docs) {
          await doc.reference.update({
            'status': 'declined',
            'approvalStatus': 'declined',
            'declinedAt': DateTime.now().toIso8601String(),
            'declinedBy': 'admin',
            'declineReason': reason,
            'revenueRecognized': false,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Subscription declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Reload payments
      _loadPayments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining subscription: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.adminBackground,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: context.adminHeaderGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subscription Approvals',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: Icon(_isHeaderExpanded ? Icons.expand_less : Icons.expand_more),
                        onPressed: () => setState(() => _isHeaderExpanded = !_isHeaderExpanded),
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: _isHeaderExpanded
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildTabButton(
                                      'Pending',
                                      0,
                                      _pendingPayments.length,
                                      Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTabButton(
                                      'Approved',
                                      1,
                                      _approvedPayments.length,
                                      Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTabButton(
                                      'Declined',
                                      2,
                                      _declinedPayments.length,
                                      Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTabButton(
                                      'Transactions',
                                      3,
                                      _transactions.length,
                                      Colors.blue,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _buildAmountChip(
                                    label: 'Pending Value',
                                    amount: _sumPaymentAmounts(_pendingPayments),
                                    color: Colors.orange,
                                  ),
                                  _buildAmountChip(
                                    label: 'Recognized Revenue',
                                    amount: _sumPaymentAmounts(_approvedPayments),
                                    color: Colors.green,
                                  ),
                                  _buildAmountChip(
                                    label: 'Recognized Tx Value',
                                    amount: _transactions
                                        .where(_isTransactionRecognized)
                                        .fold<double>(
                                          0,
                                          (sum, tx) => sum + tx.amount,
                                        ),
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                              if (_selectedTabIndex != 3) ...[
                                const SizedBox(height: 16),
                                TextField(
                                  onChanged: (value) => setState(
                                    () => _paymentsSearch = value.trim().toLowerCase(),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search user, business, plan, or transaction id',
                                    prefixIcon: const Icon(Icons.search_rounded),
                                    filled: true,
                                    fillColor: context.adminSurface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildPaymentList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(
    String label,
    int index,
    int count,
    Color color,
  ) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () async {
        setState(() => _selectedTabIndex = index);
        if (index == 3) {
          await _loadTransactions();
          setState(() {});
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.adminSurface
              : Colors.white.withOpacity(context.isAdminDark ? 0.14 : 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(
              isSelected ? 0.18 : (context.isAdminDark ? 0.08 : 0.12),
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? context.adminTextPrimary : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 80),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(context.isAdminDark ? 0.10 : 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(context.isAdminDark ? 0.10 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Color _paymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
        return Colors.green;
      case 'rejected':
      case 'declined':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _paymentStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
        return Icons.verified_rounded;
      case 'rejected':
      case 'declined':
        return Icons.cancel_rounded;
      default:
        return Icons.pending_actions_rounded;
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
        return 'Approved';
      case 'rejected':
      case 'declined':
        return 'Declined';
      default:
        return 'Pending Review';
    }
  }

  Color _transactionStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'approved':
      case 'processed':
      case 'recognized':
        return Colors.green;
      case 'failed':
      case 'declined':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _formatMoney(double amount, {String currency = 'NGN'}) {
    return '$currency ${amount.toStringAsFixed(0)}';
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    Color? accent,
  }) {
    final iconColor = accent ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.adminSurfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.adminBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.adminTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.adminTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentList() {
    final payments = _selectedTabIndex == 0
        ? _pendingPayments
        : _selectedTabIndex == 1
            ? _approvedPayments
            : _declinedPayments;

    if (_selectedTabIndex == 3) {
      return _buildStyledTransactionsList();
    }

    final filteredPayments = payments.where((payment) {
      if (_paymentsSearch.isEmpty) return true;
      final search = _paymentsSearch;
      return payment.userName.toLowerCase().contains(search) ||
          payment.userEmail.toLowerCase().contains(search) ||
          payment.businessName.toLowerCase().contains(search) ||
          payment.planName.toLowerCase().contains(search) ||
          (payment.transactionId ?? '').toLowerCase().contains(search);
    }).toList();

    if (filteredPayments.isEmpty) {
      return Center(
        child: Text(
          _paymentsSearch.isEmpty
              ? 'No ${['pending', 'approved', 'declined'][_selectedTabIndex].toLowerCase()} subscriptions'
              : 'No subscription requests match your search',
          style: TextStyle(color: context.adminTextSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredPayments.length,
      itemBuilder: (context, index) {
        final payment = filteredPayments[index];
        return _buildStyledPaymentCard(payment);
      },
    );
  }

  Widget _buildPaymentCard(SubscriptionPayment payment) {
    Color statusColor;
    String statusLabel;

    if (payment.status == 'pending') {
      statusColor = Colors.orange;
      statusLabel = '⏳ Pending';
    } else if (payment.status == 'approved' || payment.status == 'active') {
      statusColor = Colors.green;
      statusLabel = '✓ Approved';
    } else {
      statusColor = Colors.red;
      statusLabel = '✗ Declined';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header row with user info and status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // User avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      payment.userName.isNotEmpty
                          ? payment.userName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        payment.userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(height: 1, color: Colors.grey[200]),
          // Details section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan and amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subscription Plan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.planName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₦${payment.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Business tier and class
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.businessName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    if (payment.businessClass != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getTierClassColor(payment.businessClass!).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          payment.businessClass!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getTierClassColor(payment.businessClass!),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Request date and payment method
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Requested: ${_formatRequestDate(payment.requestDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    if (payment.isGatewayPayment)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D084).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.payment, size: 12, color: Color(0xFF00D084)),
                            const SizedBox(width: 4),
                            Text(
                              payment.providerLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00D084),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Receipt section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  payment.isGatewayPayment ? 'Gateway Reference' : 'Receipt',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                if (payment.isGatewayPayment)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${payment.providerLabel}: ${payment.transactionId ?? payment.receiptUrl}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (payment.receiptUrl.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.orange.withOpacity(0.35)),
                    ),
                    child: const Text(
                      'Legacy manual request without proof. New subscriptions should be paid through Kora checkout.',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  // Receipt exists - show preview and action buttons
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // When narrow, stack thumbnail and buttons vertically to avoid overflow
                      if (constraints.maxWidth < 360) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Receipt preview thumbnail
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: payment.receiptUrl.isNotEmpty
                                    ? Image.network(
                                        payment.receiptUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey[400],
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.grey[100],
                                        child: Center(
                                          child: Text(
                                            'No receipt',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: payment.receiptUrl.isNotEmpty
                                        ? () {
                                            _showReceiptDialog(payment);
                                          }
                                        : null,
                                    icon:
                                        const Icon(Icons.visibility, size: 16),
                                    label: const Text('View'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      backgroundColor: payment.receiptUrl.isNotEmpty ? Colors.blue : Colors.grey[300],
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: payment.receiptUrl.isNotEmpty
                                        ? () async {
                                            if (await canLaunchUrl(
                                                Uri.parse(payment.receiptUrl))) {
                                              await launchUrl(
                                                Uri.parse(payment.receiptUrl),
                                                mode: LaunchMode.externalApplication,
                                              );
                                            }
                                          }
                                        : null,
                                    icon: const Icon(Icons.download, size: 16),
                                    label: const Text('Download'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      backgroundColor: payment.receiptUrl.isNotEmpty ? Colors.grey[700] : Colors.grey[300],
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      // Default wide layout
                      return Row(
                        children: [
                          // Receipt preview thumbnail
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: payment.receiptUrl.isNotEmpty
                                  ? Image.network(
                                      payment.receiptUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey[400],
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: Colors.grey[100],
                                      child: Center(
                                        child: Text(
                                          'No receipt',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // View and download buttons
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: payment.receiptUrl.isNotEmpty
                                            ? () {
                                                _showReceiptDialog(payment);
                                              }
                                            : null,
                                        icon:
                                            const Icon(Icons.visibility, size: 16),
                                        label: const Text('View'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          backgroundColor: payment.receiptUrl.isNotEmpty ? Colors.blue : Colors.grey[300],
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: payment.receiptUrl.isNotEmpty
                                            ? () async {
                                                if (await canLaunchUrl(
                                                    Uri.parse(payment.receiptUrl))) {
                                                  await launchUrl(
                                                    Uri.parse(payment.receiptUrl),
                                                    mode: LaunchMode.externalApplication,
                                                  );
                                                }
                                              }
                                            : null,
                                        icon: const Icon(Icons.download, size: 16),
                                        label: const Text('Download'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          backgroundColor: payment.receiptUrl.isNotEmpty ? Colors.grey[700] : Colors.grey[300],
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          // Action buttons (for pending payments only)
          if (payment.status == 'pending')
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showDeclineDialog(payment);
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Decline'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showApproveConfirmation(payment);
                          },
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
      return Center(
        child: Text(
          'No transactions',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return Column(
      children: [
        // Search and date filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by transaction ID or email',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) async {
                    setState(() => _transactionsSearch = v.trim());
                    await _loadTransactions();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _filterStartDate = picked.start;
                      _filterEndDate = picked.end;
                    });
                    await _loadTransactions();
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.date_range),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _transactions.length,
            itemBuilder: (context, index) {
              final tx = _transactions[index];
              return _buildStyledTransactionCard(tx);
            },
          ),
        )
      ],
    );
  }

  Widget _buildTransactionCard(PaymentTransaction tx) {
    final statusColor = tx.status == 'completed'
        ? Colors.green
        : tx.status == 'failed'
            ? Colors.red
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.transactionId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tx.email,
                        style: TextStyle(color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₦${tx.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child:
                          Text(tx.status, style: TextStyle(color: statusColor)),
                    )
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Business: ${tx.businessName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Method: ${tx.method} • ${tx.createdAtFormatted}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (tx.status == 'completed')
                  ElevatedButton.icon(
                    onPressed: () => _approveTransaction(tx),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve as Subscription'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ElevatedButton.icon(
                  onPressed: () => _showDeclineTransactionDialog(tx),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Decline'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTransactionDetails(tx),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledTransactionsList() {
    if (_transactions.isEmpty) {
      return Center(
        child: Text(
          'No transactions',
          style: TextStyle(color: context.adminTextSecondary),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: context.adminCardDecoration(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by transaction ID or email',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: context.adminSurfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) async {
                    setState(() => _transactionsSearch = v.trim());
                    await _loadTransactions();
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_filterStartDate != null || _filterEndDate != null)
                      _buildMetaChip(
                        label:
                            '${_filterStartDate == null ? 'Any' : DateFormat('dd MMM').format(_filterStartDate!)} - ${_filterEndDate == null ? 'Any' : DateFormat('dd MMM').format(_filterEndDate!)}',
                        color: const Color(0xFF3B82F6),
                        icon: Icons.date_range_rounded,
                      ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _filterStartDate = picked.start;
                            _filterEndDate = picked.end;
                          });
                          await _loadTransactions();
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.date_range_rounded, size: 16),
                      label: const Text('Filter Date'),
                    ),
                    if (_filterStartDate != null || _filterEndDate != null)
                      TextButton(
                        onPressed: () async {
                          setState(() {
                            _filterStartDate = null;
                            _filterEndDate = null;
                          });
                          await _loadTransactions();
                          setState(() {});
                        },
                        child: const Text('Clear Filter'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _transactions.length,
            itemBuilder: (context, index) {
              final tx = _transactions[index];
              return _buildStyledTransactionCard(tx);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStyledPaymentCard(SubscriptionPayment payment) {
    final statusColor = _paymentStatusColor(payment.status);
    final statusLabel = _paymentStatusLabel(payment.status);
    final statusIcon = _paymentStatusIcon(payment.status);
    final amountLabel = _formatMoney(payment.amount, currency: payment.currency);
    final paymentMethod =
        (payment.paymentMethod ?? '').trim().replaceAll('_', ' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      payment.userName.isNotEmpty
                          ? payment.userName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.userName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.adminTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        payment.userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.adminTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildMetaChip(
                            label: statusLabel,
                            color: statusColor,
                            icon: statusIcon,
                          ),
                          if (payment.isGatewayPayment)
                            _buildMetaChip(
                              label: payment.providerLabel,
                              color: const Color(0xFF00D084),
                              icon: Icons.payment_rounded,
                            ),
                          if (payment.businessClass != null &&
                              payment.businessClass!.trim().isNotEmpty)
                            _buildMetaChip(
                              label: payment.businessClass!.toUpperCase(),
                              color:
                                  _getTierClassColor(payment.businessClass!),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatRequestDate(payment.requestDate),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.adminTextSecondary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Divider(color: context.adminBorder, height: 1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;
                final metricWidth = isNarrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: metricWidth,
                      child: _buildMetricTile(
                        icon: Icons.workspace_premium_rounded,
                        label: 'Subscription Plan',
                        value: payment.planName,
                        accent: const Color(0xFF8B5CF6),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _buildMetricTile(
                        icon: Icons.storefront_rounded,
                        label: 'Business',
                        value: payment.businessName,
                        accent: const Color(0xFF3B82F6),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _buildMetricTile(
                        icon: Icons.schedule_rounded,
                        label: 'Requested',
                        value: _formatRequestDate(payment.requestDate),
                        accent: const Color(0xFFF59E0B),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _buildMetricTile(
                        icon: payment.isGatewayPayment
                            ? Icons.verified_rounded
                            : Icons.receipt_long_rounded,
                        label: 'Payment Reference',
                        value: payment.transactionId?.isNotEmpty == true
                            ? payment.transactionId!
                            : (paymentMethod.isNotEmpty
                                ? paymentMethod
                                : 'Manual review'),
                        accent: statusColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.adminSurfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.adminBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        payment.isGatewayPayment
                            ? Icons.verified_rounded
                            : Icons.receipt_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        payment.isGatewayPayment
                            ? 'Gateway Verification'
                            : 'Receipt Evidence',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.adminTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    payment.receiptUrl.isEmpty
                        ? 'No proof of payment has been uploaded yet.'
                        : payment.isGatewayPayment
                            ? 'This subscription was verified automatically through ${payment.providerLabel}. No receipt upload is required.'
                            : 'Preview the uploaded receipt, download it externally, or replace it with a clearer upload.',
                    style: TextStyle(
                      color: context.adminTextSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (payment.isGatewayPayment)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D084).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF00D084).withOpacity(0.28),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_person_rounded,
                            color: Color(0xFF00A86B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${payment.providerLabel} reference: ${payment.transactionId ?? payment.receiptUrl}',
                              style: TextStyle(
                                color: context.adminTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (payment.receiptUrl.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.28),
                        ),
                      ),
                      child: Text(
                        'Legacy manual request without proof. Ask the owner to retry through Kora checkout.',
                        style: TextStyle(
                          color: context.adminTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final verticalLayout = constraints.maxWidth < 430;
                        final preview = Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: context.adminSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.adminBorder),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            payment.receiptUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: context.adminTextTertiary,
                                ),
                              );
                            },
                          ),
                        );

                        final actions = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _showStyledReceiptDialog(payment),
                              icon: const Icon(
                                Icons.visibility_rounded,
                                size: 16,
                              ),
                              label: const Text('View'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                if (await canLaunchUrl(
                                  Uri.parse(payment.receiptUrl),
                                )) {
                                  await launchUrl(
                                    Uri.parse(payment.receiptUrl),
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 16,
                              ),
                              label: const Text('Download'),
                            ),
                          ],
                        );

                        if (verticalLayout) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              preview,
                              const SizedBox(height: 12),
                              actions,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            preview,
                            const SizedBox(width: 14),
                            Expanded(child: actions),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          if (payment.status == 'pending')
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => _showStyledApproveConfirmation(payment),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Approve Subscription'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showStyledDeclineDialog(payment),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Decline Request'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStyledTransactionCard(PaymentTransaction tx) {
    final statusColor = _transactionStatusColor(tx.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.transactionId,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.adminTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tx.email,
                        style: TextStyle(color: context.adminTextSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatMoney(tx.amount, currency: tx.currency),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildMetaChip(
                      label: tx.status.toUpperCase(),
                      color: statusColor,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;
                final metricWidth = isNarrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: metricWidth,
                      child: _buildMetricTile(
                        icon: Icons.storefront_rounded,
                        label: 'Business',
                        value: tx.businessName ?? 'Unknown business',
                        accent: const Color(0xFF3B82F6),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _buildMetricTile(
                        icon: Icons.payments_rounded,
                        label: 'Method',
                        value: tx.method.isEmpty ? 'Not set' : tx.method,
                        accent: const Color(0xFF8B5CF6),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _buildMetricTile(
                        icon: Icons.schedule_rounded,
                        label: 'Created',
                        value: tx.createdAtFormatted,
                        accent: const Color(0xFFF59E0B),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _buildMetricTile(
                        icon: Icons.description_outlined,
                        label: 'Processor Notes',
                        value: tx.processorResponse?['message']?.toString() ??
                            tx.processorResponse?['status']?.toString() ??
                            'No processor details',
                        accent: statusColor,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (tx.status.toLowerCase() == 'completed')
                  FilledButton.icon(
                    onPressed: () => _approveTransaction(tx),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve as Subscription'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _showStyledDeclineTransactionDialog(tx),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showStyledTransactionDetails(tx),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.adminTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.adminTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showStyledTransactionDetails(PaymentTransaction tx) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Transaction Details',
          style: TextStyle(color: context.adminTextPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogDetailRow('Transaction ID', tx.transactionId),
              _buildDialogDetailRow('Email', tx.email),
              _buildDialogDetailRow(
                'Amount',
                _formatMoney(tx.amount, currency: tx.currency),
              ),
              _buildDialogDetailRow('Status', tx.status.toUpperCase()),
              _buildDialogDetailRow(
                'Method',
                tx.method.isEmpty ? 'Not set' : tx.method,
              ),
              _buildDialogDetailRow(
                'Business',
                tx.businessName ?? 'Unknown business',
              ),
              _buildDialogDetailRow(
                'Processor Details',
                tx.processorResponse?.toString() ?? 'N/A',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStyledDeclineTransactionDialog(PaymentTransaction tx) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Decline Transaction',
          style: TextStyle(color: context.adminTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tx.transactionId,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.adminTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason for decline',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              reasonCtrl.dispose();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _declineTransaction(tx, reasonCtrl.text);
              reasonCtrl.dispose();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  void _showStyledReceiptDialog(SubscriptionPayment payment) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          decoration: BoxDecoration(
            color: context.adminSurface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Receipt Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.adminTextPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.adminSurfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.adminBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      payment.receiptUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return SizedBox(
                          height: 300,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 48,
                                  color: context.adminTextTertiary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Could not load image',
                                  style: TextStyle(
                                    color: context.adminTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: FilledButton.icon(
                  onPressed: () async {
                    if (await canLaunchUrl(Uri.parse(payment.receiptUrl))) {
                      await launchUrl(
                        Uri.parse(payment.receiptUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download Receipt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStyledApproveConfirmation(SubscriptionPayment payment) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Approve Subscription?',
          style: TextStyle(color: context.adminTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogDetailRow('User', payment.userName),
            _buildDialogDetailRow('Plan', payment.planName),
            _buildDialogDetailRow(
              'Amount',
              _formatMoney(payment.amount, currency: payment.currency),
            ),
            Text(
              'This will activate the subscription for this user and sync the related business subscription state.',
              style: TextStyle(color: context.adminTextSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _approveSubscription(payment);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showStyledDeclineDialog(SubscriptionPayment payment) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Decline Subscription',
          style: TextStyle(color: context.adminTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogDetailRow('User', payment.userName),
            _buildDialogDetailRow('Plan', payment.planName),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter decline reason...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              reasonController.dispose();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _declineSubscription(payment, reasonController.text);
              reasonController.dispose();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(PaymentTransaction tx) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Transaction ${tx.transactionId}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${tx.email}'),
                const SizedBox(height: 8),
                Text('Amount: ₦${tx.amount.toStringAsFixed(0)}'),
                const SizedBox(height: 8),
                Text('Status: ${tx.status}'),
                const SizedBox(height: 8),
                Text('Method: ${tx.method}'),
                const SizedBox(height: 8),
                Text('Business: ${tx.businessName}'),
                const SizedBox(height: 8),
                Text('Details: ${tx.processorResponse ?? 'N/A'}'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        );
      },
    );
  }

  void _showDeclineTransactionDialog(PaymentTransaction tx) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Decline Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Transaction: ${tx.transactionId}'),
              const SizedBox(height: 8),
              TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(hintText: 'Reason for decline')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  reasonCtrl.dispose();
                },
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _declineTransaction(tx, reasonCtrl.text);
                  reasonCtrl.dispose();
                },
                child: const Text('Decline')),
          ],
        );
      },
    );
  }

  Future<void> _declineTransaction(PaymentTransaction tx, String reason) async {
    try {
      // Update transaction status
      final query = await _firestore
          .collection('payment_transactions')
          .where('transactionId', isEqualTo: tx.transactionId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'status': 'declined',
          'approvalStatus': 'declined',
          'declinedAt': DateTime.now().toIso8601String(),
          'declinedBy': 'admin',
          'declineReason': reason,
          'revenueRecognized': false,
        });
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Transaction declined')));
      await _loadTransactions();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining transaction: $e')));
    }
  }

  Future<void> _approveTransaction(PaymentTransaction tx) async {
    try {
      // Try to locate a subscription request matching this transaction
      final reqQuery = await _firestore
          .collection('subscription_requests')
          .where('transactionId', isEqualTo: tx.transactionId)
          .limit(1)
          .get();
      if (reqQuery.docs.isNotEmpty) {
        final req = reqQuery.docs.first.data();
        final uid = req['userId'] as String? ?? '';
        if (uid.isNotEmpty) {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final payment = SubscriptionPayment(
              requestId: reqQuery.docs.first.id,
              userId: uid,
              userName: userData['fullName'] ?? userData['name'] ?? 'Unknown',
              userEmail: userData['email'] ?? '',
              businessId:
                  req['businessId'] ?? userData['currentBusinessId'] ?? '',
              businessName: (await _firestore
                          .collection('businesses')
                          .doc(req['businessId'])
                          .get())
                      .data()?['name'] ??
                  'Business',
              planId: req['planId'] ?? '',
              planName: req['planName'] ??
                  SubscriptionPayment._getPlanName(req['planId'] ?? ''),
              amount: (req['amount'] ?? 0).toDouble(),
              currency: (req['currency'] as String?) ?? tx.currency,
              receiptUrl: req['receiptUrl'] ??
                  tx.processorResponse?['receiptUrl'] ??
                  '',
              requestDate: req['createdAt'] != null
                  ? (req['createdAt'] as Timestamp).toDate()
                  : DateTime.now(),
              status: 'pending',
            );

            await _approveSubscription(payment);
            // Update transaction status as processed
            final qTx = await _firestore
                .collection('payment_transactions')
                .where('transactionId', isEqualTo: tx.transactionId)
                .limit(1)
                .get();
            if (qTx.docs.isNotEmpty) {
              await qTx.docs.first.reference.update({
                'status': 'processed',
                'approvalStatus': 'approved',
                'approvedBy': 'admin',
                'processedAt': DateTime.now().toIso8601String(),
                'revenueRecognized': true,
                'revenueRecognizedAt': DateTime.now().toIso8601String(),
              });
            }

            await _loadTransactions();
            setState(() {});
            return;
          }
        }
      }

      // Fallback: try to find user by email
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: tx.email)
          .limit(1)
          .get();
      if (userQuery.docs.isNotEmpty) {
        final uid = userQuery.docs.first.id;
        final userData = userQuery.docs.first.data();
        final businessId = userData['currentBusinessId'] ?? '';
        const planId = 'basic';
        final payment = SubscriptionPayment(
          userId: uid,
          userName: userData['fullName'] ?? userData['name'] ?? 'Unknown',
          userEmail: tx.email,
          businessId: businessId,
          businessName:
              (await _firestore.collection('businesses').doc(businessId).get())
                      .data()?['name'] ??
                  'Business',
          planId: planId,
          planName: SubscriptionPayment._getPlanName(planId),
          amount: tx.amount,
          currency: tx.currency,
          receiptUrl: tx.processorResponse?['receiptUrl'] ?? '',
          requestDate: tx.createdAt ?? DateTime.now(),
          status: 'pending',
        );

        await _approveSubscription(payment);
        final qTx = await _firestore
            .collection('payment_transactions')
            .where('transactionId', isEqualTo: tx.transactionId)
            .limit(1)
            .get();
        if (qTx.docs.isNotEmpty) {
          await qTx.docs.first.reference.update({
            'status': 'processed',
            'approvalStatus': 'approved',
            'approvedBy': 'admin',
            'processedAt': DateTime.now().toIso8601String(),
            'revenueRecognized': true,
            'revenueRecognizedAt': DateTime.now().toIso8601String(),
          });
        }

        await _loadTransactions();
        setState(() {});
        return;
      }

      // If we could not match to a user, notify admin
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No matching subscription or user found for this transaction')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving transaction: $e')));
    }
  }

  void _showReceiptDialog(SubscriptionPayment payment) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Receipt Preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Image
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Image.network(
                      payment.receiptUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 300,
                          color: Colors.grey[200],
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Could not load image',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Footer with download button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (await canLaunchUrl(Uri.parse(payment.receiptUrl))) {
                      await launchUrl(
                        Uri.parse(payment.receiptUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showApproveConfirmation(SubscriptionPayment payment) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Approve Subscription?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User: ${payment.userName}'),
              const SizedBox(height: 8),
              Text('Plan: ${payment.planName}'),
              const SizedBox(height: 8),
              Text('Amount: ₦${payment.amount.toStringAsFixed(0)}'),
              const SizedBox(height: 16),
              const Text(
                'This will activate the subscription for this user.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _approveSubscription(payment);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child:
                  const Text('Approve', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDeclineDialog(SubscriptionPayment payment) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Decline Subscription'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User: ${payment.userName}'),
              const SizedBox(height: 8),
              Text('Plan: ${payment.planName}'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Enter decline reason...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                reasonController.dispose();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _declineSubscription(payment, reasonController.text);
                reasonController.dispose();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child:
                  const Text('Decline', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// Get color for business class/tier display
  Color _getTierClassColor(String tierClass) {
    switch (tierClass.toLowerCase()) {
      case 'tier1':
      case 't1':
        return const Color(0xFF3B82F6); // Blue
      case 'tier2':
      case 't2':
        return const Color(0xFF8B5CF6); // Purple
      case 'tier3':
      case 't3':
        return const Color(0xFFDC2626); // Red
      default:
        return Colors.grey;
    }
  }
}


