import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../data/models/gym_member_model.dart';
import '../../../../data/models/gym_trainer_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/gym_provider.dart';

class GymDashboardScreen extends StatelessWidget {
  const GymDashboardScreen({super.key});

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '';
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Gym Dashboard'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Manage Workers',
            onPressed: () => Navigator.pushNamed(context, Routes.workers),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () async {
              final provider = context.read<GymProvider>();
              try {
                await provider.refresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dashboard refreshed')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Refresh failed: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              try {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed(Routes.login);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Member'),
        onPressed: () => _showAddMemberDialog(context),
      ),
      body: Consumer<GymProvider>(
        builder: (context, provider, _) {
          final totalMembers = provider.members.length;
          final upcomingCount = provider.upcomingClasses().length;
          final activeMembers = provider.members.where((m) => m.active).length;
          final now = DateTime.now();
          final expiringMembers = provider.members.where((m) {
            if (m.membershipExpiry == null) return false;
            final diff = m.membershipExpiry!.difference(now).inDays;
            return diff >= 0 && diff <= 7;
          }).toList();

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroCard(
                          title: 'Gym Overview',
                          subtitle: 'Track members, classes, and performance at a glance.',
                          accent: AppColors.primary,
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'Members',
                                  value: totalMembers.toString(),
                                  icon: Icons.people_alt_rounded,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  title: 'Active',
                                  value: activeMembers.toString(),
                                  icon: Icons.verified_rounded,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                label: 'Upcoming',
                                value: upcomingCount.toString(),
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MiniStat(
                                label: 'Expiring',
                                value: expiringMembers.length.toString(),
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search members or classes',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: theme.cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: colorScheme.outline.withOpacity(0.18),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: colorScheme.outline.withOpacity(0.18),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionHeader(
                          title: 'Shortcuts',
                          actionLabel: 'Plans',
                          onAction: () => Navigator.pushNamed(
                            context,
                            Routes.gymMemberships,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 118,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: provider.members.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              if (index == provider.members.length) {
                                return _ShortcutCard(
                                  label: 'Plans',
                                  icon: Icons.workspace_premium_rounded,
                                  color: Colors.indigo,
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    Routes.gymMemberships,
                                  ),
                                );
                              }

                              final member = provider.members[index];
                              final isExpiring = expiringMembers.any((m) => m.id == member.id);

                              return _MemberCard(
                                initials: _initials(member.name),
                                name: member.name,
                                subtitle: member.active ? 'Active member' : 'Inactive',
                                highlight: isExpiring,
                                onTap: () => Navigator.of(context).pushNamed(
                                  Routes.gymMemberDetails,
                                  arguments: member.id,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionHeader(
                          title: 'Quick Actions',
                          actionLabel: 'View all',
                          onAction: () => Navigator.pushNamed(
                            context,
                            Routes.gymCalendar,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.35,
                          children: [
                            if (context.read<AuthProvider>().isOwnerUser ||
                                WorkerPermissions.canManageGymBookings(
                                  context.read<AuthProvider>().currentUser?.role ?? '',
                                ) ||
                                WorkerPermissions.canManageStaff(
                                  context.read<AuthProvider>().currentUser?.role ?? '',
                                ))
                              _ActionTile(
                                icon: Icons.card_membership_rounded,
                                label: 'Memberships',
                                color: Colors.blue,
                                onTap: () => Navigator.of(context).pushNamed(
                                  Routes.gymMemberships,
                                ),
                              ),
                            _ActionTile(
                              icon: Icons.calendar_month_rounded,
                              label: 'Classes',
                              color: Colors.teal,
                              onTap: () => Navigator.of(context).pushNamed(
                                Routes.gymCalendar,
                              ),
                            ),
                            _ActionTile(
                              icon: Icons.fitness_center_rounded,
                              label: 'Equipment',
                              color: Colors.orange,
                              onTap: () => Navigator.of(context).pushNamed(
                                Routes.gymEquipment,
                              ),
                            ),
                            _ActionTile(
                              icon: Icons.access_time_rounded,
                              label: 'Attendance',
                              color: Colors.purple,
                              onTap: () => Navigator.of(context).pushNamed(
                                Routes.gymAttendance,
                              ),
                            ),
                            _ActionTile(
                              icon: Icons.show_chart_rounded,
                              label: 'Progress',
                              color: Colors.green,
                              onTap: () => _showMemberSelectionDialog(context),
                            ),
                            _ActionTile(
                              icon: Icons.support_agent_rounded,
                              label: 'Support',
                              color: Colors.green.shade700,
                              onTap: () => WhatsAppUtils.openCustomerSupport(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SectionHeader(title: 'Upcoming Classes'),
                        const SizedBox(height: 12),
                        if (provider.upcomingClasses().isEmpty)
                          _EmptyPanel(
                            title: 'No upcoming classes',
                            subtitle: 'Create a class schedule to see it here.',
                          )
                        else
                          ...provider.upcomingClasses().map(
                            (session) {
                              final start = session.start.toLocal();
                              final timeStr =
                                  '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ClassCard(
                                  title: session.title,
                                  subtitle:
                                      '$timeStr • ${session.bookedMemberIds.length}/${session.capacity} booked',
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      showDragHandle: true,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(24),
                                        ),
                                      ),
                                      builder: (_) => _ClassDetailSheet(
                                        cls: session,
                                        provider: provider,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMemberSelectionDialog(BuildContext context) {
    final provider = context.read<GymProvider>();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select member',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 420,
                child: ListView.separated(
                  itemCount: provider.members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final member = provider.members[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      tileColor: Colors.grey.shade50,
                      leading: CircleAvatar(
                        child: Text(_initials(member.name)),
                      ),
                      title: Text(member.name),
                      subtitle: Text(member.email),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.pushNamed(
                          context,
                          Routes.gymMemberProgress,
                          arguments: {'memberId': member.id},
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          title: const Text('Add Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dlgCtx).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter member name')),
                  );
                  return;
                }

                final member = Member(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  email: email,
                  phone: phone,
                );

                try {
                  context.read<GymProvider>().addMember(member);
                  Navigator.of(dlgCtx).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Member added')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add member: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ).then((_) {
      nameCtrl.dispose();
      emailCtrl.dispose();
      phoneCtrl.dispose();
    });
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.96),
            accent.withOpacity(0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withOpacity(0.88)),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.84),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 108,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.initials,
    required this.name,
    required this.subtitle,
    required this.highlight,
    required this.onTap,
  });

  final String initials;
  final String name;
  final String subtitle;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: highlight ? Colors.red.withOpacity(0.22) : Colors.grey.withOpacity(0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor:
                          highlight ? Colors.red.withOpacity(0.12) : Colors.blue.withOpacity(0.12),
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: highlight ? Colors.red : Colors.blue,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (highlight)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Expiring',
                          style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.class_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Details'),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_rounded, size: 38, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ClassDetailSheet extends StatelessWidget {
  final ClassSession cls;
  final GymProvider provider;

  const _ClassDetailSheet({required this.cls, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cls.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${cls.bookedMemberIds.length}/${cls.capacity} booked',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 18),
          _detailLine('Start', cls.start.toLocal().toString()),
          _detailLine('End', cls.end.toLocal().toString()),
          _detailLine('Trainer', provider.trainers.isNotEmpty ? provider.trainers.first.name : 'Not assigned'),
          const SizedBox(height: 16),
          const Text(
            'Booked members',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (cls.bookedMemberIds.isEmpty)
            const Text('No members booked yet.')
          else
            ...cls.bookedMemberIds.map(
              (memberId) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_rounded),
                title: Text(memberId),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
