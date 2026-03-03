class PartsModel {
  final String id;
  final String businessId;
  final String partNumber;
  final String name;
  final int quantity;
  final double price;
  final DateTime createdAt;

  PartsModel({
    required this.id,
    required this.businessId,
    this.partNumber = '',
    this.name = '',
    this.quantity = 0,
    this.price = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PartsModel.fromJson(Map<String, dynamic> json) => PartsModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        partNumber: json['partNumber'] as String? ?? '',
        name: json['name'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 0,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'partNumber': partNumber,
        'name': name,
        'quantity': quantity,
        'price': price,
        'createdAt': createdAt.toIso8601String(),
      };
}

