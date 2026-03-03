import 'package:cloud_firestore/cloud_firestore.dart';

class LoyaltyMember {
  final String id;
  final String customerId;
  final String currentTier;
  final int totalPoints;
  final int availablePoints;
  final int pointsUsed;
  final int totalTransactions;
  final double totalSpent;
  final DateTime joinedDate;
  final DateTime lastTransactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  LoyaltyMember({
    required this.id,
    required this.customerId,
    required this.currentTier,
    required this.totalPoints,
    required this.availablePoints,
    required this.pointsUsed,
    required this.totalTransactions,
    required this.totalSpent,
    required this.joinedDate,
    required this.lastTransactionDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LoyaltyMember.fromJson(Map<String, dynamic> json) {
    return LoyaltyMember(
      id: json['id'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      currentTier: json['currentTier'] as String? ?? 'bronze',
      totalPoints: json['totalPoints'] as int? ?? 0,
      availablePoints: json['availablePoints'] as int? ?? 0,
      pointsUsed: json['pointsUsed'] as int? ?? 0,
      totalTransactions: json['totalTransactions'] as int? ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      joinedDate: json['joinedDate'] is Timestamp
          ? (json['joinedDate'] as Timestamp).toDate()
          : DateTime.now(),
      lastTransactionDate: json['lastTransactionDate'] is Timestamp
          ? (json['lastTransactionDate'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'currentTier': currentTier,
      'totalPoints': totalPoints,
      'availablePoints': availablePoints,
      'pointsUsed': pointsUsed,
      'totalTransactions': totalTransactions,
      'totalSpent': totalSpent,
      'joinedDate': Timestamp.fromDate(joinedDate),
      'lastTransactionDate': Timestamp.fromDate(lastTransactionDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  LoyaltyMember copyWith({
    String? id,
    String? customerId,
    String? currentTier,
    int? totalPoints,
    int? availablePoints,
    int? pointsUsed,
    int? totalTransactions,
    double? totalSpent,
    DateTime? joinedDate,
    DateTime? lastTransactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LoyaltyMember(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      currentTier: currentTier ?? this.currentTier,
      totalPoints: totalPoints ?? this.totalPoints,
      availablePoints: availablePoints ?? this.availablePoints,
      pointsUsed: pointsUsed ?? this.pointsUsed,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalSpent: totalSpent ?? this.totalSpent,
      joinedDate: joinedDate ?? this.joinedDate,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate progress to next tier (0-100)
  int getProgressToNextTier(int nextTierPoints) {
    if (nextTierPoints <= 0) return 100;
    final progress = (totalPoints / nextTierPoints * 100).toInt();
    return progress > 100 ? 100 : progress;
  }

  /// Calculate days since last transaction
  int getDaysSinceLastTransaction() {
    return DateTime.now().difference(lastTransactionDate).inDays;
  }

  /// Check if member is active (transaction within 30 days)
  bool isActive() {
    return getDaysSinceLastTransaction() <= 30;
  }
}

