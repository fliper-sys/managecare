import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/managecare_api_client.dart';
import '../utils/pump_row_mapper.dart';
import 'pump_upload_adjustment_history_screen.dart';

class DisputedPumpUploadsScreen extends StatefulWidget {
  const DisputedPumpUploadsScreen({super.key});

  @override
  State<DisputedPumpUploadsScreen> createState() =>
      _DisputedPumpUploadsScreenState();
}

class _DisputedPumpUploadsScreenState
    extends State<DisputedPumpUploadsScreen> {
  static const List<String> _editableFields = [
    'shiftOpeningCash',
    'shiftCloseCash',
    'openingVolume',
    'closingVolume',
    'analogOpeningVolume',
    'analogClosingVolume',
    'soldVolume',
    'cashAmount',
    'posAmount',
  ];

  static const Map<String, String> _fieldLabels = {
    'shiftOpeningCash': 'Shift opening cash',
    'shiftCloseCash': 'Shift closing cash',
    'openingVolume': 'Opening volume (digital)',
    'closingVolume': 'Closing volume (digital)',
    'analogOpeningVolume': 'Analog opening volume',
    'analogClosingVolume': 'Analog closing volume',
    'soldVolume': 'Calculated sales volume (L)',
    'cashAmount': 'Total cash amount',
    'posAmount': 'Transfer / POS amount',
  };

  // Maps the camelCase field names this screen edits to the snake_case
  // columns the /adjust endpoint accepts.
  static const Map<String, String> _fieldToColumn = {
    'shiftOpeningCash': 'shift_opening_cash',
    'shiftCloseCash': 'shift_close_cash',
    'openingVolume': 'opening_volume',
    'closingVolume': 'closing_volume',
    'analogOpeningVolume': 'analog_opening_volume',
    'analogClosingVolume': 'analog_closing_volume',
    'soldVolume': 'sold_volume',
    'cashAmount': 'cash_amount',
    'posAmount': 'pos_amount',
  };

  static const _pollInterval = Duration(seconds: 15);

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0.0;
    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0.0;
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Stream<List<Map<String, dynamic>>> _disputedUploadsStream(String businessId) async* {
    while (true) {
      try {
        final response = await ManagecareApiClient.instance.get(
          '/api/pumps/$businessId/uploads',
          query: {'isDisputed': 'true', 'limit': '200'},
        );
        final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        yield rows.map(pumpUploadRowToJson).toList();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
  }

  Future<void> _openReviewDialog(String businessId, Map<String, dynamic> data) async {
    final controllers = {
      for (final field in _editableFields)
        field: TextEditingController(
          text: _readDouble(data[field]).toString(),
        ),
    };
    final noteController = TextEditingController();

    try {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            'Pump ${data['pumpNumber'] ?? ''} - ${data['productName'] ?? ''}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final field in _editableFields) ...[
                  TextField(
                    controller: controllers[field],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: _fieldLabels[field]),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Resolution note (optional)',
                  ),
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
              onPressed: () => Navigator.of(dialogContext).pop('save'),
              child: const Text('Save Adjustment'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop('resolve'),
              child: const Text('Resolve & Return'),
            ),
          ],
        ),
      );

      if (action == null) return;
      await _applyReview(
        businessId: businessId,
        data: data,
        controllers: controllers,
        note: noteController.text,
        resolve: action == 'resolve',
      );
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      noteController.dispose();
    }
  }

  Future<void> _applyReview({
    required String businessId,
    required Map<String, dynamic> data,
    required Map<String, TextEditingController> controllers,
    required String note,
    required bool resolve,
  }) async {
    final auth = context.read<AuthProvider>().currentUser;
    final id = data['id']?.toString();
    if (id == null || id.isEmpty) return;

    final updates = <String, dynamic>{};
    for (final field in _editableFields) {
      final oldValue = _readDouble(data[field]);
      final newValue =
          double.tryParse(controllers[field]!.text.trim()) ?? oldValue;
      if (newValue != oldValue) {
        updates[_fieldToColumn[field]!] = newValue;
      }
    }

    try {
      if (updates.isNotEmpty) {
        await ManagecareApiClient.instance.patch(
          '/api/pumps/$businessId/uploads/$id/adjust',
          body: {
            'updates': updates,
            'note': note,
            'adjusted_by': auth?.id,
            'adjusted_by_name': auth?.fullName ?? auth?.email,
          },
        );
      }

      if (resolve) {
        await ManagecareApiClient.instance.patch(
          '/api/pumps/$businessId/uploads/$id/resolve',
          body: {
            'note': note,
            'resolved_by': auth?.id,
            'resolved_by_name': auth?.fullName ?? auth?.email,
          },
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resolve
                ? 'Dispute resolved — upload returned to history'
                : updates.isEmpty
                    ? 'No changes made'
                    : 'Adjustment saved',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save review: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    final role = WorkerPermissions.normalizeRole(
      context.watch<AuthProvider>().currentUser?.role ?? '',
    );
    final isOwner =
        context.watch<AuthProvider>().currentUser?.isOwner == true;
    final canManage = isOwner || WorkerPermissions.canManagePumpDisputes(role);
    final dateFormat = DateFormat.yMd().add_jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disputed Uploads'),
        actions: [
          IconButton(
            tooltip: 'Adjustment history',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PumpUploadAdjustmentHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: !canManage
          ? const Center(
              child: Text('You do not have access to this page'),
            )
          : businessId == null || businessId.isEmpty
              ? const Center(child: Text('No business selected'))
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _disputedUploadsStream(businessId),
                  builder: (context, snapshot) {
                    final rows = snapshot.data ?? [];
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        rows.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (rows.isEmpty) {
                      return const Center(
                        child: Text('No disputed uploads'),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final data = rows[index];
                        final uploadedAt = _readDate(data['uploadedAt']);
                        final disputedAt = _readDate(data['disputedAt']);
                        final reason =
                            (data['disputeReason'] as String?) ?? '';
                        final subtitleLines = <String>[
                          if (uploadedAt != null)
                            'Uploaded: ${dateFormat.format(uploadedAt)}',
                          'Operator: ${data['workerName'] ?? 'N/A'}',
                          if (disputedAt != null)
                            'Disputed: ${dateFormat.format(disputedAt)} by ${data['disputedByName'] ?? 'N/A'}',
                          if (reason.isNotEmpty) 'Reason: $reason',
                        ];
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.flag,
                              color: Colors.red,
                            ),
                            title: Text(
                              'Pump ${data['pumpNumber'] ?? ''} - ${data['productName'] ?? ''}',
                            ),
                            subtitle: Text(subtitleLines.join('\n')),
                            isThreeLine: true,
                            trailing: ElevatedButton(
                              onPressed: () => _openReviewDialog(businessId, data),
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
