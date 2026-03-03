/// Inventory model
class InventoryModel {
  final String id;
  final String businessId;
  final String name;
  final String sku;
  final String category;
  final double quantity;
  final double reorderLevel;
  final double unitPrice;
  final String unit;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.sku,
    required this.category,
    required this.quantity,
    required this.reorderLevel,
    required this.unitPrice,
    required this.unit,
    this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InventoryModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      // Cloud Firestore Timestamp
      try {
        // Avoid importing cloud_firestore here; use duck-typing
        if (v is DateTime) return v;
        if (v is String) return DateTime.tryParse(v);
        if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
        // If it's a Timestamp (from cloud_firestore), it has toDate()
        final toDate = v?.toDate;
        if (toDate is Function) {
          final dt = toDate();
          if (dt is DateTime) return dt;
        }
      } catch (_) {}
      return null;
    }

    return InventoryModel(
      id: json['id'] ?? '',
      businessId: json['businessId'] ?? '',
      name: json['name'] ?? '',
      sku: json['sku'] ?? '',
      category: json['category'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      reorderLevel: (json['reorderLevel'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? 'piece',
      expiryDate: parseDate(json['expiryDate']),
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'name': name,
      'sku': sku,
      'category': category,
      'quantity': quantity,
      'reorderLevel': reorderLevel,
      'unitPrice': unitPrice,
      'unit': unit,
      'expiryDate': expiryDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get isLowStock => quantity <= reorderLevel;
  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());
}

