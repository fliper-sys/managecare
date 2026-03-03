class LeaseModel {
  final String id;
  final String propertyId;
  final String tenantId;
  final double amount;
  final DateTime startDate;
  final DateTime? endDate;

  LeaseModel(
      {required this.id,
      required this.propertyId,
      required this.tenantId,
      required this.amount,
      required this.startDate,
      this.endDate});

  factory LeaseModel.fromJson(Map<String, dynamic> json) => LeaseModel(
        id: json['id'] as String? ?? '',
        propertyId: json['propertyId'] as String? ?? '',
        tenantId: json['tenantId'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        startDate: DateTime.parse(
            json['startDate'] as String? ?? DateTime.now().toIso8601String()),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'propertyId': propertyId,
        'tenantId': tenantId,
        'amount': amount,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };
}

