import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/gym_provider.dart';
import 'plan_management_screen.dart';

class MembershipsScreen extends StatelessWidget {
  const MembershipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GymProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Membership Plans'),
        actions: [
          IconButton(
            tooltip: 'Manage Plans',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PlanManagementScreen(),
              ));
            },
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) {
          final p = provider.plans[index];
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('\$${p.pricePerMonth.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${p.durationMonths} month(s) • Billed monthly',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        child: const Text('Buy'),
                        onPressed: () async {
                          // allow selecting a member to associate this purchase with
                          String selectedMemberId = provider.members.isNotEmpty ? provider.members.first.id : '';

                          final messenger = ScaffoldMessenger.of(context);

                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => StatefulBuilder(
                              builder: (ctx, setState) => AlertDialog(
                                title: Text('Buy ${p.name}?'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Confirm purchase for \$${p.pricePerMonth.toStringAsFixed(2)} per month.'),
                                    const SizedBox(height: 12),
                                    if (provider.members.isNotEmpty)
                                      DropdownButton<String>(
                                        value: selectedMemberId.isEmpty ? null : selectedMemberId,
                                        isExpanded: true,
                                        items: provider.members
                                            .map((m) => DropdownMenuItem(
                                                  value: m.id,
                                                  child: Text(m.name),
                                                ))
                                            .toList(),
                                        onChanged: (v) => setState(() => selectedMemberId = v ?? ''),
                                      )
                                    else
                                      const Text('No members available; purchase will be recorded as general payment.'),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel')),
                                  ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Confirm')),
                                ],
                              ),
                            ),
                          );
                          if (confirmed == true) {
                            // Simple confirmation flow: record payment and assign membership
                            try {
                              await provider.recordPayment(selectedMemberId, p.pricePerMonth, 'manual', planId: p.id, note: 'Plan purchase (confirmed)');
                              if (selectedMemberId.isNotEmpty) {
                                await provider.assignMembership(selectedMemberId, p.id, p.durationMonths);
                              }
                              messenger.showSnackBar(SnackBar(content: Text('Purchased ${p.name}')));
                            } catch (e) {
                              messenger.showSnackBar(SnackBar(content: Text('Purchase failed: $e')));
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        child: const Text('Details'),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (ctx) => Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Price: \$${p.pricePerMonth.toStringAsFixed(2)} / month'),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Duration: ${p.durationMonths} month(s)'),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    child: const Text('Buy now'),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content:
                                                  Text('Purchased ${p.name}')));
                                    },
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    ],
                  )
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: provider.plans.length,
      ),
    );
  }
}

