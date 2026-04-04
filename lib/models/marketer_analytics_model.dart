import 'package:cloud_firestore/cloud_firestore.dart';

enum MarketerClientStatus {
  active,
  inactive,
  needsBusiness,
  expiringSoon,
  expired,
  rejected,
}

extension MarketerClientStatusLabel on MarketerClientStatus {
  String get label {
    switch (this) {
      case MarketerClientStatus.active:
        return 'Active';
      case MarketerClientStatus.inactive:
        return 'Inactive';
      case MarketerClientStatus.needsBusiness:
        return 'Needs business';
      case MarketerClientStatus.expiringSoon:
        return 'Expiring soon';
      case MarketerClientStatus.expired:
        return 'Expired';
      case MarketerClientStatus.rejected:
        return 'Rejected';
    }
  }
}

class MarketerClientRecord {
  final String userId;
  final String marketerEmail;
  final String userEmail;
  final String fullName;
  final String? phoneNumber;
  final String? businessId;
  final String? businessName;
  final String? businessType;
  final bool hasBusiness;
  final bool hasActiveSubscription;
  final String subscriptionStatus;
  final DateTime? subscriptionEndDate;
  final DateTime registeredAt;
  final DateTime? lastRewardAt;
  final DateTime? lastApprovedAt;
  final double totalRewardEarned;
  final double monthlyRewardEarned;
  final int monthlyRewardCount;
  final double lastCommissionAmount;
  final String referralStatus;
  final String? notes;
  final MarketerClientStatus status;

  const MarketerClientRecord({
    required this.userId,
    required this.marketerEmail,
    required this.userEmail,
    required this.fullName,
    this.phoneNumber,
    this.businessId,
    this.businessName,
    this.businessType,
    required this.hasBusiness,
    required this.hasActiveSubscription,
    required this.subscriptionStatus,
    this.subscriptionEndDate,
    required this.registeredAt,
    this.lastRewardAt,
    this.lastApprovedAt,
    required this.totalRewardEarned,
    required this.monthlyRewardEarned,
    required this.monthlyRewardCount,
    required this.lastCommissionAmount,
    required this.referralStatus,
    this.notes,
    required this.status,
  });

  bool get isCurrentlyActive =>
      status == MarketerClientStatus.active ||
      status == MarketerClientStatus.expiringSoon;

  bool get isExpiringSoon => status == MarketerClientStatus.expiringSoon;

  int? get daysUntilExpiry {
    if (subscriptionEndDate == null) return null;
    return subscriptionEndDate!.difference(DateTime.now()).inDays;
  }
}

class MarketerRewardEntry {
  final String id;
  final String marketerId;
  final String marketerEmail;
  final String userId;
  final String userEmail;
  final String? businessId;
  final String? businessName;
  final String planId;
  final double amount;
  final String rewardType;
  final String periodKey;
  final DateTime awardedAt;
  final String? sourceRequestId;
  final String? sourceTransactionId;
  final bool isFirstActivation;

  const MarketerRewardEntry({
    required this.id,
    required this.marketerId,
    required this.marketerEmail,
    required this.userId,
    required this.userEmail,
    this.businessId,
    this.businessName,
    required this.planId,
    required this.amount,
    required this.rewardType,
    required this.periodKey,
    required this.awardedAt,
    this.sourceRequestId,
    this.sourceTransactionId,
    required this.isFirstActivation,
  });

  factory MarketerRewardEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final awardedAtValue = data['awardedAt'] ?? data['createdAt'];
    final awardedAt = awardedAtValue is Timestamp
        ? awardedAtValue.toDate()
        : DateTime.tryParse(awardedAtValue?.toString() ?? '') ??
            DateTime.now();

    return MarketerRewardEntry(
      id: doc.id,
      marketerId: data['marketerId']?.toString() ?? '',
      marketerEmail: data['marketerEmail']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? '',
      businessId: data['businessId']?.toString(),
      businessName: data['businessName']?.toString(),
      planId: data['planId']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      rewardType: data['rewardType']?.toString() ?? 'commission',
      periodKey: data['periodKey']?.toString() ?? '',
      awardedAt: awardedAt,
      sourceRequestId: data['sourceRequestId']?.toString(),
      sourceTransactionId: data['sourceTransactionId']?.toString(),
      isFirstActivation: data['isFirstActivation'] == true,
    );
  }
}

class MarketerRewardConfig {
  final int monthlyTargetSubscriptions;
  final double targetBonusAmount;
  final double rank1BonusAmount;
  final double rank2BonusAmount;
  final double rank3BonusAmount;
  final double subscriptionCommissionRate;
  final int expiryWarningDays;

