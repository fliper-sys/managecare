class RestaurantOrderModel {
  final String id;
  final String businessId;
  final String tableId;
  final List<Map<String, dynamic>> items; // itemId + qty
  final double total;
  final DateTime createdAt;

  RestaurantOrderModel({
    required this.id,
    required this.businessId,
    this.tableId = '',
    this.items = const [],
    this.total = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RestaurantOrderModel.fromJson(Map<String, dynamic> json) =>
      RestaurantOrderModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        tableId: json['tableId'] as String? ?? '',
        items:
            (json['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                [],
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'tableId': tableId,
        'items': items,
        'total': total,
        'createdAt': createdAt.toIso8601String(),
      };
}

