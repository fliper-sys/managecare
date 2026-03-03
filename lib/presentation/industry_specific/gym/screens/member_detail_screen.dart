import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final member = provider.members.firstWhere((m) => m.id == memberId,
        orElse: () => Member(id: 'n/a', name: 'Unknown', email: '', phone: ''));

    return Scaffold(
      appBar: AppBar(title: Text(member.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                    radius: 36,
                    // Member model currently doesn't include a photo field
                    photoUrl: null,
                    initials: member.name.isNotEmpty ? member.name[0] : '?'),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(member.email),
                    const SizedBox(height: 2),
                    Text(member.phone),
                  ],
                )
              ],
            ),
            const SizedBox(height: 18),
            Text('Member Since: ${member.joinedAt.toLocal()}'),
            const SizedBox(height: 8),
            // Expiry warning
            if (member.membershipExpiry != null) ...[
              Builder(builder: (ctx) {
                final now = DateTime.now();
                final daysLeft =
                    member.membershipExpiry!.difference(now).inDays;
                if (daysLeft < 0) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'Membership expired ${-daysLeft} day(s) ago',
                              style: const TextStyle(color: Colors.red))),
                      ElevatedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final chosen =
                                await showPlanPicker(context, provider.plans);
                            if (chosen != null) {
                              await provider.assignMembership(
                                  member.id, chosen.id, chosen.durationMonths);
                              messenger.showSnackBar(
                                  const SnackBar(
                                      content: Text('Membership renewed')));
                            }
                          },
                          child: const Text('Renew'))
                    ]),
                  );
                }
                if (daysLeft <= 7) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.schedule, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('Membership expires in $daysLeft day(s)',
                              style: const TextStyle(color: Colors.orange))),
                      ElevatedButton(
                          onPressed: () async {
                            final chosen =
                                await showPlanPicker(context, provider.plans);
                            if (chosen != null) {
                              await provider.assignMembership(
                                  member.id, chosen.id, chosen.durationMonths);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Membership renewed')));
                            }
                          },
                          child: const Text('Renew'))
                    ]),
                  );
                }
                return const SizedBox.shrink();
              }),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  child: Text(member.active ? 'Check-out' : 'Check-in'),
                  onPressed: () {
                    member.active = !member.active;
                    provider.updateMember(member);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            member.active ? 'Checked in' : 'Checked out')));
                  },
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  child: const Text('Edit'),
                  onPressed: () {
                    // edit flow with persistence
                    final nameCtrl = TextEditingController(text: member.name);
                    final emailCtrl = TextEditingController(text: member.email);
                    final phoneCtrl = TextEditingController(text: member.phone);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Edit Member'),
                        content:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Full name')),
                          TextField(
                              controller: emailCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Email')),
                          TextField(
                              controller: phoneCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Phone')),
                        ]),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel')),
                          ElevatedButton(
                              onPressed: () async {
                                final dialogNavigator = Navigator.of(ctx);
                                final messenger = ScaffoldMessenger.of(context);
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
                                dialogNavigator.pop();
                                messenger.showSnackBar(
                                    const SnackBar(
                                        content: Text('Member updated')));
                              },
                              child: const Text('Save'))
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  child: const Text('Delete'),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                              title: const Text('Delete Member'),
                              content: Text('Delete ${member.name}?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete'))
                              ],
                            ));
                    if (ok == true) {
                      final navigator = Navigator.of(context);
                      await provider.deleteMember(member.id);
                      navigator.pop();
                    }
                  },
                )
              ],
            ),
            const SizedBox(height: 12),
            const Text('Membership',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: Text(member.membershipPlanId ?? 'No active plan')),
              ElevatedButton(
                  onPressed: () async {
                    // show plan picker modal
                    final chosen =
                        await showPlanPicker(context, provider.plans);
                    if (chosen == null) return;
                    await provider.assignMembership(
                        member.id, chosen.id, chosen.durationMonths);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Membership assigned')));
                  },
                  child: const Text('Assign'))
            ])
          ],
        ),
      ),
    );
  }
}

