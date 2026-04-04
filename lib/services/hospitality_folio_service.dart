import 'package:cloud_firestore/cloud_firestore.dart';

class HospitalityFolioCharge {
  final String id;
  final String businessId;
  final String reservationId;
  final String roomId;
  final String roomNumber;
  final String description;
  final String category;
  final double amount;
  final String source;
  final String? sourceOrderId;
  final String? createdById;
  final String? createdByName;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const HospitalityFolioCharge({
    required this.id,
    required this.businessId,
    required this.reservationId,
    required this.roomId,
    required this.roomNumber,
    required this.description,
    required this.category,
    required this.amount,
    required this.source,
    this.sourceOrderId,
    this.createdById,
    this.createdByName,
    required this.createdAt,
    this.metadata = const {},
  });

  factory HospitalityFolioCharge.fromJson(Map<String, dynamic> json) {
    DateTime createdAt;
    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return HospitalityFolioCharge(
      id: (json['id'] ?? '').toString(),
      businessId: (json['businessId'] ?? '').toString(),
      reservationId: (json['reservationId'] ?? '').toString(),
      roomId: (json['roomId'] ?? '').toString(),
      roomNumber: (json['roomNumber'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? 'extra').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      source: (json['source'] ?? 'manual').toString(),
      sourceOrderId: json['sourceOrderId']?.toString(),
      createdById: json['createdById']?.toString(),
      createdByName: json['createdByName']?.toString(),
      createdAt: createdAt,
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'reservationId': reservationId,
      'roomId': roomId,
      'roomNumber': roomNumber,
      'description': description,
      'category': category,
      'amount': amount,
      'source': source,
      'sourceOrderId': sourceOrderId,
      'createdById': createdById,
      'createdByName': createdByName,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class HospitalityFolioService {
  HospitalityFolioService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _chargesRef(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('hotel_folio_charges');
  }

  Future<List<HospitalityFolioCharge>> fetchCharges(String businessId) async {
    if (businessId.isEmpty) return const [];

    final snapshot = await _chargesRef(businessId).get();
    final charges = snapshot.docs
        .map((doc) => HospitalityFolioCharge.fromJson({
              ...doc.data(),
              'id': doc.id,
            }))
        .toList();
    charges.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return charges;
  }

  Future<HospitalityFolioCharge> addCharge({
    required String businessId,
    required String reservationId,
    required String roomId,
    required String roomNumber,
    required String description,
    required double amount,
    String category = 'extra',
    String source = 'manual',
    String? sourceOrderId,
    String? createdById,
    String? createdByName,
    Map<String, dynamic> metadata = const {},
  }) async {
    final docRef = _chargesRef(businessId).doc();
    final charge = HospitalityFolioCharge(
      id: docRef.id,
      businessId: businessId,
      reservationId: reservationId,
      roomId: roomId,
      roomNumber: roomNumber,
      description: description,
      category: category,
      amount: amount,
      source: source,
      sourceOrderId: sourceOrderId,
      createdById: createdById,
      createdByName: createdByName,
      createdAt: DateTime.now(),
      metadata: metadata,
    );

    await docRef.set({
      ...charge.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return charge;
  }
}