  const MarketerRewardConfig({
    this.monthlyTargetSubscriptions = 5,
    this.targetBonusAmount = 10000,
    this.rank1BonusAmount = 30000,
    this.rank2BonusAmount = 20000,
    this.rank3BonusAmount = 10000,
    this.subscriptionCommissionRate = 0.10,
    this.expiryWarningDays = 14,
  });

  factory MarketerRewardConfig.fromSettings(Map<String, dynamic>? settings) {
    final data = settings ?? const <String, dynamic>{};

    double readDouble(String key, double fallback) {
      final value = data[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    int readInt(String key, int fallback) {
      final value = data[key];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return MarketerRewardConfig(
      monthlyTargetSubscriptions: readInt('marketerMonthlyTarget', 5),
      targetBonusAmount: readDouble('marketerTargetBonusAmount', 10000),
      rank1BonusAmount: readDouble('marketerRank1BonusAmount', 30000),
      rank2BonusAmount: readDouble('marketerRank2BonusAmount', 20000),
      rank3BonusAmount: readDouble('marketerRank3BonusAmount', 10000),
      subscriptionCommissionRate:
          readDouble('marketerSubscriptionCommissionRate', 0.10),
      expiryWarningDays: readInt('marketerExpiryWarningDays', 14),
    );
  }

  double podiumBonusForRank(int rank) {
    switch (rank) {
      case 1:
        return rank1BonusAmount;
      case 2:
        return rank2BonusAmount;
      case 3:
        return rank3BonusAmount;
      default:
        return 0;
    }
  }
}

class MarketerLeaderboardEntry {
  final String marketerId;
  final String marketerEmail;
  final String fullName;
  final int rank;
  final int monthlyPerformanceCount;
  final int monthlyActiveClients;
  final int totalActiveClients;
  final double monthlyRewardEarned;
  final double targetProgress;
  final bool targetReached;
  final double projectedBonus;

  const MarketerLeaderboardEntry({
    required this.marketerId,
    required this.marketerEmail,
    required this.fullName,
    required this.rank,
    required this.monthlyPerformanceCount,
    required this.monthlyActiveClients,
    required this.totalActiveClients,
    required this.monthlyRewardEarned,
    required this.targetProgress,
    required this.targetReached,
    required this.projectedBonus,
  });
}

class MarketerPerformanceSnapshot {
  final String marketerId;
  final String marketerEmail;
  final String fullName;
  final int registeredClients;
  final int activeClients;
  final int inactiveClients;
  final int expiringSoonClients;
  final int businessesAttached;
  final int monthlyPerformanceCount;
  final int monthlyActiveClients;
  final int monthlyRenewals;
  final double monthlyRewardEarned;
  final double lifetimeRewardEarned;
  final int monthlyTarget;
  final double targetProgress;
  final bool targetReached;
  final int rank;
  final double projectedBonus;
  final DateTime monthStart;

  const MarketerPerformanceSnapshot({
    required this.marketerId,
    required this.marketerEmail,
    required this.fullName,
    required this.registeredClients,
    required this.activeClients,
    required this.inactiveClients,
    required this.expiringSoonClients,
    required this.businessesAttached,
    required this.monthlyPerformanceCount,
    required this.monthlyActiveClients,
    required this.monthlyRenewals,
    required this.monthlyRewardEarned,
    required this.lifetimeRewardEarned,
    required this.monthlyTarget,
    required this.targetProgress,
    required this.targetReached,
    required this.rank,
    required this.projectedBonus,
    required this.monthStart,
  });

  MarketerPerformanceSnapshot copyWith({
    int? rank,
    double? projectedBonus,
  }) {
    return MarketerPerformanceSnapshot(
      marketerId: marketerId,
      marketerEmail: marketerEmail,
      fullName: fullName,
      registeredClients: registeredClients,
      activeClients: activeClients,
      inactiveClients: inactiveClients,
      expiringSoonClients: expiringSoonClients,
      businessesAttached: businessesAttached,
      monthlyPerformanceCount: monthlyPerformanceCount,
      monthlyActiveClients: monthlyActiveClients,
      monthlyRenewals: monthlyRenewals,
      monthlyRewardEarned: monthlyRewardEarned,
      lifetimeRewardEarned: lifetimeRewardEarned,
      monthlyTarget: monthlyTarget,
      targetProgress: targetProgress,
      targetReached: targetReached,
      rank: rank ?? this.rank,
      projectedBonus: projectedBonus ?? this.projectedBonus,
      monthStart: monthStart,
    );
  }
}
