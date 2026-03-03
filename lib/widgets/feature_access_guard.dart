import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/enhanced_subscription_provider.dart';
import '../providers/business_provider.dart';
import '../providers/auth_provider.dart';

/// Widget to guard feature access based on subscription tier
///
/// Shows feature content if user has access, otherwise shows upgrade dialog
///
/// Usage:
/// ```dart
/// FeatureAccessGuard(
///   feature: 'email_receipts',
///   child: EmailReceiptSettingsScreen(),
///   onUpgradeRequired: () {
///     // Navigate to upgrade page
///   },
/// )
/// ```
class FeatureAccessGuard extends StatelessWidget {
  final String feature;
  final Widget child;
  final VoidCallback? onUpgradeRequired;
  final bool throwOnDenied;
  final String? context;

  const FeatureAccessGuard({
    super.key,
    required this.feature,
    required this.child,
    this.onUpgradeRequired,
    this.throwOnDenied = false,
    this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<BusinessProvider, EnhancedSubscriptionProvider>(
      builder: (context, businessProvider, subscriptionProvider, _) {
        final business = businessProvider.currentBusiness;

        if (business == null) {
          return const Center(
            child: Text('No business selected'),
          );
        }

        // Use FutureBuilder to handle async access check
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final userRole = auth.currentUser?.role;

        return FutureBuilder<bool>(
          future: subscriptionProvider.canAccessFeature(
            business: business,
            feature: feature,
            context: this.context ?? feature,
            userRole: userRole,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || snapshot.data != true) {
              // Access denied
              return _buildAccessDenied(
                context,
                subscriptionProvider,
                business,
                'Feature not available for your subscription',
                userRole,
              );
            }

            // Access granted
            return child;
          },
        );
      },
    );
  }

  Widget _buildAccessDenied(
    BuildContext context,
    EnhancedSubscriptionProvider subscriptionProvider,
    dynamic business,
    String denialReason,
    String? userRole,
  ) {
    final upgradePath =
        subscriptionProvider.needsUpgrade(business: business, feature: feature, userRole: userRole)
            ? subscriptionProvider.getUpgradePath(
                business: business, feature: feature, userRole: userRole)
            : null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Feature Locked',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              denialReason,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            if (upgradePath != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade Required',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      upgradePath.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onUpgradeRequired ??
                    () {
                      Navigator.of(context).pop();
                    },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Upgrade Subscription'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mixin to add feature access check to any widget
///
/// Usage:
/// ```dart
/// class MyFeatureScreen extends StatelessWidget with FeatureAccessMixin {
///   @override
///   String get requiredFeature => 'email_receipts';
///
///   @override
///   Widget buildContent(BuildContext context) {
///     return MyActualContent();
///   }
/// }
/// ```
mixin FeatureAccessMixin {
  String get requiredFeature;

  Widget buildContent(BuildContext context);

  Widget build(BuildContext context) {
    return FeatureAccessGuard(
      feature: requiredFeature,
      child: buildContent(context),
    );
  }
}

