import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';

enum _DayFilter { all, today, days7, days30 }

class SubscriptionTransactionsScreen extends StatefulWidget {
  const SubscriptionTransactionsScreen({super.key});

  @override
  State<SubscriptionTransactionsScreen> createState() => _SubscriptionTransactionsScreenState();
}

class _SubscriptionTransactionsScreenState extends State<SubscriptionTransactionsScreen> {
  _DayFilter _selected = _DayFilter.all;

  String? _resolveBusinessId(BuildContext context) {
    final bp = context.read<BusinessProvider>();
    final businessId = bp.currentBusiness?.id;
    if (businessId != null && businessId.isNotEmpty) return businessId;
    final user = context.read<AuthProvider>().currentUser;
    final primary = user?.primaryBusinessId;
    return (primary != null && primary.isNotEmpty) ? primary : null;
  }

  DateTime? _parseCreatedAt(dynamic raw) {
    try {
      if (raw == null) return null;
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw);
      }
    } catch (_) {}
    return null;
  }

  bool _matchesFilter(DateTime? dt) {
    if (_selected == _DayFilter.all) return true;
    if (dt == null) return false;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    switch (_selected) {
      case _DayFilter.today:
        return dt.isAfter(startOfToday) || dt.isAtSameMomentAs(startOfToday);
      case _DayFilter.days7:
        return dt.isAfter(now.subtract(const Duration(days: 7)));
      case _DayFilter.days30:
        return dt.isAfter(now.subtract(const Duration(days: 30)));
      case _DayFilter.all:
        return true;
    }
  }

  Future<Map<String, dynamic>> _loadCurrentSubscriptionSummary({
    required String? businessId,
    required String? userId,
  }) async {
    final summary = <String, dynamic>{
      'id': 'current-subscription',
      'title': 'Current subscription',
      'status': 'active',
      'planId': '',
      'amount': null,
      'receiptUrl': null,
      'createdAt': null,
      'businessId': businessId,
      'userId': userId,
    };

    if (businessId != null && businessId.isNotEmpty) {
      try {
        final businessDoc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .get();
        if (businessDoc.exists) {
          final businessData = businessDoc.data() ?? {};
          final businessName = (businessData['name'] ?? businessData['businessName'] ?? '').toString();
          if (businessName.isNotEmpty) {
            summary['businessName'] = businessName;
            summary['title'] = 'Active subscription for $businessName';
          }

          final businessStatus = (businessData['subscriptionStatus'] ?? businessData['status'] ?? '').toString();
          final hasActiveBusiness = businessData['isSubscriptionActive'] == true ||
              businessData['hasActiveSubscription'] == true;
          summary['status'] = businessStatus.isNotEmpty
              ? businessStatus
              : (hasActiveBusiness ? 'active' : 'inactive');
          summary['planId'] = (businessData['subscriptionPlan'] ?? businessData['subscriptionTier'] ?? businessData['planId'] ?? '').toString();
          summary['amount'] = (businessData['subscriptionAmount'] as num?)?.toDouble();
          summary['receiptUrl'] = businessData['subscriptionReceiptUrl']?.toString();
          summary['createdAt'] = businessData['subscriptionStartDate'] ??
              businessData['subscriptionActivatedAt'] ??
              businessData['updatedAt'];
        }
      } catch (_) {}
    }

    if (userId != null && userId.isNotEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          if ((summary['businessName'] ?? '').toString().isEmpty) {
            final userBusinessName = (userData['businessName'] ?? userData['currentBusinessName'] ?? '').toString();
            if (userBusinessName.isNotEmpty) {
              summary['businessName'] = userBusinessName;
              summary['title'] = 'Active subscription for $userBusinessName';
            }
          }

          final userStatus = (userData['subscriptionStatus'] ?? '').toString();
          final hasActiveUser = userData['hasActiveSubscription'] == true ||
              userData['isSubscriptionActive'] == true;
          if (userStatus.isNotEmpty) {
            summary['status'] = userStatus;
          } else if (!hasActiveUser && summary['status'] == 'active') {
            summary['status'] = 'inactive';
          }

          if ((summary['planId'] as String).isEmpty) {
            summary['planId'] = (userData['subscriptionPlan'] ?? userData['subscriptionTier'] ?? '').toString();
          }
          if (summary['amount'] == null) {
            summary['amount'] = (userData['subscriptionAmount'] as num?)?.toDouble();
          }
          if ((summary['receiptUrl'] as String?) == null || (summary['receiptUrl'] as String).isEmpty) {
            summary['receiptUrl'] = userData['subscriptionReceiptUrl']?.toString();
          }
          if (summary['createdAt'] == null) {
            summary['createdAt'] = userData['subscriptionStartDate'] ??
                userData['subscriptionActivatedAt'] ??
                userData['updatedAt'];
          }
        }
      } catch (_) {}
    }

    return summary;
  }

  @override
  Widget build(BuildContext context) {
    final businessId = _resolveBusinessId(context);
    final userId = context.read<AuthProvider>().currentUser?.id;

    final baseQuery = FirebaseFirestore.instance.collection('subscription_requests');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Transactions'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text('Show:'),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All'),
                  selected: _selected == _DayFilter.all,
                  onSelected: (_) => setState(() => _selected = _DayFilter.all),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Today'),
                  selected: _selected == _DayFilter.today,
                  onSelected: (_) => setState(() => _selected = _DayFilter.today),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('7 days'),
                  selected: _selected == _DayFilter.days7,
                  onSelected: (_) => setState(() => _selected = _DayFilter.days7),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('30 days'),
                  selected: _selected == _DayFilter.days30,
                  onSelected: (_) => setState(() => _selected = _DayFilter.days30),
                ),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: baseQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                final requestDocs = docs.where((doc) {
                  final d = doc.data();
                  final businessMatch = (businessId == null || businessId.isEmpty)
                      ? true
                      : (d['businessId'] ?? '').toString() == businessId;
                  final userMatch = (userId == null || userId.isEmpty)
                      ? true
                      : (d['userId'] ?? '').toString() == userId;
                  return businessMatch && userMatch;
                }).toList();

                return FutureBuilder<Map<String, dynamic>>(
                  future: _loadCurrentSubscriptionSummary(businessId: businessId, userId: userId),
                  builder: (context, summarySnapshot) {
                    if (summarySnapshot.connectionState == ConnectionState.waiting && !summarySnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final fallbackItems = <Map<String, dynamic>>[
                      summarySnapshot.data ?? <String, dynamic>{
                        'id': 'current-subscription',
                        'title': 'Current subscription',
                        'status': 'active',
                        'planId': '',
                        'amount': null,
                        'receiptUrl': null,
                        'createdAt': null,
                        'businessId': businessId,
                        'userId': userId,
                      },
                    ];

                    final allItems = <Map<String, dynamic>>[
                      ...requestDocs.map((doc) => {
                            'id': doc.id,
                            ...doc.data(),
                          }),
                      ...fallbackItems,
                    ];

                    final filtered = allItems.where((item) {
                      final created = _parseCreatedAt(item['createdAt'] ?? item['approvedAt'] ?? item['updatedAt']);
                      return _matchesFilter(created);
                    }).toList()
                      ..sort((a, b) {
                        final aCreated = _parseCreatedAt(a['createdAt'] ?? a['approvedAt'] ?? a['updatedAt']);
                        final bCreated = _parseCreatedAt(b['createdAt'] ?? b['approvedAt'] ?? b['updatedAt']);
                        if (aCreated == null && bCreated == null) return 0;
                        if (aCreated == null) return 1;
                        if (bCreated == null) return -1;
                        return bCreated.compareTo(aCreated);
                      });

                    if (filtered.isEmpty) {
                      return const Center(child: Text('No subscription transactions found for the selected range.'));
                    }

                    return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final status = (item['status'] ?? item['subscriptionStatus'] ?? 'pending').toString();
                    final planId = (item['planId'] ?? item['planName'] ?? '').toString();
                    final amount = (item['amount'] as num?)?.toDouble();
                    final receipt = item['receiptUrl']?.toString();
                    final createdAt = _parseCreatedAt(item['createdAt'] ?? item['approvedAt'] ?? item['updatedAt']);
                    final dateText = createdAt != null ? createdAt.toLocal().toString().split(' ')[0] : '';
                    final businessName = (item['businessName'] ?? '').toString();
                    final title = status.toLowerCase() == 'approved'
                        ? (businessName.isNotEmpty ? 'Subscription approved for $businessName' : 'Subscription approved')
                        : status.toLowerCase() == 'pending'
                            ? (businessName.isNotEmpty ? 'Subscription request pending for $businessName' : 'Subscription request pending')
                            : (businessName.isNotEmpty ? 'Subscription ${status.toLowerCase()} for $businessName' : 'Subscription ${status.toLowerCase()}');

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                              child: const Icon(Icons.receipt_long, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: AppTextStyles.heading5),
                                  const SizedBox(height: 6),
                                  if (planId.isNotEmpty) Text('Plan: $planId', style: AppTextStyles.body2),
                                  if (dateText.isNotEmpty) Text('Date: $dateText', style: AppTextStyles.caption),
                                  Text('Status: ${status.toUpperCase()}', style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (amount != null) Text('₦${amount.toStringAsFixed(0)}', style: AppTextStyles.heading5),
                                const SizedBox(height: 8),
                                if (receipt != null && receipt.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new),
                                    onPressed: () {
                                      // Optionally open receipt externally
                                    },
                                  ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },);
  }),
          ),
        ],
      ),
    );
  }
}
