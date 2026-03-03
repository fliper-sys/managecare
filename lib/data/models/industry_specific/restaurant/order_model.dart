class OrderModel {
  final String id;
  final String tableId;
  final List<Map<String, dynamic>> items;
  final double total;
  final String status;

  OrderModel(
      {required this.id,
      required this.tableId,
      this.items = const [],
      required this.total,
      this.status = 'pending'});

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['id'] as String? ?? '',
        tableId: json['tableId'] as String? ?? '',
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] as String? ?? 'pending',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tableId': tableId,
        'items': items,
        'total': total,
        'status': status,
      };
}

