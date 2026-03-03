class DrinkBarModel {
  final String id;
  final String businessId;
  final String name;
  final List<String> drinkCategories; // e.g., cocktails, beer, wine
  final bool hasHappyHour;
  final DateTime createdAt;

  DrinkBarModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.drinkCategories = const [],
    this.hasHappyHour = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DrinkBarModel.fromJson(Map<String, dynamic> json) => DrinkBarModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        drinkCategories:
            (json['drinkCategories'] as List<dynamic>?)?.cast<String>() ?? [],
        hasHappyHour: json['hasHappyHour'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'drinkCategories': drinkCategories,
        'hasHappyHour': hasHappyHour,
        'createdAt': createdAt.toIso8601String(),
      };
}

