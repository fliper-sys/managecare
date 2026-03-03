import '../usecase.dart';

/// Manage customer loyalty program
class ManageLoyaltyProgramUseCase
    extends UseCase<LoyaltyProgram, ManageLoyaltyParams> {
  @override
  Future<LoyaltyProgram> call(ManageLoyaltyParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class ManageLoyaltyParams {
  final String businessId;
  final String customerId;
  final String operation; // enroll, addPoints, redeemPoints, upgrade
  final double? amount;

  ManageLoyaltyParams({
    required this.businessId,
    required this.customerId,
    required this.operation,
    this.amount,
  });
}

class LoyaltyProgram {
  final String customerId;
  final int totalPoints;
  final String tier; // bronze, silver, gold, platinum
  final double tierMultiplier; // points multiplier based on tier
  final DateTime enrollmentDate;
  final DateTime? nextTierDate;
  final int pointsToNextTier;
  final List<RewardRedeemed> redeemedRewards;

  LoyaltyProgram({
    required this.customerId,
    required this.totalPoints,
    required this.tier,
    required this.tierMultiplier,
    required this.enrollmentDate,
    this.nextTierDate,
    required this.pointsToNextTier,
    required this.redeemedRewards,
  });
}

class RewardRedeemed {
  final String rewardId;
  final String rewardName;
  final int pointsUsed;
  final DateTime redeemedAt;
  final String status; // pending, completed, expired

  RewardRedeemed({
    required this.rewardId,
    required this.rewardName,
    required this.pointsUsed,
    required this.redeemedAt,
    required this.status,
  });
}

/// Get available rewards
class GetAvailableRewardsUseCase
    extends UseCase<List<AvailableReward>, GetRewardsParams> {
  @override
  Future<List<AvailableReward>> call(GetRewardsParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class GetRewardsParams {
  final String businessId;
  final int currentPoints;

  GetRewardsParams({required this.businessId, required this.currentPoints});
}

class AvailableReward {
  final String id;
  final String name;
  final String description;
  final int pointsRequired;
  final double discountValue;
  final DateTime expiryDate;
  final int maxRedemptions;
  final bool canRedeem;

  AvailableReward({
    required this.id,
    required this.name,
    required this.description,
    required this.pointsRequired,
    required this.discountValue,
    required this.expiryDate,
    required this.maxRedemptions,
    required this.canRedeem,
  });
}

/// Get customer preferences and purchase history
class GetCustomerProfileUseCase extends UseCase<CustomerProfile, String> {
  @override
  Future<CustomerProfile> call(String customerId) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class CustomerProfile {
  final String customerId;
  final String name;
  final String email;
  final String phone;
  final int totalPurchases;
  final double totalSpent;
  final List<String> favoriteCategories;
  final DateTime lastPurchaseDate;
  final DateTime joinDate;
  final bool isPreferred;

  CustomerProfile({
    required this.customerId,
    required this.name,
    required this.email,
    required this.phone,
    required this.totalPurchases,
    required this.totalSpent,
    required this.favoriteCategories,
    required this.lastPurchaseDate,
    required this.joinDate,
    required this.isPreferred,
  });
}

