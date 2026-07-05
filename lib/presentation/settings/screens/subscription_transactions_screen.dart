import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
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
      if (raw is String && raw.isNotEmpty) return DateTime.parse(raw);
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
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = _resolveBusinessId(context);
    final userId = context.read<AuthProvider>().currentUser?.id;

    final baseQuery = (businessId != null && businessId.isNotEmpty)
        ? FirebaseFirestore.instance
            .collection('subscription_events')
            .where('businessId', isEqualTo: businessId)
            .orderBy('createdAt', descending: true)
        : FirebaseFirestore.instance
            .collection('subscription_events')
            .where('userId', isEqualTo: userId ?? '')
            .orderBy('createdAt', descending: true);

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
                final filtered = docs.where((doc) {
                  final d = doc.data();
                  final created = _parseCreatedAt(d['createdAt']);
                  return _matchesFilter(created);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No subscription transactions found for the selected range.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final d = filtered[index].data();
                    final action = (d['action'] ?? '').toString();
                    final planId = (d['planId'] ?? '').toString();
                    final amount = (d['amount'] as num?)?.toDouble();
                    final receipt = d['receiptUrl']?.toString();
                    final createdAt = _parseCreatedAt(d['createdAt']);
                    final dateText = createdAt != null ? createdAt.toLocal().toString().split(' ')[0] : '';

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
                                  Text(action.replaceAll('_', ' ').toUpperCase(), style: AppTextStyles.heading5),
                                  const SizedBox(height: 6),
                                  if (planId.isNotEmpty) Text('Plan: $planId', style: AppTextStyles.body2),
                                  if (dateText.isNotEmpty) Text('Date: $dateText', style: AppTextStyles.caption),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
