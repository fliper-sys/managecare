class KitchenQueueModel {
  final String id;
  final String orderId;
  final List<Map<String, dynamic>> items;
  final String status;

  KitchenQueueModel(
      {required this.id,
      required this.orderId,
      this.items = const [],
      this.status = 'queued'});

  factory KitchenQueueModel.fromJson(Map<String, dynamic> json) =>
      KitchenQueueModel(
        id: json['id'] as String? ?? '',
        orderId: json['orderId'] as String? ?? '',
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        status: json['status'] as String? ?? 'queued',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'items': items,
        'status': status,
      };
}

