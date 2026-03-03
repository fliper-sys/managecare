class BeverageModel {
  final String id;
  final String businessId;
  final String name;
  final String category;
  final double price;
  final DateTime createdAt;

  BeverageModel({
    required this.id,
    required this.businessId,
    this.name = '',
    this.category = '',
    this.price = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BeverageModel.fromJson(Map<String, dynamic> json) => BeverageModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'category': category,
        'price': price,
        'createdAt': createdAt.toIso8601String(),
      };
}

