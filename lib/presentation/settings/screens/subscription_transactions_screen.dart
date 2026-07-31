import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../services/managecare_api_client.dart';

enum _DayFilter { all, today, days7, days30 }

class SubscriptionTransactionsScreen extends StatefulWidget {
  const SubscriptionTransactionsScreen({super.key});

  @override
  State<SubscriptionTransactionsScreen> createState() => _SubscriptionTransactionsScreenState();
}

class _SubscriptionTransactionsScreenState extends State<SubscriptionTransactionsScreen> {
  _DayFilter _selected = _DayFilter.all;
  late Future<List<Map<String, dynamic>>> _future;

  String? _resolveBusinessId(BuildContext context) {
    final bp = context.read<BusinessProvider>();
    final businessId = bp.currentBusiness?.id;
    if (businessId != null && businessId.isNotEmpty) return businessId;
    final user = context.read<AuthProvider>().currentUser;
    final primary = user?.primaryBusinessId;
    return (primary != null && primary.isNotEmpty) ? primary : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _future = _loadItems(
          businessId: _resolveBusinessId(context),
          userId: context.read<AuthProvider>().currentUser?.id,
        );
      });
    });
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  DateTime? _parseCreatedAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
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
        final business = await ManagecareApiClient.instance
            .get('/api/subscriptions/business/$businessId');
        final businessData = Map<String, dynamic>.from(business as Map);
        final businessName = (businessData['name'] ?? '').toString();
        if (businessName.isNotEmpty) {
          summary['businessName'] = businessName;
          summary['title'] = 'Active subscription for $businessName';
        }

        final businessStatus = (businessData['subscription_status'] ?? '').toString();
        final hasActiveBusiness = businessData['is_subscription_active'] == true;
        summary['status'] = businessStatus.isNotEmpty
            ? businessStatus
            : (hasActiveBusiness ? 'active' : 'inactive');
        summary['planId'] = (businessData['subscription_plan'] ??
                businessData['subscription_tier'] ??
                '')
            .toString();
        summary['amount'] = _readDouble(businessData['subscription_amount']);
        summary['receiptUrl'] = businessData['subscription_receipt_url']?.toString();
        summary['createdAt'] = businessData['subscription_start_date'] ??
            businessData['updated_at'];
      } catch (_) {}
    }

    if (userId != null && userId.isNotEmpty) {
      try {
        final user = await ManagecareApiClient.instance
            .get('/api/subscriptions/user/$userId');
        final userData = Map<String, dynamic>.from(user as Map);
        final userStatus = (userData['subscription_status'] ?? '').toString();
        final hasActiveUser = userData['has_active_subscription'] == true;
        if (userStatus.isNotEmpty) {
          summary['status'] = userStatus;
        } else if (!hasActiveUser && summary['status'] == 'active') {
          summary['status'] = 'inactive';
        }

        if ((summary['planId'] as String).isEmpty) {
          summary['planId'] =
              (userData['subscription_plan'] ?? userData['subscription_tier'] ?? '').toString();
        }
        summary['amount'] ??= _readDouble(userData['subscription_amount']);
        if ((summary['receiptUrl'] as String?)?.isEmpty ?? true) {
          summary['receiptUrl'] = userData['subscription_receipt_url']?.toString();
        }
        summary['createdAt'] ??=
            userData['subscription_start_date'] ?? userData['updated_at'];
      } catch (_) {}
    }

    return summary;
  }

  Future<List<Map<String, dynamic>>> _loadItems({
    required String? businessId,
    required String? userId,
  }) async {
    final results = await Future.wait([
      _loadHistory(businessId: businessId, userId: userId),
      _loadCurrentSubscriptionSummary(businessId: businessId, userId: userId),
    ]);
    final history = results[0] as List<Map<String, dynamic>>;
    final summary = results[1] as Map<String, dynamic>;
    return [...history, summary];
  }

  Future<List<Map<String, dynamic>>> _loadHistory({
    required String? businessId,
    required String? userId,
  }) async {
    if ((businessId == null || businessId.isEmpty) && (userId == null || userId.isEmpty)) {
      return [];
    }
    try {
      final response = await ManagecareApiClient.instance.get(
        '/api/subscriptions/history',
        query: {
          if (businessId != null && businessId.isNotEmpty) 'businessId': businessId,
          if (userId != null && userId.isNotEmpty) 'userId': userId,
        },
      );
      return ((response['data'] as List?) ?? [])
          .map((row) {
            final data = Map<String, dynamic>.from(row as Map);
            return {
              'id': data['id'],
              'businessId': data['business_id'],
              'userId': data['user_id'],
              'planId': data['plan_id'] ?? data['plan_tier'],
              'planName': data['plan_name'],
              'amount': _readDouble(data['amount']),
              'receiptUrl': data['receipt_url'],
              'status': data['status'],
              'createdAt': data['createdAt'],
            };
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
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
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() {
                      _future = _loadItems(
                        businessId: _resolveBusinessId(context),
                        userId: context.read<AuthProvider>().currentUser?.id,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allItems = snapshot.data ?? const [];
                final filtered = allItems.where((item) {
                  final created = _parseCreatedAt(item['createdAt']);
                  return _matchesFilter(created);
                }).toList()
                  ..sort((a, b) {
                    final aCreated = _parseCreatedAt(a['createdAt']);
                    final bCreated = _parseCreatedAt(b['createdAt']);
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
                    final status = (item['status'] ?? 'pending').toString();
                    final planId = (item['planId'] ?? item['planName'] ?? '').toString();
                    final amount = item['amount'] as double?;
                    final receipt = item['receiptUrl']?.toString();
                    final createdAt = _parseCreatedAt(item['createdAt']);
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
