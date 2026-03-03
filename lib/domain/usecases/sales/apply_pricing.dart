import '../usecase.dart';

/// Apply dynamic pricing and discounts
class ApplyPricingUseCase extends UseCase<PricingResult, ApplyPricingParams> {
  @override
  Future<PricingResult> call(ApplyPricingParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class ApplyPricingParams {
  final String businessId;
  final String customerId;
  final List<CartItem> items;
  final String? couponCode;
  final String? loyaltyTier;

  ApplyPricingParams({
    required this.businessId,
    required this.customerId,
    required this.items,
    this.couponCode,
    this.loyaltyTier,
  });
}

class CartItem {
  final String itemId;
  final int quantity;
  final double basePrice;

  CartItem({
    required this.itemId,
    required this.quantity,
    required this.basePrice,
  });
}

class PricingResult {
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double total;
  final List<DiscountApplied> appliedDiscounts;
  final double loyaltyPointsEarned;

  PricingResult({
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
    required this.appliedDiscounts,
    required this.loyaltyPointsEarned,
  });
}

class DiscountApplied {
  final String type; // percentage, fixed, tiered, loyalty
  final double amount;
  final String description;

  DiscountApplied({
    required this.type,
    required this.amount,
    required this.description,
  });
}

/// Manage bulk discounts
class ManageBulkDiscountUseCase
    extends UseCase<void, ManageBulkDiscountParams> {
  @override
  Future<void> call(ManageBulkDiscountParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class ManageBulkDiscountParams {
  final String businessId;
  final int minimumQuantity;
  final double discountPercentage;
  final String? productCategory;

  ManageBulkDiscountParams({
    required this.businessId,
    required this.minimumQuantity,
    required this.discountPercentage,
    this.productCategory,
  });
}

/// Get pricing rules
class GetPricingRulesUseCase extends UseCase<List<PricingRule>, String> {
  @override
  Future<List<PricingRule>> call(String businessId) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class PricingRule {
  final String id;
  final String type; // bulk, loyalty, seasonal, promotional
  final String condition;
  final double discount;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  PricingRule({
    required this.id,
    required this.type,
    required this.condition,
    required this.discount,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });
}

