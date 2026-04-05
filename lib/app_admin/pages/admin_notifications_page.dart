import 'package:flutter/material.dart';
import '../../../models/admin_notification_model.dart';
import '../../../services/admin_notification_service.dart';
import '../admin_theme.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final AdminNotificationService _notificationService =
      AdminNotificationService();
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.adminBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(
              _showUnreadOnly
                  ? Icons.mark_email_unread_rounded
                  : Icons.mail_outline_rounded,
            ),
            onPressed: () {
              setState(() => _showUnreadOnly = !_showUnreadOnly);
            },
            tooltip: _showUnreadOnly ? 'Show all' : 'Show unread only',
          ),
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () => _markAllAsRead(),
            tooltip: 'Mark all as read',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => _deleteReadNotifications(),
            tooltip: 'Delete read notifications',
          ),
        ],
      ),
      body: StreamBuilder<List<AdminNotification>>(
        stream: _showUnreadOnly
            ? _notificationService.getUnreadNotificationsStream()
            : _notificationService.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_rounded,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: context.adminTextSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(AdminNotification notification) {
    Color typeColor;
    IconData typeIcon;

    switch (notification.type) {
      case 'payment':
        typeColor = const Color(0xFF10B981);
        typeIcon = Icons.attach_money_rounded;
        break;
      case 'business':
        typeColor = const Color(0xFF3B82F6);
        typeIcon = Icons.business_rounded;
        break;
      case 'user':
        typeColor = const Color(0xFF8B5CF6);
        typeIcon = Icons.person_rounded;
        break;
      default:
        typeColor = const Color(0xFFF59E0B);
        typeIcon = Icons.info_rounded;
    }

    return Dismissible(
      key: Key(notification.id),
      onDismissed: (direction) {
        _notificationService.deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      },
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_rounded, color: Colors.red),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: context.adminCardDecoration(
          color: notification.isRead
              ? context.adminSurface
              : typeColor.withOpacity(context.isAdminDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            if (!notification.isRead) {
              _notificationService.markAsRead(notification.id);
            }
            _showNotificationDetails(notification);
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            typeIcon,
                            color: typeColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.adminTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notification.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.adminTextSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: typeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(notification.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.adminTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationDetails(AdminNotification notification) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          notification.title,
          style: TextStyle(color: context.adminTextPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.message,
                style: TextStyle(color: context.adminTextPrimary),
              ),
              const SizedBox(height: 16),
              if (notification.data.isNotEmpty) ...[
                Text(
                  'Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ...notification.data.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.adminTextSecondary,
                        ),
                      ),
                    )),
              ],
              const SizedBox(height: 12),
              Text(
                _formatDateTime(notification.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: context.adminTextTertiary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _markAllAsRead() {
    _notificationService.markAllAsRead();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  void _deleteReadNotifications() {
    _notificationService.deleteReadNotifications();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Read notifications deleted')),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

