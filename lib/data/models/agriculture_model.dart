class AgricultureModel {
  final String id;
  final String businessId;
  final String name;
  final List<String> farmTypes; // e.g., crops, livestock
  final Map<String, dynamic>? fieldInventory; // mapping fieldId -> details
  final DateTime createdAt;

  AgricultureModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.farmTypes = const [],
    this.fieldInventory,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AgricultureModel.fromJson(Map<String, dynamic> json) =>
      AgricultureModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        farmTypes: (json['farmTypes'] as List<dynamic>?)?.cast<String>() ?? [],
        fieldInventory: json['fieldInventory'] as Map<String, dynamic>?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'farmTypes': farmTypes,
        'fieldInventory': fieldInventory,
        'createdAt': createdAt.toIso8601String(),
      };
}

