import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessModel {
  final String id;
  final String name;
  final String
      businessType; // pharmacy, retail, agri, auto, salon, hotel, drink, restaurant, realestate
  final String? description;
  final String ownerId;
  final String? logoUrl;
  final String? photoUrl; // Business profile/avatar photo
  final String? currency;
  final String? taxId;
  final double? taxRate;

  // Contact Information
  final String? email;
  final String? phone;
  final String? website;

  // Address
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final GeoPoint? location;

  // Subscription
  final String subscriptionTier; // free, basic, professional, enterprise
  final String businessClass; // tier1, tier2, tier3 (new)
  final String? subscriptionPlan; // specific plan id (e.g., basic_monthly)
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final bool isSubscriptionActive;

  // Settings
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? industrySpecificSettings;

  // Status
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Statistics (optional, can be calculated)
  final int? totalWorkers;
  final int? totalProducts;
  final int? totalCustomers;

  BusinessModel({
    required this.id,
    required this.name,
    required this.businessType,
    this.description,
    required this.ownerId,
    this.logoUrl,
    this.photoUrl,
    this.currency = 'NGN',
    this.taxId,
    this.taxRate = 0.0,
    this.email,
    this.phone,
    this.website,
    this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.location,
    this.subscriptionTier = 'free',
    this.businessClass = 'tier1',
    this.subscriptionPlan,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.isSubscriptionActive = true,
    this.settings,
    this.industrySpecificSettings,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.totalWorkers,
    this.totalProducts,
    this.totalCustomers,
  });

  factory BusinessModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessModel(
      id: doc.id,
      name: data['name'] ?? '',
      businessType: data['businessType'] ?? '',
      description: data['description'],
      ownerId: data['ownerId'] ?? '',
      logoUrl: data['logoUrl'],
      photoUrl: data['photoUrl'],
      currency: data['currency'] ?? 'NGN',
      taxId: data['taxId'],
      taxRate: data['taxRate']?.toDouble() ?? 0.0,
      email: data['email'],
      phone: data['phone'],
      website: data['website'],
      address: data['address'],
      city: data['city'],
      state: data['state'],
      country: data['country'],
      postalCode: data['postalCode'],
      location: data['location'],
      subscriptionTier: data['subscriptionTier'] ?? 'free',
      businessClass: data['businessClass'] ?? 'tier1',
      subscriptionPlan: data['subscriptionPlan'],
      subscriptionStartDate: _parseFirestoreDate(data['subscriptionStartDate']),
      subscriptionEndDate: _parseFirestoreDate(data['subscriptionEndDate']),
      isSubscriptionActive: data['isSubscriptionActive'] ?? true,
      settings: data['settings'],
      industrySpecificSettings: data['industrySpecificSettings'],
      isActive: data['isActive'] ?? true,
      createdAt: _parseFirestoreDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseFirestoreDate(data['updatedAt']),
      totalWorkers: data['totalWorkers'],
      totalProducts: data['totalProducts'],
      totalCustomers: data['totalCustomers'],
    );
  }

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      businessType: json['businessType'] ?? '',
      description: json['description'],
      ownerId: json['ownerId'] ?? '',
      logoUrl: json['logoUrl'],
      photoUrl: json['photoUrl'],
      currency: json['currency'] ?? 'NGN',
      taxId: json['taxId'],
      taxRate: json['taxRate']?.toDouble() ?? 0.0,
      email: json['email'],
      phone: json['phone'],
      website: json['website'],
      address: json['address'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      postalCode: json['postalCode'],
      location: json['location'],
      subscriptionTier: json['subscriptionTier'] ?? 'free',
      businessClass: json['businessClass'] ?? 'tier1',
      subscriptionPlan: json['subscriptionPlan'],
      subscriptionStartDate: json['subscriptionStartDate'] != null
          ? DateTime.parse(json['subscriptionStartDate'])
          : null,
      subscriptionEndDate: json['subscriptionEndDate'] != null
          ? DateTime.parse(json['subscriptionEndDate'])
          : null,
      isSubscriptionActive: json['isSubscriptionActive'] ?? true,
      settings: json['settings'],
      industrySpecificSettings: json['industrySpecificSettings'],
      isActive: json['isActive'] ?? true,
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      totalWorkers: json['totalWorkers'],
      totalProducts: json['totalProducts'],
      totalCustomers: json['totalCustomers'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'businessType': businessType,
      'description': description,
      'ownerId': ownerId,
      'logoUrl': logoUrl,
      'photoUrl': photoUrl,
      'currency': currency,
      'taxId': taxId,
      'taxRate': taxRate,
      'email': email,
      'phone': phone,
      'website': website,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'location': location,
      'subscriptionTier': subscriptionTier,
      'subscriptionPlan': subscriptionPlan,
      'businessClass': businessClass,
      'subscriptionStartDate': subscriptionStartDate?.toIso8601String(),
      'subscriptionEndDate': subscriptionEndDate?.toIso8601String(),
      'isSubscriptionActive': isSubscriptionActive,
      'settings': settings,
      'industrySpecificSettings': industrySpecificSettings,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'totalWorkers': totalWorkers,
      'totalProducts': totalProducts,
      'totalCustomers': totalCustomers,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'businessType': businessType,
      'description': description,
      'ownerId': ownerId,
      'logoUrl': logoUrl,
      'photoUrl': photoUrl,
      'currency': currency,
      'taxId': taxId,
      'taxRate': taxRate,
      'email': email,
      'phone': phone,
      'website': website,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'location': location,
      'subscriptionTier': subscriptionTier,
      'subscriptionPlan': subscriptionPlan,
      'businessClass': businessClass,
      'subscriptionStartDate': subscriptionStartDate != null
          ? Timestamp.fromDate(subscriptionStartDate!)
          : null,
      'subscriptionEndDate': subscriptionEndDate != null
          ? Timestamp.fromDate(subscriptionEndDate!)
          : null,
      'isSubscriptionActive': isSubscriptionActive,
      'settings': settings,
      'industrySpecificSettings': industrySpecificSettings,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'totalWorkers': totalWorkers,
      'totalProducts': totalProducts,
      'totalCustomers': totalCustomers,
    };
  }

  // helper to parse Timestamp/String/int/double into DateTime
  // Accepts Firestore Timestamp, ISO-8601 string, or numeric milliseconds since epoch
  static DateTime? _parseFirestoreDate(dynamic v) {
    try {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is Timestamp) return v.toDate();
      if (v is String) {
        // Some documents may incorrectly store ISO strings; attempt to parse
        try {
          return DateTime.parse(v);
        } catch (e) {
          // Fallthrough to attempt numeric conversion
        }
      }
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      // last-resort: if map with seconds/nanoseconds (server timestamp shape)
      if (v is Map) {
        if (v.containsKey('_seconds') || v.containsKey('seconds')) {
          final seconds = v['_seconds'] ?? v['seconds'];
          final nanos = v['_nanoseconds'] ?? v['nanoseconds'] ?? 0;
          final millis = (seconds as int) * 1000 + ((nanos as int) ~/ 1000000);
          return DateTime.fromMillisecondsSinceEpoch(millis);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  BusinessModel copyWith({
    String? id,
    String? name,
    String? businessType,
    String? description,
    String? ownerId,
    String? logoUrl,
    String? photoUrl,
    String? currency,
    String? taxId,
    double? taxRate,
    String? email,
    String? phone,
    String? website,
    String? address,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    GeoPoint? location,
    String? subscriptionTier,
    String? businessClass,
    String? subscriptionPlan,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    bool? isSubscriptionActive,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? industrySpecificSettings,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalWorkers,
    int? totalProducts,
    int? totalCustomers,
  }) {
    return BusinessModel(
      id: id ?? this.id,
      name: name ?? this.name,
      businessType: businessType ?? this.businessType,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      logoUrl: logoUrl ?? this.logoUrl,
      photoUrl: photoUrl ?? this.photoUrl,
      currency: currency ?? this.currency,
      taxId: taxId ?? this.taxId,
      taxRate: taxRate ?? this.taxRate,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      location: location ?? this.location,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      businessClass: businessClass ?? this.businessClass,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionStartDate:
          subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      isSubscriptionActive: isSubscriptionActive ?? this.isSubscriptionActive,
      settings: settings ?? this.settings,
      industrySpecificSettings:
          industrySpecificSettings ?? this.industrySpecificSettings,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalWorkers: totalWorkers ?? this.totalWorkers,
      totalProducts: totalProducts ?? this.totalProducts,
      totalCustomers: totalCustomers ?? this.totalCustomers,
    );
  }

  String get fullAddress {
    final parts = [address, city, state, country, postalCode]
        .where((part) => part != null && part.isNotEmpty);
    return parts.join(', ');
  }

  @override
  String toString() {
    return 'BusinessModel(id: $id, name: $name, type: $businessType)';
  }
}

