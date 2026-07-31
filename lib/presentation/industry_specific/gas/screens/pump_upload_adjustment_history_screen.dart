import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/amount_formatter.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/managecare_api_client.dart';
import '../utils/pump_row_mapper.dart';

class PumpUploadAdjustmentHistoryScreen extends StatefulWidget {
  const PumpUploadAdjustmentHistoryScreen({super.key});

  @override
  State<PumpUploadAdjustmentHistoryScreen> createState() =>
      _PumpUploadAdjustmentHistoryScreenState();
}

class _PumpUploadAdjustmentHistoryScreenState
    extends State<PumpUploadAdjustmentHistoryScreen> {
  static const _pollInterval = Duration(seconds: 15);

  String _formatValue(dynamic value) {
    if (value is num) return formatAmount(value.toDouble(), decimalDigits: 2);
    return value?.toString() ?? '';
  }

  String _fieldLabel(String field) {
    const labels = {
      'shift_opening_cash': 'Shift opening cash',
      'shift_close_cash': 'Shift closing cash',
      'opening_volume': 'Opening volume (digital)',
      'closing_volume': 'Closing volume (digital)',
      'analog_opening_volume': 'Analog opening volume',
      'analog_closing_volume': 'Analog closing volume',
      'sold_volume': 'Calculated sales volume (L)',
      'cash_amount': 'Total cash amount',
      'pos_amount': 'Transfer / POS amount',
      // Legacy camelCase labels, kept for any older audit rows.
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

  DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Stream<List<Map<String, dynamic>>> _adjustmentsStream(String businessId) async* {
    while (true) {
      try {
        final response = await ManagecareApiClient.instance.get(
          '/api/pumps/$businessId/upload-adjustments',
          query: {'limit': '200'},
        );
        final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        yield rows.map(pumpUploadAdjustmentRowToJson).toList();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
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
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _adjustmentsStream(businessId),
              builder: (context, snapshot) {
                final rows = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    rows.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('No adjustments recorded yet'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = rows[index];
                    final adjustedAt = _readDate(data['adjustedAt']);
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
