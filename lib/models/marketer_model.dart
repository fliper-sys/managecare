import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for App Marketer/Worker
class MarketerModel {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String password; // Hashed password
  final double balance;
  final List<String> referredUserIds; // List of user IDs they referred
  final List<Map<String, dynamic>> referrals; // Detailed referral information
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final String? profilePhotoUrl;
  final double totalCommissionEarned;
  final int totalReferralsApproved;
  final int totalReferralsPending;
  final double? commissionRateOverride;

  MarketerModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.password,
    this.balance = 0.0,
    this.referredUserIds = const [],
    this.referrals = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.profilePhotoUrl,
    this.totalCommissionEarned = 0.0,
    this.totalReferralsApproved = 0,
    this.totalReferralsPending = 0,
    this.commissionRateOverride,
  });

  /// Create from Firestore document
  factory MarketerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketerModel(
      id: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phoneNumber: data['phoneNumber'],
      password: data['password'] ?? '',
      balance: (data['balance'] ?? 0.0).toDouble(),
      referredUserIds: List<String>.from(data['referredUserIds'] ?? []),
      referrals: List<Map<String, dynamic>>.from(data['referrals'] ?? []),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      profilePhotoUrl: data['profilePhotoUrl'],
      totalCommissionEarned: (data['totalCommissionEarned'] ?? 0.0).toDouble(),
      totalReferralsApproved: data['totalReferralsApproved'] ?? 0,
      totalReferralsPending: data['totalReferralsPending'] ?? 0,
      commissionRateOverride: data['commissionRateOverride'] != null ? (data['commissionRateOverride'] as num).toDouble() : null,
    );
  }

  /// Convert to Firestore JSON
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'password': password,
      'balance': balance,
      'referredUserIds': referredUserIds,
      'referrals': referrals,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'profilePhotoUrl': profilePhotoUrl,
      'totalCommissionEarned': totalCommissionEarned,
      'totalReferralsApproved': totalReferralsApproved,
      'totalReferralsPending': totalReferralsPending,
      'commissionRateOverride': commissionRateOverride,
    };
  }

  /// Create a copy with modified fields
  MarketerModel copyWith({
    String? password,
    String? fullName,
    String? phoneNumber,
    double? balance,
    List<String>? referredUserIds,
    List<Map<String, dynamic>>? referrals,
    bool? isActive,
    DateTime? lastLoginAt,
    String? profilePhotoUrl,
    double? totalCommissionEarned,
    int? totalReferralsApproved,
    int? totalReferralsPending,
    double? commissionRateOverride,
  }) {
    return MarketerModel(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      password: password ?? this.password,
      balance: balance ?? this.balance,
      referredUserIds: referredUserIds ?? this.referredUserIds,
      referrals: referrals ?? this.referrals,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      totalCommissionEarned: totalCommissionEarned ?? this.totalCommissionEarned,
      totalReferralsApproved: totalReferralsApproved ?? this.totalReferralsApproved,
      totalReferralsPending: totalReferralsPending ?? this.totalReferralsPending,
      commissionRateOverride: commissionRateOverride ?? this.commissionRateOverride,
    );
  }
}

/// Model for Referral tracking
class ReferralRecord {
  final String id;
  final String marketerEmail;
  final String userId;
  final String userEmail;
  final String? businessId;
  final double commissionAmount;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvingAdminId;
  final String? notes;

  ReferralRecord({
    required this.id,
    required this.marketerEmail,
    required this.userId,
    required this.userEmail,
    this.businessId,
    this.commissionAmount = 0.0,
    this.status = 'pending',
    required this.createdAt,
    this.approvedAt,
    this.approvingAdminId,
    this.notes,
  });

  factory ReferralRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReferralRecord(
      id: doc.id,
      marketerEmail: data['marketerEmail'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      businessId: data['businessId'],
      commissionAmount: (data['commissionAmount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      approvingAdminId: data['approvingAdminId'],
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'marketerEmail': marketerEmail,
      'userId': userId,
      'userEmail': userEmail,
      'businessId': businessId,
      'commissionAmount': commissionAmount,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvingAdminId': approvingAdminId,
      'notes': notes,
    };
  }
}
