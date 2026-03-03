class AutoRepairModel {
  final String id;
  final String businessId;
  final String name;
  final List<String> serviceTypes; // e.g., oil change, brake repair
  final List<String> partsInventory; // part SKUs
  final DateTime createdAt;

  AutoRepairModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.serviceTypes = const [],
    this.partsInventory = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AutoRepairModel.fromJson(Map<String, dynamic> json) =>
      AutoRepairModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        serviceTypes:
            (json['serviceTypes'] as List<dynamic>?)?.cast<String>() ?? [],
        partsInventory:
            (json['partsInventory'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'serviceTypes': serviceTypes,
        'partsInventory': partsInventory,
        'createdAt': createdAt.toIso8601String(),
      };
}

