class PharmacyModel {
  final String id;
  final String businessId;
  final String name;
  final List<String> medications; // medication SKUs or names
  final Map<String, dynamic>? prescriptionRules;
  final DateTime createdAt;

  PharmacyModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.medications = const [],
    this.prescriptionRules,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PharmacyModel.fromJson(Map<String, dynamic> json) => PharmacyModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        medications:
            (json['medications'] as List<dynamic>?)?.cast<String>() ?? [],
        prescriptionRules: json['prescriptionRules'] as Map<String, dynamic>?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'medications': medications,
        'prescriptionRules': prescriptionRules,
        'createdAt': createdAt.toIso8601String(),
      };
}

