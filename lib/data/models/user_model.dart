/// User model
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? photoUrl;
  final String role;
  final String? phoneNumber;
  final String businessId;
  final List<String> businessIds;
  final String? currentBusinessId;
  final String? preferredBusinessId;
  final String? businessType;
  final String? storeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final bool isOwner;
  final String? pin; // 4-digit personal PIN for cashier confirmation
  final String? referralEmail;

  // Subscription fields
  final bool hasActiveSubscription;
  final String?
      subscriptionPlan; // 'free', 'basic', 'professional', 'enterprise'
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final bool subscriptionPaymentRequired;
  final String? subscriptionTransactionId;
  final double? subscriptionAmount;

  UserModel({
    this.storeId,
    required this.id,
    required this.email,
    required this.fullName,
    this.photoUrl,
    required this.role,
    this.phoneNumber,
    required this.businessId,
    this.businessIds = const [],
    this.currentBusinessId,
    this.preferredBusinessId,
    this.businessType,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.isActive,
    this.isOwner = false,
    this.pin,
    this.referralEmail,
    this.hasActiveSubscription = false,
    this.subscriptionPlan,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.subscriptionPaymentRequired = true,
    this.subscriptionTransactionId,
    this.subscriptionAmount,
  })  : createdAt = createdAt ?? DateTime.fromMicrosecondsSinceEpoch(0),
        updatedAt = updatedAt ?? DateTime.fromMicrosecondsSinceEpoch(0);

  // Get user initials from full name
  String get initials {
    return fullName.isNotEmpty
        ? fullName
            .split(' ')
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join('')
        : 'U';
  }

  /// Primary business id for backward compatibility
  String get primaryBusinessId {
    if (currentBusinessId != null && currentBusinessId!.isNotEmpty) return currentBusinessId!;
    if (businessIds.isNotEmpty) return businessIds.first;
    return businessId;
  }

  /// Check if subscription is active and not expired.
  /// Non-owners are always considered to have valid subscription access.
  bool get isSubscriptionValid {
    if (!isOwner) return true;
    if (!hasActiveSubscription || subscriptionEndDate == null) {
      return false;
    }
    return DateTime.now().isBefore(subscriptionEndDate!);
  }

  /// Get days remaining in subscription
  int? get daysRemainingInSubscription {
    if (subscriptionEndDate == null) return null;
    final diff = subscriptionEndDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Helper to convert Firestore Timestamp or String to DateTime
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      // Handle Firestore Timestamp
      if (value.runtimeType.toString().contains('Timestamp')) {
        return (value as dynamic).toDate();
      }
      // Handle String
      if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    // Legacy compatibility: some user docs have a single `businessId` string
    final rawBusinessId = json['businessId']?.toString() ?? '';

    // Normalize businessIds: handle List<String>, comma-separated String, or fall back to single businessId
    List<String> parsedBusinessIds = [];
    final dynamic rawBusinessIdsValue = json['businessIds'];
    if (rawBusinessIdsValue is List) {
      parsedBusinessIds = List<String>.from(rawBusinessIdsValue.map((e) => e.toString()));
    } else if (rawBusinessIdsValue is String) {
      final s = rawBusinessIdsValue.trim();
      if (s.isNotEmpty) {
        parsedBusinessIds = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    } else if (rawBusinessId.isNotEmpty) {
      parsedBusinessIds = [rawBusinessId];
    }

    // Determine a sensible currentBusinessId: prefer stored current, then preferred, then first of businessIds
    String? current = json['currentBusinessId']?.toString();
    final preferred = json['preferredBusinessId']?.toString();
    if ((current == null || current.isEmpty) && (preferred != null && preferred.isNotEmpty)) {
      current = preferred;
    }
    if ((current == null || current.isEmpty) && parsedBusinessIds.isNotEmpty) {
      current = parsedBusinessIds.first;
    }

    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['name'] ?? '',
      photoUrl: json['photoUrl'],
      role: json['role'] ?? 'staff',
      phoneNumber: json['phoneNumber'],
      businessId: rawBusinessId,
      businessIds: parsedBusinessIds,
      currentBusinessId: current,
      preferredBusinessId: preferred,
      businessType: json['businessType'],
      storeId: json['storeId'] as String?,
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      isActive: json['isActive'] ?? true,
      isOwner: json['isOwner'] ?? (json['role'] == 'owner'),
      pin: json['pin']?.toString(),
      hasActiveSubscription: json['hasActiveSubscription'] ?? false,
      subscriptionPlan: json['subscriptionPlan'],
      subscriptionStartDate: json['subscriptionStartDate'] != null
          ? parseDateTime(json['subscriptionStartDate'])
          : null,
      subscriptionEndDate: json['subscriptionEndDate'] != null
          ? parseDateTime(json['subscriptionEndDate'])
          : null,
      subscriptionPaymentRequired: json['subscriptionPaymentRequired'] ?? true,
      subscriptionTransactionId: json['subscriptionTransactionId'],
      subscriptionAmount: (json['subscriptionAmount'] as num?)?.toDouble(),
      referralEmail: json['referralEmail']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'photoUrl': photoUrl,
      'role': role,
      'phoneNumber': phoneNumber,
      // Keep legacy `businessId` for backward compatibility but populate it from primaryBusinessId
      'businessId': primaryBusinessId,
      'businessIds': businessIds,
      'currentBusinessId': currentBusinessId,
      'businessType': businessType,
      'storeId': storeId,
      'preferredBusinessId': preferredBusinessId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
      'isOwner': isOwner,
      'hasActiveSubscription': hasActiveSubscription,
      'pin': pin,
      'subscriptionPlan': subscriptionPlan,
      'subscriptionStartDate': subscriptionStartDate?.toIso8601String(),
      'subscriptionEndDate': subscriptionEndDate?.toIso8601String(),
      'subscriptionPaymentRequired': subscriptionPaymentRequired,
      'subscriptionTransactionId': subscriptionTransactionId,
      'subscriptionAmount': subscriptionAmount,
      'referralEmail': referralEmail,
    };
  }

  // Copy with method for immutable updates
  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? photoUrl,
    String? role,
    String? phoneNumber,
    String? businessId,
    List<String>? businessIds,
    String? currentBusinessId,
    String? businessType,
    String? storeId,
    String? preferredBusinessId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? isOwner,
    bool? hasActiveSubscription,
    String? subscriptionPlan,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    bool? subscriptionPaymentRequired,
    String? subscriptionTransactionId,
    double? subscriptionAmount,
    String? pin,
    String? referralEmail,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      businessId: businessId ?? this.businessId,
      businessIds: businessIds ?? this.businessIds,
      currentBusinessId: currentBusinessId ?? this.currentBusinessId,
      businessType: businessType ?? this.businessType,
      storeId: storeId ?? this.storeId,
      preferredBusinessId: preferredBusinessId ?? this.preferredBusinessId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      isOwner: isOwner ?? this.isOwner,
      pin: pin ?? this.pin,
      hasActiveSubscription:
          hasActiveSubscription ?? this.hasActiveSubscription,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionStartDate:
          subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      subscriptionPaymentRequired:
          subscriptionPaymentRequired ?? this.subscriptionPaymentRequired,
      subscriptionTransactionId:
          subscriptionTransactionId ?? this.subscriptionTransactionId,
      subscriptionAmount: subscriptionAmount ?? this.subscriptionAmount,
      referralEmail: referralEmail ?? this.referralEmail,
    );
  }
}

