import 'package:cloud_firestore/cloud_firestore.dart';

/// Parse a Firestore timestamp / DateTime / String / numeric value into DateTime.
/// Handles:
/// - null -> returns DateTime.now()
/// - DateTime -> returns unchanged
/// - Timestamp -> converts to DateTime
/// - int / num -> treated as milliseconds since epoch
/// - String -> attempts DateTime.parse, falls back to int parsing
DateTime parseTimestamp(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is String) {
    // Try ISO parse
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    // Try number-in-string
    final ms = int.tryParse(value);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    // Fallback
    return DateTime.now();
  }
  return DateTime.now();
}
