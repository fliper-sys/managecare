class FarmModel {
  final String id;
  final String businessId;
  final String name;
  final String location;
  final List<String> fields; // field IDs
  final DateTime createdAt;

  FarmModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.location = '',
    this.fields = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory FarmModel.fromJson(Map<String, dynamic> json) => FarmModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        location: json['location'] as String? ?? '',
        fields: (json['fields'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'location': location,
        'fields': fields,
        'createdAt': createdAt.toIso8601String(),
      };
}

