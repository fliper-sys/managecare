import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../settings/screens/manage_devices_screen.dart';
import '../../settings/screens/notification_admin_screen.dart';
import '../../settings/screens/notification_preferences_screen.dart';

enum _FeedFilter { all, unread, read }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  _FeedFilter _filter = _FeedFilter.all;
  bool _busy = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Query<Map<String, dynamic>> _query(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(100);

  bool _isRead(Map<String, dynamic> data) =>
      data['isRead'] == true || data['readAt'] != null;

  DateTime _createdAt(Map<String, dynamic> data) =>
      parseTimestamp(data['createdAt']) ?? DateTime.now();

  String _type(Map<String, dynamic> data) {
    final payload = data['data'];
    if (data['type'] != null) return data['type'].toString();
    if (payload is Map && payload['type'] != null) {
      return payload['type'].toString();
    }
    if (data['source'] != null) return data['source'].toString();
    return 'general';
  }

  String _frequencyLabel(NotificationFrequency frequency) {
    switch (frequency) {
      case NotificationFrequency.realTime:
        return 'Real-time';
      case NotificationFrequency.hourly:
        return 'Hourly';
      case NotificationFrequency.daily:
        return 'Daily';
    }
  }

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$mm/$dd/${dt.year}';
  }

  IconData _iconFor(String type) {
    final value = type.toLowerCase();
    if (value.contains('sale') || value.contains('order')) {
      return Icons.point_of_sale_rounded;
    }
    if (value.contains('inventory') || value.contains('stock')) {
      return Icons.inventory_2_rounded;
    }
    if (value.contains('payment') || value.contains('billing')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (value.contains('customer') || value.contains('booking')) {
      return Icons.people_alt_rounded;
    }
    if (value.contains('appointment')) {
      return Icons.event_available_rounded;
    }
    if (value.contains('checkout') || value.contains('arrival')) {
      return Icons.hotel_rounded;
    }
    if (value.contains('system') || value.contains('admin')) {
      return Icons.settings_suggest_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  Future<void> _setRead(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool read,
  ) async {
    await doc.reference.set({
      'isRead': read,
      'readAt': read ? FieldValue.serverTimestamp() : FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _markAll(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final unread = docs.where((doc) => !_isRead(doc.data())).toList();
    if (unread.isEmpty) {
      _snack('Everything is already marked as read.');
      return;
    }
    setState(() => _busy = true);
    try {
      final batch = _firestore.batch();
      for (final doc in unread) {
        batch.set(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      _snack('Marked ${unread.length} notification(s) as read.');
    } catch (e) {
      _snack('Failed to update notifications: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearRead(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final read = docs.where((doc) => _isRead(doc.data())).toList();
    if (read.isEmpty) {
      _snack('There are no read notifications to clear.');
      return;
    }
    setState(() => _busy = true);
    try {
      final batch = _firestore.batch();
      for (final doc in read) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      _snack('Cleared ${read.length} read notification(s).');
    } catch (e) {
      _snack('Failed to clear notifications: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendTest() async {
    final uid = _uid;
    if (uid == null) {
      _snack('Please sign in again to test notifications.', error: true);
      return;
    }
    try {
      final now = DateTime.now();
      await NotificationService.instance.sendNotification(
        'Test notification',
        'Your notifications are working on this device.',
        id: now.millisecondsSinceEpoch.remainder(100000),
      );
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': 'Test notification',
        'body': 'Your notifications are working on this device.',
        'type': 'system',
        'source': 'local_test',
        'channel': 'local',
        'delivered': true,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _snack('Test notification sent.');
    } catch (e) {
      _snack('Unable to send test notification: $e', error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? scheme.error : scheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final uid = _uid;
    final business = context.watch<BusinessProvider>().currentBusiness;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: uid == null
          ? const EmptyState(
              title: 'Sign in required',
              subtitle: 'Please sign in again to view your notifications.',
              icon: Icons.lock_outline_rounded,
            )
          : Consumer<NotificationProvider>(
              builder: (context, prefs, _) {
                if (!prefs.isInitialized) {
                  return const Center(child: CustomLoadingIndicator());
                }
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _query(uid).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CustomLoadingIndicator());
                    }

                    final docs =
                        snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final unread = docs.where((doc) => !_isRead(doc.data())).length;
                    final filtered = docs.where((doc) {
                      switch (_filter) {
                        case _FeedFilter.unread:
                          return !_isRead(doc.data());
                        case _FeedFilter.read:
                          return _isRead(doc.data());
                        case _FeedFilter.all:
                          return true;
                      }
                    }).toList();

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        Container(
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
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'A cleaner notification center',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Track unread alerts, test delivery, and jump straight into notification settings.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.92),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _HeroChip(label: 'Unread', value: '$unread'),
                                  _HeroChip(label: 'Total', value: '${docs.length}'),
                                  _HeroChip(
                                    label: 'Delivery',
                                    value: _frequencyLabel(prefs.frequency),
                                  ),
                                  _HeroChip(
                                    label: 'Quiet Hours',
                                    value: prefs.isQuietHoursEnabled ? 'On' : 'Off',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _ActionTile(
                              icon: Icons.tune_rounded,
                              label: 'Preferences',
                              subtitle: 'Channels and quiet hours',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const NotificationPreferencesScreen(),
                                ),
                              ),
                            ),
                            _ActionTile(
                              icon: Icons.devices_other_rounded,
                              label: 'Devices',
                              subtitle: 'Manage push-enabled devices',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ManageDevicesScreen(),
                                ),
                              ),
                            ),
                            _ActionTile(
                              icon: Icons.bolt_rounded,
                              label: 'Test Alert',
                              subtitle: 'Send a local test notification',
                              onTap: prefs.isPushEnabled || prefs.isInAppEnabled
                                  ? _sendTest
                                  : null,
                            ),
                            _ActionTile(
                              icon: Icons.receipt_long_rounded,
                              label: 'Logs',
                              subtitle: 'Delivery and message activity',
                              onTap: business == null
                                  ? null
                                  : () => Navigator.pushNamed(
                                        context,
                                        Routes.notificationLogs,
                                      ),
                            ),
                            _ActionTile(
                              icon: Icons.admin_panel_settings_outlined,
                              label: 'Admin',
                              subtitle: 'Thresholds and scheduled alerts',
                              onTap: business == null
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const NotificationAdminScreen(),
                                        ),
                                      ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              selected: _filter == _FeedFilter.all,
                              label: Text('All (${docs.length})'),
                              onSelected: (_) => setState(() => _filter = _FeedFilter.all),
                            ),
                            FilterChip(
                              selected: _filter == _FeedFilter.unread,
                              label: Text('Unread ($unread)'),
                              onSelected: (_) => setState(() => _filter = _FeedFilter.unread),
                            ),
                            FilterChip(
                              selected: _filter == _FeedFilter.read,
                              label: Text('Read (${docs.length - unread})'),
                              onSelected: (_) => setState(() => _filter = _FeedFilter.read),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: docs.isEmpty || _busy ? null : () => _markAll(docs),
                              icon: const Icon(Icons.done_all_rounded),
                              label: const Text('Mark all read'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: docs.isEmpty || _busy ? null : () => _clearRead(docs),
                              icon: const Icon(Icons.cleaning_services_outlined),
                              label: const Text('Clear read'),
                            ),
                            if (_busy) ...[
                              const Spacer(),
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (filtered.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: scheme.outline.withOpacity(0.45),
                              ),
                            ),
                            child: EmptyState(
                              title: docs.isEmpty ? 'No notifications yet' : 'Nothing here',
                              subtitle: docs.isEmpty
                                  ? 'Alerts will appear here once they are delivered to your account.'
                                  : 'Try another filter or send a test notification.',
                              icon: Icons.notifications_none_rounded,
                            ),
                          )
                        else
                          ...filtered.map((doc) {
                            final data = doc.data();
                            final read = _isRead(data);
                            final type = _type(data);
                            final accent = scheme.primary;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: () async {
                                    if (!read) {
                                      await _setRead(doc, true);
                                    }
                                  },
                                  child: Ink(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: read
                                          ? theme.cardColor
                                          : accent.withOpacity(
                                              theme.brightness == Brightness.dark
                                                  ? 0.16
                                                  : 0.08,
                                            ),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: read
                                            ? scheme.outline.withOpacity(0.45)
                                            : accent.withOpacity(0.28),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: accent.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Icon(_iconFor(type), color: accent),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      (data['title'] ?? 'Notification').toString(),
                                                      style: theme.textTheme.titleSmall?.copyWith(
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    _relative(_createdAt(data)),
                                                    style: theme.textTheme.labelSmall?.copyWith(
                                                      color: scheme.onSurface.withOpacity(0.55),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                (data['body'] ?? 'No details provided.').toString(),
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: scheme.onSurface.withOpacity(0.8),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _MetaChip(label: type.replaceAll('_', ' ')),
                                                  _MetaChip(
                                                    label: (data['source'] ?? 'app')
                                                        .toString()
                                                        .replaceAll('_', ' '),
                                                  ),
                                                  if (!read)
                                                    _MetaChip(label: 'new', highlighted: true),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (value) async {
                                            if (value == 'toggle') {
                                              await _setRead(doc, !read);
                                            }
                                            if (value == 'delete') {
                                              await doc.reference.delete();
                                              _snack('Notification removed.');
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'toggle',
                                              child: Text(read ? 'Mark unread' : 'Mark read'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final width =
        screenWidth > 640 ? (screenWidth - 56) / 2 : screenWidth - 32;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: scheme.outline.withOpacity(enabled ? 0.55 : 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(enabled ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: enabled
                        ? scheme.primary
                        : scheme.onSurface.withOpacity(0.35),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color =
        highlighted ? scheme.primary : scheme.onSurface.withOpacity(0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(highlighted ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
