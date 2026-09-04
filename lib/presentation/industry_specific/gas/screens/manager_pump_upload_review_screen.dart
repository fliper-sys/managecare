import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/managecare_api_client.dart';
import '../utils/pump_row_mapper.dart';

class ManagerPumpUploadReviewScreen extends StatefulWidget {
  const ManagerPumpUploadReviewScreen({super.key});

  @override
  State<ManagerPumpUploadReviewScreen> createState() =>
      _ManagerPumpUploadReviewScreenState();
}

class _ManagerPumpUploadReviewScreenState
    extends State<ManagerPumpUploadReviewScreen> {
  static const _pollInterval = Duration(seconds: 15);

  Stream<List<Map<String, dynamic>>> _pendingUploads(String businessId) async* {
    while (true) {
      try {
        final response = await ManagecareApiClient.instance.get(
          '/api/pumps/$businessId/uploads',
          query: {'status': 'pending_review', 'limit': '200'},
        );
        final rows =
            ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        yield rows.map(pumpUploadRowToJson).toList();
      } catch (_) {}
      await Future.delayed(_pollInterval);
    }
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ??
        0.0;
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Future<void> _openReview(String businessId, Map<String, dynamic> upload) async {
    final fields = <String, String>{
      'opening_volume': 'Opening volume',
      'closing_volume': 'Closing volume',
      'analog_opening_volume': 'Analog opening volume',
      'analog_closing_volume': 'Analog closing volume',
      'sold_volume': 'Sold volume',
      'shift_opening_cash': 'Shift opening cash',
      'shift_close_cash': 'Shift closing cash',
      'cash_amount': 'Cash amount',
      'pos_amount': 'POS/transfer amount',
    };
    final source = <String, dynamic>{
      'opening_volume': upload['openingVolume'],
      'closing_volume': upload['closingVolume'],
      'analog_opening_volume': upload['analogOpeningVolume'],
      'analog_closing_volume': upload['analogClosingVolume'],
      'sold_volume': upload['soldVolume'],
      'shift_opening_cash': upload['shiftOpeningCash'],
      'shift_close_cash': upload['shiftCloseCash'],
      'cash_amount': upload['cashAmount'],
      'pos_amount': upload['posAmount'],
    };
    final controllers = {
      for (final key in fields.keys)
        key: TextEditingController(text: _readDouble(source[key]).toString())
    };
    final noteController = TextEditingController();
    final reasonController = TextEditingController();

    try {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Pump ${upload['pumpNumber'] ?? ''} Review'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in fields.entries) ...[
                  TextField(
                    controller: controllers[entry.key],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: entry.value),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Manager note'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  decoration:
                      const InputDecoration(labelText: 'Decline/fault reason'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('faulty'),
              child: const Text('Faulty'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('declined'),
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop('approve'),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (action == null) return;

      final auth = context.read<AuthProvider>().currentUser;
      if (action == 'approve') {
        await ManagecareApiClient.instance.patch(
          '/api/pumps/$businessId/uploads/${upload['id']}/review',
          body: {
            'updates': {
              for (final entry in controllers.entries)
                entry.key: double.tryParse(entry.value.text.trim()) ?? 0,
              'cash_breakdown': upload['cashBreakdown'] ?? [],
            },
            'note': noteController.text.trim(),
            'reviewed_by': auth?.id,
            'reviewed_by_name': auth?.fullName ?? auth?.email,
          },
        );
      } else {
        await ManagecareApiClient.instance.patch(
          '/api/pumps/$businessId/uploads/${upload['id']}/decline',
          body: {
            'status': action,
            'reason': reasonController.text.trim(),
            'note': noteController.text.trim(),
            'reviewed_by': auth?.id,
            'reviewed_by_name': auth?.fullName ?? auth?.email,
          },
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approve'
                ? 'Pump upload approved'
                : 'Pump upload marked $action',
          ),
        ),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review failed: $error')),
      );
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      noteController.dispose();
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    final user = context.watch<AuthProvider>().currentUser;
    final role = WorkerPermissions.normalizeRole(user?.role ?? '');
    final canReview = user?.isOwner == true ||
        WorkerPermissions.canManagePumpDisputes(role);
    final dateFormat = DateFormat.yMMMd().add_jm();
    return Scaffold(
      appBar: AppBar(title: const Text('Pump Upload Review')),
      body: !canReview
          ? const Center(child: Text('Only managers can review pump uploads'))
          : businessId == null || businessId.isEmpty
          ? const Center(child: Text('No business selected'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _pendingUploads(businessId),
              builder: (context, snapshot) {
                final rows = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    rows.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (rows.isEmpty) {
                  return const Center(child: Text('No pending pump uploads'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final upload = rows[index];
                    final submitted = _readDate(
                      upload['submittedAt'] ?? upload['uploadedAt'],
                    );
                    final total = _readDouble(upload['totalPaid']);
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.pending_actions_outlined),
                        title: Text(
                          'Pump ${upload['pumpNumber'] ?? ''} - ${upload['productName'] ?? 'Fuel'}',
                        ),
                        subtitle: Text(
                          [
                            'Operator: ${upload['workerName'] ?? 'N/A'}',
                            'Sold: ${_readDouble(upload['soldVolume']).toStringAsFixed(3)} ${upload['productUnit'] ?? 'L'}',
                            'Total: ${total.toStringAsFixed(2)}',
                            if (submitted != null)
                              'Submitted: ${dateFormat.format(submitted)}',
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: ElevatedButton(
                          onPressed: () => _openReview(businessId, upload),
                          child: const Text('Review'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
