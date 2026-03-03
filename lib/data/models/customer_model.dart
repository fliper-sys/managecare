import 'package:cloud_firestore/cloud_firestore.dart';

/// Customer model
class CustomerModel {
  final String id;
  final String businessId;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? state;
  final double totalSpent;
  final int totalTransactions;
  final double averageOrderValue;
  final DateTime firstPurchaseDate;
  final DateTime lastPurchaseDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? notes;

  CustomerModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.state,
    required this.totalSpent,
    required this.totalTransactions,
    required this.averageOrderValue,
    required this.firstPurchaseDate,
    required this.lastPurchaseDate,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    this.notes,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] ?? '',
      businessId: json['businessId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      address: json['address'],
      city: json['city'],
      state: json['state'],
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: json['totalTransactions'] ?? 0,
      averageOrderValue: (json['averageOrderValue'] as num?)?.toDouble() ?? 0.0,
      firstPurchaseDate: json['firstPurchaseDate'] is Timestamp
          ? (json['firstPurchaseDate'] as Timestamp).toDate()
          : json['firstPurchaseDate'] is DateTime
              ? json['firstPurchaseDate']
              : DateTime.parse(json['firstPurchaseDate'] ??
                  DateTime.now().toIso8601String()),
      lastPurchaseDate: json['lastPurchaseDate'] is Timestamp
          ? (json['lastPurchaseDate'] as Timestamp).toDate()
          : json['lastPurchaseDate'] is DateTime
              ? json['lastPurchaseDate']
              : DateTime.parse(
                  json['lastPurchaseDate'] ?? DateTime.now().toIso8601String()),
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : json['createdAt'] is DateTime
              ? json['createdAt']
              : DateTime.parse(
                  json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : json['updatedAt'] is DateTime
              ? json['updatedAt']
              : DateTime.parse(
                  json['updatedAt'] ?? DateTime.now().toIso8601String()),
      isActive: json['isActive'] ?? true,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'totalSpent': totalSpent,
      'totalTransactions': totalTransactions,
      'averageOrderValue': averageOrderValue,
      'firstPurchaseDate': firstPurchaseDate,
      'lastPurchaseDate': lastPurchaseDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isActive': isActive,
      'notes': notes,
    };
  }

  /// Copy with
  CustomerModel copyWith({
    String? id,
    String? businessId,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    double? totalSpent,
    int? totalTransactions,
    double? averageOrderValue,
    DateTime? firstPurchaseDate,
    DateTime? lastPurchaseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? notes,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      totalSpent: totalSpent ?? this.totalSpent,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      averageOrderValue: averageOrderValue ?? this.averageOrderValue,
      firstPurchaseDate: firstPurchaseDate ?? this.firstPurchaseDate,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }
}

