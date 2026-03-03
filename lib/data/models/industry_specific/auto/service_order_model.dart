class ServiceOrderModel {
  final String id;
  final String businessId;
  final String vehicleId;
  final String customerName;
  final List<String> serviceItems; // list of service codes
  final DateTime createdAt;

  ServiceOrderModel({
    required this.id,
    required this.businessId,
    required this.vehicleId,
    this.customerName = '',
    this.serviceItems = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ServiceOrderModel.fromJson(Map<String, dynamic> json) =>
      ServiceOrderModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        vehicleId: json['vehicleId'] as String,
        customerName: json['customerName'] as String? ?? '',
        serviceItems:
            (json['serviceItems'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'vehicleId': vehicleId,
        'customerName': customerName,
        'serviceItems': serviceItems,
        'createdAt': createdAt.toIso8601String(),
      };
}

