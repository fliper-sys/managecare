class CropModel {
  final String id;
  final String businessId;
  final String name;
  final String variety;
  final DateTime plantedAt;
  final DateTime? expectedHarvest;
  final DateTime createdAt;

  CropModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.variety = '',
    DateTime? plantedAt,
    this.expectedHarvest,
    DateTime? createdAt,
  })  : plantedAt = plantedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory CropModel.fromJson(Map<String, dynamic> json) => CropModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        name: json['name'] as String,
        variety: json['variety'] as String? ?? '',
        plantedAt: json['plantedAt'] != null
            ? DateTime.parse(json['plantedAt'] as String)
            : null,
        expectedHarvest: json['expectedHarvest'] != null
            ? DateTime.parse(json['expectedHarvest'] as String)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'variety': variety,
        'plantedAt': plantedAt.toIso8601String(),
        'expectedHarvest': expectedHarvest?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}

