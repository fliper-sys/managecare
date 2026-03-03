class RealEstatePaymentModel {
  final String id;
  final String leaseId;
  final double amount;
  final DateTime date;

  RealEstatePaymentModel(
      {required this.id,
      required this.leaseId,
      required this.amount,
      required this.date});

  factory RealEstatePaymentModel.fromJson(Map<String, dynamic> json) =>
      RealEstatePaymentModel(
        id: json['id'] as String? ?? '',
        leaseId: json['leaseId'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        date: DateTime.parse(
            json['date'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'leaseId': leaseId,
        'amount': amount,
        'date': date.toIso8601String(),
      };
}

