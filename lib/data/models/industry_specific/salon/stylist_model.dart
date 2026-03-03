class StylistModel {
  final String id;
  final String businessId;
  final String name;
  final List<String> skills;
  final DateTime createdAt;

  StylistModel({
    required this.id,
    required this.businessId,
    this.name = '',
    this.skills = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StylistModel.fromJson(Map<String, dynamic> json) => StylistModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String? ?? '',
        skills: (json['skills'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'skills': skills,
        'createdAt': createdAt.toIso8601String(),
      };
}

