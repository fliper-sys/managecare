import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/managecare_api_client.dart';
import '../utils/pump_row_mapper.dart';

class ManagerPumpUploadReviewScreen extends StatefulWidget {
  const ManagerPumpUploadReviewScreen({super.key, this.initialUploadId});

  final String? initialUploadId;

  @override
  State<ManagerPumpUploadReviewScreen> createState() =>
      _ManagerPumpUploadReviewScreenState();
}

class _ManagerPumpUploadReviewScreenState
    extends State<ManagerPumpUploadReviewScreen> {
  static const _pollInterval = Duration(seconds: 15);
  String? _openedUploadId;

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

  Widget _cashBreakdownEditor(
    dynamic raw,
    Map<int, Map<String, TextEditingController>> controllers,
  ) {
    final entries = (raw as List?)
            ?.whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .where((entry) => _readDouble(entry['denomination']) > 0)
            .toList() ??
        <Map<String, dynamic>>[];
    if (entries.isEmpty) {
      return const Text('No cash denomination breakdown recorded.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Editable cash denomination breakdown',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...entries.asMap().entries.map((indexed) {
          final index = indexed.key;
          final entry = indexed.value;
          final entryControllers = {
            'denomination': TextEditingController(
              text: _readDouble(entry['denomination']).toStringAsFixed(0),
            ),
            'pieces': TextEditingController(
              text: (entry['pieces'] ?? 0).toString(),
            ),
            'amount': TextEditingController(
              text: _readDouble(entry['amount']).toStringAsFixed(2),
            ),
          };
          controllers[index] = entryControllers;
          return Row(
            children: [
              Expanded(
                child: TextField(
                  controller: entryControllers['denomination'],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Denomination'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: entryControllers['pieces'],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pieces'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: entryControllers['amount'],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Future<void> _openReview(String businessId, Map<String, dynamic> upload) async {
    final fields = <String, String>{
      'pump_number': 'Pump number',
      'product_name': 'Product name',
      'product_unit': 'Product unit',
      'product_price': 'Product price',
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
      'pump_number': upload['pumpNumber'],
      'product_name': upload['productName'],
      'product_unit': upload['productUnit'],
      'product_price': upload['productPrice'],
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
        key: TextEditingController(
          text: key == 'pump_number' ||
                  key == 'product_name' ||
                  key == 'product_unit'
              ? source[key]?.toString() ?? ''
              : _readDouble(source[key]).toString(),
        )
    };
    final breakdownControllers = <int, Map<String, TextEditingController>>{};
    List<Map<String, dynamic>> adjustments = [];
    try {
      final response = await ManagecareApiClient.instance.get(
        '/api/pumps/$businessId/upload-adjustments',
        query: {'uploadId': upload['id'], 'limit': '50'},
      );
      adjustments = ((response['data'] as List?) ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (_) {
      // The review remains usable if the audit endpoint is temporarily unavailable.
    }
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
                _reviewImage(upload['shiftOpeningCashPhotoUrl'], 'Shift opening cash image'),
                _reviewImage(upload['shiftCloseCashPhotoUrl'], 'Shift close cash image'),
                _reviewImage(upload['openingPhotoUrl'], 'Opening pump volume image'),
                _reviewImage(upload['closingPhotoUrl'], 'Closing pump volume image'),
                _cashBreakdownEditor(
                  upload['cashBreakdown'],
                  breakdownControllers,
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  initiallyExpanded: adjustments.isNotEmpty,
                  title: const Text('Marked review log'),
                  children: adjustments.isEmpty
                      ? [
                          const ListTile(
                            title: Text('No previous review changes recorded'),
                          ),
                        ]
                      : adjustments.map((adjustment) {
                          final changes = (adjustment['changes'] as List?)
                                  ?.whereType<Map>()
                                  .toList() ??
                              const <Map>[];
                          return ListTile(
                            title: Text(
                              '${adjustment['action'] ?? 'change'} by ${adjustment['adjusted_by_name'] ?? 'N/A'}',
                            ),
                            subtitle: Text(
                              changes.isEmpty
                                  ? (adjustment['note']?.toString() ?? '')
                                  : changes
                                      .map((change) =>
                                          '${change['field']}: ${change['oldValue']} -> ${change['newValue']}')
                                      .join('\n'),
                            ),
                          );
                        }).toList(),
                ),
                for (final entry in fields.entries) ...[
                  TextField(
                    controller: controllers[entry.key],
                    keyboardType: entry.key == 'pump_number' ||
                        entry.key == 'product_name' ||
                        entry.key == 'product_unit'
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),
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
                entry.key: entry.key == 'pump_number' ||
                        entry.key == 'product_name' ||
                        entry.key == 'product_unit'
                    ? entry.value.text.trim()
                    : double.tryParse(entry.value.text.trim()) ?? 0,
              'cash_breakdown': [
                for (final entry in breakdownControllers.entries)
                  {
                    'denomination':
                        double.tryParse(entry.value['denomination']!.text) ?? 0,
                    'pieces': int.tryParse(entry.value['pieces']!.text) ?? 0,
                    'amount': double.tryParse(entry.value['amount']!.text) ?? 0,
                  },
              ],
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review failed: $error')),
      );
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      for (final entry in breakdownControllers.values) {
        for (final controller in entry.values) {
          controller.dispose();
        }
      }
      noteController.dispose();
      reasonController.dispose();
    }
  }

  Widget _reviewImage(dynamic value, String label) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SizedBox(
            width: 320,
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: double.infinity,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 60,
                  child: Center(child: Text('Image unavailable')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
                final targetId = widget.initialUploadId;
                if (targetId != null &&
                    targetId.isNotEmpty &&
                    _openedUploadId != targetId) {
                  final target = rows.cast<Map<String, dynamic>?>().firstWhere(
                        (row) => row?['id']?.toString() == targetId,
                        orElse: () => null,
                      );
                  if (target != null) {
                    _openedUploadId = targetId;
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _openReview(businessId, target),
                    );
                  }
                }
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
