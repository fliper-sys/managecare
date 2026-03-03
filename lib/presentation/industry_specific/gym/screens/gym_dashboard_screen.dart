import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/gym_provider.dart';
import '../../../../core/constants/routes.dart';
import '../../../../data/models/gym_member_model.dart';
import '../../../../data/models/gym_trainer_model.dart';

class GymDashboardScreen extends StatelessWidget {
  const GymDashboardScreen({super.key});

  String _initials(String name) {
    final parts = name.split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Manage Workers',
            onPressed: () => Navigator.pushNamed(context, Routes.workers),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final provider = Provider.of<GymProvider>(context, listen: false);
              try {
                await provider.refresh();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Refreshed')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Refresh failed: $e')));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              try {
                await context.read<AuthProvider>().logout();
                if (context.mounted) Navigator.of(context).pushReplacementNamed(Routes.login);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
        onPressed: () async {
          final nameCtrl = TextEditingController();
          final phoneCtrl = TextEditingController();
          final emailCtrl = TextEditingController();
          final provider = Provider.of<GymProvider>(context, listen: false);

          final messenger = ScaffoldMessenger.of(context);
          final res = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Add Member'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Full name')),
                  TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email')),
                  TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone')),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    provider.addMember(
                      Member(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                      ),
                    );
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          );

          if (res == true) {
            messenger.showSnackBar(const SnackBar(content: Text('Member added')));
          }
        },
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
          final expiringCount = expiringMembers.length;

          return RefreshIndicator(
            onRefresh: () async {
              try {
                await provider.refresh();
              } catch (_) {
                // ignore errors for now
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text('Gym Overview',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),

                  // metrics
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MetricCard(
                          title: 'Members',
                          value: '$totalMembers',
                          color: Colors.blue),
                      _MetricCard(
                          title: 'Active',
                          value: '$activeMembers',
                          color: Colors.green),
                      _MetricCard(
                          title: 'Upcoming',
                          value: '$upcomingCount',
                          color: Colors.orange),
                      _MetricCard(
                          title: 'Expiring',
                          value: '$expiringCount',
                          color: Colors.red),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // search
                  TextField(
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search members or classes',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8))),
                    onChanged: (q) {
                      // could filter lists in provider; left as placeholder
                    },
                  ),

                  const SizedBox(height: 12),

                  // member avatars
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.members.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        if (index == provider.members.length) {
                          return GestureDetector(
                            onTap: () => Navigator.of(context)
                                .pushNamed(Routes.gymMemberships),
                            child: Container(
                              width: 86,
                              decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Center(
                                  child: Text('Plans',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                            ),
                          );
                        }

                        final m = provider.members[index];
                        final daysLeft =
                            m.membershipExpiry?.difference(now).inDays;
                        final isExpiring =
                            daysLeft != null && daysLeft >= 0 && daysLeft <= 7;
                        return GestureDetector(
                          onTap: () => Navigator.of(context).pushNamed(
                              Routes.gymMemberDetails,
                              arguments: m.id),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                      radius: 28,
                                      child: Text(_initials(m.name))),
                                  if (isExpiring)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white,
                                                width: 1.5)),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                  width: 86,
                                  child: Text(m.name,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick actions
                  Builder(builder: (context) {
                    final auth = Provider.of<AuthProvider>(context);
                    final role = auth.currentUser?.role ?? '';
                    final actions = <Widget>[];

                    if (auth.isOwnerUser ||
                        WorkerPermissions.hasPermission(role, 'memberships') ||
                        WorkerPermissions.canManageStaff(role)) {
                      actions.add(Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.card_membership),
                          label: const Text('Memberships'),
                          onPressed: () => Navigator.of(context)
                              .pushNamed(Routes.gymMemberships),
                        ),
                      ));
                    }

                    if (auth.isOwnerUser ||
                        WorkerPermissions.hasPermission(role, 'classes') ||
                        WorkerPermissions.canAttendance(role)) {
                      if (actions.isNotEmpty) {
                        actions.add(const SizedBox(width: 12));
                      }
                      actions.add(Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Classes'),
                          onPressed: () => Navigator.of(context)
                              .pushNamed(Routes.gymCalendar),
                        ),
                      ));
                    }

                    if (actions.isEmpty) {
                      return const Center(
                          child: Text('No quick actions available'));
                    }
                    return Row(children: actions);
                  }),

                  const SizedBox(height: 18),

                  Text('Upcoming Classes',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),

                  // upcoming classes
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.upcomingClasses().length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final cls = provider.upcomingClasses()[index];
                      final start = cls.start.toLocal();
                      final timeStr =
                          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          title: Text(cls.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '$timeStr • ${cls.bookedMemberIds.length}/${cls.capacity} booked'),
                          trailing: ElevatedButton(
                            child: const Text('Details'),
                            onPressed: () {
                              showModalBottomSheet(
                                  context: context,
                                  builder: (_) => _ClassDetailSheet(
                                      cls: cls, provider: provider));
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MetricCard(
      {required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cls.title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                'Trainer: ${provider.trainers.firstWhere((t) => t.id == cls.trainerId, orElse: () => Trainer(id: 'n/a', name: 'TBD')).name}'),
            const SizedBox(height: 8),
            Text('Capacity: ${cls.capacity}'),
            const SizedBox(height: 12),
            const Text('Attendees:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cls.bookedMemberIds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final memberId = cls.bookedMemberIds[index];
                  final m = provider.members.firstWhere(
                      (mm) => mm.id == memberId,
                      orElse: () => Member(
                          id: 'n/a', name: 'Unknown', email: '', phone: ''));
                  return Column(
                    children: [
                      CircleAvatar(
                          child: Text(m.name.isEmpty ? '?' : m.name[0])),
                      const SizedBox(height: 6),
                      Text(m.name, style: const TextStyle(fontSize: 12)),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    child: const Text('Book (first member)'),
                    onPressed: () {
                      if (provider.members.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('No members to book')));
                        return;
                      }
                      try {
                        provider.bookClass(provider.members.first.id, cls.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Booked')));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not book: $e')));
                      }
                    },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

