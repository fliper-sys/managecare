import '../../../core/utils/search_utils.dart';

/// Finds the product for a scanned code, with the same rules the old POS uses:
/// an exact numeric match wins at once; otherwise the best close match is used
/// (similar by up to two characters scores 0.9, a looser match 0.7).
/// Returns the item id, or null when nothing matches.
String? findIdForBarcode(String scanned, Iterable<({String id, String? barcode})> items) {
  final code = scanned.trim();
  if (code.isEmpty) return null;
  String? best;
  var bestScore = 0.0;
  for (final p in items) {
    final b = (p.barcode ?? '').trim();
    if (b.isEmpty) continue;
    if (!SearchUtils.matchesBarcode(b, code)) continue;
    if (SearchUtils.extractNumeric(b) == SearchUtils.extractNumeric(code)) return p.id;
    final score = SearchUtils.areBarcodesSimilar(b, code, threshold: 2) ? 0.9 : 0.7;
    if (score > bestScore) {
      bestScore = score;
      best = p.id;
    }
  }
  return bestScore >= 0.7 ? best : null;
}
