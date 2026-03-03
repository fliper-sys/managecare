import 'package:flutter/material.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';

class SubscriptionSelectionScreen extends StatefulWidget {
  const SubscriptionSelectionScreen({super.key});

  @override
  State<SubscriptionSelectionScreen> createState() =>
      _SubscriptionSelectionScreenState();
}

class _SubscriptionSelectionScreenState
    extends State<SubscriptionSelectionScreen> {
  String? selectedPlan;

  final List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      name: 'Starter',
      price: 'Free',
      features: [
        'Basic inventory',
        'Up to 50 products',
        'Manual reports',
        'Single user',
      ],
    ),
    SubscriptionPlan(
      name: 'Pro',
      price: '\$29/month',
      features: [
        'Advanced inventory',
        'Unlimited products',
        'Automated reports',
        'Up to 5 users',
        'Priority support',
      ],
      highlighted: true,
    ),
    SubscriptionPlan(
      name: 'Enterprise',
      price: 'Custom',
      features: [
        'Everything in Pro',
        'Custom features',
        'Dedicated support',
        'Unlimited users',
        'API access',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed(Routes.ownerDashboard);
              }
            },
            child: const Text('Skip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: plans.length,
        itemBuilder: (context, index) {
          final plan = plans[index];
          return _buildPlanCard(plan);
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: selectedPlan != null
              ? () =>
                  Navigator.pushReplacementNamed(context, Routes.ownerDashboard)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Continue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isSelected = selectedPlan == plan.name;
    return GestureDetector(
      onTap: () => setState(() => selectedPlan = plan.name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.lightGrey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: plan.highlighted
              ? AppColors.primary.withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.price,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Radio<String>(
                  value: plan.name,
                  groupValue: selectedPlan,
                  onChanged: (value) => setState(() => selectedPlan = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(feature),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionPlan {
  final String name;
  final String price;
  final List<String> features;
  final bool highlighted;

  SubscriptionPlan({
    required this.name,
    required this.price,
    required this.features,
    this.highlighted = false,
  });
}

