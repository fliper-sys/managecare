import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../data/repositories/worker_repository_impl.dart';

class WorkersProvider with ChangeNotifier {
  final WorkerRepositoryImpl _repository;
  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = false;
  String? _error;
  String? _businessId;

  WorkersProvider(
      {required String businessId, WorkerRepositoryImpl? repository})
      : _repository = repository ??
            WorkerRepositoryImpl(firestore: FirebaseFirestore.instance) {
    // initial load
    if (businessId.isNotEmpty) {
      loadWorkers(businessId);
    }
  }

  List<Map<String, dynamic>> get workers => _workers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _syncBusinessWorkerCount(String businessId) async {
    try {
      final activeWorkers = await _repository.getWorkers(businessId);
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .set(
        {
          'totalWorkers': activeWorkers.length,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('[WorkersProvider] Failed to sync worker count: $e');
    }
  }

  Future<void> _refreshBusinessScopeAfterMutation(String? businessId) async {
    final targetBusinessId = (businessId ?? _businessId ?? '').trim();
    if (targetBusinessId.isEmpty) return;

    _businessId = targetBusinessId;
    await refreshForBusiness(targetBusinessId);
    await _syncBusinessWorkerCount(targetBusinessId);
  }

  Future<void> loadWorkers(String businessId) async {
    _businessId = businessId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final list = await _repository.getWorkers(businessId);
      // ensure a consistent map type
      _workers = list
          .cast<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      _error = 'Failed to load workers: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshForBusiness(String businessId) async {
    await loadWorkers(businessId);
  }

  /// Set business id and refresh workers for that business
  Future<void> setBusinessId(String businessId) async {
    if (_businessId != null && _businessId == businessId) return;
    _businessId = businessId;
    await refreshForBusiness(businessId);
    notifyListeners();
  }

  Map<String, dynamic>? getById(String id) {
    try {
      return _workers.firstWhere(
          (w) => (w['id'] ?? '') == id || (w['employeeId'] ?? '') == id);
    } catch (e) {
      return null;
    }
  }

  /// Update worker document and related business-scoped copies (barbers/stylists)
  Future<void> updateWorker(String workerId, Map<String, dynamic> data, {String? businessId, List<String>? roles}) async {
    try {
      await _repository.updateWorker(workerId, data);

      // Update business-specific collections where appropriate
      if (businessId != null && businessId.isNotEmpty) {
        final rolesSet = (roles ?? []).map((r) => r.toLowerCase()).toSet();
        final docRefBarber = FirebaseFirestore.instance.collection('businesses').doc(businessId).collection('barbers').doc(workerId);
        final docRefStylist = FirebaseFirestore.instance.collection('businesses').doc(businessId).collection('stylists').doc(workerId);

        // Ensure merged updates where role present
        if (rolesSet.contains('barber')) {
          await docRefBarber.set(data, SetOptions(merge: true));
        } else {
          try { await docRefBarber.delete(); } catch (_) {}
        }

        if (rolesSet.contains('hairstylist') || rolesSet.contains('stylist')) {
          await docRefStylist.set(data, SetOptions(merge: true));
        } else {
          try { await docRefStylist.delete(); } catch (_) {}
        }
      }

      // If a PIN was included in the update, also sync it to the users collection
      final Map<String, dynamic> usersMerge = {};
      if (data.containsKey('pin')) usersMerge['pin'] = data['pin'];
      // Map common worker profile fields to user document keys
      if (data.containsKey('name')) usersMerge['fullName'] = data['name'];
      if (data.containsKey('email')) usersMerge['email'] = data['email'];
      if (data.containsKey('phoneNumber')) usersMerge['phoneNumber'] = data['phoneNumber'];
      if (data.containsKey('isActive')) usersMerge['isActive'] = data['isActive'];

      if (usersMerge.isNotEmpty) {
        try {
          usersMerge['updatedAt'] = DateTime.now();
          await FirebaseFirestore.instance.collection('users').doc(workerId).set(usersMerge, SetOptions(merge: true));
        } catch (e) {
          print('[WorkersProvider] Failed to sync profile to users collection: $e');
        }
      }

      await _refreshBusinessScopeAfterMutation(businessId);
    } catch (e) {
      print('[WorkersProvider] updateWorker failed: $e');
      rethrow;
    }
  }

  /// Delete worker completely including auth account
  Future<void> deleteWorker(String workerId, {String? businessId}) async {
    try {
      // Call Firebase Function to delete worker completely
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('deleteWorkerCompletely');
      await callable.call({'workerId': workerId});

      await _refreshBusinessScopeAfterMutation(businessId);
    } catch (e) {
      print('[WorkersProvider] deleteWorker failed: $e');
      rethrow;
    }
  }
}

