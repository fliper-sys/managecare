import 'package:cloud_firestore/cloud_firestore.dart';

class Apartment {
  final String id;
  final String title;
  final String description;
  final String ownerId;
  final String address;
  final List<String> photos;
  final List<String> amenities;
  final String? defaultCancellationPolicyId;
  final Timestamp? createdAt;

  Apartment({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerId,
    required this.address,
    this.photos = const [],
    this.amenities = const [],
    this.defaultCancellationPolicyId,
    this.createdAt,
  });

  factory Apartment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Apartment(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      ownerId: data['ownerId'] ?? '',
      address: data['address'] ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      amenities: List<String>.from(data['amenities'] ?? []),
      defaultCancellationPolicyId: data['defaultCancellationPolicyId'],
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'ownerId': ownerId,
      'address': address,
      'photos': photos,
      'amenities': amenities,
      'defaultCancellationPolicyId': defaultCancellationPolicyId,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
