import 'package:flutter/material.dart';
import '../../../widgets/loading_indicator.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/business_provider.dart';
import '../../../services/notification_service.dart';
import '../../../providers/agri_provider.dart';

class NotificationAdminScreen extends StatefulWidget {
  const NotificationAdminScreen({super.key});

  @override
  State<NotificationAdminScreen> createState() =>
      _NotificationAdminScreenState();
}

class _NotificationAdminScreenState extends State<NotificationAdminScreen> {
  final _firstController = TextEditingController();
  final _secondController = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _scheduled = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final svc = NotificationService.instance;
    final thresholds = await svc.getDaysBeforeThresholds();
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    final scheduled =
        await svc.getScheduledAlertMetadata(businessId: businessId);
    setState(() {
      _firstController.text =
          thresholds.isNotEmpty ? thresholds[0].toString() : '7';
      _secondController.text =
          thresholds.length > 1 ? thresholds[1].toString() : '1';
      _scheduled = scheduled;
      _loading = false;
    });
  }

  Future<void> _saveThresholds() async {
    final a = int.tryParse(_firstController.text) ?? 7;
    final b = int.tryParse(_secondController.text) ?? 1;
    await NotificationService.instance.setDaysBeforeThresholds([a, b]);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification thresholds saved')));
    // After saving thresholds, reschedule Agri hints for current business (if Agri provider exists)
    try {
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;
      if (businessId != null) {
        try {
          final agri = context.read<AgriProvider>();
          await agri.rescheduleAllHints(businessId: businessId);
        } catch (_) {
          // AgriProvider not present — ignore
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshScheduled() async {
    setState(() => _loading = true);
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    final scheduled = await NotificationService.instance
        .getScheduledAlertMetadata(businessId: businessId);
    setState(() {
      _scheduled = scheduled;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Admin'),
      ),
      body: _loading
          ? const Center(child: CustomLoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Expiry Alert Thresholds',
                      style: AppTextStyles.subtitle2),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firstController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Primary days before (e.g. 7)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _secondController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Secondary days before (e.g. 1)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveThresholds,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await NotificationService.instance
                              .requestPermissions();
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Permission requested')));
                        },
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Request Permission'),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: _refreshScheduled,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Scheduled Alerts',
                      style: AppTextStyles.subtitle2),
                  const SizedBox(height: 8),
                  if (_scheduled.isEmpty) ...[
                    const Text('No scheduled alerts'),
                  ] else
                    ..._scheduled.map((s) {
                      final dt = s['notifyAt'] as DateTime?;
                      return Card(
                        child: ListTile(
                          title: Text(s['memberName'] ?? 'Member'),
                          subtitle: Text(dt != null
                              ? 'Notify at: ${dt.toLocal()}'
                              : 'Notify time unknown'),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () async {
                              final id = s['id'] as int;
                              await NotificationService.instance
                                  .cancelNotification(id);
                              await _refreshScheduled();
                            },
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

