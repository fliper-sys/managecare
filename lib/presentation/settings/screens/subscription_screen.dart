import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  late String _currentPlan;
  bool _isLoading = false;
  File? _selectedReceipt;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    _currentPlan = (user?.subscriptionPlan ?? 'free').toLowerCase();
  }

  Widget _buildCurrentPlanCard(
      SubscriptionPlan plan, bool isActive, DateTime? endDate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
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
                    .copyWith(color: AppColors.textSecondary),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.grey,
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
            style: AppTextStyles.heading4.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (endDate != null)
            Text(
              'Expires: ${endDate.toString().split(' ')[0]}',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
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
      dynamic user, SubscriptionPlan? currentPlan, DateTime? endDate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Billing Information',
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
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
            user?.subscriptionStartDate != null
                ? user!.subscriptionStartDate.toString().split(' ')[0]
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
        Text(value,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  List<Widget> _buildPlanCards() {
    return SubscriptionService.plans
        .map((plan) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PlanCard(
                plan: plan,
                isCurrentPlan:
                    _currentPlan.toLowerCase() == plan.id.toLowerCase(),
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

    // On web, ImagePicker returns an XFile that cannot be converted to dart:io File.
    // Upload bytes directly and pass the resulting URL to the activation flow.
    if (kIsWeb) {
      try {
        final bytes = await image.readAsBytes();
        final authProvider = context.read<AuthProvider>();
        final currentUser = authProvider.currentUser;
        final storageService = SubscriptionStorageService();
        final uploadResult = await storageService.uploadSubscriptionProofBytesWithProgress(
          bytes,
          image.name,
          currentUser?.id ?? 'unknown',
          plan.id,
          onProgress: (progress) {
            if (mounted) {
              setState(() => _uploadProgress = progress);
            }
          },
        );

        final uploadResultMap = {
          'success': uploadResult.success,
          'serverUrl': uploadResult.downloadUrl,
          'error': uploadResult.error,
        };

        // Directly proceed with activation using the uploaded URL
        await _uploadReceiptAndActivateOrRenewSubscription(plan, isRenew: isRenew, serverUrlOverride: uploadResultMap['serverUrl'] as String?);
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
    if (_selectedReceipt == null) {
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
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
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
      final businessProvider = context.read<BusinessProvider>();
      final currentBusiness = businessProvider.currentBusiness;

      String? receiptUrl = serverUrlOverride;
      if (receiptUrl == null && _selectedReceipt != null) {
        final storageService = SubscriptionStorageService();
        final uploadResult = await storageService.uploadSubscriptionProofWithProgress(
          _selectedReceipt!,
          currentUser?.id ?? 'unknown',
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

      // Activate or renew subscription via SubscriptionService so events and logs are recorded
      if (currentUser != null) {
        final subscriptionService = SubscriptionService(firestore: FirebaseFirestore.instance);
        final activationSuccess = await subscriptionService.activateOrRenewSubscription(
          userId: currentUser.id,
          planId: plan.id,
          receiptUrl: receiptUrl!,
          amount: plan.price,
          businessId: currentBusiness?.id,
        );

        if (!mounted) return;

        if (!activationSuccess) {
          if (mounted) setState(() => _isLoading = false);
          _showError(isRenew ? 'Failed to renew subscription' : 'Failed to activate subscription');
          return;
        }

        // Update local models to reflect new subscription (end date is handled by service)
        final updatedUser = currentUser.copyWith(
          subscriptionPlan: plan.id,
          hasActiveSubscription: true,
          subscriptionStartDate: DateTime.now(),
          subscriptionEndDate: DateTime.now().add(Duration(days: plan.durationInDays)),
          subscriptionAmount: plan.price,
        );

        await context.read<AuthProvider>().updateUserModel(updatedUser);

        if (currentBusiness != null) {
          final updatedBusiness = currentBusiness.copyWith(
            subscriptionTier: plan.id.split('_').first,
            subscriptionPlan: plan.id,
            isSubscriptionActive: true,
          );
          await context.read<BusinessProvider>().updateBusiness(updatedBusiness);
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentPlan = plan.id;
            _selectedReceipt = null;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isRenew ? 'Subscription renewed successfully!' : 'Subscription upgraded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
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
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;
        final hasActiveSubscription = user?.hasActiveSubscription ?? false;
        final currentPlan = SubscriptionService.getPlanById(_currentPlan);
        final subscriptionEndDate = user?.subscriptionEndDate;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Subscription'),
            elevation: 0,
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.black),
            actions: [
              TextButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/');
                  }
                },
                child: const Text('Skip', style: TextStyle(color: Colors.black)),
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
                          user, currentPlan, subscriptionEndDate),
                      const SizedBox(height: 24),

                      // Available Plans
                      const Text('Available Plans',
                          style: AppTextStyles.heading5),
                      const SizedBox(height: 12),
                      ..._buildPlanCards(),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentPlan
            ? AppColors.primary.withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlan ? AppColors.primary : Colors.grey[300]!,
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
                  style:
                      AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '₦${plan.price.toStringAsFixed(0)} / ${plan.durationInDays} days',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                if (plan.features.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...plan.features.take(2).map(
                        (feature) => Text(
                          '• $feature',
                          style: AppTextStyles.caption,
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
              backgroundColor: isCurrentPlan ? Colors.grey : AppColors.primary,
            ),
            child: Text(isCurrentPlan ? 'Current' : 'Select'),
          ),
        ],
      ),
    );
  }
}

