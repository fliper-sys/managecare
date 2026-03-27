import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/datetime_utils.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/enhanced_subscription_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/loading_indicator.dart';

/// Notification logs screen showing recent WhatsApp & SMS sends
class NotificationLogsScreen extends StatefulWidget {
  const NotificationLogsScreen({super.key});

  @override
  State<NotificationLogsScreen> createState() => _NotificationLogsScreenState();
}

class _NotificationLogsScreenState extends State<NotificationLogsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filterType = 'all'; // all, order, payment, etc.
  String _filterChannel = 'whatsapp'; // whatsapp, sms, email, all

  @override
  Widget build(BuildContext context) {
    return Consumer2<BusinessProvider, EnhancedSubscriptionProvider>(
      builder: (context, businessProvider, subProvider, _) {
        final business = businessProvider.currentBusiness;
        if (business == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Notification Logs')),
            body: const Center(child: Text('No business selected')),
          );
        }

        final auth = Provider.of<AuthProvider>(context, listen: false);
        final userRole = auth.currentUser?.role;

        return FutureBuilder<bool>(
          future: subProvider.canAccessFeature(
            business: business,
            feature: 'api_access',
            context: 'notification_logs_screen',
            userRole: userRole,
          ),
          builder: (context, snapshot) {
            final allowed = snapshot.data ?? false;
            if (snapshot.connectionState != ConnectionState.done) {
              return Scaffold(
                appBar: AppBar(title: const Text('Notification Logs')),
                body: const Center(child: CustomLoadingIndicator()),
              );
            }

            if (!allowed) {
              return Scaffold(
                appBar: AppBar(title: const Text('Notification Logs')),
                body: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Upgrade Required',
                          style: AppTextStyles.heading4),
                      const SizedBox(height: 8),
                      const Text(
                          'Notification logs are available to Professional and Enterprise plans.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(
                            context, '/subscription-status'),
                        child: const Text('Manage Subscription'),
                      )
                    ],
                  ),
                ),
              );
            }

            // allowed
            return Scaffold(
              appBar: AppBar(
                title: const Text('Notification Logs'),
                elevation: 0,
                backgroundColor: Colors.transparent,
                iconTheme: IconThemeData(
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
              body: Column(
                children: [
                  // Filters
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            value: _filterType,
                            items: const [
                              DropdownMenuItem(
                                  value: 'all', child: Text('All Types')),
                              DropdownMenuItem(
                                  value: 'order', child: Text('Orders')),
                              DropdownMenuItem(
                                  value: 'payment', child: Text('Payments')),
                              DropdownMenuItem(
                                  value: 'receipt', child: Text('Receipts')),
                            ],
                            onChanged: (val) =>
                                setState(() => _filterType = val ?? 'all'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            value: _filterChannel,
                            items: const [
                              DropdownMenuItem(
                                  value: 'whatsapp', child: Text('WhatsApp')),
                              DropdownMenuItem(
                                  value: 'sms', child: Text('SMS')),
                              DropdownMenuItem(
                                  value: 'email', child: Text('Email')),
                              DropdownMenuItem(
                                  value: 'all', child: Text('All Channels')),
                            ],
                            onChanged: (val) => setState(
                                () => _filterChannel = val ?? 'whatsapp'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Logs list
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('businesses')
                          .doc(business.id)
                          .collection('notificationLogs')
                          .orderBy('timestamp', descending: true)
                          .limit(100)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: CustomLoadingIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('No notification logs yet'),
                          );
                        }

                        var logs = snapshot.data!.docs;

                        // Apply filters
                        if (_filterType != 'all') {
                          logs = logs
                              .where((doc) =>
                                  (doc['type'] as String?) == _filterType)
                              .toList();
                        }
                        if (_filterChannel != 'all') {
                          logs = logs
                              .where((doc) =>
                                  (doc['channel'] as String?) == _filterChannel)
                              .toList();
                        }

                        if (logs.isEmpty) {
                          return const Center(
                            child: Text('No logs match the selected filters'),
                          );
                        }

                        return ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final doc = logs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final timestamp =
                              parseTimestamp(data['timestamp']) ??
                                DateTime.now();
                            final type = data['type'] as String? ?? 'unknown';
                            final channel =
                                data['channel'] as String? ?? 'unknown';
                            final recipient =
                                data['recipient'] as String? ?? 'N/A';
                            final success = data['success'] as bool? ?? false;
                            final orderId = data['orderId'] as String?;
                            final error = data['error'] as String?;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: success ? Colors.green : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    success ? Icons.check : Icons.close,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    size: 16,
                                  ),
                                ),
                                title: Text(
                                  '${type.toUpperCase()} via $channel',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'To: $recipient',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    if (orderId != null)
                                      Text(
                                        'Order: $orderId',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    Text(
                                      DateFormat('MMM dd, hh:mm a')
                                          .format(timestamp),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withAlpha(0xAA)),
                                    ),
                                    if (error != null && !success)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'Error: $error',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  success ? 'Sent' : 'Failed',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: success
                                            ? AppColors.success
                                            : Theme.of(context)
                                                .colorScheme
                                                .error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                isThreeLine: error != null && !success,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

