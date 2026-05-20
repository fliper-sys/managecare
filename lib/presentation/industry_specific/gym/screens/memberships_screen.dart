import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../data/models/gym_member_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/gym_provider.dart';
import '../../../../providers/hotel_provider.dart';
import '../../../../services/kora_payment_service.dart';
import '../../../auth/screens/kora_checkout_screen.dart';
import 'plan_management_screen.dart';

class MembershipsScreen extends StatelessWidget {
  const MembershipsScreen({super.key});

  void _showBlockingDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _dismissBlockingDialog(BuildContext context) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _buyPlanWithKora({
    required BuildContext context,
    required GymProvider provider,
    required BusinessProvider businessProvider,
    required String selectedMemberId,
    required Member selectedMember,
    required MembershipPlan plan,
    required double effectivePrice,
    required String guestTier,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final currentBusiness = businessProvider.currentBusiness;
    final businessId = currentBusiness?.id ??
        provider.currentBusinessId ??
        currentUser?.primaryBusinessId ??
        '';

    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in again before making payment.')),
      );
      return;
    }

    if (businessId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Select a business before making payment.'),
        ),
      );
      return;
    }

    if (effectivePrice <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Plan price must be greater than zero.')),
      );
      return;
    }

    final customerEmail = selectedMember.email.trim().isNotEmpty
        ? selectedMember.email.trim()
        : currentUser.email.trim();
    final customerName = selectedMember.name.trim().isNotEmpty
        ? selectedMember.name.trim()
        : currentUser.fullName.trim();

    if (customerEmail.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('A customer email is required for Kora checkout.'),
        ),
      );
      return;
    }

    final reference = KoraPaymentService.buildReference(
      prefix: 'kgym',
      userId: currentUser.id,
    );
    final paymentService = KoraPaymentService();
    var isBlockingDialogVisible = false;

    void showProgress(String message) {
      isBlockingDialogVisible = true;
      _showBlockingDialog(context, message);
    }

    void hideProgress() {
      if (!isBlockingDialogVisible) return;
      _dismissBlockingDialog(context);
      isBlockingDialogVisible = false;
    }

    try {
      showProgress('Preparing secure Kora checkout...');
      final initialization = await paymentService.initializeSubscriptionPayment(
        reference: reference,
        amount: effectivePrice,
        currency: currentBusiness?.currency ?? 'NGN',
        email: customerEmail,
        fullName: customerName.isNotEmpty ? customerName : customerEmail,
        planId: plan.id,
        businessId: businessId,
        userId: currentUser.id,
        businessType: currentBusiness?.businessType ?? 'gym',
      );
      hideProgress();

      if (!context.mounted) return;
      final checkoutResult = await Navigator.of(context).push<KoraCheckoutResult>(
        MaterialPageRoute(
          builder: (_) => KoraCheckoutScreen(
            checkoutUrl: initialization.checkoutUrl,
            redirectUrl: initialization.redirectUrl,
            reference: initialization.reference,
          ),
        ),
      );

      if (checkoutResult?.completed != true) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Kora checkout was not completed.')),
        );
        return;
      }

      final verifiedReference =
          checkoutResult?.reference?.trim().isNotEmpty == true
              ? checkoutResult!.reference!.trim()
              : initialization.reference;

      if (!context.mounted) return;
      showProgress('Verifying Kora payment...');
      final verification = await paymentService.verifySubscriptionPayment(
        reference: verifiedReference,
        planId: plan.id,
        userId: currentUser.id,
        businessId: businessId,
      );
      hideProgress();

      if (!verification.success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Payment verification failed: ${verification.message}',
            ),
          ),
        );
        return;
      }

      await provider.recordPayment(
        selectedMemberId,
        effectivePrice,
        'kora',
        planId: plan.id,
        note:
            'Kora plan purchase (${guestTier.replaceAll('_', ' ')}) - Ref: $verifiedReference',
        currency: currentBusiness?.currency ?? 'NGN',
      );
      if (selectedMemberId.isNotEmpty) {
        await provider.assignMembership(
          selectedMemberId,
          plan.id,
          plan.durationMonths,
          recordPaymentEntry: false,
        );
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Purchased ${plan.name} with Kora')),
      );
    } catch (e) {
      hideProgress();
      messenger.showSnackBar(
        SnackBar(content: Text('Purchase failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GymProvider>(context);
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    final businessProvider =
        Provider.of<BusinessProvider>(context, listen: false);

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
                                String selectedMemberId =
                                    provider.members.isNotEmpty
                                        ? provider.members.first.id
                                        : '';

                                Member resolveSelectedMember() {
                                  if (selectedMemberId.isEmpty) {
                                    return Member(
                                      id: '',
                                      name: '',
                                      email: '',
                                      phone: '',
                                    );
                                  }
                                  return provider.members.firstWhere(
                                    (member) => member.id == selectedMemberId,
                                    orElse: () => Member(
                                      id: '',
                                      name: '',
                                      email: '',
                                      phone: '',
                                    ),
                                  );
                                }

                                double resolveEffectivePrice(Member member) {
                                  if (member.id.isEmpty) {
                                    return plan.pricePerMonth;
                                  }
                                  return hotelProvider
                                      .calculateTieredHospitalityPrice(
                                    plan.pricePerMonth,
                                    guestName: member.name,
                                    guestEmail: member.email,
                                    guestPhone: member.phone,
                                  );
                                }

                                String resolveGuestTier(Member member) {
                                  if (member.id.isEmpty) return 'walk_in';
                                  return hotelProvider.getGuestTier(
                                    guestName: member.name,
                                    guestEmail: member.email,
                                    guestPhone: member.phone,
                                  );
                                }

                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => StatefulBuilder(
                                    builder: (ctx, setDialogState) {
                                      final selectedMember =
                                          resolveSelectedMember();
                                      final effectivePrice =
                                          resolveEffectivePrice(selectedMember);
                                      final guestTier = resolveGuestTier(selectedMember);
                                      return AlertDialog(
                                        title: Text('Buy ${plan.name}?'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Confirm purchase for ${formatCurrency(effectivePrice)} per month.',
                                            ),
                                            if (selectedMember.id.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Text(
                                                  'Guest tier: ${guestTier.replaceAll('_', ' ').toUpperCase()}',
                                                ),
                                              ),
                                            const SizedBox(height: 12),
                                            if (provider.members.isNotEmpty)
                                              DropdownButton<String>(
                                                value: selectedMemberId.isEmpty
                                                    ? null
                                                    : selectedMemberId,
                                                isExpanded: true,
                                                items: provider.members
                                                    .map((member) =>
                                                        DropdownMenuItem(
                                                          value: member.id,
                                                          child: Text(member.name),
                                                        ))
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
                                      );
                                    },
                                  ),
                                );

                                if (confirmed == true) {
                                  final selectedMember =
                                      resolveSelectedMember();
                                  final effectivePrice =
                                      resolveEffectivePrice(selectedMember);
                                  final guestTier =
                                      resolveGuestTier(selectedMember);
                                  await _buyPlanWithKora(
                                    context: context,
                                    provider: provider,
                                    businessProvider: businessProvider,
                                    selectedMemberId: selectedMemberId,
                                    selectedMember: selectedMember,
                                    plan: plan,
                                    effectivePrice: effectivePrice,
                                    guestTier: guestTier,
                                  );
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
