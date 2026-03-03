import 'package:cloud_firestore/cloud_firestore.dart';

import 'agri_repository.dart';

class AgriFirestoreRepository implements AgriRepository {
  final FirebaseFirestore _firestore;

  AgriFirestoreRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> addCrop(Map<String, dynamic> crop) async {
    // Example: store under agriculture/crops
    await _firestore.collection('agriculture').add(crop);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFarms(String businessId) async {
    final snap = await _firestore
        .collection('businesses/$businessId/farms')
        .orderBy('name')
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchInputs(String businessId) async {
    final snap =
        await _firestore.collection('businesses/$businessId/inputs').get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  @override
  Future<void> saveHint(
      String businessId, String farmId, Map<String, dynamic> hint) async {
    await _firestore.collection('businesses/$businessId/hints').add(hint);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchHints(String businessId,
      {String? farmId}) async {
    final q = _firestore
        .collection('businesses/$businessId/hints')
        .orderBy('date', descending: true);
    final snap = await q.get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  // Livestock persistence
  @override
  Future<void> saveLivestockGroup(
      String businessId, Map<String, dynamic> group) async {
    final id = group['id'] as String?;
    if (id == null || id.isEmpty) {
      await _firestore
          .collection('businesses/$businessId/livestock')
          .add(group);
    } else {
      await _firestore
          .collection('businesses/$businessId/livestock')
          .doc(id)
          .set(group, SetOptions(merge: true));
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLivestockGroups(
      String businessId) async {
    final snap = await _firestore
        .collection('businesses/$businessId/livestock')
        .orderBy('name')
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  @override
  Future<void> deleteLivestockGroup(String businessId, String groupId) async {
    await _firestore
        .collection('businesses/$businessId/livestock')
        .doc(groupId)
        .delete();
  }
  
  @override
  Future<void> deleteFarm(String businessId, String farmId) async {
    await _firestore
        .collection('businesses/$businessId/farms')
        .doc(farmId)
        .delete();
  }
  
  @override
  Future<void> saveFarm(String businessId, Map<String, dynamic> farm) async {
    final id = farm['id'] as String?;
    if (id == null || id.isEmpty) {
      await _firestore
          .collection('businesses/$businessId/farms')
          .add(farm);
    } else {
      await _firestore
          .collection('businesses/$businessId/farms')
          .doc(id)
          .set(farm, SetOptions(merge: true));
    }
  }
}

