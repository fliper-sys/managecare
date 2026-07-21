import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../utils/pump_upload_dispute_utils.dart';
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

  CollectionReference<Map<String, dynamic>>? _collection(String name) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection(name);
  }

  Future<void> _openReviewDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final controllers = {
      for (final field in _editableFields)
        field: TextEditingController(
          text: readPumpUploadDouble(data[field]).toString(),
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
        doc: doc,
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
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Map<String, dynamic> data,
    required Map<String, TextEditingController> controllers,
    required String note,
    required bool resolve,
  }) async {
    final auth = context.read<AuthProvider>().currentUser;
    final adjustments = _collection('pump_upload_adjustments');

    final updates = <String, dynamic>{};
    final changes = <Map<String, dynamic>>[];
    for (final field in _editableFields) {
      final oldValue = readPumpUploadDouble(data[field]);
      final newValue =
          double.tryParse(controllers[field]!.text.trim()) ?? oldValue;
      if (newValue != oldValue) {
        updates[field] = newValue;
        changes.add({
          'field': field,
          'oldValue': oldValue,
          'newValue': newValue,
        });
      }
    }

    if (updates.isNotEmpty) {
      final openingVolume =
          (updates['openingVolume'] as double?) ?? readPumpUploadDouble(data['openingVolume']);
      final closingVolume =
          (updates['closingVolume'] as double?) ?? readPumpUploadDouble(data['closingVolume']);
      final shiftOpeningCash = (updates['shiftOpeningCash'] as double?) ??
          readPumpUploadDouble(data['shiftOpeningCash']);
      final shiftCloseCash = (updates['shiftCloseCash'] as double?) ??
          readPumpUploadDouble(data['shiftCloseCash']);
      final soldVolume =
          (updates['soldVolume'] as double?) ?? readPumpUploadDouble(data['soldVolume']);
      final cashAmount =
          (updates['cashAmount'] as double?) ?? readPumpUploadDouble(data['cashAmount']);
      final posAmount =
          (updates['posAmount'] as double?) ?? readPumpUploadDouble(data['posAmount']);
      final productPrice = readPumpUploadDouble(data['productPrice']);

      updates['digitalVolume'] = closingVolume - openingVolume;
      updates['volumeDifference'] = closingVolume - openingVolume;
      updates['shiftCashDifference'] = shiftCloseCash - shiftOpeningCash;
      updates['expectedAmount'] = soldVolume * productPrice;
      updates['cashDerivedVolume'] = soldVolume;
      updates['todayPumpCash'] = cashAmount;
      updates['totalPaid'] = cashAmount + posAmount;

      await doc.reference.update(updates);
      if (adjustments != null) {
        await logPumpUploadDisputeEvent(
          adjustments: adjustments,
          uploadId: doc.id,
          uploadData: data,
          action: 'adjusted',
          changes: changes,
          note: note,
          adjustedBy: auth?.id,
          adjustedByName: auth?.fullName ?? auth?.email,
        );
      }
    }

    if (resolve) {
      await doc.reference.update({
        'isDisputed': false,
        'disputeResolvedAt': FieldValue.serverTimestamp(),
        'disputeResolvedBy': auth?.id,
        'disputeResolvedByName': auth?.fullName ?? auth?.email,
      });
      if (adjustments != null) {
        await logPumpUploadDisputeEvent(
          adjustments: adjustments,
          uploadId: doc.id,
          uploadData: data,
          action: 'resolved',
          note: note,
          adjustedBy: auth?.id,
          adjustedByName: auth?.fullName ?? auth?.email,
        );
      }
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
  }

  @override
  Widget build(BuildContext context) {
    final uploads = _collection('pump_daily_uploads');
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
          : uploads == null
              ? const Center(child: Text('No business selected'))
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: uploads
                      .orderBy('uploadedAt', descending: true)
                      .limit(200)
                      .snapshots(includeMetadataChanges: true),
                  builder: (context, snapshot) {
                    final docs = (snapshot.data?.docs ?? [])
                        .where((doc) => doc.data()['isDisputed'] == true)
                        .toList();
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        docs.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No disputed uploads'),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final uploadedAt = data['uploadedAt'] is Timestamp
                            ? (data['uploadedAt'] as Timestamp).toDate()
                            : null;
                        final disputedAt = data['disputedAt'] is Timestamp
                            ? (data['disputedAt'] as Timestamp).toDate()
                            : null;
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
                              onPressed: () => _openReviewDialog(doc),
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
