class VehicleModel {
  final String id;
  final String businessId;
  final String plateNumber;
  final String make;
  final String model;
  final int year;
  final DateTime createdAt;

  VehicleModel({
    required this.id,
    required this.businessId,
    this.plateNumber = '',
    this.make = '',
    this.model = '',
    this.year = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory VehicleModel.fromJson(Map<String, dynamic> json) => VehicleModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        plateNumber: json['plateNumber'] as String? ?? '',
        make: json['make'] as String? ?? '',
        model: json['model'] as String? ?? '',
        year: json['year'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'plateNumber': plateNumber,
        'make': make,
        'model': model,
        'year': year,
        'createdAt': createdAt.toIso8601String(),
      };
}

