class RestaurantModel {
  final String id;
  final String businessId;
  final String name;
  final List<String> menuSections; // e.g., starters, mains, desserts
  final bool supportsReservations;
  final DateTime createdAt;

  RestaurantModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.menuSections = const [],
    this.supportsReservations = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RestaurantModel.fromJson(Map<String, dynamic> json) =>
      RestaurantModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        menuSections:
            (json['menuSections'] as List<dynamic>?)?.cast<String>() ?? [],
        supportsReservations: json['supportsReservations'] as bool? ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'menuSections': menuSections,
        'supportsReservations': supportsReservations,
        'createdAt': createdAt.toIso8601String(),
      };
}

