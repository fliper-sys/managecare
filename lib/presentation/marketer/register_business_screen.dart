import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/colors.dart';
import '../../providers/marketer_provider.dart';
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
  String _selectedBusinessClass = 'small'; // small, medium, enterprise
  String _selectedSubscriptionTier = 'basic'; // basic, pro
  String _selectedPlanDuration = '3m'; // 3m, 6m, 12m
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

  // Map business class to tier prefix for plan IDs
  final Map<String, String> _classToPlanPrefix = {
    'small': 't1',
    'medium': 't2',
    'enterprise': 't3',
  };

  // Helper to get available tiers based on business class
  List<String> _getAvailableTiers(String businessClass) {
    if (businessClass == 'small') {
      return ['basic']; // Tier 1 only has basic
    }
    return ['basic', 'pro']; // Tier 2 and 3 have both
  }

  // Helper to get subscription plan options
  Map<String, Map<String, String>> _getSubscriptionPlans() {
    return {
      'small': {
        'basic_3m': 'Basic - 3 Months (₦23,750)',
        'basic_6m': 'Basic - 6 Months (₦42,250)',
        'basic_12m': 'Basic - 12 Months (₦77,850)',
      },
      'medium': {
        'basic_3m': 'Basic - 3 Months (₦28,980)',
        'basic_6m': 'Basic - 6 Months (₦48,480)',
        'basic_12m': 'Basic - 12 Months (₦88,180)',
        'pro_3m': 'Pro - 3 Months (₦32,780)',
        'pro_6m': 'Pro - 6 Months (₦81,880)',
        'pro_12m': 'Pro - 12 Months (₦91,900)',
      },
      'enterprise': {
        'basic_3m': 'Basic - 3 Months (₦36,580)',
        'basic_6m': 'Basic - 6 Months (₦53,980)',
        'basic_12m': 'Basic - 12 Months (₦93,780)',
        'pro_3m': 'Pro - 3 Months (₦37,900)',
        'pro_6m': 'Pro - 6 Months (₦56,100)',
        'pro_12m': 'Pro - 12 Months (₦97,780)',
      },
    };
  }

  String _getSelectedPlanKey() {
    return '${_selectedSubscriptionTier}_${_selectedPlanDuration}';
  }

  String _getPlanIdFromSelection() {
    final prefix = _classToPlanPrefix[_selectedBusinessClass] ?? 't1';
    return '${prefix}_${_selectedSubscriptionTier}_${_selectedPlanDuration}';
  }

  @override
  void initState() {
    super.initState();
    context.read<MarketerProvider>().clearError();
    // Set default tier based on business class
    _selectedSubscriptionTier = _getAvailableTiers(_selectedBusinessClass).first;
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _addressController.dispose();
    _contactPhoneController.dispose();
    _landmarkController.dispose();
    super.dispose();
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

    setState(() => _isLoading = true);

    // Extract subscription tier from selection
    final subscriptionTier = _selectedSubscriptionTier;

    final success =
        await context.read<MarketerProvider>().registerBusinessForUser(
      userId: widget.userId,
      businessData: {
        'businessName': _businessNameController.text.trim(),
        'businessType': _selectedBusinessType!,
        'address': _addressController.text.trim(),
        'phone': _contactPhoneController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'businessClass': _selectedBusinessClass,
        'businessTier': subscriptionTier,
        'subscriptionPlan': _getPlanIdFromSelection(),
        'subscriptionTier': subscriptionTier,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Business'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0F766E),
                          Color(0xFF1D4ED8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Step 2 of 2',
                          style: TextStyle(
                            color: Color(0xFFE6FFFB),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Complete business onboarding',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.userEmail?.isNotEmpty == true
                              ? 'You are creating the business profile for ${widget.userEmail}.'
                              : 'Attach a business profile so this lead can move into the approval flow.',
                          style: const TextStyle(
                            color: Color(0xFFD6EEFF),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _businessNameController,
                            label: 'Business name',
                            hint: 'Enter business name',
                            prefixIcon: Icons.storefront_outlined,
                            textCapitalization: TextCapitalization.words,
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
                            items: _businessTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(_display(type)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedBusinessType = value);
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select business type';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedBusinessClass,
                                  decoration: const InputDecoration(
                                    labelText: 'Business class',
                                    border: OutlineInputBorder(),
                                    helperText: 'Small, Medium, or Enterprise',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'small',
                                      child: Text('Small'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'medium',
                                      child: Text('Medium'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'enterprise',
                                      child: Text('Enterprise'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedBusinessClass = value;
                                        // Reset tier to first available for this class
                                        _selectedSubscriptionTier =
                                            _getAvailableTiers(value).first;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedSubscriptionTier,
                                  decoration: const InputDecoration(
                                    labelText: 'Subscription tier',
                                    border: OutlineInputBorder(),
                                    helperText: 'Basic or Pro',
                                  ),
                                  items: _getAvailableTiers(_selectedBusinessClass)
                                      .map((tier) {
                                    return DropdownMenuItem(
                                      value: tier,
                                      child: Text(_display(tier)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedSubscriptionTier = value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedPlanDuration,
                            decoration: const InputDecoration(
                              labelText: 'Plan duration',
                              border: OutlineInputBorder(),
                              helperText: '3, 6, or 12 months',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: '3m',
                                child: Text('3 Months'),
                              ),
                              DropdownMenuItem(
                                value: '6m',
                                child: Text('6 Months'),
                              ),
                              DropdownMenuItem(
                                value: '12m',
                                child: Text('12 Months'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedPlanDuration = value);
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
                            textCapitalization: TextCapitalization.sentences,
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
                            hint: 'Optional location note',
                            prefixIcon: Icons.pin_drop_outlined,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 24),
                          CustomButton(
                            text: 'Finish Business Registration',
                            icon: Icons.check_circle_outline_rounded,
                            isLoading: _isLoading,
                            onPressed: _isLoading ? null : _registerBusiness,
                            backgroundColor: const Color(0xFF0F766E),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Registration Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label: 'Owner',
                          value: widget.ownerName?.isNotEmpty == true
                              ? widget.ownerName!
                              : 'Assigned from lead account',
                        ),
                        _SummaryRow(
                          label: 'Email',
                          value: widget.userEmail?.isNotEmpty == true
                              ? widget.userEmail!
                              : 'Saved on owner profile',
                        ),
                        _SummaryRow(
                          label: 'Business Type',
                          value: _selectedBusinessType != null
                              ? _display(_selectedBusinessType!)
                              : 'Not selected',
                        ),
                        _SummaryRow(
                          label: 'Business Class',
                          value: _display(_selectedBusinessClass),
                        ),
                        _SummaryRow(
                          label: 'Subscription Tier',
                          value: _display(_selectedSubscriptionTier),
                        ),
                        _SummaryRow(
                          label: 'Plan Duration',
                          value: _selectedPlanDuration == '3m'
                              ? '3 Months'
                              : _selectedPlanDuration == '6m'
                                  ? '6 Months'
                                  : '12 Months',
                        ),
                        _SummaryRow(
                          label: 'Plan ID',
                          value: _getPlanIdFromSelection(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
