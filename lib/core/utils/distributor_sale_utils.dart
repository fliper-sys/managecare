double calculateDistributorSaleTotal({
  required num unitPrice,
  required num quantity,
  required num discountPercent,
}) {
  final safeUnitPrice = unitPrice.toDouble();
  final safeQuantity = quantity.toDouble();
  final safeDiscountPercent = discountPercent.toDouble();

  if (safeUnitPrice <= 0 || safeQuantity <= 0) {
    return 0.0;
  }

  final discountRate = (safeDiscountPercent / 100).clamp(0.0, 1.0);
  final discountedUnitPrice = safeUnitPrice * (1 - discountRate);
  return discountedUnitPrice * safeQuantity;
}
