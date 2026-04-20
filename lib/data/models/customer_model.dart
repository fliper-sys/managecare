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

  factory CustomerModel.fromJson(
    Map<String, dynamic> json, {
    String? documentId,
  }) {
    final now = DateTime.now();
    final totalSpent = _readDouble(
          json['totalSpent'] ?? json['totalPurchases'],
        ) ??
        0.0;
    final totalTransactions = _readInt(
          json['totalTransactions'] ?? json['totalOrders'],
        ) ??
        0;
    final createdAt = _readDateTime(json['createdAt']) ?? now;
    final updatedAt = _readDateTime(json['updatedAt']) ?? createdAt;
    final firstPurchaseDate =
        _readDateTime(json['firstPurchaseDate']) ?? createdAt;
    final lastPurchaseDate =
        _readDateTime(json['lastPurchaseDate']) ?? updatedAt;

    return CustomerModel(
      id: _readString(json['id']) ??
          _readString(json['customerId']) ??
          documentId ??
          '',
      businessId: _readString(json['businessId']) ?? '',
      name: _readString(json['name']) ??
          _readString(json['fullName']) ??
          _readString(json['displayName']) ??
          '',
      email: _readNullableString(json['email']),
      phone:
          _readNullableString(json['phone']) ?? _readNullableString(json['phoneNumber']),
      address: _readNullableString(json['address']),
      city: _readNullableString(json['city']),
      state: _readNullableString(json['state']),
      totalSpent: totalSpent,
      totalTransactions: totalTransactions,
      averageOrderValue: _readDouble(json['averageOrderValue']) ??
          (totalTransactions > 0 ? totalSpent / totalTransactions : 0.0),
      firstPurchaseDate: firstPurchaseDate,
      lastPurchaseDate: lastPurchaseDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isActive: _readBool(json['isActive']) ?? true,
      notes: _readNullableString(json['notes']),
    );
  }

  factory CustomerModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return CustomerModel.fromJson(
      doc.data() ?? const <String, dynamic>{},
      documentId: doc.id,
    );
  }

  Map<String, dynamic> toJson({Map<String, dynamic>? additionalFields}) {
    final payload = <String, dynamic>{
      'id': id,
      'customerId': id,
      'businessId': businessId,
      'name': name,
      'fullName': name,
      'email': email,
      'phone': phone,
      'phoneNumber': phone,
      'address': address,
      'city': city,
      'state': state,
      'totalSpent': totalSpent,
      'totalPurchases': totalSpent,
      'totalTransactions': totalTransactions,
      'totalOrders': totalTransactions,
      'averageOrderValue': averageOrderValue,
      'firstPurchaseDate': firstPurchaseDate,
      'lastPurchaseDate': lastPurchaseDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isActive': isActive,
      'notes': notes,
    };

    if (additionalFields != null && additionalFields.isNotEmpty) {
      payload.addAll(additionalFields);
      payload['id'] = id;
      payload['customerId'] = id;
      payload['businessId'] = businessId;
      payload['name'] = name;
      payload['fullName'] = name;
      payload['email'] = email;
      payload['phone'] = phone;
      payload['phoneNumber'] = phone;
      payload['address'] = address;
      payload['city'] = city;
      payload['state'] = state;
      payload['totalSpent'] = totalSpent;
      payload['totalPurchases'] = totalSpent;
      payload['totalTransactions'] = totalTransactions;
      payload['totalOrders'] = totalTransactions;
      payload['averageOrderValue'] = averageOrderValue;
      payload['firstPurchaseDate'] = firstPurchaseDate;
      payload['lastPurchaseDate'] = lastPurchaseDate;
      payload['createdAt'] = createdAt;
      payload['updatedAt'] = updatedAt;
      payload['isActive'] = isActive;
      payload['notes'] = notes;
    }

    return payload;
  }

  static Map<String, dynamic> normalizeFirestoreData(
    Map<String, dynamic> rawData, {
    String? documentId,
  }) {
    final source = Map<String, dynamic>.from(rawData);
    final model = CustomerModel.fromJson(source, documentId: documentId);
    return model.toJson(additionalFields: source);
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  static String? _readNullableString(dynamic value) => _readString(value);

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool? _readBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return null;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.tryParse(value.toString());
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

