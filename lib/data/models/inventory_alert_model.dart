import '../../core/utils/datetime_utils.dart';

/// Inventory alert model for low stock notifications
class InventoryAlert {
  final String id;
  final String businessId;
  final String productId;
  final String productName;
  final int currentStock;
  final int minimumThreshold;
  final int reorderQuantity;
  final String severity; // 'critical', 'warning', 'normal'
  final bool isActive;
  final bool acknowledged;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acknowledgedAt;
  final String? notes;

  InventoryAlert({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.minimumThreshold,
    required this.reorderQuantity,
    required this.severity,
    required this.isActive,
    required this.acknowledged,
    required this.createdAt,
    required this.updatedAt,
    this.acknowledgedAt,
    this.notes,
  });

  factory InventoryAlert.fromJson(Map<String, dynamic> json) {
    return InventoryAlert(
      id: json['id'] ?? '',
      businessId: json['businessId'] ?? '',
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      currentStock: json['currentStock'] ?? 0,
      minimumThreshold: json['minimumThreshold'] ?? 0,
      reorderQuantity: json['reorderQuantity'] ?? 0,
      severity: json['severity'] ?? 'normal',
      isActive: json['isActive'] ?? true,
      acknowledged: json['acknowledged'] ?? false,
      createdAt: parseTimestamp(json['createdAt']),
      updatedAt: parseTimestamp(json['updatedAt']),
      acknowledgedAt: json['acknowledgedAt'] == null
          ? null
          : parseTimestamp(json['acknowledgedAt']),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'productId': productId,
      'productName': productName,
      'currentStock': currentStock,
      'minimumThreshold': minimumThreshold,
      'reorderQuantity': reorderQuantity,
      'severity': severity,
      'isActive': isActive,
      'acknowledged': acknowledged,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'acknowledgedAt': acknowledgedAt,
      'notes': notes,
    };
  }

  InventoryAlert copyWith({
    String? id,
    String? businessId,
    String? productId,
    String? productName,
    int? currentStock,
    int? minimumThreshold,
    int? reorderQuantity,
    String? severity,
    bool? isActive,
    bool? acknowledged,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? acknowledgedAt,
    String? notes,
  }) {
    return InventoryAlert(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      currentStock: currentStock ?? this.currentStock,
      minimumThreshold: minimumThreshold ?? this.minimumThreshold,
      reorderQuantity: reorderQuantity ?? this.reorderQuantity,
      severity: severity ?? this.severity,
      isActive: isActive ?? this.isActive,
      acknowledged: acknowledged ?? this.acknowledged,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      notes: notes ?? this.notes,
    );
  }

  /// Calculate stock urgency
  String calculateSeverity() {
    final stockPercentage = (currentStock / minimumThreshold) * 100;
    if (stockPercentage <= 25) return 'critical';
    if (stockPercentage <= 50) return 'warning';
    return 'normal';
  }

  /// Check if product needs reordering
  bool needsReorder() {
    return currentStock <= minimumThreshold;
  }

  /// Days until stock runs out (estimated)
  int estimatedDaysUntilStockout(double dailyUsage) {
    if (dailyUsage <= 0) return 999;
    return (currentStock / dailyUsage).ceil();
  }
}

