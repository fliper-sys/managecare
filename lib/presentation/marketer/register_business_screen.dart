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
  bool _isLoading = false;

  // Business metrics for automatic tier detection
  final _productCountController = TextEditingController(text: '0');
  final _staffCountController = TextEditingController(text: '0');
  final _monthlyRevenueController = TextEditingController(text: '0');
  String _detectedTier = 'tier1';

  final List<String> _businessTypes = const [
    'pharmacy',
    'retail',
    'bakery',
    'wholesale',
    'agriculture',
    'auto_repair',
    'salon',
    'barbershop',
    'hotel',
    'restaurant',
    'bar',
    'gas',
    'petroleum',
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
    _productCountController.dispose();
    _staffCountController.dispose();
    _monthlyRevenueController.dispose();
    super.dispose();
  }

  void _updateDetectedTier() {
    final products = int.tryParse(_productCountController.text) ?? 0;
    final staff = int.tryParse(_staffCountController.text) ?? 0;
    final revenue = double.tryParse(_monthlyRevenueController.text) ?? 0.0;

    _detectedTier = SubscriptionService.detectTier(
      products: products,
      staff: staff,
      monthlyIncome: revenue,
      businessType: _selectedBusinessType,
    );

    setState(() {});
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

    final success =
        await context.read<MarketerProvider>().registerBusinessForUser(
      userId: widget.userId,
      businessData: {
        'businessName': _businessNameController.text.trim(),
        'businessType': _selectedBusinessType!,
        'address': _addressController.text.trim(),
        'phone': _contactPhoneController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'businessClass': _detectedTier,
        'businessTier': _detectedTier,
        'subscriptionTier': _detectedTier,
        'productCount': int.tryParse(_productCountController.text) ?? 0,
        'staffCount': int.tryParse(_staffCountController.text) ?? 0,
        'monthlyRevenue': double.tryParse(_monthlyRevenueController.text) ?? 0.0,
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
                      'Register a new business with automatic tier detection',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter business details and metrics. The subscription tier will be automatically detected based on your business size and revenue.',
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
                        });
                        _updateDetectedTier();
                      },
                      validator: (value) {
                        if (value == null) return 'Please select business type';
                        return null;
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
                    Text(
                      'Business Metrics (for automatic tier detection)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _productCountController,
                            label: 'Number of products',
                            hint: '0',
                            prefixIcon: Icons.inventory_2_outlined,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _updateDetectedTier(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            controller: _staffCountController,
                            label: 'Number of staff',
                            hint: '0',
                            prefixIcon: Icons.people_outline,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _updateDetectedTier(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _monthlyRevenueController,
                      label: 'Monthly revenue (₦)',
                      hint: '0',
                      prefixIcon: Icons.attach_money_outlined,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updateDetectedTier(),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Detected Tier: ${_detectedTier.toUpperCase()}',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  'This tier will be automatically assigned based on your business metrics',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
