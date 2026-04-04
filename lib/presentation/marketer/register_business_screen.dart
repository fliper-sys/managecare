import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/colors.dart';
import '../../providers/marketer_provider.dart';
import '../../services/subscription_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class RegisterBusinessScreen extends StatefulWidget {
  const RegisterBusinessScreen({
    super.key,
    required this.userId,
    this.userEmail,
    this.ownerName,
  });

  final String userId;
  final String? userEmail;
  final String? ownerName;

  @override
  State<RegisterBusinessScreen> createState() => _RegisterBusinessScreenState();
}

class _RegisterBusinessScreenState extends State<RegisterBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _landmarkController = TextEditingController();

  String? _selectedBusinessType;
  String _selectedTier = 'tier1';
  String _selectedPlanId = '';
  bool _isLoading = false;

  final List<String> _businessTypes = const [
    'pharmacy',
    'retail',
    'wholesale',
    'agriculture',
    'auto_repair',
    'salon',
    'barbershop',
    'hotel',
    'restaurant',
    'bar',
    'gas',
    'real_estate',
    'apartment',
    'gym',
  ];

  @override
  void initState() {
    super.initState();
    context.read<MarketerProvider>().clearError();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _addressController.dispose();
    _contactPhoneController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  List<String> _tierOptions() {
    return SubscriptionService.getTierOptionsForBusinessType(
      _selectedBusinessType,
    );
  }

  List<SubscriptionPlan> _planOptions() {
    return SubscriptionService.getPlansForBusinessType(
      _selectedBusinessType,
      tierId: _selectedTier,
    );
  }

  void _syncSelections() {
    final tiers = _tierOptions();
    if (tiers.isEmpty) {
      _selectedTier = 'tier1';
      _selectedPlanId = '';
      return;
    }

    if (!tiers.contains(_selectedTier)) {
      _selectedTier = tiers.first;
    }

    final plans = _planOptions();
    if (plans.isEmpty) {
      _selectedPlanId = '';
      return;
    }

    if (!plans.any((plan) => plan.id == _selectedPlanId)) {
      _selectedPlanId = plans.first.id;
    }
  }

  Future<void> _registerBusiness() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBusinessType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select business type'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    _syncSelections();
    if (_selectedPlanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a subscription plan'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success =
        await context.read<MarketerProvider>().registerBusinessForUser(
      userId: widget.userId,
      businessData: {
        'businessName': _businessNameController.text.trim(),
        'businessType': _selectedBusinessType!,
        'address': _addressController.text.trim(),
        'phone': _contactPhoneController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'businessClass': _selectedTier,
        'businessTier': _selectedTier,
        'subscriptionPlan': _selectedPlanId,
        'subscriptionTier': _selectedTier,
      },
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      final error = context.read<MarketerProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to register business'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Business registered successfully'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.marketerDashboard,
      (route) => false,
    );
  }

  String _display(String value) {
    return value.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    _syncSelections();
    final plans = _planOptions();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Register Business')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.24),
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    Text(
                      'Create a business with its own plan and limits',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Each business keeps its own subscription, so choose the business type, tier, and plan that match this specific account.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.72),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      controller: _businessNameController,
                      label: 'Business name',
                      hint: 'Enter business name',
                      prefixIcon: Icons.storefront_outlined,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter business name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedBusinessType,
                      decoration: const InputDecoration(
                        labelText: 'Business type',
                        border: OutlineInputBorder(),
                      ),
                      items: _businessTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(_display(type)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBusinessType = value;
                          _selectedTier = 'tier1';
                          _selectedPlanId = '';
                        });
                      },
                      validator: (value) {
                        if (value == null) return 'Please select business type';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedTier,
                      decoration: const InputDecoration(
                        labelText: 'Business tier',
                        border: OutlineInputBorder(),
                      ),
                      items: _tierOptions()
                          .map(
                            (tier) => DropdownMenuItem(
                              value: tier,
                              child: Text(tier.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedTier = value;
                          _selectedPlanId = '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedPlanId.isNotEmpty ? _selectedPlanId : null,
                      decoration: const InputDecoration(
                        labelText: 'Subscription plan',
                        border: OutlineInputBorder(),
                      ),
                      items: plans
                          .map(
                            (plan) => DropdownMenuItem(
                              value: plan.id,
                              child: Text(
                                '${plan.name} (N${plan.price.toStringAsFixed(0)})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedPlanId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _contactPhoneController,
                      label: 'Business contact phone',
                      hint: 'Optional if same as owner',
                      prefixIcon: Icons.phone_in_talk_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _addressController,
                      label: 'Business address',
                      hint: 'Enter business address',
                      prefixIcon: Icons.location_on_outlined,
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _landmarkController,
                      label: 'Landmark or note',
                      hint: 'Optional',
                      prefixIcon: Icons.place_outlined,
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : CustomButton(
                            text: 'Register Business',
                            onPressed: _registerBusiness,
                            backgroundColor: AppColors.primary,
                            icon: Icons.check_circle_outline,
                          ),
                  ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
