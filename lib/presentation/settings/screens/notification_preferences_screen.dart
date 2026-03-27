import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/routes.dart';
import '../../../providers/notification_provider.dart';
import 'manage_devices_screen.dart';
import '../../../widgets/custom_app_bar.dart';

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary,
                          Color.lerp(scheme.primary, scheme.secondary, 0.5)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stay in control',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose how alerts show up across your device, email, and in-app workspace.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

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

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width > 640
                            ? (MediaQuery.of(context).size.width - 56) / 2
                            : MediaQuery.of(context).size.width - 32,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, Routes.notifications);
                          },
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('Open Notification Center'),
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width > 640
                            ? (MediaQuery.of(context).size.width - 56) / 2
                            : MediaQuery.of(context).size.width - 32,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageDevicesScreen()));
                          },
                          icon: const Icon(Icons.devices),
                          label: const Text('Manage Devices'),
                        ),
                      ),
                    ],
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
                        backgroundColor: scheme.onSurface.withOpacity(0.68),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              scheme.primary.withOpacity(isDark ? 0.08 : 0.02),
              theme.cardColor,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outline.withOpacity(0.68),
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
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outline.withOpacity(0.45),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outline.withOpacity(0.45),
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
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.68),
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
    final scheme = Theme.of(context).colorScheme;

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
                border: Border.all(color: scheme.outline.withOpacity(0.55)),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outline.withOpacity(0.55),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? scheme.primary.withOpacity(0.08)
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
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.68),
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

