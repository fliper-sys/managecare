import 'package:cloud_firestore/cloud_firestore.dart';

class TimestampUtils {
  /// Returns a Firestore-friendly timestamp value for writing.
  /// If [dt] is null, returns FieldValue.serverTimestamp() so Firestore sets the server time.
  static dynamic firestoreTimestamp([DateTime? dt]) {
    if (dt == null) return FieldValue.serverTimestamp();
    return Timestamp.fromDate(dt);
  }

  /// Parse a dynamic value (Timestamp, DateTime, String, int, double, or Firestore map)
  /// into a DateTime. Returns null on failure.
  static DateTime? parse(dynamic v) {
    try {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is Timestamp) return v.toDate();
      if (v is String) {
        final s = v.trim();
        if (s.isEmpty) return null;
        // Try ISO-8601 parse
        final dt = DateTime.tryParse(s);
        if (dt != null) return dt;
        // Try numeric parsing
        final n = int.tryParse(s);
        if (n != null) return DateTime.fromMillisecondsSinceEpoch(_normalizeMillis(n));
        return null;
      }
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(_normalizeMillis(v));
      if (v is double) return DateTime.fromMillisecondsSinceEpoch(_normalizeMillis(v.toInt()));
      if (v is Map) {
        // Firestore web serializes Timestamp as {_seconds: seconds, _nanoseconds: nanos}
        if (v.containsKey('_seconds') || v.containsKey('seconds')) {
          final seconds = (v['_seconds'] ?? v['seconds']) as int? ?? 0;
          final nanos = (v['_nanoseconds'] ?? v['nanoseconds'] ?? 0) as int? ?? 0;
          final millis = seconds * 1000 + (nanos ~/ 1000000);
          return DateTime.fromMillisecondsSinceEpoch(millis);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static int _normalizeMillis(int n) {
    // If number is in seconds, convert to milliseconds
    if (n < 1000000000000) return n * 1000; // < ~Sat Sep 09 2001
    return n;
  }
}
