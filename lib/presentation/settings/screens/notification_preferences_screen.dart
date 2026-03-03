import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/notification_provider.dart';
import 'manage_devices_screen.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/custom_app_bar.dart';

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Notification Preferences',
        showBackButton: true,
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, _) {
          if (!notificationProvider.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notification Channels
                _buildSection(
                  context,
                  title: 'Notification Channels',
                  children: [
                    _buildChannelToggle(
                      context,
                      'Push Notifications',
                      notificationProvider.isPushEnabled,
                      (enabled) =>
                          notificationProvider.setPushNotifications(enabled),
                    ),
                    _buildChannelToggle(
                      context,
                      'Email Notifications',
                      notificationProvider.isEmailEnabled,
                      (enabled) =>
                          notificationProvider.setEmailNotifications(enabled),
                    ),
                    _buildChannelToggle(
                      context,
                      'SMS Notifications',
                      notificationProvider.isSmsEnabled,
                      (enabled) =>
                          notificationProvider.setSmsNotifications(enabled),
                    ),
                    _buildChannelToggle(
                      context,
                      'In-App Notifications',
                      notificationProvider.isInAppEnabled,
                      (enabled) =>
                          notificationProvider.setInAppNotifications(enabled),
                    ),
                  ],
                ),

                // Notification Types
                _buildSection(
                  context,
                  title: 'Notification Types',
                  children: [
                    _buildAlertToggle(
                      context,
                      'Sales Alerts',
                      'Get notified for every sale',
                      notificationProvider.salesAlertsEnabled,
                      (enabled) => notificationProvider.setSalesAlerts(enabled),
                    ),
                    _buildAlertToggle(
                      context,
                      'Inventory Alerts',
                      'Low stock and inventory warnings',
                      notificationProvider.inventoryAlertsEnabled,
                      (enabled) =>
                          notificationProvider.setInventoryAlerts(enabled),
                    ),
                    _buildAlertToggle(
                      context,
                      'Payment Alerts',
                      'Payment and transaction notifications',
                      notificationProvider.paymentAlertsEnabled,
                      (enabled) =>
                          notificationProvider.setPaymentAlerts(enabled),
                    ),
                    _buildAlertToggle(
                      context,
                      'Customer Alerts',
                      'New bookings and customer requests',
                      notificationProvider.customerAlertsEnabled,
                      (enabled) =>
                          notificationProvider.setCustomerAlerts(enabled),
                    ),
                    _buildAlertToggle(
                      context,
                      'System Alerts',
                      'System updates and maintenance',
                      notificationProvider.systemAlertsEnabled,
                      (enabled) =>
                          notificationProvider.setSystemAlerts(enabled),
                    ),
                  ],
                ),

                // Quiet Hours
                _buildSection(
                  context,
                  title: 'Quiet Hours',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: const Text('Enable Quiet Hours'),
                            subtitle: const Text(
                                'No notifications during specified time'),
                            value: notificationProvider.isQuietHoursEnabled,
                            onChanged: (enabled) => notificationProvider
                                .setQuietHoursEnabled(enabled),
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (notificationProvider.isQuietHoursEnabled) ...[
                            const SizedBox(height: 16),
                            _buildTimeRow(
                              context,
                              'From',
                              notificationProvider.quietHoursStart,
                              (time) =>
                                  notificationProvider.setQuietHoursStart(time),
                            ),
                            const SizedBox(height: 12),
                            _buildTimeRow(
                              context,
                              'To',
                              notificationProvider.quietHoursEnd,
                              (time) =>
                                  notificationProvider.setQuietHoursEnd(time),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Notification Frequency
                _buildSection(
                  context,
                  title: 'Notification Frequency',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How often to send notifications',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          _buildFrequencyOption(
                            context,
                            'Real-time',
                            'Instant notifications',
                            notificationProvider.frequency ==
                                NotificationFrequency.realTime,
                            () => notificationProvider
                                .setFrequency(NotificationFrequency.realTime),
                          ),
                          _buildFrequencyOption(
                            context,
                            'Hourly Digest',
                            'Combined hourly summary',
                            notificationProvider.frequency ==
                                NotificationFrequency.hourly,
                            () => notificationProvider
                                .setFrequency(NotificationFrequency.hourly),
                          ),
                          _buildFrequencyOption(
                            context,
                            'Daily Digest',
                            'Combined daily summary',
                            notificationProvider.frequency ==
                                NotificationFrequency.daily,
                            () => notificationProvider
                                .setFrequency(NotificationFrequency.daily),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Manage devices
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageDevicesScreen()));
                      },
                      icon: const Icon(Icons.devices),
                      label: const Text('Manage Devices'),
                    ),
                  ),
                ),

                // Reset Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Reset Settings?'),
                            content: const Text(
                                'This will reset all notification preferences to defaults.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  notificationProvider.resetToDefaults();
                                  Navigator.pop(context);
                                },
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset to Defaults'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildChannelToggle(
    BuildContext context,
    String title,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertToggle(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.1),
          ),
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
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(
    BuildContext context,
    String label,
    TimeOfDay time,
    Function(TimeOfDay) onTimeChanged,
  ) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final selectedTime = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (selectedTime != null) {
                onTimeChanged(selectedTime);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencyOption(
    BuildContext context,
    String title,
    String subtitle,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? Colors.blue.withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: isSelected,
              onChanged: (_) => onTap(),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

