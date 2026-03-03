import 'package:cloud_firestore/cloud_firestore.dart';
import 'real_estate_repository.dart';

class RealEstateRepositoryImpl implements RealEstateRepository {
  final FirebaseFirestore firestore;

  RealEstateRepositoryImpl({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _props(String businessId) => firestore
      .collection('businesses')
      .doc(businessId)
      .collection('real_estate_properties');
  CollectionReference _owners(String businessId) => firestore
      .collection('businesses')
      .doc(businessId)
      .collection('real_estate_owners');
  CollectionReference _bookings(String businessId) => firestore
      .collection('businesses')
      .doc(businessId)
      .collection('real_estate_bookings');
  CollectionReference _payments(String businessId) => firestore
      .collection('businesses')
      .doc(businessId)
      .collection('real_estate_payments');
  CollectionReference _documents(String businessId) => firestore
      .collection('businesses')
      .doc(businessId)
      .collection('real_estate_documents');
  CollectionReference _escrows(String businessId) => firestore
      .collection('businesses')
      .doc(businessId)
      .collection('real_estate_escrows');
  CollectionReference _inventory(String businessId) => firestore
      .collection('businesses')
      .doc(businessId)
      .collection('real_estate_inventory');

  @override
  Future<void> deleteProperty(String businessId, String id) async {
    await _props(businessId).doc(id).delete();
  }

  @override
  Future<Map<String, dynamic>> fetchPropertyById(
      String businessId, String id) async {
    final doc = await _props(businessId).doc(id).get();
    if (!doc.exists) return {};
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return data;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProperties(String businessId) async {
    final snap =
        await _props(businessId).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) {
      final m = d.data() as Map<String, dynamic>;
      m['id'] = d.id;
      return m;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> saveProperty(
      String businessId, Map<String, dynamic> property) async {
    final id = property['id'] as String?;
    final copy = Map<String, dynamic>.from(property);
    copy['updatedAt'] = DateTime.now().toIso8601String();
    if (id == null || id.isEmpty) {
      copy['createdAt'] = DateTime.now().toIso8601String();
      final doc = await _props(businessId).add(copy);
      copy['id'] = doc.id;
      return copy;
    } else {
      await _props(businessId).doc(id).set(copy, SetOptions(merge: true));
      return copy;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOwners(String businessId) async {
    final snap = await _owners(businessId).orderBy('name').get();
    return snap.docs.map((d) {
      final m = d.data() as Map<String, dynamic>;
      m['id'] = d.id;
      return m;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> saveOwner(
      String businessId, Map<String, dynamic> owner) async {
    final id = owner['id'] as String?;
    final copy = Map<String, dynamic>.from(owner);
    if (id == null || id.isEmpty) {
      final doc = await _owners(businessId).add(copy);
      copy['id'] = doc.id;
      return copy;
    } else {
      await _owners(businessId).doc(id).set(copy, SetOptions(merge: true));
      return copy;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBookings(String businessId) async {
    final snap =
        await _bookings(businessId).orderBy('startAt', descending: true).get();
    return snap.docs.map((d) {
      final m = d.data() as Map<String, dynamic>;
      m['id'] = d.id;
      return m;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> saveBooking(
      String businessId, Map<String, dynamic> booking) async {
    final id = booking['id'] as String?;
    final copy = Map<String, dynamic>.from(booking);
    copy['updatedAt'] = DateTime.now().toIso8601String();
    if (id == null || id.isEmpty) {
      copy['createdAt'] = DateTime.now().toIso8601String();
      final doc = await _bookings(businessId).add(copy);
      copy['id'] = doc.id;
      return copy;
    } else {
      await _bookings(businessId).doc(id).set(copy, SetOptions(merge: true));
      return copy;
    }
  }

  @override
  Future<void> deleteBooking(String businessId, String id) async {
    await _bookings(businessId).doc(id).delete();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPayments(String businessId) async {
    final snap = await _payments(businessId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) {
      final m = d.data() as Map<String, dynamic>;
      m['id'] = d.id;
      return m;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> savePayment(
      String businessId, Map<String, dynamic> payment) async {
    final copy = Map<String, dynamic>.from(payment);
    copy['createdAt'] = DateTime.now().toIso8601String();
    final doc = await _payments(businessId).add(copy);
    copy['id'] = doc.id;
    return copy;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDocuments(String businessId,
      {String? propertyId}) async {
    Query q = _documents(businessId);
    if (propertyId != null && propertyId.isNotEmpty) {
      q = q.where('propertyId', isEqualTo: propertyId);
    }
    final snap = await q.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) {
      final m = d.data() as Map<String, dynamic>;
      m['id'] = d.id;
      return m;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> saveDocument(
      String businessId, Map<String, dynamic> document) async {
    final copy = Map<String, dynamic>.from(document);
    copy['createdAt'] = DateTime.now().toIso8601String();
    final doc = await _documents(businessId).add(copy);
    copy['id'] = doc.id;
    return copy;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEscrows(String businessId) async {
    final snap =
        await _escrows(businessId).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) {
      final m = d.data() as Map<String, dynamic>;
      m['id'] = d.id;
      return m;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> saveEscrow(
      String businessId, Map<String, dynamic> escrow) async {
    final id = escrow['id'] as String?;
    final copy = Map<String, dynamic>.from(escrow);
    copy['updatedAt'] = DateTime.now().toIso8601String();
    if (id == null || id.isEmpty) {
      copy['createdAt'] = DateTime.now().toIso8601String();
      final doc = await _escrows(businessId).add(copy);
      copy['id'] = doc.id;
      return copy;
    } else {
      await _escrows(businessId).doc(id).set(copy, SetOptions(merge: true));
      return copy;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchInventory(String businessId) async {
    final snap = await _inventory(businessId).orderBy('name').get();
    return snap.docs.map((d) {
      final m = d.data() as Map<String, dynamic>;
      m['id'] = d.id;
      return m;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> saveInventoryItem(
      String businessId, Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    final copy = Map<String, dynamic>.from(item);
    if (id == null || id.isEmpty) {
      final doc = await _inventory(businessId).add(copy);
      copy['id'] = doc.id;
      return copy;
    } else {
      await _inventory(businessId).doc(id).set(copy, SetOptions(merge: true));
      return copy;
    }
  }

  @override
  Future<void> deleteInventoryItem(String businessId, String id) async {
    await _inventory(businessId).doc(id).delete();
  }
}

