class DistributorSalesAnalytics {
  const DistributorSalesAnalytics({
    required this.saleCount,
    required this.totalQuantity,
    required this.totalAmount,
    required this.distributorCount,
  });

  final int saleCount;
  final int totalQuantity;
  final double totalAmount;
  final int distributorCount;

  factory DistributorSalesAnalytics.summarize(List<Map<String, dynamic>> sales) {
    final saleCount = sales.length;
    final totalQuantity = sales.fold<int>(0, (sum, entry) {
      final quantity = entry['quantity'];
      if (quantity is num) {
        return sum + quantity.toInt();
      }
      final parsed = int.tryParse(quantity?.toString() ?? '');
      return sum + (parsed ?? 0);
    });

    final totalAmount = sales.fold<double>(0, (sum, entry) {
      final amount = entry['totalAmount'];
      if (amount is num) return sum + amount.toDouble();
      if (amount is String) {
        return sum + (double.tryParse(amount) ?? 0);
      }
      return sum;
    });

    final distributorCount = sales.fold<Set<String>>(
      <String>{},
      (set, entry) {
        final value = (entry['distributorName'] ?? entry['distributorId'] ?? '').toString().trim();
        if (value.isNotEmpty) {
          set.add(value);
        }
        return set;
      },
    ).length;

    return DistributorSalesAnalytics(
      saleCount: saleCount,
      totalQuantity: totalQuantity,
      totalAmount: totalAmount,
      distributorCount: distributorCount,
    );
  }
}
