import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../services/subscription_storage_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/subscription_service.dart';
// Use AuthProvider to update user instead of directly depending on AuthRepository

import '../../../widgets/loading_indicator.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _currentPlan = 'tier1';
  bool _isLoading = false;
  File? _selectedReceipt;
  double _uploadProgress = 0.0;

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
            const Text('Upload receipt to activate subscription:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _pickReceiptFile(plan),
            child: const Text('Upload Receipt'),
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
            const Text('Upload receipt to renew subscription:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _pickReceiptFile(plan, isRenew: true),
            child: const Text('Upload Receipt to Renew'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReceiptFile(SubscriptionPlan plan, {bool isRenew = false}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final currentUserId = _resolveCurrentUserId(authProvider);
    if (currentUser == null) {
      _showError('Please sign in again before uploading a receipt.');
      return;
    }
    if (currentUserId.isEmpty) {
      _showError('We could not resolve your account ID. Please sign in again.');
      return;
    }

    // On web, ImagePicker returns an XFile that cannot be converted to dart:io File.
    // Upload bytes directly and pass the resulting URL to the activation flow.
    if (kIsWeb) {
      try {
        final bytes = await image.readAsBytes();
        final storageService = SubscriptionStorageService();
        final uploadResult = await storageService.uploadSubscriptionProofBytesWithProgress(
          bytes,
          image.name,
          currentUserId,
          plan.id,
          onProgress: (progress) {
            if (mounted) {
              setState(() => _uploadProgress = progress);
            }
          },
        );

        if (!uploadResult.success || uploadResult.downloadUrl == null) {
          _showError('Upload failed: ${uploadResult.error ?? 'Unknown error'}');
          return;
        }

        // Directly proceed with activation using the uploaded URL
        await _uploadReceiptAndActivateOrRenewSubscription(
          plan,
          isRenew: isRenew,
          serverUrlOverride: uploadResult.downloadUrl,
        );
      } catch (e) {
        _showError('Upload failed: $e');
      }
      return;
    }

    // Native platforms: use dart:io File
    _selectedReceipt = File(image.path);
    if (mounted) Navigator.pop(context);
    await _uploadReceiptAndActivateOrRenewSubscription(plan, isRenew: isRenew);
  }

    Future<void> _uploadReceiptAndActivateOrRenewSubscription(
      SubscriptionPlan plan, {bool isRenew = false, String? serverUrlOverride}) async {
    if (_selectedReceipt == null && serverUrlOverride == null) {
      _showError('No receipt selected');
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    // Show a modal upload indicator (keeps flow consistent with profile upload)
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Uploading receipt...'),
              if (_uploadProgress > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
    }

    try {
      // Upload receipt using Firebase Storage
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      final currentUserId = _resolveCurrentUserId(authProvider);
      final businessProvider = context.read<BusinessProvider>();
      final currentBusiness = businessProvider.currentBusiness;

      if (currentUser == null) {
        if (mounted) {
          Navigator.pop(context);
          setState(() => _isLoading = false);
        }
        _showError('Please sign in again before updating your subscription.');
        return;
      }
      if (currentUserId.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          setState(() => _isLoading = false);
        }
        _showError('We could not resolve your account ID. Please sign in again.');
        return;
      }

      String? receiptUrl = serverUrlOverride;
      if (receiptUrl == null && _selectedReceipt != null) {
        final storageService = SubscriptionStorageService();
        final uploadResult = await storageService.uploadSubscriptionProofWithProgress(
          _selectedReceipt!,
          currentUserId,
          plan.id,
          onProgress: (progress) {
            if (mounted) {
              setState(() => _uploadProgress = progress);
            }
          },
        );

        if (!uploadResult.success || uploadResult.downloadUrl == null) {
          if (!mounted) return;
          Navigator.pop(context); // close upload dialog
          _showError('Failed to upload receipt: ${uploadResult.error ?? 'Unknown error'}');
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        receiptUrl = uploadResult.downloadUrl;
      }

      final pendingRequestService =
          SubscriptionService(firestore: FirebaseFirestore.instance);
      final submittedForApproval =
          await pendingRequestService.submitManualSubscriptionForApproval(
        userId: currentUserId,
        planId: plan.id,
        receiptUrl: receiptUrl!,
        amount: plan.price,
        businessId: currentBusiness?.id,
        currency: currentBusiness?.currency ?? 'NGN',
        userEmail: currentUser.email,
        userName: currentUser.fullName,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (!submittedForApproval) {
        if (mounted) setState(() => _isLoading = false);
        _showError(
            isRenew ? 'Failed to submit renewal request' : 'Failed to submit upgrade request');
        return;
      }

      final stillHasActiveAccess = businessProvider.isSubscriptionValid();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedReceipt = null;
          _uploadProgress = 0.0;
        });
      }

      if (stillHasActiveAccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isRenew
                    ? 'Renewal request submitted for approval.'
                    : 'Upgrade request submitted for approval.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/subscription-status',
          arguments: {
            'userId': currentUserId,
            'userEmail': currentUser.email,
            'userName': currentUser.fullName,
            'businessId': currentBusiness?.id,
            'businessType': currentBusiness?.businessType,
            'subscriptionPlan': plan.id,
            'subscriptionAmount': plan.price,
          },
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}
      }
      if (mounted) setState(() {
        _isLoading = false;
        _uploadProgress = 0.0;
      });
      _showError('Error: $e');
    }
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
          body: _isLoading
              ? const Center(child: CustomLoadingIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Plan Card
                      if (currentPlan != null)
                        _buildCurrentPlanCard(currentPlan,
                            hasActiveSubscription, subscriptionEndDate),
                      const SizedBox(height: 24),

                      // Billing Info
                      _buildBillingInfoCard(
                          business, currentPlan, subscriptionEndDate),
                      const SizedBox(height: 24),

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

