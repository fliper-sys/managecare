class BottleTrackingModel {
  final String id;
  final String businessId;
  final String bottleId;
  final DateTime receivedAt;
  final String status; // full, empty, in-use
  final DateTime createdAt;

  BottleTrackingModel({
    required this.id,
    required this.businessId,
    this.bottleId = '',
    DateTime? receivedAt,
    this.status = 'full',
    DateTime? createdAt,
  })  : receivedAt = receivedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory BottleTrackingModel.fromJson(Map<String, dynamic> json) =>
      BottleTrackingModel(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        bottleId: json['bottleId'] as String? ?? '',
        receivedAt: json['receivedAt'] != null
            ? DateTime.parse(json['receivedAt'] as String)
            : null,
        status: json['status'] as String? ?? 'full',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'bottleId': bottleId,
        'receivedAt': receivedAt.toIso8601String(),
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };
}

