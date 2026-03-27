import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
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
  String _selectedBusinessClass = 'small';
  String _selectedBusinessTier = 'starter';
  bool _isLoading = false;

  final List<String> _businessTypes = const [
    'pharmacy',
    'retail',
    'agriculture',
    'auto_repair',
    'salon',
    'hotel',
    'restaurant',
    'bar',
    'real_estate',
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

  Future<void> _registerBusiness() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBusinessType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select business type')),
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
        'businessClass': _selectedBusinessClass,
        'businessTier': _selectedBusinessTier,
      },
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (!success) {
      final error = context.read<MarketerProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to register business')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Business registered successfully')),
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
                                      setState(() => _selectedBusinessClass = value);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedBusinessTier,
                                  decoration: const InputDecoration(
                                    labelText: 'Suggested tier',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'starter',
                                      child: Text('Starter'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'growth',
                                      child: Text('Growth'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'premium',
                                      child: Text('Premium'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedBusinessTier = value);
                                    }
                                  },
                                ),
                              ),
                            ],
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
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Registration summary',
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
                          label: 'Class',
                          value: _display(_selectedBusinessClass),
                        ),
                        _SummaryRow(
                          label: 'Tier',
                          value: _display(_selectedBusinessTier),
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
