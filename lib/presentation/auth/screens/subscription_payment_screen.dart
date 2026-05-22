import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../services/kora_payment_service.dart';
import '../../../services/subscription_service.dart';
import '../../../widgets/loading_indicator.dart';
import 'kora_checkout_screen.dart';

class SubscriptionPaymentScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String userName;
  final String? businessId;
  final String? businessType;
  final String? businessTier;
  final String? businessClass;
  final String? initialPlanId;

  const SubscriptionPaymentScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.businessId,
    this.businessType,
    this.businessTier,
    this.businessClass,
    this.initialPlanId,
  });

  @override
  State<SubscriptionPaymentScreen> createState() =>
      _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState extends State<SubscriptionPaymentScreen> {
  final KoraPaymentService _koraPaymentService = KoraPaymentService();
  String _selectedPlanId = '';
  String _selectedPaymentMethod = 'card';
  bool _recurringEnabled = false;
  bool _isProcessing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureSelectedPlan(context.read<BusinessProvider>());
  }

  String _resolveBusinessType(BusinessProvider businessProvider) {
    final explicitBusinessType = widget.businessType?.trim() ?? '';
    if (explicitBusinessType.isNotEmpty) return explicitBusinessType;

    final currentBusinessType =
        businessProvider.currentBusiness?.businessType.trim() ?? '';
    if (currentBusinessType.isNotEmpty) return currentBusinessType;

    final userBusinessType =
        context.read<AuthProvider>().currentUser?.businessType?.trim() ?? '';
    if (userBusinessType.isNotEmpty) return userBusinessType;

    return 'retail';
  }

  String _resolveBusinessId(BusinessProvider businessProvider) {
    final explicitBusinessId = widget.businessId?.trim() ?? '';
    if (explicitBusinessId.isNotEmpty) return explicitBusinessId;

    final currentBusinessId = businessProvider.currentBusiness?.id.trim() ?? '';
    if (currentBusinessId.isNotEmpty) return currentBusinessId;

    final user = context.read<AuthProvider>().currentUser;
    final primaryBusinessId = user?.primaryBusinessId.trim() ?? '';
    if (primaryBusinessId.isNotEmpty) return primaryBusinessId;

    return user?.businessId.trim() ?? '';
  }

  List<SubscriptionPlan> _availablePlans(BusinessProvider businessProvider) {
    return SubscriptionService.getPlansForBusinessType(
      _resolveBusinessType(businessProvider),
      tierId: widget.businessTier ?? widget.businessClass,
    );
  }

  void _ensureSelectedPlan(BusinessProvider businessProvider) {
    final plans = _availablePlans(businessProvider);
    if (plans.isEmpty) return;
    if (plans.any((plan) => plan.id == _selectedPlanId)) return;

    final initialPlanId = widget.initialPlanId?.trim() ?? '';
    if (initialPlanId.isNotEmpty &&
        plans.any((plan) => plan.id == initialPlanId)) {
      _selectedPlanId = initialPlanId;
      return;
    }

    final preferredTier = SubscriptionService.normalizeStoredPlanLevel(
      subscriptionTier: widget.businessTier,
      businessClass: widget.businessClass,
    );
    final preferredPlan = plans.where((plan) => plan.tierId == preferredTier);
    _selectedPlanId =
        (preferredPlan.isNotEmpty ? preferredPlan.first : plans.first).id;
  }

  SubscriptionPlan? _selectedPlan(BusinessProvider businessProvider) {
    final plans = _availablePlans(businessProvider);
    if (plans.isEmpty) return null;
    return plans.firstWhere(
      (plan) => plan.id == _selectedPlanId,
      orElse: () => plans.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final role = auth.currentUser?.role.toLowerCase();
    if (role == 'worker') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Subscription'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Subscriptions are managed by business owners.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async => !_isProcessing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Choose Your Plan'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: _isProcessing
                  ? null
                  : () async {
                      await context.read<AuthProvider>().logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        Routes.login,
                        (_) => false,
                      );
                    },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: _isProcessing
            ? const Center(child: CustomLoadingIndicator())
            : Consumer<BusinessProvider>(
                builder: (context, businessProvider, _) {
                  _ensureSelectedPlan(businessProvider);
                  final selectedPlan = _selectedPlan(businessProvider);
                  final plans = _availablePlans(businessProvider);
                  final currency =
                      businessProvider.currentBusiness?.currency ?? 'NGN';
                  final currencySymbol = _getCurrencySymbol(currency);
                  final businessType = _resolveBusinessType(businessProvider);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Plans for ${businessType.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Kora checkout is now the default subscription payment route. Once payment is verified, this business is activated automatically.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (plans.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: const Text(
                              'No plans are configured for this business type yet.',
                            ),
                          )
                        else
                          ...plans.map(
                            (plan) => _buildPlanCard(
                              plan: plan,
                              isSelected: plan.id == _selectedPlanId,
                              currencySymbol: currencySymbol,
                              onTap: () => setState(() => _selectedPlanId = plan.id),
                            ),
                          ),
                        const SizedBox(height: 24),
                        if (selectedPlan != null)
                          _buildKoraSection(
                            currency: currency,
                            currencySymbol: currencySymbol,
                            selectedPlan: selectedPlan,
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionPlan plan,
    required bool isSelected,
    required String currencySymbol,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.tierId.toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$currencySymbol${plan.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${plan.durationInDays} days access',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...plan.features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '- $feature',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKoraSection({
    required String currency,
    required String currencySymbol,
    required SubscriptionPlan selectedPlan,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Recommended Payment Route',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Pay securely with Kora and your subscription will be approved automatically after successful verification.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          _buildPaymentMethodSelector(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Summary',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _summaryRow('Plan', selectedPlan.name),
                const SizedBox(height: 8),
                _summaryRow(
                  'Amount',
                  '$currencySymbol${selectedPlan.price.toStringAsFixed(0)}',
                ),
                const SizedBox(height: 8),
                _summaryRow('Currency', currency),
                const SizedBox(height: 8),
                _summaryRow('Payment method', _selectedPaymentMethodLabel),
                const SizedBox(height: 8),
                _summaryRow(
                  'Recurring',
                  _recurringEnabled
                      ? 'Enabled with card renewal reminders'
                      : 'Off',
                ),
                const SizedBox(height: 8),
                _summaryRow(
                  'Activation',
                  'Automatic after successful payment',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _payWithKora(currency),
            icon: const Icon(Icons.lock_outline),
            label: Text('Pay with $_selectedPaymentMethodLabel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    final methods = <_KoraPaymentMethodOption>[
      const _KoraPaymentMethodOption(
        id: 'card',
        label: 'Card',
        description: 'Best for recurring renewals and instant confirmation.',
        icon: Icons.credit_card_rounded,
      ),
      const _KoraPaymentMethodOption(
        id: 'bank_transfer',
        label: 'Bank Transfer / USSD',
        description: 'Use bank transfer or bank USSD options shown by Kora.',
        icon: Icons.account_balance_rounded,
      ),
      const _KoraPaymentMethodOption(
        id: 'pay_with_bank',
        label: 'Pay with Bank',
        description: 'Authorize payment directly from supported banks.',
        icon: Icons.account_balance_wallet_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose payment method',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...methods.map(
          (method) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: _selectedPaymentMethod == method.id
                  ? AppColors.primary.withOpacity(0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedPaymentMethod == method.id
                    ? AppColors.primary
                    : Colors.grey[300]!,
              ),
            ),
            child: RadioListTile<String>(
              value: method.id,
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedPaymentMethod = value;
                  if (value != 'card') {
                    _recurringEnabled = false;
                  }
                });
              },
              secondary: Icon(method.icon, color: AppColors.primary),
              title: Text(
                method.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(method.description),
            ),
          ),
        ),
        SwitchListTile.adaptive(
          value: _recurringEnabled,
          onChanged: _selectedPaymentMethod == 'card'
              ? (value) => setState(() => _recurringEnabled = value)
              : null,
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable recurring card renewals'),
          subtitle: Text(
            _selectedPaymentMethod == 'card'
                ? 'We will remember your preference and remind you before renewal. You confirm each renewal securely through Kora.'
                : 'Recurring renewals require card payment.',
          ),
        ),
      ],
    );
  }

  List<String> get _selectedKoraChannels {
    switch (_selectedPaymentMethod) {
      case 'bank_transfer':
        return const ['bank_transfer'];
      case 'pay_with_bank':
        return const ['pay_with_bank'];
      case 'card':
      default:
        return const ['card'];
    }
  }

  String get _selectedPaymentMethodLabel {
    switch (_selectedPaymentMethod) {
      case 'bank_transfer':
        return 'Bank Transfer / USSD';
      case 'pay_with_bank':
        return 'Pay with Bank';
      case 'card':
      default:
        return 'Card';
    }
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Future<void> _payWithKora(String currency) async {
    final businessProvider = context.read<BusinessProvider>();
    final selectedPlan = _selectedPlan(businessProvider);
    if (selectedPlan == null) {
      _showError('No subscription plan is selected.');
      return;
    }
    if (widget.userId.isEmpty) {
      _showError('User ID missing. Please log in again.');
      return;
    }

    final businessId = _resolveBusinessId(businessProvider);
    if (businessId.isEmpty) {
      _showError('No business is linked to this payment yet.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final businessType = _resolveBusinessType(businessProvider);
      final reference = KoraPaymentService.buildReference(
        prefix: 'ksub',
        userId: widget.userId,
      );
      final init = await _koraPaymentService.initializeSubscriptionPayment(
        reference: reference,
        amount: selectedPlan.price,
        currency: currency,
        email: widget.userEmail,
        fullName: widget.userName,
        planId: selectedPlan.id,
        businessId: businessId,
        userId: widget.userId,
        businessType: businessType,
        channels: _selectedKoraChannels,
        recurringEnabled: _recurringEnabled,
        recurrenceInterval: _recurringEnabled ? 'plan_duration' : null,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final checkoutResult =
          await Navigator.of(context).push<KoraCheckoutResult>(
        MaterialPageRoute(
          builder: (_) => KoraCheckoutScreen(
            checkoutUrl: init.checkoutUrl,
            redirectUrl: init.redirectUrl,
            reference: init.reference,
          ),
        ),
      );

      if (checkoutResult?.completed != true) {
        return;
      }

      if (!mounted) return;
      setState(() => _isProcessing = true);

      final verification = await _koraPaymentService.verifySubscriptionPayment(
        reference: checkoutResult?.reference ?? init.reference,
        planId: selectedPlan.id,
        userId: widget.userId,
        businessId: businessId,
      );

      if (!verification.success) {
        _showError(verification.message);
        return;
      }

      await _finalizeApprovedSubscription(
        selectedPlan: selectedPlan,
        businessId: businessId,
        businessType: businessType,
        currency: currency,
        reference: verification.reference,
        processorResponse: verification.raw,
        paymentMethod: verification.paymentMethod ?? 'kora',
        recurringEnabled: _recurringEnabled,
        selectedPaymentMethod: _selectedPaymentMethod,
      );
    } catch (e) {
      _showError('Payment error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _finalizeApprovedSubscription({
    required SubscriptionPlan selectedPlan,
    required String businessId,
    required String businessType,
    required String currency,
    required String reference,
    required Map<String, dynamic> processorResponse,
    required String paymentMethod,
    required bool recurringEnabled,
    required String selectedPaymentMethod,
  }) async {
    final now = DateTime.now();
    final receiptUrl = 'kora:$reference';

    await FirebaseFirestore.instance
        .collection('subscription_requests')
        .doc('KORA_${widget.userId}_${now.millisecondsSinceEpoch}')
        .set({
      'userId': widget.userId,
      'businessId': businessId,
      'businessType': businessType,
      'planId': selectedPlan.id,
      'planName': selectedPlan.name,
      'planTier': selectedPlan.tierId,
      'planFamily': selectedPlan.businessFamily,
      'amount': selectedPlan.price,
      'currency': currency,
      'userEmail': widget.userEmail,
      'userName': widget.userName,
      'receiptUrl': receiptUrl,
      'status': 'approved',
      'paymentMethod': paymentMethod,
      'paymentProcessor': 'kora',
      'selectedKoraPaymentMethod': selectedPaymentMethod,
      'recurringEnabled': recurringEnabled,
      'recurrenceInterval': recurringEnabled ? 'plan_duration' : null,
      'processorTransactionId': reference,
      'subscriptionStatus': 'approved',
      'createdAt': now.toIso8601String(),
      'approvedAt': now.toIso8601String(),
      'approvedBy': 'system',
      'updatedAt': now.toIso8601String(),
      'processorResponse': processorResponse,
    });

    await FirebaseFirestore.instance.collection('payment_transactions').add({
      'transactionId': reference,
      'businessId': businessId,
      'userId': widget.userId,
      'userEmail': widget.userEmail,
      'userName': widget.userName,
      'amount': selectedPlan.price,
      'currency': currency,
      'method': paymentMethod,
      'provider': 'kora',
      'selectedKoraPaymentMethod': selectedPaymentMethod,
      'recurringEnabled': recurringEnabled,
      'status': 'completed',
      'subscriptionPayment': true,
      'planId': selectedPlan.id,
      'processorResponse': processorResponse,
      'createdAt': now.toIso8601String(),
    });

    final activated = await SubscriptionService(
      firestore: FirebaseFirestore.instance,
    ).activateSubscriptionImmediately(
      userId: widget.userId,
      planId: selectedPlan.id,
      receiptUrl: receiptUrl,
      amount: selectedPlan.price,
      businessId: businessId,
    );

    if (!activated) {
      _showError(
        'Payment succeeded, but subscription activation did not complete. Please contact support.',
      );
      return;
    }

    if (recurringEnabled) {
      await _saveRecurringPreference(
        businessId: businessId,
        selectedPlan: selectedPlan,
        currency: currency,
        reference: reference,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment successful and subscription activated'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pushReplacementNamed(
      '/subscription-status',
      arguments: {
        'userId': widget.userId,
        'userEmail': widget.userEmail,
        'userName': widget.userName,
        'businessId': businessId,
        'businessType': businessType,
        'subscriptionPlan': selectedPlan.id,
        'subscriptionAmount': selectedPlan.price,
      },
    );
  }

  Future<void> _saveRecurringPreference({
    required String businessId,
    required SubscriptionPlan selectedPlan,
    required String currency,
    required String reference,
  }) async {
    final now = DateTime.now();
    final nextRenewal = now.add(Duration(days: selectedPlan.durationInDays));
    final recurringData = {
      'subscriptionRecurringEnabled': true,
      'subscriptionRecurringProvider': 'kora',
      'subscriptionRecurringMethod': 'card',
      'subscriptionRecurringStatus': 'active',
      'subscriptionRecurringInterval': 'plan_duration',
      'subscriptionRecurringPlanId': selectedPlan.id,
      'subscriptionRecurringAmount': selectedPlan.price,
      'subscriptionRecurringCurrency': currency,
      'subscriptionRecurringLastReference': reference,
      'subscriptionRecurringNextRenewalAt': Timestamp.fromDate(nextRenewal),
      'subscriptionRecurringUpdatedAt': Timestamp.fromDate(now),
      'subscriptionRecurringReminderSentFor': FieldValue.delete(),
    };

    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .set(recurringData, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .set(recurringData, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('admin_notifications').add({
      'type': 'subscription',
      'title': 'Recurring Renewal Enabled',
      'message':
          '${widget.userName} enabled recurring card renewal for ${selectedPlan.name}.',
      'data': {
        'userId': widget.userId,
        'businessId': businessId,
        'planId': selectedPlan.id,
        'amount': selectedPlan.price,
        'currency': currency,
        'nextRenewalAt': nextRenewal.toIso8601String(),
        'provider': 'kora',
      },
      'isRead': false,
      'createdAt': Timestamp.fromDate(now),
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('notifications')
        .add({
      'title': 'Recurring renewal enabled',
      'body':
          'Your card renewal preference is active. We will remind you before your next ${selectedPlan.name} renewal.',
      'type': 'subscription_recurring_enabled',
      'isRead': false,
      'createdAt': Timestamp.fromDate(now),
      'data': {
        'businessId': businessId,
        'planId': selectedPlan.id,
        'nextRenewalAt': nextRenewal.toIso8601String(),
      },
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getCurrencySymbol(String currency) {
    const symbols = {
      'NGN': 'N',
      'USD': '\$',
      'EUR': 'EUR',
      'GBP': 'GBP',
      'KES': 'Ksh',
      'ZAR': 'R',
    };
    return symbols[currency] ?? currency;
  }
}

class _KoraPaymentMethodOption {
  final String id;
  final String label;
  final String description;
  final IconData icon;

  const _KoraPaymentMethodOption({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });
}
