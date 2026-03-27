import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../models/marketer_model.dart';
import '../../providers/marketer_provider.dart';

class MarketerDashboardScreen extends StatefulWidget {
  const MarketerDashboardScreen({super.key});

  @override
  State<MarketerDashboardScreen> createState() => _MarketerDashboardScreenState();
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
    if (marketer != null) {
      await provider.fetchMarketerReferrals(marketer.email);
    }
  }

  List<ReferralRecord> _filtered(List<ReferralRecord> referrals) {
    switch (_filter) {
      case 'pending':
        return referrals.where((e) => e.status == 'pending').toList();
      case 'approved':
        return referrals.where((e) => e.status == 'approved').toList();
      case 'needs_business':
        return referrals
            .where((e) =>
                e.status == 'pending' &&
                (e.businessId == null || e.businessId!.isEmpty))
            .toList();
      case 'rejected':
        return referrals.where((e) => e.status == 'rejected').toList();
      default:
        return referrals;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF15803D);
      case 'rejected':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFFB45309);
    }
  }

  String _money(double value) => 'NGN ${value.toStringAsFixed(0)}';

  String _date(DateTime value) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  Future<void> _logout() async {
    context.read<MarketerProvider>().logoutMarketer();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.marketerLogin, (route) => false);
  }

  Future<void> _openBusiness(ReferralRecord referral) async {
    await Navigator.of(context).pushNamed(
      Routes.marketerRegisterBusiness,
      arguments: {'userId': referral.userId, 'userEmail': referral.userEmail},
    );
    if (mounted) _refresh();
  }

  void _pickLead(List<ReferralRecord> referrals) {
    if (referrals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending leads need a business setup right now')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Choose a lead', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...referrals.map(
              (referral) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1_rounded)),
                title: Text(referral.userEmail),
                subtitle: Text('Created ${_date(referral.createdAt)}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).pop();
                  _openBusiness(referral);
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
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _action(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
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
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(Routes.marketerLogin, (route) => false),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Go To Marketer Login'),
              ),
            ),
          );
        }

        final referrals = provider.referrals;
        final needsBusiness = referrals
            .where((e) => e.status == 'pending' && (e.businessId == null || e.businessId!.isEmpty))
            .toList();
        final approved = referrals.where((e) => e.status == 'approved').length;
        final pending = referrals.where((e) => e.status == 'pending').length;
        final rejected = referrals.where((e) => e.status == 'rejected').length;
        final attached = referrals.where((e) => e.businessId != null && e.businessId!.isNotEmpty).length;
        final visible = _filtered(referrals);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Marketer Hub'),
            actions: [
              IconButton(
                onPressed: provider.isLoading
                    ? null
                    : () {
                        _refresh();
                      },
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).pushNamed(Routes.marketerRegisterUser),
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
                      colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF14B8A6)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(marketer.fullName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(marketer.email, style: const TextStyle(color: Color(0xFFD6EEFF))),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _heroPill(Icons.account_balance_wallet_outlined, 'Balance', _money(marketer.balance)),
                          _heroPill(Icons.approval_outlined, 'Earned', _money(marketer.totalCommissionEarned)),
                          _heroPill(Icons.phone_outlined, 'Phone', marketer.phoneNumber?.isNotEmpty == true ? marketer.phoneNumber! : 'Not set'),
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
                    _metric('Total leads', '${referrals.length}', Icons.groups_rounded, const Color(0xFF1D4ED8)),
                    _metric('Need business', '${needsBusiness.length}', Icons.store_mall_directory_outlined, const Color(0xFFB45309)),
                    _metric('Approved', '$approved', Icons.task_alt_rounded, const Color(0xFF15803D)),
                    _metric('Attached', '$attached', Icons.apartment_rounded, const Color(0xFF0F766E)),
                  ],
                ),
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
                      const Text('Quick actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text('Move leads from registration to full business setup faster.', style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _action('Register new lead', 'Create a new owner account.', Icons.person_add_alt_1_rounded, const Color(0xFF1D4ED8), () => Navigator.of(context).pushNamed(Routes.marketerRegisterUser)),
                          _action('Attach business', 'Finish setup for waiting leads.', Icons.business_center_outlined, const Color(0xFFB45309), () => _pickLead(needsBusiness)),
                          _action('Change password', 'Keep your marketer access secure.', Icons.lock_reset_rounded, const Color(0xFF0F766E), () => Navigator.of(context).pushNamed(Routes.marketerChangePassword)),
                          _action('Refresh pipeline', 'Pull the latest referral updates.', Icons.sync_rounded, const Color(0xFF7C3AED), () {
                            _refresh();
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _mini('Pending', '$pending', const Color(0xFFB45309))),
                      const SizedBox(width: 10),
                      Expanded(child: _mini('Approved', '$approved', const Color(0xFF15803D))),
                      const SizedBox(width: 10),
                      Expanded(child: _mini('Rejected', '$rejected', const Color(0xFFB91C1C))),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  children: [
                    _filterChip('All', 'all'),
                    _filterChip('Pending', 'pending'),
                    _filterChip('Needs business', 'needs_business'),
                    _filterChip('Approved', 'approved'),
                    _filterChip('Rejected', 'rejected'),
                  ],
                ),
                const SizedBox(height: 14),
                if (!provider.isLoading && visible.isEmpty)
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
                        const Text('No referrals match this view yet.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Switch filters or create a new lead to keep moving.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                else
                  ...visible.map(
                    (referral) => Container(
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
                                backgroundColor: _statusColor(referral.status).withOpacity(0.12),
                                child: Icon(Icons.person_outline_rounded, color: _statusColor(referral.status)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(referral.userEmail, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                    Text('Created ${_date(referral.createdAt)}', style: TextStyle(color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _statusColor(referral.status).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(referral.status.toUpperCase(), style: TextStyle(color: _statusColor(referral.status), fontSize: 12, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _tag(Icons.paid_outlined, _money(referral.commissionAmount), const Color(0xFF15803D)),
                              _tag(
                                referral.businessId != null && referral.businessId!.isNotEmpty ? Icons.domain_verification_outlined : Icons.apartment_outlined,
                                referral.businessId != null && referral.businessId!.isNotEmpty ? 'Business attached' : 'Business pending',
                                referral.businessId != null && referral.businessId!.isNotEmpty ? const Color(0xFF0F766E) : const Color(0xFFB45309),
                              ),
                            ],
                          ),
                          if ((referral.notes ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(referral.notes!, style: TextStyle(color: Colors.grey.shade700)),
                          ],
                          if (referral.status == 'pending' && (referral.businessId == null || referral.businessId!.isEmpty)) ...[
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () => _openBusiness(referral),
                              icon: const Icon(Icons.business_center_rounded),
                              label: const Text('Register business'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
              Text(label, style: const TextStyle(color: Color(0xFFD6EEFF), fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
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
