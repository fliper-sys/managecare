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
    // Try ISO parse. The backend (Postgres TIMESTAMPTZ) always returns
    // UTC-marked strings ("...Z" / "+00:00"), so DateTime.tryParse gives
    // back a UTC-flagged DateTime here - unlike the Firestore Timestamp
    // branch above, where .toDate() has always silently returned local
    // time. Every caller of this function historically got local time for
    // free from that Firestore behavior; without toLocal() here, every
    // Postgres-sourced timestamp displays in raw UTC instead of the
    // device's real timezone (e.g. sales made at 3:30pm WAT showing as
    // roughly 2:30pm) - a correctness regression from the backend
    // migration, not a display formatting choice.
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
    // Try number-in-string
    final ms = int.tryParse(value);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    // Fallback
    return DateTime.now();
  }
  return DateTime.now();
}
