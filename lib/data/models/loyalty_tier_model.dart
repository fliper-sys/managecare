import 'package:cloud_firestore/cloud_firestore.dart';

class LoyaltyTier {
  final String id;
  final String name;
  final int pointsRequired;
  final double discountPercentage;
  final List<String> benefits;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  LoyaltyTier({
    required this.id,
    required this.name,
    required this.pointsRequired,
    required this.discountPercentage,
    required this.benefits,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LoyaltyTier.fromJson(Map<String, dynamic> json) {
    return LoyaltyTier(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pointsRequired: json['pointsRequired'] as int? ?? 0,
      discountPercentage:
          (json['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      benefits: List<String>.from(json['benefits'] as List? ?? []),
      color: json['color'] as String? ?? '#FFFFFF',
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
      'name': name,
      'pointsRequired': pointsRequired,
      'discountPercentage': discountPercentage,
      'benefits': benefits,
      'color': color,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  LoyaltyTier copyWith({
    String? id,
    String? name,
    int? pointsRequired,
    double? discountPercentage,
    List<String>? benefits,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LoyaltyTier(
      id: id ?? this.id,
      name: name ?? this.name,
      pointsRequired: pointsRequired ?? this.pointsRequired,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      benefits: benefits ?? this.benefits,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

