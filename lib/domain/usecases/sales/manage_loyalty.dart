import '../usecase.dart';

/// Manage customer loyalty program
class ManageLoyaltyProgramUseCase
    extends UseCase<LoyaltyProgram, ManageLoyaltyParams> {
  @override
  Future<LoyaltyProgram> call(ManageLoyaltyParams params) async {
    if (params.businessId.trim().isEmpty || params.customerId.trim().isEmpty) {
      throw ArgumentError('businessId and customerId are required');
    }
    final normalized = params.operation.trim().toLowerCase();
    var points = 0;
    final redeemedRewards = <RewardRedeemed>[];

    switch (normalized) {
      case 'enroll':
        points = 100;
        break;
      case 'addpoints':
        points = (params.amount ?? 0).floor();
        break;
      case 'redeempoints':
        final redeemPoints = (params.amount ?? 0).floor().clamp(0, 1000000);
        points = -redeemPoints;
        if (redeemPoints > 0) {
          redeemedRewards.add(
            RewardRedeemed(
              rewardId: 'reward_$redeemPoints',
              rewardName: 'Points redemption',
              pointsUsed: redeemPoints,
              redeemedAt: DateTime.now(),
              status: 'completed',
            ),
          );
        }
        break;
      case 'upgrade':
        points = ((params.amount ?? 0) * 2).floor();
        break;
      default:
        throw ArgumentError('Unsupported loyalty operation: ${params.operation}');
    }

    final totalPoints = points < 0 ? 0 : points;
    final tier = _tierForPoints(totalPoints);
    return LoyaltyProgram(
      customerId: params.customerId,
      totalPoints: totalPoints,
      tier: tier,
      tierMultiplier: _tierMultiplier(tier),
      enrollmentDate: DateTime.now(),
      nextTierDate: DateTime.now().add(const Duration(days: 30)),
      pointsToNextTier: _pointsToNextTier(totalPoints),
      redeemedRewards: redeemedRewards,
    );
  }

  String _tierForPoints(int points) {
    if (points >= 5000) return 'platinum';
    if (points >= 2500) return 'gold';
    if (points >= 1000) return 'silver';
    return 'bronze';
  }

  double _tierMultiplier(String tier) {
    switch (tier) {
      case 'silver':
        return 1.2;
      case 'gold':
        return 1.5;
      case 'platinum':
        return 2.0;
      default:
        return 1.0;
    }
  }

  int _pointsToNextTier(int points) {
    if (points >= 5000) return 0;
    if (points >= 2500) return 5000 - points;
    if (points >= 1000) return 2500 - points;
    return 1000 - points;
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
    final now = DateTime.now();
    final rewards = [
      AvailableReward(
        id: 'rw_500',
        name: '5% Discount',
        description: 'Redeem for a 5% discount on your next order',
        pointsRequired: 500,
        discountValue: 5,
        expiryDate: now.add(const Duration(days: 90)),
        maxRedemptions: 1,
        canRedeem: params.currentPoints >= 500,
      ),
      AvailableReward(
        id: 'rw_1000',
        name: '10% Discount',
        description: 'Redeem for a 10% discount on your next order',
        pointsRequired: 1000,
        discountValue: 10,
        expiryDate: now.add(const Duration(days: 90)),
        maxRedemptions: 1,
        canRedeem: params.currentPoints >= 1000,
      ),
      AvailableReward(
        id: 'rw_2500',
        name: 'Free Delivery',
        description: 'Redeem for one free delivery',
        pointsRequired: 2500,
        discountValue: 2500,
        expiryDate: now.add(const Duration(days: 90)),
        maxRedemptions: 1,
        canRedeem: params.currentPoints >= 2500,
      ),
    ];
    return rewards;
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
    if (customerId.trim().isEmpty) {
      throw ArgumentError('customerId is required');
    }
    final now = DateTime.now();
    return CustomerProfile(
      customerId: customerId,
      name: 'Customer $customerId',
      email: '',
      phone: '',
      totalPurchases: 0,
      totalSpent: 0,
      favoriteCategories: const [],
      lastPurchaseDate: now,
      joinDate: now,
      isPreferred: false,
    );
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

