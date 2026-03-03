import 'package:cloud_firestore/cloud_firestore.dart';

import 'agri_repository.dart';

class AgriRepositoryImpl implements AgriRepository {
  final String businessId;
  final FirebaseFirestore _fs;

  AgriRepositoryImpl({required this.businessId})
      : _fs = FirebaseFirestore.instance;

  CollectionReference _col(String name) =>
      _fs.collection('businesses').doc(businessId).collection(name);

  @override
  Future<void> addCrop(Map<String, dynamic> crop) async {
    // Use Firestore server timestamp so stored types are consistent (Timestamp)
    await _col('agri_crops').add({...crop, 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFarms(String businessId) async {
    final snap = await _fs
        .collection('businesses')
        .doc(businessId)
        .collection('agri_farms')
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchInputs(String businessId) async {
    final snap = await _fs
        .collection('businesses')
        .doc(businessId)
        .collection('agri_inputs')
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<void> saveHint(
      String businessId, String farmId, Map<String, dynamic> hint) async {
    final col =
        _fs.collection('businesses').doc(businessId).collection('agri_hints');
    await col.add({
      'farmId': farmId,
      'text': hint['text'] ?? '',
      // Accept DateTime from caller or fall back to server timestamp
      'date': hint['date'] ?? FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchHints(String businessId,
      {String? farmId}) async {
    final col =
        _fs.collection('businesses').doc(businessId).collection('agri_hints');
    Query query = col;
    if (farmId != null) query = query.where('farmId', isEqualTo: farmId);
    // Order by date descending so newest hints come first
    final snap = await query.orderBy('date', descending: true).get();
    return snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      final rawDate = data['date'];
      String dateStr;
      if (rawDate is Timestamp) {
        dateStr = rawDate.toDate().toIso8601String();
      } else if (rawDate is String) {
        dateStr = rawDate;
      } else if (rawDate is DateTime) {
        dateStr = rawDate.toIso8601String();
      } else {
        dateStr = DateTime.now().toIso8601String();
      }
      return {'id': d.id, ...data, 'date': dateStr};
    }).toList();
  }

  @override
  Future<void> deleteLivestockGroup(String businessId, String groupId) async {
    final ref = _fs.collection('businesses').doc(businessId).collection('animal_groups').doc(groupId);
    await ref.delete();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLivestockGroups(String businessId) async {
    final col = _fs.collection('businesses').doc(businessId).collection('animal_groups');
    final snap = await col.get();
    return snap.docs.map((d) {
      final data = d.data();
      final created = data['createdAt'];
      final updated = data['updatedAt'];
      final createdStr = created is Timestamp ? created.toDate().toIso8601String() : (created is String ? created : DateTime.now().toIso8601String());
      final updatedStr = updated is Timestamp ? updated.toDate().toIso8601String() : (updated is String ? updated : DateTime.now().toIso8601String());
      return {'id': d.id, ...data, 'createdAt': createdStr, 'updatedAt': updatedStr};
    }).toList();
  }

  @override
  Future<void> saveLivestockGroup(String businessId, Map<String, dynamic> group) async {
    final col = _fs.collection('businesses').doc(businessId).collection('animal_groups');
    if (group['id'] != null && (group['id'] as String).isNotEmpty) {
      await col.doc(group['id']).set({
        ...group,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await col.add({
        ...group,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> saveFarm(String businessId, Map<String, dynamic> farm) async {
    final col = _fs.collection('businesses').doc(businessId).collection('agri_farms');
    if (farm['id'] != null && (farm['id'] as String).isNotEmpty) {
      await col.doc(farm['id']).set({...farm, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } else {
      await col.add({...farm, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  @override
  Future<void> deleteFarm(String businessId, String farmId) async {
    final ref = _fs.collection('businesses').doc(businessId).collection('agri_farms').doc(farmId);
    await ref.delete();
  }
}

