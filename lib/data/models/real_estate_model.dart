class RealEstateModel {
  final String id;
  final String businessId;
  final String name;
  final List<String> propertyTypes; // e.g., residential, commercial
  final List<Map<String, dynamic>> listings; // basic listing info
  final DateTime createdAt;

  RealEstateModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.propertyTypes = const [],
    this.listings = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RealEstateModel.fromJson(Map<String, dynamic> json) =>
      RealEstateModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        propertyTypes:
            (json['propertyTypes'] as List<dynamic>?)?.cast<String>() ?? [],
        listings: (json['listings'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'propertyTypes': propertyTypes,
        'listings': listings,
        'createdAt': createdAt.toIso8601String(),
      };
}

