/// Utility functions for advanced search with fuzzy matching and barcode support
class SearchUtils {
  /// Calculate the Levenshtein distance between two strings (for fuzzy matching)
  /// Lower distance = more similar
  static int levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    if (len1 == 0) return len2;
    if (len2 == 0) return len1;

    final d = List<List<int>>.generate(
      len1 + 1,
      (i) => List<int>.generate(len2 + 1, (j) => 0),
    );

    for (int i = 0; i <= len1; i++) d[i][0] = i;
    for (int j = 0; j <= len2; j++) d[0][j] = j;

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1, // deletion
          d[i][j - 1] + 1, // insertion
          d[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return d[len1][len2];
  }

  /// Check if two strings are similar (fuzzy match)
  /// Returns true if distance is below threshold (typically 2-3 for 80%+ similarity)
  static bool areSimilar(String s1, String s2, {int threshold = 2}) {
    return levenshteinDistance(s1.toLowerCase(), s2.toLowerCase()) <= threshold;
  }

  /// Extract numeric characters from a barcode (for fuzzy barcode matching)
  static String extractNumeric(String barcode) {
    return barcode.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Check if barcodes are similar (ignoring formatting differences)
  /// This handles cases where barcodes might have dashes, spaces, etc.
  static bool areBarcodesSimilar(String barcode1, String barcode2,
      {int threshold = 1}) {
    final cleaned1 = extractNumeric(barcode1);
    final cleaned2 = extractNumeric(barcode2);

    // If numeric parts are identical, definitely a match
    if (cleaned1 == cleaned2) return true;

    // For same-length barcodes, use fuzzy matching
    if (cleaned1.length == cleaned2.length) {
      return areSimilar(cleaned1, cleaned2, threshold: threshold);
    }

    // For different lengths, check if one contains the other
    if (cleaned1.isNotEmpty && cleaned2.isNotEmpty) {
      return cleaned1.contains(cleaned2) || cleaned2.contains(cleaned1);
    }

    return false;
  }

  /// Search products by name (case-insensitive with fuzzy matching)
  /// Returns true if the search query matches the product name
  static bool matchesProductName(String productName, String query) {
    final queryLower = query.toLowerCase();
    final nameLower = productName.toLowerCase();

    // Exact match (case-insensitive)
    if (nameLower.contains(queryLower)) return true;

    // Fuzzy match - check if similar enough
    // For product names, use a slightly higher threshold
    return areSimilar(nameLower, queryLower, threshold: 3);
  }

  /// Search products by barcode (handles formatting variations)
  /// Returns true if the barcode matches or is similar to the query
  static bool matchesBarcode(String? productBarcode, String query) {
    if (productBarcode == null || productBarcode.isEmpty) return false;

    final queryTrimmed = query.trim();
    if (queryTrimmed.isEmpty) return false;

    // Check if query looks like a barcode (mostly digits)
    final numericQuery = extractNumeric(queryTrimmed);
    if (numericQuery.isEmpty) return false; // Not a barcode format

    // Exact barcode match (after removing formatting)
    if (extractNumeric(productBarcode) == numericQuery) return true;

    // Fuzzy barcode match (handles scanning errors)
    return areBarcodesSimilar(productBarcode, queryTrimmed, threshold: 2);
  }

  /// Comprehensive search that matches either name or barcode
  /// Returns true if either the product name or barcode matches the query
  static bool matchesSearchQuery(
    String productName,
    String? productBarcode,
    String query,
  ) {
    if (query.isEmpty) return true;

    // First check exact/fuzzy name match
    if (matchesProductName(productName, query)) return true;

    // Then check barcode match
    if (matchesBarcode(productBarcode, query)) return true;

    return false;
  }

  /// Calculate relevance score for sorting search results
  /// Higher score = more relevant
  /// Returns score between 0.0 and 1.0
  static double calculateRelevanceScore(
    String productName,
    String? productBarcode,
    String query,
  ) {
    if (query.isEmpty) return 0.5;

    double score = 0.0;
    final queryLower = query.toLowerCase();
    final nameLower = productName.toLowerCase();

    // Name match scoring (higher weight)
    if (nameLower == queryLower) {
      score = 1.0; // Perfect match
    } else if (nameLower.startsWith(queryLower)) {
      score = 0.9; // Starts with query
    } else if (nameLower.contains(queryLower)) {
      score = 0.8; // Contains query
    } else if (areSimilar(nameLower, queryLower, threshold: 3)) {
      score = 0.6; // Fuzzy match
    }

    // Barcode match scoring (lower weight, but still important)
    if (productBarcode != null && productBarcode.isNotEmpty) {
      final numericQuery = extractNumeric(query);
      if (numericQuery.isNotEmpty) {
        if (extractNumeric(productBarcode) == numericQuery) {
          score = 0.95; // Exact barcode match
        } else if (areBarcodesSimilar(productBarcode, query, threshold: 2)) {
          score = 0.7; // Fuzzy barcode match
        }
      }
    }

    return score.clamp(0.0, 1.0);
  }
}
