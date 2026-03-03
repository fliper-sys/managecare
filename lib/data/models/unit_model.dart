import 'package:cloud_firestore/cloud_firestore.dart';

class Unit {
  final String id;
  final String name; // e.g., Unit 101
  final int capacity;
  final double pricePerNight;
  final Timestamp? availableFrom;
  final Timestamp? availableTo;
  final List<String> photos;
  final bool active;

  Unit({
    required this.id,
    required this.name,
    required this.capacity,
    required this.pricePerNight,
    this.availableFrom,
    this.availableTo,
    this.photos = const [],
    this.active = true,
  });

  factory Unit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Unit(
      id: doc.id,
      name: data['name'] ?? '',
      capacity: (data['capacity'] ?? 1) as int,
      pricePerNight: (data['pricePerNight'] ?? 0.0).toDouble(),
      availableFrom: data['availableFrom'],
      availableTo: data['availableTo'],
      photos: List<String>.from(data['photos'] ?? []),
      active: data['active'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'capacity': capacity,
      'pricePerNight': pricePerNight,
      'availableFrom': availableFrom,
      'availableTo': availableTo,
      'photos': photos,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
