class RetailModel {
  final String id;
  final String businessId;
  final String name;
  final List<String> productCategories;
  final bool supportsPOS;
  final DateTime createdAt;

  RetailModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.productCategories = const [],
    this.supportsPOS = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RetailModel.fromJson(Map<String, dynamic> json) => RetailModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        productCategories:
            (json['productCategories'] as List<dynamic>?)?.cast<String>() ?? [],
        supportsPOS: json['supportsPOS'] as bool? ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'productCategories': productCategories,
        'supportsPOS': supportsPOS,
        'createdAt': createdAt.toIso8601String(),
      };
}

