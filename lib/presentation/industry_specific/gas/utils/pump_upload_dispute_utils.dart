import 'package:cloud_firestore/cloud_firestore.dart';

double readPumpUploadDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? 0.0;
  }
  return 0.0;
}

/// Appends one event to `businesses/{id}/pump_upload_adjustments`, the audit
/// trail behind the Disputed Uploads "History" screen — tracks a pump
/// upload being disputed, having its figures adjusted, or being resolved.
Future<void> logPumpUploadDisputeEvent({
  required CollectionReference<Map<String, dynamic>> adjustments,
  required String uploadId,
  required Map<String, dynamic> uploadData,
  required String action, // 'disputed' | 'adjusted' | 'resolved'
  List<Map<String, dynamic>> changes = const [],
  String? note,
  required String? adjustedBy,
  required String? adjustedByName,
}) async {
  await adjustments.add({
    'uploadId': uploadId,
    'pumpId': uploadData['pumpId'],
    'pumpNumber': uploadData['pumpNumber'],
    'productName': uploadData['productName'],
    'uploadedAt': uploadData['uploadedAt'],
    'action': action,
    'changes': changes,
    if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    'adjustedBy': adjustedBy,
    'adjustedByName': adjustedByName,
    'adjustedAt': FieldValue.serverTimestamp(),
  });
}
