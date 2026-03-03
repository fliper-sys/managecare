// lib/data/models/gym_model.dart
// Data model representing a Gym / Fitness Business

class GymModel {
  final String id;
  final String name;
  final String ownerName;
  final String description;
  final String address;
  final String phone;
  final String email;
  final double? latitude;
  final double? longitude;
  final List<String> images;
  final List<String> facilities;
  final List<MembershipOptionModel> memberships;
  final Map<String, String>
      openingHours; // e.g. { "mon": "06:00-22:00", "sun": "08:00-20:00" }
  final bool isActive;
  final double rating;
  final int reviewsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? taxId;
  final String? licenseNumber;

  GymModel({
    required this.id,
    required this.name,
    required this.ownerName,
    this.description = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.latitude,
    this.longitude,
    List<String>? images,
    List<String>? facilities,
    List<MembershipOptionModel>? memberships,
    Map<String, String>? openingHours,
    this.isActive = true,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.createdAt,
    this.updatedAt,
    this.taxId,
    this.licenseNumber,
  })  : images = images ?? const [],
        facilities = facilities ?? const [],
        memberships = memberships ?? const [],
        openingHours = openingHours ?? const {};

  GymModel copyWith({
    String? id,
    String? name,
    String? ownerName,
    String? description,
    String? address,
    String? phone,
    String? email,
    double? latitude,
    double? longitude,
    List<String>? images,
    List<String>? facilities,
    List<MembershipOptionModel>? memberships,
    Map<String, String>? openingHours,
    bool? isActive,
    double? rating,
    int? reviewsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? taxId,
    String? licenseNumber,
  }) {
    return GymModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      description: description ?? this.description,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      images: images ?? List<String>.from(this.images),
      facilities: facilities ?? List<String>.from(this.facilities),
      memberships:
          memberships ?? List<MembershipOptionModel>.from(this.memberships),
      openingHours: openingHours ?? Map<String, String>.from(this.openingHours),
      isActive: isActive ?? this.isActive,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      taxId: taxId ?? this.taxId,
      licenseNumber: licenseNumber ?? this.licenseNumber,
    );
  }

  factory GymModel.fromJson(Map<String, dynamic> json) {
    return GymModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      ownerName: json['ownerName'] ?? json['owner_name'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      images: _listFromJsonString(json['images']),
      facilities: _listFromJsonString(json['facilities']),
      memberships: (json['memberships'] as List<dynamic>?)
              ?.map((e) =>
                  MembershipOptionModel.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      openingHours: (json['openingHours'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v?.toString() ?? '')) ??
          {},
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      rating: _toDouble(json['rating']) ?? 0.0,
      reviewsCount: (json['reviewsCount'] ?? json['reviews_count'] ?? 0) as int,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
      taxId: json['taxId'] ?? json['tax_id'],
      licenseNumber: json['licenseNumber'] ?? json['license_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ownerName': ownerName,
      'description': description,
      'address': address,
      'phone': phone,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
      'images': images,
      'facilities': facilities,
      'memberships': memberships.map((m) => m.toJson()).toList(),
      'openingHours': openingHours,
      'isActive': isActive,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'taxId': taxId,
      'licenseNumber': licenseNumber,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static List<String> _listFromJsonString(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e?.toString() ?? '').toList();
    if (value is String) {
      // assume comma separated
      return value
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }
}

class MembershipOptionModel {
  final String id;
  final String name;
  final int durationDays;
  final double price;
  final List<String> features;

  MembershipOptionModel({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.price,
    List<String>? features,
  }) : features = features ?? const [];

  MembershipOptionModel copyWith({
    String? id,
    String? name,
    int? durationDays,
    double? price,
    List<String>? features,
  }) {
    return MembershipOptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      durationDays: durationDays ?? this.durationDays,
      price: price ?? this.price,
      features: features ?? List<String>.from(this.features),
    );
  }

  factory MembershipOptionModel.fromJson(Map<String, dynamic> json) {
    return MembershipOptionModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      durationDays: (json['durationDays'] ?? json['duration_days'] ?? 0) as int,
      price: GymModel._toDouble(json['price']) ?? 0.0,
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'durationDays': durationDays,
      'price': price,
      'features': features,
    };
  }
}

class MemberSubscriptionModel {
  final String planId;
  final DateTime? expiry;

  MemberSubscriptionModel({required this.planId, this.expiry});

  MemberSubscriptionModel copyWith({String? planId, DateTime? expiry}) {
    return MemberSubscriptionModel(
      planId: planId ?? this.planId,
      expiry: expiry ?? this.expiry,
    );
  }

  factory MemberSubscriptionModel.fromJson(Map<String, dynamic> json) {
    return MemberSubscriptionModel(
      planId: json['planId']?.toString() ?? json['plan_id']?.toString() ?? '',
      expiry: GymModel._parseDate(
          json['expiry'] ?? json['expiry_at'] ?? json['expiryDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'expiry': expiry?.toIso8601String(),
    };
  }
}

class PaymentRecord {
  final String id;
  final String memberId;
  final double amount;
  final String currency;
  final String method; // e.g., cash, card, stripe
  final DateTime timestamp;
  final String? note;
  final String? planId;

  PaymentRecord({
    required this.id,
    required this.memberId,
    required this.amount,
    this.currency = 'USD',
    this.method = 'cash',
    DateTime? timestamp,
    this.note,
    this.planId,
  }) : timestamp = timestamp ?? DateTime.now();

  PaymentRecord copyWith({
    String? id,
    String? memberId,
    double? amount,
    String? currency,
    String? method,
    DateTime? timestamp,
    String? note,
    String? planId,
  }) {
    return PaymentRecord(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      method: method ?? this.method,
      timestamp: timestamp ?? this.timestamp,
      note: note ?? this.note,
      planId: planId ?? this.planId,
    );
  }

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id']?.toString() ?? json['paymentId']?.toString() ?? '',
      memberId:
          json['memberId']?.toString() ?? json['member_id']?.toString() ?? '',
      amount: GymModel._toDouble(json['amount']) ?? 0.0,
      currency: json['currency']?.toString() ?? 'USD',
      method: json['method']?.toString() ?? 'cash',
      timestamp: GymModel._parseDate(json['timestamp'] ?? json['createdAt']) ??
          DateTime.now(),
      note: json['note']?.toString(),
      planId: json['planId']?.toString() ?? json['plan_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'amount': amount,
      'currency': currency,
      'method': method,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
      'planId': planId,
    };
  }
}

