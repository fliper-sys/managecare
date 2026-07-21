import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/amount_formatter.dart';
import '../../../../providers/business_provider.dart';

class PumpUploadAdjustmentHistoryScreen extends StatelessWidget {
  const PumpUploadAdjustmentHistoryScreen({super.key});

  String _formatValue(dynamic value) {
    if (value is num) return formatAmount(value.toDouble(), decimalDigits: 2);
    return value?.toString() ?? '';
  }

  String _fieldLabel(String field) {
    const labels = {
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
    return labels[field] ?? field;
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'disputed':
        return 'Marked as disputed';
      case 'resolved':
        return 'Resolved';
      case 'adjusted':
        return 'Figures adjusted';
      default:
        return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = context.watch<BusinessProvider>().currentBusiness?.id;
    final dateFormat = DateFormat.yMd().add_jm();

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Adjustment History')),
      body: businessId == null || businessId.isEmpty
          ? const Center(child: Text('No business selected'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(businessId)
                  .collection('pump_upload_adjustments')
                  .orderBy('adjustedAt', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    docs.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No adjustments recorded yet'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final adjustedAt = data['adjustedAt'] is Timestamp
                        ? (data['adjustedAt'] as Timestamp).toDate()
                        : null;
                    final action = (data['action'] as String?) ?? '';
                    final changes = (data['changes'] as List?)
                            ?.whereType<Map<String, dynamic>>()
                            .toList() ??
                        const <Map<String, dynamic>>[];
                    final note = (data['note'] as String?) ?? '';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pump ${data['pumpNumber'] ?? ''} - ${data['productName'] ?? ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(_actionLabel(action)),
                            const SizedBox(height: 4),
                            if (adjustedAt != null)
                              Text(
                                'By ${data['adjustedByName'] ?? 'N/A'} on ${dateFormat.format(adjustedAt)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            if (changes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ...changes.map(
                                (change) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    '${_fieldLabel(change['field']?.toString() ?? '')}: '
                                    '${_formatValue(change['oldValue'])} → ${_formatValue(change['newValue'])}',
                                  ),
                                ),
                              ),
                            ],
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Note: $note',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
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
