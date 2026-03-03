class HarvestModel {
  final String id;
  final String businessId;
  final String cropId;
  final double quantity; // kg or units
  final DateTime harvestedAt;
  final DateTime createdAt;

  HarvestModel({
    required this.id,
    required this.businessId,
    required this.cropId,
    this.quantity = 0,
    DateTime? harvestedAt,
    DateTime? createdAt,
  })  : harvestedAt = harvestedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory HarvestModel.fromJson(Map<String, dynamic> json) => HarvestModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        cropId: json['cropId'] as String,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        harvestedAt: json['harvestedAt'] != null
            ? DateTime.parse(json['harvestedAt'] as String)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'cropId': cropId,
        'quantity': quantity,
        'harvestedAt': harvestedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}

