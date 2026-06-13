import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<void> _ensureAuthenticatedSession() async {
    final firebaseAuth = FirebaseAuth.instance;
    var firebaseUser = firebaseAuth.currentUser;
    if (firebaseUser == null) {
      throw StateError(
        'Your session has expired. Please sign in again before deleting a worker.',
      );
    }

    try {
      await firebaseUser.reload();
    } on FirebaseAuthException catch (e) {
      // `requires-recent-login` is not expected for reload, but if Firebase has
      // already invalidated the session we want to surface a clean message.
      if (e.code == 'user-token-expired' ||
          e.code == 'user-disabled' ||
          e.code == 'user-not-found') {
        throw StateError(
          'Your session has expired. Please sign in again before deleting a worker.',
        );
      }
      rethrow;
    }

    firebaseUser = firebaseAuth.currentUser;
    if (firebaseUser == null) {
      throw StateError(
        'Your session has expired. Please sign in again before deleting a worker.',
      );
    }

    try {
      final token = await firebaseUser.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw StateError(
          'Your session has expired. Please sign in again before deleting a worker.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw StateError(
          'Unable to verify your session right now. Check your connection and try again.',
        );
      }

      if (e.code == 'user-token-expired' ||
          e.code == 'invalid-user-token' ||
          e.code == 'user-disabled' ||
          e.code == 'user-not-found') {
        throw StateError(
          'Your session has expired. Please sign in again before deleting a worker.',
        );
      }

      rethrow;
    }
  }

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

  Future<String?> _resolveWorkerEmail(String workerId) async {
    final firestore = FirebaseFirestore.instance;

    String? readEmail(Map<String, dynamic>? data) {
      if (data == null) return null;
      final value = data['emailLowercase'] ?? data['email'];
      final email = value?.toString().trim();
      if (email == null || email.isEmpty) return null;
      return email.toLowerCase();
    }

    try {
      final workerDoc = await firestore.collection('workers').doc(workerId).get();
      final email = readEmail(workerDoc.data());
      if (email != null) return email;
    } catch (_) {}

    try {
      final userDoc = await firestore.collection('users').doc(workerId).get();
      final email = readEmail(userDoc.data());
      if (email != null) return email;
    } catch (_) {}

    return null;
  }

  Future<void> _deleteMatchingWorkerDocsByEmail(
    String collection,
    String email,
    String? businessId,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final trimmedBusinessId = businessId?.trim() ?? '';
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return;

    for (final field in const ['emailLowercase', 'email']) {
      try {
        Query query = firestore.collection(collection).where(field, isEqualTo: normalizedEmail);
        if (trimmedBusinessId.isNotEmpty) {
          query = query.where('businessId', isEqualTo: trimmedBusinessId);
        }
        final snapshot = await query.get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        print('[WorkersProvider] Failed to delete matching $collection docs by email: $e');
      }
    }
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

  /// Soft-remove a worker from a business without deleting the record entirely.
  /// This is used by owner management flows that detach a worker from the business
  /// but may keep a historical worker document for audit/reference purposes.
  Future<void> removeWorkerFromBusiness(
    String workerId, {
    required String businessId,
  }) async {
    final targetBusinessId = businessId.trim();
    if (targetBusinessId.isEmpty) {
      throw ArgumentError('businessId is required to remove a worker');
    }

    try {
      await _ensureAuthenticatedSession();

      final now = FieldValue.serverTimestamp();
      final workerDocRef =
          FirebaseFirestore.instance.collection('workers').doc(workerId);
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(workerId);

      // Detach the worker from the business in both collections so all worker
      // count paths stop treating the record as an active slot.
      try {
        await workerDocRef.set({
          'isActive': false,
          'businessId': FieldValue.delete(),
          'role': FieldValue.delete(),
          'roles': FieldValue.delete(),
          'updatedAt': now,
          'removedAt': now,
        }, SetOptions(merge: true));
      } catch (e) {
        print('[WorkersProvider] Failed to detach worker doc: $e');
        rethrow;
      }

      try {
        await userDocRef.set({
          'isActive': false,
          'businessId': FieldValue.delete(),
          'role': FieldValue.delete(),
          'roles': FieldValue.delete(),
          'updatedAt': now,
          'removedAt': now,
        }, SetOptions(merge: true));
      } catch (e) {
        print('[WorkersProvider] Failed to detach user doc: $e');
      }

      final businessDocRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(targetBusinessId);

      for (final collection in const ['barbers', 'stylists']) {
        try {
          await businessDocRef.collection(collection).doc(workerId).delete();
        } catch (e) {
          print(
            '[WorkersProvider] Failed to delete worker from $collection collection: $e',
          );
        }
      }

      await _refreshBusinessScopeAfterMutation(targetBusinessId);
    } catch (e) {
      print('[WorkersProvider] removeWorkerFromBusiness failed: $e');
      rethrow;
    }
  }

  /// Delete worker from Firestore collections (users, workers, and business-specific collections)
  /// Note: Firebase Auth account deletion cannot be performed from client-side code for security reasons.
  /// This requires server-side implementation (Cloud Functions) to delete the Auth user.
  Future<void> deleteWorker(String workerId, {String? businessId}) async {
    try {
      await _ensureAuthenticatedSession();

      final workerEmail = await _resolveWorkerEmail(workerId);
      final firestore = FirebaseFirestore.instance;

      // Delete from main collections by document id first
      await _repository.deleteWorker(workerId);
      try {
        await firestore.collection('users').doc(workerId).delete();
      } catch (e) {
        print('[WorkersProvider] Failed to delete users doc by id: $e');
      }

      // Also remove any lingering duplicates by email so recreation with the
      // same email works even if older records used a different document id.
      if (workerEmail != null && workerEmail.isNotEmpty) {
        await _deleteMatchingWorkerDocsByEmail('workers', workerEmail, businessId);
        await _deleteMatchingWorkerDocsByEmail('users', workerEmail, businessId);
      }

      // Delete from business-specific collections if businessId is provided
      if (businessId != null && businessId.isNotEmpty) {
        final businessDocRef = firestore.collection('businesses').doc(businessId);

        // Delete from barbers collection
        try {
          await businessDocRef.collection('barbers').doc(workerId).delete();
          print('[WorkersProvider] Deleted worker from barbers collection: $workerId');
        } catch (e) {
          print('[WorkersProvider] Failed to delete from barbers collection: $e');
        }

        // Delete from stylists collection
        try {
          await businessDocRef.collection('stylists').doc(workerId).delete();
          print('[WorkersProvider] Deleted worker from stylists collection: $workerId');
        } catch (e) {
          print('[WorkersProvider] Failed to delete from stylists collection: $e');
        }

        for (final collection in const [
          'mechanics',
          'electricians',
          'body_technicians',
          'painters',
          'valucnizers',
          'staff',
          'managers',
        ]) {
          try {
            await businessDocRef.collection(collection).doc(workerId).delete();
          } catch (_) {}
        }

        if (workerEmail != null && workerEmail.isNotEmpty) {
          for (final collection in const [
            'barbers',
            'stylists',
            'mechanics',
            'electricians',
            'body_technicians',
            'painters',
            'valucnizers',
            'staff',
            'managers',
          ]) {
            await _deleteMatchingWorkerDocsByEmail(collection, workerEmail, businessId);
          }
        }
      }

      // Note: Firebase Auth user deletion cannot be performed from client-side code.
      // This requires a Cloud Function with admin privileges to delete the Auth user.
      // The worker's login will remain active until deleted server-side.

      await _refreshBusinessScopeAfterMutation(businessId);
    } catch (e) {
      print('[WorkersProvider] deleteWorker failed: $e');
      rethrow;
    }
  }
}
