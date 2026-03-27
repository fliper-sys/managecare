import 'package:flutter/material.dart';

import 'notification_preferences_screen.dart';

/// Backwards-compatible alias for older route references.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NotificationPreferencesScreen();
  }
}
