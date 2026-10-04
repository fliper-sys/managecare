import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/business_provider.dart';
import '../../../../services/subscription_service.dart';

class AdministrativeDashboardScreen extends StatelessWidget {
  const AdministrativeDashboardScreen({super.key});

  static const _sections = [
    ('Overview', Icons.dashboard_outlined),
    ('Clients', Icons.people_outline),
    ('Expenses', Icons.receipt_long_outlined),
    ('Revenue', Icons.account_balance_wallet_outlined),
    ('Documents', Icons.folder_outlined),
    ('Staffing', Icons.badge_outlined),
    ('Obligations', Icons.event_repeat_outlined),
    ('Invoicing', Icons.request_quote_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>().currentBusiness;
    final plans = SubscriptionService.getPlansForBusinessType('administrative');
    final tier = business?.subscriptionTier ?? 'tier1';
    SubscriptionPlan? plan;
    for (final item in plans) {
      if (item.tierId == tier) {
        plan = item;
        break;
      }
    }
    plan ??= plans.isEmpty ? null : plans.first;

    return DefaultTabController(
      length: _sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(business?.name.isNotEmpty == true ? business!.name : 'Administrative Services'),
          bottom: TabBar(
            isScrollable: true,
            tabs: _sections.map((section) => Tab(icon: Icon(section.$2), text: section.$1)).toList(),
          ),
        ),
        body: TabBarView(
          children: [
            _Overview(plan: plan),
            const _EmptyState(title: 'Clients', message: 'Client records will appear here.'),
            const _EmptyState(title: 'Expenses', message: 'Client-linked expenses will appear here.'),
            const _EmptyState(title: 'Revenue', message: 'Revenue and invoices will appear here.'),
            const _EmptyState(title: 'Documents', message: 'Create client folders and assign document work here.'),
            const _EmptyState(title: 'Staffing', message: 'Assign workers to the clients they manage here.'),
            const _EmptyState(title: 'Obligations', message: 'Set fixed-date or trailing recurring deadlines here.'),
            const _EmptyState(title: 'Invoicing', message: 'Client invoices will appear here.'),
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.plan});

  final SubscriptionPlan? plan;

  @override
  Widget build(BuildContext context) {
    final limits = plan?.limits ?? const <String, int?>{};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _Metric(label: 'Revenue', value: '0'),
            _Metric(label: 'Expenses', value: '0'),
            _Metric(label: 'Clients', value: '0'),
            _Metric(label: 'Staff', value: '0'),
          ],
        ),
        const SizedBox(height: 28),
        Text('Current Plan', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(plan?.name ?? 'Administrative plan'),
          subtitle: Text('${_limit(limits['storage_gb'], 'GB')} storage | ${_limit(limits['workers'], 'staff')} | ${_limit(limits['clients'], 'clients')} | ${_limit(limits['branches'], 'branches')}'),
        ),
        const SizedBox(height: 20),
        Text('Work Queue', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const _EmptyState(title: 'Nothing needs review', message: 'Document submissions and upcoming obligations will be shown here.'),
      ],
    );
  }

  String _limit(int? value, String unit) => value == null ? 'Unlimited $unit' : '$value $unit';
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
