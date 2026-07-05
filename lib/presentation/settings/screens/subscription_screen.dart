import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../services/subscription_service.dart';
// Use AuthProvider to update user instead of directly depending on AuthRepository

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _currentPlan = 'tier1';

  String _resolveCurrentUserId(AuthProvider authProvider) {
    final userId = authProvider.currentUser?.id.trim() ?? '';
    if (userId.isNotEmpty) return userId;
    return FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  }

  @override
  void initState() {
    super.initState();
    final business = context.read<BusinessProvider>().currentBusiness;
    _currentPlan =
        (business?.subscriptionPlan ?? business?.subscriptionTier ?? 'tier1')
            .toLowerCase();
  }

  Widget _buildCurrentPlanCard(
      SubscriptionPlan plan, bool isActive, DateTime? endDate) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withOpacity(isDark ? 0.20 : 0.10),
            scheme.surfaceContainerHighest.withOpacity(isDark ? 0.72 : 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withOpacity(isDark ? 0.48 : 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Plan',
                style: AppTextStyles.body2
                    .copyWith(color: scheme.onSurface.withOpacity(0.72)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : scheme.outline,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            plan.name,
            style: AppTextStyles.heading4.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          if (endDate != null)
            Text(
              'Expires: ${endDate.toString().split(' ')[0]}',
              style: AppTextStyles.caption
                  .copyWith(color: scheme.onSurface.withOpacity(0.72)),
            ),
          const SizedBox(height: 12),
          if (isActive)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showRenewDialog(plan),
                child: const Text('Renew'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBillingInfoCard(
      dynamic business, SubscriptionPlan? currentPlan, DateTime? endDate) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Billing Information',
            style: AppTextStyles.heading5.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildBillingRow('Account name:', 'Manage Care Limited'),
          const SizedBox(height: 12),
          _buildBillingRow('Bank', 'Moniepoint'),
          const SizedBox(height: 12),
          _buildBillingRow('Bank account no.:', '5181766595'),
          const SizedBox(height: 12),
          _buildBillingRow('Plan', currentPlan?.name ?? 'N/A'),
          const SizedBox(height: 12),
          _buildBillingRow(
              'Price',
              currentPlan != null
                  ? '₦${currentPlan.price.toStringAsFixed(0)}'
                  : 'N/A'),
          const SizedBox(height: 12),
          _buildBillingRow(
              'Duration',
              currentPlan != null
                  ? '${currentPlan.durationInDays} days'
                  : 'N/A'),
          const SizedBox(height: 12),
          _buildBillingRow(
            'Start Date',
            business?.subscriptionStartDate != null
                ? business!.subscriptionStartDate.toString().split(' ')[0]
                : 'N/A',
          ),
          const SizedBox(height: 12),
          _buildBillingRow(
            'End Date',
            endDate != null ? endDate.toString().split(' ')[0] : 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildBillingRow(String label, String value) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                AppTextStyles.body2.copyWith(color: scheme.onSurface.withOpacity(0.72))),
        Text(value,
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            )),
      ],
    );
  }

  List<Widget> _buildPlanCards({
    required String? businessType,
    required String? tierId,
    required String currentPlanId,
  }) {
    return SubscriptionService.getPlansForBusinessType(businessType, tierId: tierId)
        .map((plan) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PlanCard(
                plan: plan,
                isCurrentPlan: currentPlanId.toLowerCase() == plan.id.toLowerCase(),
                onSelect: () => _showUpgradeDialog(plan),
              ),
            ))
        .toList();
  }

  void _showUpgradeDialog(SubscriptionPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade to ${plan.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: ₦${plan.price.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            Text('Duration: ${plan.durationInDays} days'),
            const SizedBox(height: 16),
            const Text(
              'Continue to secure Kora checkout for automatic subscription activation.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openSubscriptionCheckout(plan);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showRenewDialog(SubscriptionPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Renew ${plan.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: ₦${plan.price.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            Text('Duration: ${plan.durationInDays} days'),
            const SizedBox(height: 16),
            const Text(
              'Continue to secure Kora checkout for automatic renewal approval.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openSubscriptionCheckout(plan);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _openSubscriptionCheckout(SubscriptionPlan plan) {
    final authProvider = context.read<AuthProvider>();
    final businessProvider = context.read<BusinessProvider>();
    final currentUser = authProvider.currentUser;
    final currentUserId = _resolveCurrentUserId(authProvider);

    if (currentUser == null || currentUserId.isEmpty) {
      _showError('Please sign in again before updating your subscription.');
      return;
    }

    Navigator.of(context).pushNamed(
      Routes.subscriptionPayment,
      arguments: {
        'userId': currentUserId,
        'userEmail': currentUser.email,
        'userName': currentUser.fullName,
        'businessId': businessProvider.currentBusiness?.id,
        'businessType': businessProvider.currentBusiness?.businessType,
        'businessTier': businessProvider.currentBusiness?.subscriptionTier,
        'businessClass': businessProvider.currentBusiness?.businessClass,
        'initialPlanId': plan.id,
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Consumer2<AuthProvider, BusinessProvider>(
      builder: (context, authProvider, businessProvider, _) {
        final user = authProvider.currentUser;
        final business = businessProvider.currentBusiness;
        final hasActiveSubscription = business?.isSubscriptionActive ?? false;
        final currentPlanId =
            (business?.subscriptionPlan ?? business?.subscriptionTier ?? _currentPlan)
                .toLowerCase();
        final fallbackPlans = SubscriptionService.getPlansForBusinessType(
          business?.businessType,
          tierId: business?.subscriptionTier,
        );
        final currentPlan = SubscriptionService.getPlanById(currentPlanId) ??
            (fallbackPlans.isNotEmpty ? fallbackPlans.first : null);
        final subscriptionEndDate = business?.subscriptionEndDate;
        _currentPlan = currentPlanId;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Subscription'),
            elevation: 0,
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: theme.iconTheme.color),
            actions: [
              TextButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/');
                  }
                },
                child: Text(
                  'Skip',
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Plan Card
                if (currentPlan != null)
                  _buildCurrentPlanCard(
                      currentPlan, hasActiveSubscription, subscriptionEndDate),
                const SizedBox(height: 24),

                // Billing Info
                _buildBillingInfoCard(business, currentPlan, subscriptionEndDate),
                const SizedBox(height: 24),

                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('View subscription transactions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pushNamed(Routes.subscriptionTransactions);
                  },
                ),
                const SizedBox(height: 12),

                // Available Plans
                Text(
                  'Available Plans',
                  style: AppTextStyles.heading5.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildPlanCards(
                  businessType: business?.businessType ?? user?.businessType,
                  tierId: business?.subscriptionTier ?? business?.businessClass,
                  currentPlanId: currentPlanId,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrentPlan,
    required this.onSelect,
  });

  final bool isCurrentPlan;
  final VoidCallback onSelect;
  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentPlan
            ? scheme.primary.withOpacity(isDark ? 0.18 : 0.10)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlan
              ? scheme.primary
              : scheme.outline.withOpacity(0.28),
          width: isCurrentPlan ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₦${plan.price.toStringAsFixed(0)} / ${plan.durationInDays} days',
                  style: AppTextStyles.caption
                      .copyWith(color: scheme.onSurface.withOpacity(0.72)),
                ),
                if (plan.features.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...plan.features.take(2).map(
                        (feature) => Text(
                          '• $feature',
                          style: AppTextStyles.caption.copyWith(
                            color: scheme.onSurface.withOpacity(0.78),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: isCurrentPlan ? null : onSelect,
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentPlan
                  ? scheme.outline.withOpacity(0.60)
                  : AppColors.primary,
            ),
            child: Text(isCurrentPlan ? 'Current' : 'Select'),
          ),
        ],
      ),
    );
  }
}

