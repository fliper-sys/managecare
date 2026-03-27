import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency.dart';
import '../../models/marketer_model.dart';
import '../../providers/marketer_provider.dart';

class MarketersPage extends StatefulWidget {
  const MarketersPage({super.key});

  @override
  State<MarketersPage> createState() => _MarketersPageState();
}

class _MarketersPageState extends State<MarketersPage> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketerProvider>().fetchMarketers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Consumer<MarketerProvider>(
        builder: (context, marketerProv, _) {
          final filteredMarketers = marketerProv.marketers.where((marketer) {
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            return marketer.fullName.toLowerCase().contains(query) ||
                marketer.email.toLowerCase().contains(query) ||
                (marketer.phoneNumber ?? '').toLowerCase().contains(query);
          }).toList();

          final totalBalance = marketerProv.marketers.fold<double>(
            0,
            (sum, marketer) => sum + marketer.balance,
          );
          final activeCount =
              marketerProv.marketers.where((marketer) => marketer.isActive).length;
          final inactiveCount = marketerProv.marketers.length - activeCount;

          return RefreshIndicator(
            onRefresh: marketerProv.fetchMarketers,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Marketer Hub',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Manage app marketers, monitor partner performance, and control who can bring in new businesses.',
                                  style: TextStyle(
                                    color: Color(0xFFD7E3FF),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _showCreateDialog,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0F172A),
                            ),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Create'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search marketers by name, email, or phone',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildSummaryCard(
                      title: 'Total',
                      value: marketerProv.marketers.length.toString(),
                      subtitle: 'registered marketers',
                      color: const Color(0xFF3B82F6),
                    ),
                    _buildSummaryCard(
                      title: 'Active',
                      value: activeCount.toString(),
                      subtitle: 'currently enabled',
                      color: const Color(0xFF10B981),
                    ),
                    _buildSummaryCard(
                      title: 'Paused',
                      value: inactiveCount.toString(),
                      subtitle: 'need follow-up',
                      color: const Color(0xFFEF4444),
                    ),
                    _buildSummaryCard(
                      title: 'Balance',
                      value: formatCurrency(totalBalance),
                      subtitle: 'outstanding marketer balance',
                      color: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (marketerProv.isLoading && marketerProv.marketers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filteredMarketers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.campaign_outlined, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No marketers match this search',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredMarketers.map(_buildMarketerCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketerCard(MarketerModel marketer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: marketer.isActive
                        ? const [Color(0xFF2563EB), Color(0xFF7C3AED)]
                        : const [Color(0xFF64748B), Color(0xFF94A3B8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    marketer.fullName.isEmpty
                        ? 'M'
                        : marketer.fullName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marketer.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      marketer.email,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    if ((marketer.phoneNumber ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        marketer.phoneNumber!,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildStatusPill(marketer.isActive),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMiniMetric(
                label: 'Balance',
                value: formatCurrency(marketer.balance),
                color: const Color(0xFF8B5CF6),
              ),
              _buildMiniMetric(
                label: 'Approved',
                value: marketer.totalReferralsApproved.toString(),
                color: const Color(0xFF10B981),
              ),
              _buildMiniMetric(
                label: 'Pending',
                value: marketer.totalReferralsPending.toString(),
                color: const Color(0xFFF97316),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showDetails(marketer),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Details'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showEditDialog(marketer),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: () => _toggleMarketerStatus(marketer),
                icon: Icon(
                  marketer.isActive
                      ? Icons.pause_circle_outline_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(marketer.isActive ? 'Pause' : 'Enable'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: marketer.isActive
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                  side: BorderSide(
                    color: marketer.isActive
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _confirmDelete(marketer),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.92),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(bool isActive) {
    final color = isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Active' : 'Paused',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showCreateDialog() {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create marketer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final provider = context.read<MarketerProvider>();
              final id = await provider.createMarketer(
                email: emailCtrl.text.trim(),
                fullName: nameCtrl.text.trim(),
                password: passwordCtrl.text.trim(),
                phoneNumber: phoneCtrl.text.trim(),
              );
              if (!context.mounted) return;
              if (id != null) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marketer created successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.errorMessage ?? 'Unable to create marketer',
                    ),
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(MarketerModel marketer) {
    final nameCtrl = TextEditingController(text: marketer.fullName);
    final phoneCtrl = TextEditingController(text: marketer.phoneNumber);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit marketer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await context.read<MarketerProvider>().updateMarketer(
                    marketer.id,
                    fullName: nameCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim(),
                  );
              if (!context.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? 'Marketer updated' : 'Unable to update marketer',
                  ),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMarketerStatus(MarketerModel marketer) async {
    final ok = await context.read<MarketerProvider>().updateMarketer(
          marketer.id,
          isActive: !marketer.isActive,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? marketer.isActive
                  ? 'Marketer paused'
                  : 'Marketer enabled'
              : 'Unable to update marketer status',
        ),
      ),
    );
  }

  void _confirmDelete(MarketerModel marketer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${marketer.fullName}?'),
        content: const Text('This removes the marketer record permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await context.read<MarketerProvider>().deleteMarketer(marketer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Marketer deleted' : 'Unable to delete marketer'),
        ),
      );
    }
  }

  void _showDetails(MarketerModel marketer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketerDetailPage(marketer: marketer),
      ),
    );
  }
}

class MarketerDetailPage extends StatefulWidget {
  final MarketerModel marketer;

  const MarketerDetailPage({
    required this.marketer,
    super.key,
  });

  @override
  State<MarketerDetailPage> createState() => _MarketerDetailPageState();
}

class _MarketerDetailPageState extends State<MarketerDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<MarketerProvider>()
          .fetchMarketerReferrals(widget.marketer.email);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketerProvider>();
    final marketer = widget.marketer;

    return Scaffold(
      appBar: AppBar(title: Text(marketer.fullName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF111827), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  marketer.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  marketer.email,
                  style: const TextStyle(color: Color(0xFFD7E3FF)),
                ),
                if ((marketer.phoneNumber ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    marketer.phoneNumber!,
                    style: const TextStyle(color: Color(0xFFD7E3FF)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _detailMetric(
                'Current Balance',
                formatCurrency(marketer.balance),
                const Color(0xFF8B5CF6),
              ),
              _detailMetric(
                'Total Earned',
                formatCurrency(marketer.totalCommissionEarned),
                const Color(0xFF10B981),
              ),
              _detailMetric(
                'Approved Referrals',
                marketer.totalReferralsApproved.toString(),
                const Color(0xFF3B82F6),
              ),
              _detailMetric(
                'Pending Referrals',
                marketer.totalReferralsPending.toString(),
                const Color(0xFFF97316),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Referral Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (provider.isLoading && provider.referrals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.referrals.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text('No referrals yet'),
            )
          else
            ...provider.referrals.map(_buildReferralCard),
        ],
      ),
    );
  }

  Widget _detailMetric(String title, String value, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard(ReferralRecord referral) {
    final statusColor = referral.status == 'approved'
        ? const Color(0xFF10B981)
        : referral.status == 'rejected'
            ? const Color(0xFFEF4444)
            : const Color(0xFFF97316);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_outline_rounded, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  referral.userEmail,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  referral.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                if ((referral.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    referral.notes!,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            formatCurrency(referral.commissionAmount),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
