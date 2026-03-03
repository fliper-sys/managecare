class SalonModel {
  final String id;
  final String businessId;
  final String name;
  final List<String> services; // e.g., haircut, coloring
  final List<String> staffIds; // stylist/employee ids
  final DateTime createdAt;

  SalonModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.services = const [],
    this.staffIds = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SalonModel.fromJson(Map<String, dynamic> json) => SalonModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        services: (json['services'] as List<dynamic>?)?.cast<String>() ?? [],
        staffIds: (json['staffIds'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'services': services,
        'staffIds': staffIds,
        'createdAt': createdAt.toIso8601String(),
      };
}

