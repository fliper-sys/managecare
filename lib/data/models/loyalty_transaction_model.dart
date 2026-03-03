import 'package:cloud_firestore/cloud_firestore.dart';

class LoyaltyTransaction {
  final String id;
  final String memberId;
  final String transactionType; // 'earn', 'redeem'
  final int pointsAmount;
  final double? transactionValue;
  final String? description;
  final String? relatedSaleId;
  final DateTime createdAt;

  LoyaltyTransaction({
    required this.id,
    required this.memberId,
    required this.transactionType,
    required this.pointsAmount,
    this.transactionValue,
    this.description,
    this.relatedSaleId,
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      id: json['id'] as String? ?? '',
      memberId: json['memberId'] as String? ?? '',
      transactionType: json['transactionType'] as String? ?? 'earn',
      pointsAmount: json['pointsAmount'] as int? ?? 0,
      transactionValue: (json['transactionValue'] as num?)?.toDouble(),
      description: json['description'] as String?,
      relatedSaleId: json['relatedSaleId'] as String?,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'transactionType': transactionType,
      'pointsAmount': pointsAmount,
      'transactionValue': transactionValue,
      'description': description,
      'relatedSaleId': relatedSaleId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool isEarning() => transactionType == 'earn';
  bool isRedemption() => transactionType == 'redeem';

  String getFormattedType() {
    return isEarning() ? 'Points Earned' : 'Points Redeemed';
  }
}

