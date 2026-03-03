List<Map<String, dynamic>> mergeInventoryMaps(
  List<Map<String, dynamic>> primary,
  List<Map<String, dynamic>> secondary,
) {
  final mergedMap = <String, Map<String, dynamic>>{};

  String keyFor(Map<String, dynamic> p) {
    final sku = (p['sku'] ?? '').toString().trim();
    return sku.isNotEmpty
        ? 'sku:$sku'
        : 'name:${(p['name'] ?? '').toString().toLowerCase()}';
  }

  for (final p in secondary) {
    mergedMap[keyFor(p)] = p;
  }
  for (final p in primary) {
    mergedMap[keyFor(p)] = p; // primary overrides
  }

  return mergedMap.values.toList();
}

/// Normalize a procurement quantity to the product's base inventory unit.
/// Currently supports converting 'ton' -> 'kg' when the base unit is 'kg'.
int normalizeProcurementQuantity(int quantity, String selectedUnit, String baseUnit) {
  if (selectedUnit == 'ton' && baseUnit == 'kg') {
    return quantity * 907;
  }
  // Add other conversions here as needed.
  return quantity;
}

