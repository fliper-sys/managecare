import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class BusinessSetupWizard extends StatefulWidget {
  const BusinessSetupWizard({super.key});

  @override
  State<BusinessSetupWizard> createState() => _BusinessSetupWizardState();
}

class _BusinessSetupWizardState extends State<BusinessSetupWizard> {
  int _currentStep = 0;
  final List<String> steps = [
    'Business Info',
    'Contact Details',
    'Location',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Your Business'),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _currentStep < steps.length - 1
            ? () => setState(() => _currentStep++)
            : () => Navigator.pop(context),
        onStepCancel:
            _currentStep > 0 ? () => setState(() => _currentStep--) : null,
        steps: [
          Step(
            title: const Text('Business Information'),
            content: _buildBusinessInfoForm(),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text('Contact Details'),
            content: _buildContactForm(),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text('Location'),
            content: _buildLocationForm(),
            isActive: _currentStep >= 2,
          ),
          Step(
            title: const Text('Business Settings'),
            content: _buildSettingsForm(),
            isActive: _currentStep >= 3,
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessInfoForm() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: 'Business Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            labelText: 'Registration Number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactForm() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: 'Phone Number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationForm() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            labelText: 'City',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsForm() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Enable Notifications'),
          value: true,
          onChanged: (value) {},
        ),
        SwitchListTile(
          title: const Text('Enable Offline Mode'),
          value: true,
          onChanged: (value) {},
        ),
      ],
    );
  }
}

