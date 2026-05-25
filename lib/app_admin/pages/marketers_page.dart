import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency.dart';
import '../../models/marketer_analytics_model.dart';
import '../../models/marketer_model.dart';
import '../../providers/marketer_provider.dart';
import '../admin_theme.dart';

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
      context.read<MarketerProvider>().fetchMarketingOverview();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.adminBackground,
      child: SafeArea(
        child: Consumer<MarketerProvider>(
        builder: (context, marketerProv, _) {
          final snapshots = marketerProv.performanceByMarketerEmail.values.toList();
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
          final totalRegisteredClients = snapshots.fold<int>(
            0,
            (sum, snapshot) => sum + snapshot.registeredClients,
          );
          final totalActiveClients = snapshots.fold<int>(
            0,
            (sum, snapshot) => sum + snapshot.activeClients,
          );
          final totalExpiringClients = snapshots.fold<int>(
            0,
            (sum, snapshot) => sum + snapshot.expiringSoonClients,
          );
          final leaderboard = marketerProv.leaderboard.take(5).toList();

          return RefreshIndicator(
            onRefresh: marketerProv.fetchMarketingOverview,
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
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _showRewardConfigDialog(marketerProv),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                            ),
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text('Rewards'),
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
                          fillColor: context.adminSurface,
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
                      title: 'Clients',
                      value: totalRegisteredClients.toString(),
                      subtitle: 'registered by marketers',
                      color: const Color(0xFF0F766E),
                    ),
                    _buildSummaryCard(
                      title: 'Live Clients',
                      value: totalActiveClients.toString(),
                      subtitle: 'currently subscribed',
                      color: const Color(0xFF8B5CF6),
                    ),
                    _buildSummaryCard(
                      title: 'Expiring',
                      value: totalExpiringClients.toString(),
                      subtitle: 'need renewal follow-up',
                      color: const Color(0xFFF97316),
                    ),
                    _buildSummaryCard(
                      title: 'Balance',
                      value: formatCurrency(totalBalance),
                      subtitle: 'outstanding marketer balance',
                      color: const Color(0xFFEF4444),
                    ),
                  ],
                ),
                if (leaderboard.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _buildLeaderboardCard(leaderboard),
                ],
                const SizedBox(height: 18),
                _buildRewardConfigCard(marketerProv),
                const SizedBox(height: 20),
                if (marketerProv.isLoading && marketerProv.marketers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filteredMarketers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: context.adminCardDecoration(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 48,
                          color: context.adminTextTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No marketers match this search',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.adminTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredMarketers.map(
                    (marketer) => _buildMarketerCard(
                      marketer,
                      marketerProv.performanceForMarketer(marketer.email),
                    ),
                  ),
              ],
            ),
          );
        },
        ),
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
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(22),
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.adminTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: context.adminTextSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard(List<MarketerLeaderboardEntry> leaderboard) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Leaderboard',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.adminTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Admin can now see every marketer progress line, current rank, and projected bonus for the month.',
            style: TextStyle(
              color: context.adminTextSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ...leaderboard.map(
            (entry) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.adminSurfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.adminBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    child: Text('#${entry.rank}'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: context.adminTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${entry.monthlyPerformanceCount} wins - ${entry.totalActiveClients} active clients',
                          style:
                              TextStyle(color: context.adminTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency(entry.monthlyRewardEarned),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: context.adminTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.projectedBonus > 0
                            ? 'Bonus ${formatCurrency(entry.projectedBonus)}'
                            : 'No bonus yet',
                        style: TextStyle(
                          color: entry.projectedBonus > 0
                              ? const Color(0xFFEA580C)
                              : context.adminTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardConfigCard(MarketerProvider marketerProv) {
    final config = marketerProv.rewardConfig;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reward Configuration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.adminTextPrimary,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showRewardConfigDialog(marketerProv),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Commission, target, podium bonus, and expiry follow-up settings now live here for super admin control.',
            style: TextStyle(
              color: context.adminTextSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMiniMetric(
                label: 'Monthly target',
                value: config.monthlyTargetSubscriptions.toString(),
                color: const Color(0xFF2563EB),
              ),
              _buildMiniMetric(
                label: 'Commission',
                value:
                    '${(config.subscriptionCommissionRate * 100).toStringAsFixed(0)}%',
                color: const Color(0xFF0F766E),
              ),
              _buildMiniMetric(
                label: 'Target bonus',
                value: formatCurrency(config.targetBonusAmount),
                color: const Color(0xFFEA580C),
              ),
              _buildMiniMetric(
                label: 'Expiry warning',
                value: '${config.expiryWarningDays} days',
                color: const Color(0xFF7C3AED),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag(
                Icons.looks_one_rounded,
                '1st ${formatCurrency(config.rank1BonusAmount)}',
                const Color(0xFFEA580C),
              ),
              _buildTag(
                Icons.looks_two_rounded,
                '2nd ${formatCurrency(config.rank2BonusAmount)}',
                const Color(0xFF2563EB),
              ),
              _buildTag(
                Icons.looks_3_rounded,
                '3rd ${formatCurrency(config.rank3BonusAmount)}',
                const Color(0xFF7C3AED),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketerCard(
    MarketerModel marketer,
    MarketerPerformanceSnapshot? performance,
  ) {
    final progressValue = performance?.targetProgress ?? 0;
    final registeredClients =
        performance?.registeredClients ?? marketer.referredUserIds.length;
    final activeClients = performance?.activeClients ?? 0;
    final monthlyWins = performance?.monthlyPerformanceCount ?? 0;

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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.adminTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      marketer.email,
                      style: TextStyle(color: context.adminTextSecondary),
                    ),
                    if ((marketer.phoneNumber ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        marketer.phoneNumber!,
                        style: TextStyle(
                          color: context.adminTextTertiary,
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
                label: 'Clients',
                value: registeredClients.toString(),
                color: const Color(0xFF10B981),
              ),
              _buildMiniMetric(
                label: 'Active',
                value: activeClients.toString(),
                color: const Color(0xFF2563EB),
              ),
              _buildMiniMetric(
                label: 'This month',
                value: monthlyWins.toString(),
                color: const Color(0xFFF97316),
              ),
            ],
          ),
          if (performance != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.adminSurfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.adminBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Target progress',
                        style: TextStyle(
                          color: context.adminTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${performance.monthlyPerformanceCount}/${performance.monthlyTarget}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: context.adminTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 10,
                      backgroundColor: context.adminBorder,
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag(
                        Icons.emoji_events_outlined,
                        performance.rank > 0
                            ? 'Rank #${performance.rank}'
                            : 'Unranked',
                        const Color(0xFFEA580C),
                      ),
                      _buildTag(
                        Icons.alarm_on_outlined,
                        '${performance.expiringSoonClients} expiring',
                        const Color(0xFFF97316),
                      ),
                      _buildTag(
                        Icons.card_giftcard_rounded,
                        performance.projectedBonus > 0
                            ? 'Bonus ${formatCurrency(performance.projectedBonus)}'
                            : 'Bonus pending',
                        const Color(0xFF7C3AED),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
        color: context.adminSurfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.16)),
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
              color: context.adminTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
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

  void _showRewardConfigDialog(MarketerProvider provider) {
    final config = provider.rewardConfig;
    final monthlyTargetCtrl = TextEditingController(
      text: config.monthlyTargetSubscriptions.toString(),
    );
    final commissionCtrl = TextEditingController(
      text: (config.subscriptionCommissionRate * 100).toStringAsFixed(0),
    );
    final targetBonusCtrl = TextEditingController(
      text: config.targetBonusAmount.toStringAsFixed(0),
    );
    final rank1Ctrl = TextEditingController(
      text: config.rank1BonusAmount.toStringAsFixed(0),
    );
    final rank2Ctrl = TextEditingController(
      text: config.rank2BonusAmount.toStringAsFixed(0),
    );
    final rank3Ctrl = TextEditingController(
      text: config.rank3BonusAmount.toStringAsFixed(0),
    );
    final expiryCtrl = TextEditingController(
      text: config.expiryWarningDays.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marketer reward settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: monthlyTargetCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Monthly target'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commissionCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Commission rate (%)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetBonusCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    const InputDecoration(labelText: 'Target bonus amount'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rank1Ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    const InputDecoration(labelText: '1st place bonus'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rank2Ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    const InputDecoration(labelText: '2nd place bonus'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rank3Ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    const InputDecoration(labelText: '3rd place bonus'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expiryCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Expiry warning days',
                ),
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
              final monthlyTarget =
                  int.tryParse(monthlyTargetCtrl.text.trim()) ?? 0;
              final commissionRate =
                  (double.tryParse(commissionCtrl.text.trim()) ?? 0) / 100.0;
              final targetBonus =
                  double.tryParse(targetBonusCtrl.text.trim()) ?? 0.0;
              final rank1 = double.tryParse(rank1Ctrl.text.trim()) ?? 0.0;
              final rank2 = double.tryParse(rank2Ctrl.text.trim()) ?? 0.0;
              final rank3 = double.tryParse(rank3Ctrl.text.trim()) ?? 0.0;
              final expiryDays = int.tryParse(expiryCtrl.text.trim()) ?? 0;

              final ok = await context.read<MarketerProvider>().updateRewardConfig(
                    monthlyTargetSubscriptions: monthlyTarget <= 0 ? 1 : monthlyTarget,
                    targetBonusAmount: targetBonus,
                    rank1BonusAmount: rank1,
                    rank2BonusAmount: rank2,
                    rank3BonusAmount: rank3,
                    subscriptionCommissionRate:
                        commissionRate < 0 ? 0 : commissionRate,
                    expiryWarningDays: expiryDays <= 0 ? 1 : expiryDays,
                  );
              if (!context.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Marketer reward settings updated'
                        : (context.read<MarketerProvider>().errorMessage ??
                            'Unable to update marketer reward settings'),
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
                await provider.fetchMarketingOverview();
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
    final commissionCtrl = TextEditingController(
        text: marketer.commissionRateOverride != null
            ? (marketer.commissionRateOverride! * 100).toStringAsFixed(0)
            : '');

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
            const SizedBox(height: 12),
            TextField(
              controller: commissionCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Commission Rate (%)',
                hintText: 'e.g., 10 for 10% (Leave empty for default)',
              ),
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
              final commissionText = commissionCtrl.text.trim();
              double? parsedRate;
              if (commissionText.isNotEmpty) {
                final rate = double.tryParse(commissionText);
                if (rate != null) {
                  parsedRate = rate / 100.0;
                }
              } else {
                parsedRate = -1.0; // Sentinel value to remove override
              }

              final ok = await context.read<MarketerProvider>().updateMarketer(
                    marketer.id,
                    fullName: nameCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim(),
                    commissionRateOverride: parsedRate,
                  );
              if (!context.mounted) return;
              if (ok) {
                await context.read<MarketerProvider>().fetchMarketingOverview();
              }
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
    final provider = context.read<MarketerProvider>();
    final ok = await provider.updateMarketer(
          marketer.id,
          isActive: !marketer.isActive,
        );
    if (ok) {
      await provider.fetchMarketingOverview();
    }
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
      final provider = context.read<MarketerProvider>();
      final ok = await provider.deleteMarketer(marketer.id);
      if (ok) {
        await provider.fetchMarketingOverview();
      }
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<MarketerProvider>();
      await Future.wait([
        provider.fetchMarketerReferrals(widget.marketer.email),
        provider.fetchMarketingOverview(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketerProvider>();
    final marketer = provider.marketers.firstWhere(
      (item) => item.id == widget.marketer.id,
      orElse: () => widget.marketer,
    );
    final performance = provider.performanceForMarketer(marketer.email);
    final clients = provider.clientsForMarketer(marketer.email);

    return Scaffold(
      backgroundColor: context.adminBackground,
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
                formatCurrency(
                  performance?.lifetimeRewardEarned ??
                      marketer.totalCommissionEarned,
                ),
                const Color(0xFF10B981),
              ),
              _detailMetric(
                'Registered Clients',
                (performance?.registeredClients ?? clients.length).toString(),
                const Color(0xFF3B82F6),
              ),
              _detailMetric(
                'Active Clients',
                (performance?.activeClients ??
                        clients.where((client) => client.isCurrentlyActive).length)
                    .toString(),
                const Color(0xFFF97316),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Registered Clients',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.adminTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (provider.isLoading && clients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (clients.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: context.adminCardDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'No registered clients yet',
                style: TextStyle(color: context.adminTextPrimary),
              ),
            )
          else
            ...clients.map(_buildClientOverviewCard),
          const SizedBox(height: 22),
          Text(
            'Referral Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.adminTextPrimary,
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
              decoration: context.adminCardDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'No referrals yet',
                style: TextStyle(color: context.adminTextPrimary),
              ),
            )
          else
            ...provider.referrals.map(_buildReferralCard),
        ],
      ),
    );
  }

  Widget _buildClientOverviewCard(MarketerClientRecord client) {
    final statusColor = client.isExpiringSoon
        ? const Color(0xFFF97316)
        : client.isCurrentlyActive
            ? const Color(0xFF10B981)
            : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      client.fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.adminTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.userEmail,
                      style: TextStyle(color: context.adminTextSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                client.status.label,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInlineTag(
                Icons.store_mall_directory_outlined,
                client.businessName ?? 'Business pending',
                client.hasBusiness
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFB45309),
              ),
              _buildInlineTag(
                Icons.event_available_outlined,
                client.subscriptionEndDate == null
                    ? 'No subscription date'
                    : client.subscriptionEndDate!.isAfter(DateTime.now())
                        ? 'Expires ${_formatDate(client.subscriptionEndDate!)}'
                        : 'Expired ${_formatDate(client.subscriptionEndDate!)}',
                statusColor,
              ),
              _buildInlineTag(
                Icons.payments_outlined,
                'Rewards ${formatCurrency(client.totalRewardEarned)}',
                const Color(0xFF7C3AED),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailMetric(String title, String value, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: context.adminCardDecoration(
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
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: context.adminTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  Widget _buildInlineTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
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
      decoration: context.adminCardDecoration(
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
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.adminTextPrimary,
                  ),
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
                    style: TextStyle(
                      color: context.adminTextSecondary,
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
