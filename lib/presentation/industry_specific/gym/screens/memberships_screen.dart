import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
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
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            tooltip: 'Manage Plans',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PlanManagementScreen(),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: provider.plans.isEmpty
          ? Center(
              child: Text(
                'No membership plans available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: provider.plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final plan = provider.plans[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                plan.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              formatCurrency(plan.pricePerMonth),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${plan.durationMonths} month(s) - billed monthly',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        if (plan.features.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: plan.features
                                .map(
                                  (feature) => Chip(
                                    label: Text(feature),
                                    backgroundColor: AppColors.primary
                                        .withOpacity(0.08),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                String selectedMemberId = provider.members.isNotEmpty
                                    ? provider.members.first.id
                                    : '';

                                final messenger = ScaffoldMessenger.of(context);

                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => StatefulBuilder(
                                    builder: (ctx, setDialogState) => AlertDialog(
                                      title: Text('Buy ${plan.name}?'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Confirm purchase for ${formatCurrency(plan.pricePerMonth)} per month.',
                                          ),
                                          const SizedBox(height: 12),
                                          if (provider.members.isNotEmpty)
                                            DropdownButton<String>(
                                              value: selectedMemberId.isEmpty
                                                  ? null
                                                  : selectedMemberId,
                                              isExpanded: true,
                                              items: provider.members
                                                  .map(
                                                    (member) => DropdownMenuItem(
                                                      value: member.id,
                                                      child: Text(member.name),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (value) {
                                                setDialogState(
                                                  () => selectedMemberId =
                                                      value ?? '',
                                                );
                                              },
                                            )
                                          else
                                            const Text(
                                              'No members available; purchase will be recorded as a general payment.',
                                            ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Confirm'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );

                                if (confirmed == true) {
                                  try {
                                    await provider.recordPayment(
                                      selectedMemberId,
                                      plan.pricePerMonth,
                                      'manual',
                                      planId: plan.id,
                                      note: 'Plan purchase (confirmed)',
                                    );
                                    if (selectedMemberId.isNotEmpty) {
                                      await provider.assignMembership(
                                        selectedMemberId,
                                        plan.id,
                                        plan.durationMonths,
                                      );
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Purchased ${plan.name}'),
                                      ),
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Purchase failed: $e'),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Buy'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () {
                                showModalBottomSheet<void>(
                                  context: context,
                                  builder: (ctx) => Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plan.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Price: ${formatCurrency(plan.pricePerMonth)} / month',
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Duration: ${plan.durationMonths} month(s)',
                                        ),
                                        if (plan.features.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Features',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...plan.features.map(
                                            (feature) => Text('- $feature'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Details'),
                            ),
                          ],
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
