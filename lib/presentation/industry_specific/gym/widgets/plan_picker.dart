import 'package:flutter/material.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/gym_provider.dart';

/// Displays a modal listing available membership plans and returns the
/// selected [MembershipPlan] or null if the user cancels.
Future<MembershipPlan?> showPlanPicker(
    BuildContext context, List<MembershipPlan> plans) {
  return showDialog<MembershipPlan>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Choose a Plan'),
        content: SizedBox(
          width: double.maxFinite,
          child: plans.isEmpty
              ? const Text('No plans available')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const Divider(height: 8),
                  itemBuilder: (context, index) {
                    final p = plans[index];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                          '${p.durationMonths} month(s) - ${formatCurrency(p.pricePerMonth)} per month${p.features.isNotEmpty ? '\n${p.features.join(', ')}' : ''}'),
                      trailing: ElevatedButton(
                        child: const Text('Select'),
                        onPressed: () => Navigator.of(ctx).pop(p),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel')),
        ],
      );
    },
  );
}

