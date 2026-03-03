import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/enhanced_subscription_provider.dart';

/// Widget to display subscription status and access information
///
/// Usage:
/// ```dart
/// Consumer2<BusinessProvider, EnhancedSubscriptionProvider>(
///   builder: (context, businessProvider, subscriptionProvider, _) {
///     final business = businessProvider.currentBusiness;
///     if (business == null) return SizedBox.shrink();
///
///     return SubscriptionStatusWidget(
///       businessId: business.id,
///       onUpgradePressed: () {
///         // Navigate to upgrade page
///       },
///     );
///   },
/// )
/// ```
class SubscriptionStatusWidget extends StatelessWidget {
  final String businessId;
  final VoidCallback? onUpgradePressed;
  final bool compact;

  const SubscriptionStatusWidget({
    super.key,
    required this.businessId,
    this.onUpgradePressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedSubscriptionProvider>(
      builder: (context, subscriptionProvider, _) {
        final status = subscriptionProvider.getSubscriptionStatus(businessId);

        if (status == null) {
          return const SizedBox.shrink();
        }

        // Show warning if subscription is invalid or expiring
        if (!status.isValid) {
          return _buildInvalidStatus(context, subscriptionProvider, status);
        }

        if (status.daysUntilExpiration != null &&
            status.daysUntilExpiration! <= 7) {
          return _buildExpiringWarning(context, subscriptionProvider, status);
        }

        // Active subscription
        if (compact) {
          return _buildCompactStatus(context, status);
        }

        return _buildFullStatus(context, status);
      },
    );
  }

  Widget _buildInvalidStatus(
    BuildContext context,
    EnhancedSubscriptionProvider subscriptionProvider,
    dynamic status,
  ) {
    final daysLeft = status.daysUntilExpiration ?? 0;
    final message = status.statusMessage ?? 'Subscription expired';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withAlpha(0x11),
        border:
            Border.all(color: Theme.of(context).colorScheme.error, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning,
                  color: Theme.of(context).colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (daysLeft > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Expires in $daysLeft days',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onUpgradePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Renew Subscription'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringWarning(
    BuildContext context,
    EnhancedSubscriptionProvider subscriptionProvider,
    dynamic status,
  ) {
    final daysLeft = status.daysUntilExpiration ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withAlpha(0x11),
        border: Border.all(
            color: Theme.of(context).colorScheme.secondary, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule,
                  color: Theme.of(context).colorScheme.secondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Subscription Expiring Soon',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your subscription expires in $daysLeft days (${status.endDate})',
            style: TextStyle(
              color: Colors.orange.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onUpgradePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Renew Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatus(BuildContext context, dynamic status) {
    return Chip(
      label: Text(
        'Tier: ${status.tier.toUpperCase()}',
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: _getTierColor(status.tier),
      labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w600),
    );
  }

  Widget _buildFullStatus(BuildContext context, dynamic status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(0x11),
        border:
            Border.all(color: Theme.of(context).colorScheme.primary, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subscription: ${status.tier.toUpperCase()}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Chip(
                label: const Text('ACTIVE'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Expires: ${status.endDate}',
            style: TextStyle(
              color: Colors.green.shade600,
              fontSize: 12,
            ),
          ),
          if (status.statusMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              status.statusMessage,
              style: TextStyle(
                color: Colors.green.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'free':
        return Colors.blue;
      case 'basic':
        return Colors.green;
      case 'pro':
        return Colors.orange;
      case 'enterprise':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

