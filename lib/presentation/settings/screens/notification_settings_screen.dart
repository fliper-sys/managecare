import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../widgets/custom_button.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late bool _emailEnabled;
  late bool _smsEnabled;
  late bool _pushEnabled;
  late int _frequency;
  late List<String> _selectedTypes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _emailEnabled = settings.emailNotificationsEnabled;
    _smsEnabled = settings.smsNotificationsEnabled;
    _pushEnabled = settings.pushNotificationsEnabled;
    _frequency = settings.notificationFrequency;
    _selectedTypes = List.from(settings.notificationTypes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notification Channels
            _buildSectionHeader('Notification Channels'),
            const SizedBox(height: 12),
            _buildNotificationChannelCard(),
            const SizedBox(height: 24),

            // Notification Frequency
            _buildSectionHeader('Notification Frequency'),
            const SizedBox(height: 12),
            _buildFrequencySelector(),
            const SizedBox(height: 24),

            // Notification Types
            _buildSectionHeader('Notification Types'),
            const SizedBox(height: 12),
            _buildNotificationTypesCard(),
            const SizedBox(height: 32),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: _isSaving ? 'Saving...' : 'Save Preferences',
                onPressed: _isSaving ? null : _saveSettings,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resetToDefaults,
                child: const Text('Reset to Defaults'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.heading5.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildNotificationChannelCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildChannelOption(
            'Email Notifications',
            'Receive updates via email',
            _emailEnabled,
            (value) => setState(() => _emailEnabled = value),
            Icons.email_outlined,
          ),
          const Divider(height: 1),
          _buildChannelOption(
            'SMS Notifications',
            'Receive alerts via text message',
            _smsEnabled,
            (value) => setState(() => _smsEnabled = value),
            Icons.sms_outlined,
          ),
          const Divider(height: 1),
          _buildChannelOption(
            'Push Notifications',
            'In-app notifications and alerts',
            _pushEnabled,
            (value) => setState(() => _pushEnabled = value),
            Icons.notifications_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildChannelOption(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildFrequencyOption('Immediate', 1, 'Get notified right away'),
          const Divider(height: 1),
          _buildFrequencyOption('Hourly', 2, 'Batched hourly summary'),
          const Divider(height: 1),
          _buildFrequencyOption('Daily', 3, 'Once daily summary'),
        ],
      ),
    );
  }

  Widget _buildFrequencyOption(String label, int value, String description) {
    return GestureDetector(
      onTap: () => setState(() => _frequency = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: _frequency == value
            ? AppColors.primary.withOpacity(0.05)
            : Colors.transparent,
        child: Row(
          children: [
            Radio<int>(
              value: value,
              groupValue: _frequency,
              onChanged: (val) {
                if (val != null) setState(() => _frequency = val);
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypesCard() {
    final types = [
      {
        'id': 'sales',
        'label': 'Sales Alerts',
        'icon': Icons.shopping_cart_outlined
      },
      {
        'id': 'inventory',
        'label': 'Inventory Updates',
        'icon': Icons.inventory_outlined
      },
      {
        'id': 'payments',
        'label': 'Payment Updates',
        'icon': Icons.payment_outlined
      },
      {
        'id': 'orders',
        'label': 'Order Notifications',
        'icon': Icons.receipt_outlined
      },
      {
        'id': 'alerts',
        'label': 'System Alerts',
        'icon': Icons.warning_outlined
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (int i = 0; i < types.length; i++) ...[
            _buildTypeCheckbox(
              types[i]['label'] as String,
              types[i]['id'] as String,
              types[i]['icon'] as IconData,
            ),
            if (i < types.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeCheckbox(String label, String id, IconData icon) {
    final isSelected = _selectedTypes.contains(id);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTypes.remove(id);
          } else {
            _selectedTypes.add(id);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.05)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedTypes.add(id);
                  } else {
                    _selectedTypes.remove(id);
                  }
                });
              },
              activeColor: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final settingsProvider = context.read<SettingsProvider>();
      final businessProvider = context.read<BusinessProvider>();

      if (businessProvider.currentBusiness?.id != null) {
        final success = await settingsProvider.updateNotificationSettings(
          businessProvider.currentBusiness!.id,
          'current_user_id', // Replace with actual user ID
          emailEnabled: _emailEnabled,
          smsEnabled: _smsEnabled,
          pushEnabled: _pushEnabled,
          frequency: _frequency,
          types: _selectedTypes,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification settings saved successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _resetToDefaults() {
    setState(() {
      _emailEnabled = true;
      _smsEnabled = false;
      _pushEnabled = true;
      _frequency = 1;
      _selectedTypes = ['sales', 'inventory', 'payments', 'orders', 'alerts'];
    });
  }
}

