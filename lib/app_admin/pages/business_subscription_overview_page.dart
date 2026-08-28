import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/datetime_utils.dart';
import '../../data/repositories/admin_repository.dart';
import '../../providers/admin_provider.dart';
import '../admin_theme.dart';

class BusinessSubscriptionOverviewPage extends StatefulWidget {
  const BusinessSubscriptionOverviewPage({super.key});

  @override
  State<BusinessSubscriptionOverviewPage> createState() =>
      _BusinessSubscriptionOverviewPageState();
}

class _BusinessSubscriptionOverviewPageState
    extends State<BusinessSubscriptionOverviewPage> {
  final _adminRepository = AdminRepository();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<AdminProvider>();
      if (admin.allBusinesses.isEmpty) {
        admin.fetchAdminStats();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.adminBackground,
      appBar: AppBar(
        title: const Text('Active Businesses'),
      ),
      body: Consumer<AdminProvider>(
        builder: (context, admin, _) {
          final businesses = admin.allBusinesses.where((business) {
            if (!_isActiveSubscription(business)) return false;
            if (_query.isEmpty) return true;
            final query = _query.toLowerCase();
            final name = (business['name'] ?? '').toString().toLowerCase();
            final owner =
                (business['ownerName'] ?? business['email'] ?? '')
                    .toString()
                    .toLowerCase();
            final tier =
                (business['subscriptionTier'] ?? business['businessClass'] ?? '')
                    .toString()
                    .toLowerCase();
            return name.contains(query) ||
                owner.contains(query) ||
                tier.contains(query);
          }).toList()
            ..sort((a, b) {
              final aDue = _subscriptionEndDate(a);
              final bDue = _subscriptionEndDate(b);
              if (aDue == null && bDue == null) return 0;
              if (aDue == null) return 1;
              if (bDue == null) return -1;
              return aDue.compareTo(bDue);
            });

          final activeCount = admin.allBusinesses
              .where((business) => _isActiveSubscription(business))
              .length;
          final expiringSoonCount = admin.allBusinesses.where((business) {
            final dueDate = _subscriptionEndDate(business);
            if (dueDate == null) return false;
            final days = dueDate.difference(DateTime.now()).inDays;
            return days >= 0 && days <= 14;
          }).length;
          final expiredCount = admin.allBusinesses.where((business) {
            final dueDate = _subscriptionEndDate(business);
            if (dueDate == null) return false;
            return dueDate.isBefore(DateTime.now());
          }).length;

          return RefreshIndicator(
            onRefresh: () => admin.fetchAdminStats(force: true),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: context.adminHeaderGradient,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Businesses',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Businesses shown here have an active subscription. Use the search to find a live business by name, owner, or tier.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search by business, owner, or tier',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: context.adminSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildSummaryChip(
                            label: 'Active',
                            value: activeCount.toString(),
                            color: const Color(0xFF10B981),
                          ),
                          _buildSummaryChip(
                            label: 'Expiring Soon',
                            value: expiringSoonCount.toString(),
                            color: const Color(0xFFF59E0B),
                          ),
                          _buildSummaryChip(
                            label: 'Expired',
                            value: expiredCount.toString(),
                            color: const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (admin.isLoading && admin.allBusinesses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (businesses.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration:
                        context.adminCardDecoration(borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 48,
                          color: context.adminTextTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No active businesses match your search',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.adminTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...businesses.map(_buildBusinessCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(Map<String, dynamic> business) {
    final theme = Theme.of(context);
    final name = (business['name'] ?? 'Unknown Business').toString();
    final owner =
        (business['ownerName'] ?? business['email'] ?? 'Unknown Owner')
            .toString();
    final tier = (business['subscriptionTier'] ??
            business['businessClass'] ??
            'tier1')
        .toString();
    final startDate = _subscriptionStartDate(business);
    final dueDate = _subscriptionEndDate(business);
    final dueText = dueDate == null ? 'No due date' : _formatDate(dueDate);
    final startText = startDate == null ? 'Not set' : _formatDate(startDate);
    final dueDays = dueDate == null
        ? null
        : dueDate.difference(DateTime.now()).inDays;
    final dueLabel = dueDays == null
        ? 'No active subscription'
        : dueDays < 0
            ? 'Expired ${dueDays.abs()}d ago'
            : dueDays == 0
                ? 'Due today'
                : '$dueDays days left';
    final dueColor = dueDays == null
        ? theme.colorScheme.secondary
        : dueDays < 0
            ? theme.colorScheme.error
            : dueDays <= 14
                ? const Color(0xFFF59E0B)
                : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.adminTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      owner,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.adminTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: dueColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  dueLabel,
                  style: TextStyle(
                    color: dueColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoBlock(
                  label: 'Tier',
                  value: tier.toUpperCase(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoBlock(
                  label: 'Start',
                  value: startText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoBlock(
                  label: 'Due',
                  value: dueText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showManageSheet(business),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Manage Subscription Options'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.adminSurfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.adminBorder),
      ),
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
          const SizedBox(height: 6),
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

  void _showManageSheet(Map<String, dynamic> business) {
    String selectedTier =
        (business['subscriptionTier'] ?? 'tier1').toString().toLowerCase();
    int selectedDuration = 365;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.adminSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                business['name']?.toString() ?? 'Business',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.adminTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select a tier and duration, then apply a new subscription window.',
                style: TextStyle(color: context.adminTextSecondary),
              ),
              const SizedBox(height: 18),
              Text(
                'Tier',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.adminTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['tier1', 'tier2', 'tier3', 'basic', 'pro', 'enterprise']
                    .map(
                      (tier) => ChoiceChip(
                        label: Text(tier.toUpperCase()),
                        selected: selectedTier == tier,
                        onSelected: (_) =>
                            setModalState(() => selectedTier = tier),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text(
                'Duration',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.adminTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  (30, '30 days'),
                  (90, '90 days'),
                  (180, '180 days'),
                  (365, '365 days'),
                ]
                    .map(
                      (option) => ChoiceChip(
                        label: Text(option.$2),
                        selected: selectedDuration == option.$1,
                        onSelected: (_) => setModalState(
                          () => selectedDuration = option.$1,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              _buildSubscriptionHistory(
                (business['id'] ?? business['businessId']).toString(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await context
                        .read<AdminProvider>()
                        .grantBusinessSubscription(
                          businessId:
                              (business['id'] ?? business['businessId'])
                                  .toString(),
                          businessName:
                              (business['name'] ?? 'Business').toString(),
                          tier: selectedTier,
                          durationDays: selectedDuration,
                        );
                    if (!mounted) return;
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Subscription updated successfully'
                              : 'Unable to update subscription',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Apply Subscription'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionHistory(String businessId) {
    if (businessId.isEmpty) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _adminRepository.fetchSubscriptionHistory(businessId),
      builder: (context, snapshot) {
        final records = (snapshot.data ?? const []).take(10).toList();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.adminSurfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subscription History',
                style: TextStyle(
                  color: context.adminTextPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                Text(
                  'Unable to load subscription records',
                  style: TextStyle(color: context.adminTextSecondary),
                )
              else if (records.isEmpty)
                Text(
                  'No subscription records found for this business',
                  style: TextStyle(color: context.adminTextSecondary),
                )
              else
                ...records.map((data) {
                  final amount = _readDouble(data['amount']);
                  final createdAt = data['createdAt'] == null
                      ? null
                      : parseTimestamp(data['createdAt']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (data['planName'] ??
                                        data['plan_name'] ??
                                        data['planId'] ??
                                        data['plan_id'] ??
                                        data['subscriptionTier'] ??
                                        'Subscription')
                                    .toString(),
                                style: TextStyle(
                                  color: context.adminTextPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                [
                                  (data['status'] ?? 'pending').toString(),
                                  if (createdAt != null) _formatDate(createdAt),
                                ].join(' - '),
                                style: TextStyle(
                                  color: context.adminTextSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'NGN ${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  DateTime? _subscriptionStartDate(Map<String, dynamic> business) {
    final raw = business['subscriptionStartDate'];
    if (raw == null) return null;
    return parseTimestamp(raw);
  }

  DateTime? _subscriptionEndDate(Map<String, dynamic> business) {
    final raw = business['subscriptionEndDate'];
    if (raw == null) return null;
    return parseTimestamp(raw);
  }

  bool _isActiveSubscription(Map<String, dynamic> business) {
    final activeFlag =
        business['isSubscriptionActive'] ?? business['hasActiveSubscription'];
    if (activeFlag is bool && activeFlag) return true;
    if (activeFlag is num && activeFlag != 0) return true;
    if (activeFlag != null) {
      final normalized = activeFlag.toString().trim().toLowerCase();
      if (normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'active') {
        return true;
      }
    }

    final dueDate = _subscriptionEndDate(business);
    if (dueDate == null) return false;
    return dueDate.isAfter(DateTime.now());
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }
}
