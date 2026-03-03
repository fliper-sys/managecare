class InputModel {
  final String id;
  final String businessId;
  final String name;
  final String type; // fertilizer, seed, chemical
  final int quantity;
  final DateTime createdAt;

  InputModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.type = '',
    this.quantity = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory InputModel.fromJson(Map<String, dynamic> json) => InputModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        type: json['type'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'type': type,
        'quantity': quantity,
        'createdAt': createdAt.toIso8601String(),
      };
}

