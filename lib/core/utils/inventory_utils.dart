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

const List<String> kInventoryUnitOptions = [
  'pc',
  'pack',
  'carton',
  'box',
  'bottle',
  'bag',
  'sachet',
  'tray',
  'crate',
  'dozen',
  'set',
  'pair',
  'roll',
  'meter',
  'kg',
  'g',
  'ton',
  'L',
  'mL',
  'cylinder',
];

String canonicalizeInventoryUnit(String? unit) {
  final normalized = (unit ?? '').trim().toLowerCase();
  switch (normalized) {
    case '':
      return 'pc';
    case 'pcs':
    case 'piece':
    case 'pieces':
      return 'pc';
    case 'packs':
      return 'pack';
    case 'cartons':
      return 'carton';
    case 'boxes':
      return 'box';
    case 'bottles':
      return 'bottle';
    case 'bags':
      return 'bag';
    case 'sachets':
      return 'sachet';
    case 'trays':
      return 'tray';
    case 'crates':
      return 'crate';
    case 'litre':
    case 'litres':
    case 'liter':
    case 'liters':
    case 'l':
      return 'L';
    case 'millilitre':
    case 'millilitres':
    case 'milliliter':
    case 'milliliters':
    case 'ml':
      return 'mL';
    case 'kilogram':
    case 'kilograms':
      return 'kg';
    case 'gram':
    case 'grams':
      return 'g';
    case 'tons':
    case 'tonnes':
    case 'tonne':
      return 'ton';
    case 'cyl':
    case 'cylinders':
      return 'cylinder';
    default:
      return (unit ?? '').trim();
  }
}

String inventoryUnitLabel(String unit) {
  switch (canonicalizeInventoryUnit(unit)) {
    case 'pc':
      return 'Pieces (pc)';
    case 'pack':
      return 'Packs';
    case 'carton':
      return 'Cartons';
    case 'box':
      return 'Boxes';
    case 'bottle':
      return 'Bottles';
    case 'bag':
      return 'Bags';
    case 'sachet':
      return 'Sachets';
    case 'tray':
      return 'Trays';
    case 'crate':
      return 'Crates';
    case 'dozen':
      return 'Dozens';
    case 'set':
      return 'Sets';
    case 'pair':
      return 'Pairs';
    case 'roll':
      return 'Rolls';
    case 'meter':
      return 'Meters';
    case 'kg':
      return 'Kilograms (kg)';
    case 'g':
      return 'Grams (g)';
    case 'ton':
      return 'Tons';
    case 'L':
      return 'Litres (L)';
    case 'mL':
      return 'Millilitres (mL)';
    case 'cylinder':
      return 'Cylinders';
    default:
      return unit.trim().isEmpty ? 'Pieces (pc)' : unit;
  }
}

List<String> getInventoryUnitOptions({String? selectedUnit}) {
  final selected = canonicalizeInventoryUnit(selectedUnit);
  final units = <String>{...kInventoryUnitOptions};
  units.add(selected);
  final ordered = [
    ...kInventoryUnitOptions.where(units.contains),
    ...units.where((unit) => !kInventoryUnitOptions.contains(unit)),
  ];
  return ordered.toList();
}

List<String> getCompatibleProcurementUnits(String? baseUnit) {
  final canonicalBase = canonicalizeInventoryUnit(baseUnit);
  final units = <String>{canonicalBase};

  switch (canonicalBase) {
    case 'kg':
    case 'g':
    case 'ton':
      units.addAll(['kg', 'g', 'ton', 'bag']);
      break;
    case 'L':
    case 'mL':
      units.addAll(['L', 'mL']);
      break;
    case 'pc':
    case 'dozen':
      units.addAll(['pc', 'dozen']);
      break;
  }

  final ordered = [
    ...kInventoryUnitOptions.where(units.contains),
    ...units.where((unit) => !kInventoryUnitOptions.contains(unit)),
  ];
  return ordered.toList();
}

String formatInventoryQuantity(num? value) {
  final safeValue = value ?? 0;
  if (safeValue is int) return safeValue.toString();
  final asDouble = safeValue.toDouble();
  if (asDouble == asDouble.roundToDouble()) {
    return asDouble.toInt().toString();
  }
  return asDouble
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'\.?0+$'), '');
}

num normalizeProcurementQuantity(
  num quantity,
  String selectedUnit,
  String baseUnit, {
  num bagWeightKg = 0,
}) {
  final selected = canonicalizeInventoryUnit(selectedUnit);
  final base = canonicalizeInventoryUnit(baseUnit);
  final qty = quantity.toDouble();

  if (qty == 0 || selected == base || base.isEmpty) {
    return _cleanQuantity(qty);
  }

  const weightFactors = {'g': 1.0, 'kg': 1000.0, 'ton': 1000000.0};
  const liquidFactors = {'mL': 1.0, 'L': 1000.0};
  const countFactors = {'pc': 1.0, 'dozen': 12.0};

  // Support 'bag' as a purchasable unit (e.g., 1 bag = 50 kg). bagWeightKg is expected in kilograms.
  if (selected == 'bag' && (weightFactors.containsKey(base) || base == 'kg' || base == 'g' || base == 'ton')) {
    final bw = bagWeightKg > 0 ? bagWeightKg.toDouble() : 0.0;
    if (bw <= 0) {
      // fallback: treat bag as 1 unit (no conversion)
      return _cleanQuantity(qty);
    }
    // Convert bags -> kg, then kg -> base
    final kgAmount = qty * bw; // in kg
    final normalized = kgAmount * weightFactors['kg']! / weightFactors[base]!;
    return _cleanQuantity(normalized);
  }

  if (weightFactors.containsKey(selected) && weightFactors.containsKey(base)) {
    final normalized = qty * weightFactors[selected]! / weightFactors[base]!;
    return _cleanQuantity(normalized);
  }

  if (liquidFactors.containsKey(selected) && liquidFactors.containsKey(base)) {
    final normalized = qty * liquidFactors[selected]! / liquidFactors[base]!;
    return _cleanQuantity(normalized);
  }

  if (countFactors.containsKey(selected) && countFactors.containsKey(base)) {
    final normalized = qty * countFactors[selected]! / countFactors[base]!;
    return _cleanQuantity(normalized);
  }

  return _cleanQuantity(qty);
}

num _cleanQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt();
  }

  return double.parse(value.toStringAsFixed(3));
}

