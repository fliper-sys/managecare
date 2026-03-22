import 'dart:math' as math;

import '../usecase.dart';

/// Apply dynamic pricing and discounts
class ApplyPricingUseCase extends UseCase<PricingResult, ApplyPricingParams> {
  @override
  Future<PricingResult> call(ApplyPricingParams params) async {
    if (params.items.isEmpty) {
      return PricingResult(
        subtotal: 0,
        discountAmount: 0,
        taxAmount: 0,
        total: 0,
        appliedDiscounts: const [],
        loyaltyPointsEarned: 0,
      );
    }

    final subtotal = params.items.fold<double>(
      0,
      (sum, item) => sum + (item.basePrice * item.quantity),
    );

    final appliedDiscounts = <DiscountApplied>[];
    double discountAmount = 0;

    final totalQty = params.items.fold<int>(0, (sum, item) => sum + item.quantity);
    if (totalQty >= 10) {
      final bulkDiscount = subtotal * 0.05;
      discountAmount += bulkDiscount;
      appliedDiscounts.add(
        DiscountApplied(
          type: 'bulk',
          amount: bulkDiscount,
          description: '5% bulk discount for 10+ items',
        ),
      );
    }

    final loyaltyDiscountRate = _loyaltyDiscountRate(params.loyaltyTier);
    if (loyaltyDiscountRate > 0) {
      final loyaltyDiscount = subtotal * loyaltyDiscountRate;
      discountAmount += loyaltyDiscount;
      appliedDiscounts.add(
        DiscountApplied(
          type: 'loyalty',
          amount: loyaltyDiscount,
          description: '${(loyaltyDiscountRate * 100).toStringAsFixed(0)}% ${params.loyaltyTier} tier discount',
        ),
      );
    }

    final couponDiscount = _couponDiscount(params.couponCode, subtotal);
    if (couponDiscount > 0) {
      discountAmount += couponDiscount;
      appliedDiscounts.add(
        DiscountApplied(
          type: 'coupon',
          amount: couponDiscount,
          description: 'Coupon ${params.couponCode!.trim().toUpperCase()} applied',
        ),
      );
    }

    discountAmount = math.min(discountAmount, subtotal);
    final taxableAmount = subtotal - discountAmount;
    final taxAmount = taxableAmount * 0.075;
    final total = taxableAmount + taxAmount;

    return PricingResult(
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      total: total,
      appliedDiscounts: appliedDiscounts,
      loyaltyPointsEarned: taxableAmount <= 0 ? 0 : taxableAmount.floorToDouble(),
    );
  }

  double _loyaltyDiscountRate(String? tier) {
    switch ((tier ?? '').trim().toLowerCase()) {
      case 'silver':
        return 0.02;
      case 'gold':
        return 0.05;
      case 'platinum':
        return 0.08;
      default:
        return 0;
    }
  }

  double _couponDiscount(String? couponCode, double subtotal) {
    final code = (couponCode ?? '').trim().toUpperCase();
    switch (code) {
      case 'SAVE10':
        return subtotal * 0.10;
      case 'SAVE5':
        return subtotal * 0.05;
      case 'FLAT1000':
        return math.min(1000, subtotal);
      default:
        return 0;
    }
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
    if (params.businessId.trim().isEmpty) {
      throw ArgumentError('businessId is required');
    }
    if (params.minimumQuantity < 1) {
      throw ArgumentError('minimumQuantity must be at least 1');
    }
    if (params.discountPercentage < 0 || params.discountPercentage > 100) {
      throw ArgumentError('discountPercentage must be between 0 and 100');
    }
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
    if (businessId.trim().isEmpty) return const [];
    final now = DateTime.now();
    return [
      PricingRule(
        id: 'bulk-default',
        type: 'bulk',
        condition: '10+ items in cart',
        discount: 5,
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.add(const Duration(days: 365)),
        isActive: true,
      ),
      PricingRule(
        id: 'loyalty-gold',
        type: 'loyalty',
        condition: 'Gold tier customer',
        discount: 5,
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.add(const Duration(days: 365)),
        isActive: true,
      ),
      PricingRule(
        id: 'promo-save10',
        type: 'promotional',
        condition: 'Coupon SAVE10',
        discount: 10,
        startDate: now.subtract(const Duration(days: 7)),
        endDate: now.add(const Duration(days: 90)),
        isActive: true,
      ),
    ];
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

