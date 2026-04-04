import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../models/marketer_analytics_model.dart';
import '../../providers/marketer_provider.dart';

class MarketerDashboardScreen extends StatefulWidget {
  const MarketerDashboardScreen({super.key});

  @override
  State<MarketerDashboardScreen> createState() =>
      _MarketerDashboardScreenState();
}

class _MarketerDashboardScreenState extends State<MarketerDashboardScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final provider = context.read<MarketerProvider>();
    final marketer = provider.currentMarketer;
    if (marketer == null) return;

    await provider.fetchMarketingOverview();
  }

  List<MarketerClientRecord> _filteredClients(
    List<MarketerClientRecord> clients,
  ) {
    switch (_filter) {
      case 'active':
        return clients.where((client) => client.isCurrentlyActive).toList();
      case 'inactive':
        return clients.where((client) => !client.isCurrentlyActive).toList();
      case 'expiring':
        return clients.where((client) => client.isExpiringSoon).toList();
      case 'needs_business':
        return clients
            .where(
              (client) => client.status == MarketerClientStatus.needsBusiness,
            )
            .toList();
      case 'rejected':
        return clients
            .where((client) => client.status == MarketerClientStatus.rejected)
            .toList();
      default:
        return clients;
    }
  }

  Color _statusColor(MarketerClientStatus status) {
    switch (status) {
      case MarketerClientStatus.active:
        return const Color(0xFF15803D);
      case MarketerClientStatus.expiringSoon:
        return const Color(0xFFF97316);
      case MarketerClientStatus.needsBusiness:
        return const Color(0xFFB45309);
      case MarketerClientStatus.expired:
        return const Color(0xFFB91C1C);
      case MarketerClientStatus.rejected:
        return const Color(0xFF7F1D1D);
      case MarketerClientStatus.inactive:
        return const Color(0xFF475569);
    }
  }

  String _money(double value) {
    return NumberFormat.currency(
      locale: 'en_NG',
      symbol: 'NGN ',
      decimalDigits: 0,
    ).format(value);
  }

  String _date(DateTime value) => DateFormat('d MMM yyyy').format(value);

  Future<void> _logout() async {
    context.read<MarketerProvider>().logoutMarketer();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(Routes.marketerLogin, (route) => false);
  }

  Future<void> _openBusiness(MarketerClientRecord client) async {
    await Navigator.of(context).pushNamed(
      Routes.marketerRegisterBusiness,
      arguments: {
        'userId': client.userId,
        'userEmail': client.userEmail,
        'ownerName': client.fullName,
      },
    );
    if (mounted) {
      await _refresh();
    }
  }

  void _pickLead(List<MarketerClientRecord> clients) {
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No clients are waiting for business setup right now'),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Choose a lead',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...clients.map(
              (client) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.person_add_alt_1_rounded),
                ),
                title: Text(client.fullName),
                subtitle: Text(
                  '${client.userEmail} - Registered ${_date(client.registeredAt)}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openBusiness(client);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _action(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: 220,
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withOpacity(0.16),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketerProvider>(
      builder: (context, provider, _) {
        final marketer = provider.currentMarketer;
        if (marketer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Marketer Hub')),
            body: Center(
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  Routes.marketerLogin,
                  (route) => false,
                ),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Go To Marketer Login'),
              ),
            ),
          );
        }

        final performance = provider.currentMarketerPerformance;
        final clients = provider.currentMarketerClients;
        final visibleClients = _filteredClients(clients);
        final needsBusiness = clients
            .where(
              (client) => client.status == MarketerClientStatus.needsBusiness,
            )
            .toList();
        final leaderboard = provider.leaderboard.take(5).toList();
        final lifetimeEarned = performance?.lifetimeRewardEarned ??
            marketer.totalCommissionEarned;
        final currentRank = performance?.rank ?? 0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Marketer Hub'),
            actions: [
              IconButton(
                onPressed: provider.isLoading ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                Navigator.of(context).pushNamed(Routes.marketerRegisterUser),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('New Lead'),
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F172A),
                        Color(0xFF1D4ED8),
                        Color(0xFF14B8A6),
                      ],
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
                      const SizedBox(height: 4),
                      Text(
                        marketer.email,
                        style: const TextStyle(color: Color(0xFFD6EEFF)),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _heroPill(
                            Icons.account_balance_wallet_outlined,
                            'Balance',
                            _money(marketer.balance),
                          ),
                          _heroPill(
                            Icons.approval_outlined,
                            'Lifetime earned',
                            _money(lifetimeEarned),
                          ),
                          _heroPill(
                            Icons.emoji_events_outlined,
                            'Rank',
                            currentRank > 0 ? '#$currentRank' : 'Unranked',
                          ),
                          _heroPill(
                            Icons.phone_outlined,
                            'Phone',
                            marketer.phoneNumber?.isNotEmpty == true
                                ? marketer.phoneNumber!
                                : 'Not set',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _metric(
                      'Registered clients',
                      '${performance?.registeredClients ?? clients.length}',
                      Icons.groups_rounded,
                      const Color(0xFF1D4ED8),
                    ),
                    _metric(
                      'Active clients',
                      '${performance?.activeClients ?? clients.where((client) => client.isCurrentlyActive).length}',
                      Icons.task_alt_rounded,
                      const Color(0xFF15803D),
                    ),
                    _metric(
                      'Inactive clients',
                      '${performance?.inactiveClients ?? clients.where((client) => !client.isCurrentlyActive).length}',
                      Icons.hourglass_bottom_rounded,
                      const Color(0xFF475569),
                    ),
                    _metric(
                      'Expiring soon',
                      '${performance?.expiringSoonClients ?? clients.where((client) => client.isExpiringSoon).length}',
                      Icons.alarm_on_outlined,
                      const Color(0xFFF97316),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildProgressCard(provider, performance),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick actions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep your monthly pipeline moving and stay ahead on renewals.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _action(
                            'Register new lead',
                            'Create a new owner account.',
                            Icons.person_add_alt_1_rounded,
                            const Color(0xFF1D4ED8),
                            () => Navigator.of(
                              context,
                            ).pushNamed(Routes.marketerRegisterUser),
                          ),
                          _action(
                            'Attach business',
                            'Finish setup for waiting leads.',
                            Icons.business_center_outlined,
                            const Color(0xFFB45309),
                            () => _pickLead(needsBusiness),
                          ),
                          _action(
                            'Change password',
                            'Keep your marketer access secure.',
                            Icons.lock_reset_rounded,
                            const Color(0xFF0F766E),
                            () => Navigator.of(
                              context,
                            ).pushNamed(Routes.marketerChangePassword),
                          ),
                          _action(
                            'Refresh workspace',
                            'Pull the latest client and reward updates.',
                            Icons.sync_rounded,
                            const Color(0xFF7C3AED),
                            _refresh,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildLeaderboardCard(marketer.email, leaderboard, performance),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  children: [
                    _filterChip('All', 'all'),
                    _filterChip('Active', 'active'),
                    _filterChip('Inactive', 'inactive'),
                    _filterChip('Expiring', 'expiring'),
                    _filterChip('Needs business', 'needs_business'),
                    _filterChip('Rejected', 'rejected'),
                  ],
                ),
                const SizedBox(height: 14),
                if (provider.isLoading && clients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visibleClients.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.inbox_outlined, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'No clients match this view yet.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Switch filters or register a new lead to keep building your pipeline.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  ...visibleClients.map(_buildClientCard),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressCard(
    MarketerProvider provider,
    MarketerPerformanceSnapshot? performance,
  ) {
    final target = performance?.monthlyTarget ??
        provider.rewardConfig.monthlyTargetSubscriptions;
    final monthlyWins = performance?.monthlyPerformanceCount ?? 0;
    final progressValue = performance?.targetProgress ?? 0;
    final projectedBonus = performance?.projectedBonus ?? 0;
    final monthLabel = DateFormat(
      'MMMM yyyy',
    ).format(performance?.monthStart ?? DateTime.now());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Monthly target',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                monthLabel,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hit $target paid subscriptions or renewals this month to unlock your target bonus. Top 3 also earn leaderboard bonuses.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.45),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 12,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$monthlyWins / $target achieved',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                performance?.targetReached == true
                    ? 'Target unlocked'
                    : 'Keep pushing',
                style: TextStyle(
                  color: performance?.targetReached == true
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB45309),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _tag(
                Icons.trending_up_rounded,
                '${performance?.monthlyActiveClients ?? 0} new active clients',
                const Color(0xFF15803D),
              ),
              _tag(
                Icons.refresh_rounded,
                '${performance?.monthlyRenewals ?? 0} renewals',
                const Color(0xFF0F766E),
              ),
              _tag(
                Icons.payments_outlined,
                _money(performance?.monthlyRewardEarned ?? 0),
                const Color(0xFF7C3AED),
              ),
              _tag(
                Icons.card_giftcard_rounded,
                projectedBonus > 0
                    ? 'Bonus in sight: ${_money(projectedBonus)}'
                    : 'Bonus not unlocked yet',
                const Color(0xFFEA580C),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard(
    String currentMarketerEmail,
    List<MarketerLeaderboardEntry> leaderboard,
    MarketerPerformanceSnapshot? performance,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly leaderboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Your position updates from approved subscriptions and renewal commissions.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (leaderboard.isEmpty)
            Text(
              'No marketer rankings yet for this month.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            ...leaderboard.map(
              (entry) => _buildLeaderboardRow(
                entry,
                isCurrent: entry.marketerEmail.toLowerCase() ==
                    currentMarketerEmail.toLowerCase(),
              ),
            ),
          if (performance != null && performance.rank > 5) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    child: Icon(Icons.person_outline_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are currently #${performance.rank} with ${performance.monthlyPerformanceCount} monthly wins.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow(
    MarketerLeaderboardEntry entry, {
    required bool isCurrent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent ? const Color(0xFF38BDF8) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isCurrent
                ? const Color(0xFF1D4ED8)
                : const Color(0xFFCBD5E1),
            foregroundColor: isCurrent ? Colors.white : const Color(0xFF0F172A),
            child: Text('#${entry.rank}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.monthlyPerformanceCount} wins - ${entry.totalActiveClients} active clients',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(entry.monthlyRewardEarned),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                entry.projectedBonus > 0
                    ? 'Bonus ${_money(entry.projectedBonus)}'
                    : 'No bonus yet',
                style: TextStyle(
                  color: entry.projectedBonus > 0
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(MarketerClientRecord client) {
    final statusColor = _statusColor(client.status);
    final expiryText = client.subscriptionEndDate == null
        ? 'No subscription date yet'
        : client.subscriptionEndDate!.isAfter(DateTime.now())
            ? 'Expires ${_date(client.subscriptionEndDate!)}'
            : 'Expired ${_date(client.subscriptionEndDate!)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withOpacity(0.12),
                child: Icon(Icons.person_outline_rounded, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.userEmail,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Registered ${_date(client.registeredAt)}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  client.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(
                client.hasBusiness
                    ? Icons.store_mall_directory_outlined
                    : Icons.apartment_outlined,
                client.businessName ?? 'Business not attached yet',
                client.hasBusiness
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFB45309),
              ),
              _tag(Icons.event_available_outlined, expiryText, statusColor),
              _tag(
                Icons.payments_outlined,
                'Total rewards ${_money(client.totalRewardEarned)}',
                const Color(0xFF7C3AED),
              ),
              if (client.monthlyRewardEarned > 0)
                _tag(
                  Icons.trending_up_rounded,
                  'This month ${_money(client.monthlyRewardEarned)}',
                  const Color(0xFF2563EB),
                ),
            ],
          ),
          if ((client.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(client.notes!, style: TextStyle(color: Colors.grey.shade700)),
          ],
          if (client.isExpiringSoon) ...[
            const SizedBox(height: 12),
            Text(
              'Renewal follow-up is due soon. Reach out before this client slips out of the active bucket.',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (client.status == MarketerClientStatus.needsBusiness) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _openBusiness(client),
              icon: const Icon(Icons.business_center_rounded),
              label: const Text('Register business'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFD6EEFF),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _tag(IconData icon, String text, Color color) {
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
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
