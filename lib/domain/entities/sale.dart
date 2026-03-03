class Sale {
  final String id;
  final String businessId;
  final double totalAmount;
  final DateTime createdAt;

  Sale(
      {required this.id,
      required this.businessId,
      required this.totalAmount,
      required this.createdAt});
}

