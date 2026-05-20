import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/gym_provider.dart';
import '../../../../widgets/profile_avatar.dart';
import '../../../../data/models/gym_member_model.dart';
import '../widgets/plan_picker.dart';

class MemberDetailScreen extends StatelessWidget {
  final String memberId;

  const MemberDetailScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GymProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final role = auth.currentUser?.role ?? '';
    final canManageMemberships =
        WorkerPermissions.canManageGymBookings(role) ||
            WorkerPermissions.canManageStaff(role);
    final canTrackAttendance =
        WorkerPermissions.canAttendance(role) || canManageMemberships;
    final member = provider.members.firstWhere(
      (item) => item.id == memberId,
      orElse: () => Member(id: 'n/a', name: 'Unknown', email: '', phone: ''),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(member.name),
        backgroundColor: AppColors.primary,
      ),
      backgroundColor: Colors.grey[50],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              ProfileAvatar(
                radius: 36,
                photoUrl: null,
                initials: member.name.isNotEmpty ? member.name[0] : '?',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(member.email.isEmpty ? 'No email set' : member.email),
                    const SizedBox(height: 2),
                    Text(member.phone.isEmpty ? 'No phone set' : member.phone),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Member Since: ${DateFormat('MMM d, yyyy').format(member.joinedAt)}',
          ),
          const SizedBox(height: 12),
          if (member.membershipExpiry != null) ...[
            _ExpiryBanner(
              member: member,
              provider: provider,
              canManageMemberships: canManageMemberships,
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Membership',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.membershipPlanId ?? 'No active plan',
                        ),
                      ),
                      ElevatedButton(
                        onPressed: canManageMemberships
                            ? () async {
                                final chosen = await showPlanPicker(
                                  context,
                                  provider.plans,
                                );
                                if (chosen == null) return;
                                await provider.assignMembership(
                                  member.id,
                                  chosen.id,
                                  chosen.durationMonths,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Membership assigned'),
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: const Text('Assign'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(
                onPressed: canTrackAttendance
                    ? () async {
                        member.active = !member.active;
                        await provider.updateMember(member);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                member.active ? 'Checked in' : 'Checked out',
                              ),
                            ),
                          );
                        }
                      }
                    : null,
                child: Text(member.active ? 'Check-out' : 'Check-in'),
              ),
              OutlinedButton(
                onPressed: canManageMemberships
                    ? () => _showEditDialog(context, provider, member)
                    : null,
                child: const Text('Edit'),
              ),
              OutlinedButton(
                onPressed: WorkerPermissions.canManageStaff(role)
                    ? () => _confirmDelete(context, provider, member)
                    : null,
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    GymProvider provider,
    Member member,
  ) {
    final nameCtrl = TextEditingController(text: member.name);
    final emailCtrl = TextEditingController(text: member.email);
    final phoneCtrl = TextEditingController(text: member.phone);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
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
          ElevatedButton(
            onPressed: () async {
              final updated = Member(
                id: member.id,
                name: nameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                joinedAt: member.joinedAt,
                active: member.active,
                membershipPlanId: member.membershipPlanId,
                membershipExpiry: member.membershipExpiry,
              );
              await provider.updateMember(updated);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    GymProvider provider,
    Member member,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Delete ${member.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteMember(member.id);
              if (context.mounted) Navigator.of(context).pop();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ExpiryBanner extends StatelessWidget {
  final Member member;
  final GymProvider provider;
  final bool canManageMemberships;

  const _ExpiryBanner({
    required this.member,
    required this.provider,
    required this.canManageMemberships,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysLeft = member.membershipExpiry!.difference(now).inDays;

    if (daysLeft < 0) {
      return _BannerCard(
        color: Colors.red,
        icon: Icons.warning,
        text: 'Membership expired ${-daysLeft} day(s) ago',
        onPressed: canManageMemberships
            ? () async {
                final chosen = await showPlanPicker(context, provider.plans);
                if (chosen != null) {
                  await provider.assignMembership(
                    member.id,
                    chosen.id,
                    chosen.durationMonths,
                  );
                }
              }
            : null,
      );
    }

    if (daysLeft <= 7) {
      return _BannerCard(
        color: Colors.orange,
        icon: Icons.schedule,
        text: 'Membership expires in $daysLeft day(s)',
        onPressed: canManageMemberships
            ? () async {
                final chosen = await showPlanPicker(context, provider.plans);
                if (chosen != null) {
                  await provider.assignMembership(
                    member.id,
                    chosen.id,
                    chosen.durationMonths,
                  );
                }
              }
            : null,
      );
    }

    return const SizedBox.shrink();
  }
}

class _BannerCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final Future<void> Function()? onPressed;

  const _BannerCard({
    required this.color,
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
          ElevatedButton(
            onPressed: onPressed,
            child: const Text('Renew'),
          ),
        ],
      ),
    );
  }
}
