import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/worker_repository.dart';

/// Firebase implementation of worker repository
class WorkerRepositoryImpl implements WorkerRepository {
  final FirebaseFirestore _firestore;

  WorkerRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  @override
  Future<dynamic> addWorker(Map<String, dynamic> workerData) async {
    try {
      workerData['createdAt'] = DateTime.now();
      workerData['updatedAt'] = DateTime.now();

      // If an 'id' is provided, use it as the document ID
      if (workerData.containsKey('id') &&
          (workerData['id'] as String).isNotEmpty) {
        final docId = workerData['id'] as String;
        print('[WorkerRepo] Adding worker with custom ID: $docId');
        await _firestore.collection('workers').doc(docId).set(workerData);
        print('[WorkerRepo] Worker saved successfully with ID: $docId');
        return {'id': docId, ...workerData};
      }

      // Otherwise, auto-generate the document ID
      print('[WorkerRepo] Adding worker with auto-generated ID');
      final docRef = await _firestore.collection('workers').add(workerData);
      print(
          '[WorkerRepo] Worker saved successfully with auto-generated ID: ${docRef.id}');
      return {'id': docRef.id, ...workerData};
    } catch (e) {
      print('[WorkerRepo] Error adding worker: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateWorker(
      String workerId, Map<String, dynamic> workerData) async {
    try {
      workerData['updatedAt'] = DateTime.now();
      await _firestore
          .collection('workers')
          .doc(workerId)
          .set(workerData, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteWorker(String workerId) async {
    try {
      await _firestore.collection('workers').doc(workerId).delete();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getWorkers(String businessId) async {
    try {
      print('[WorkerRepo] Fetching workers for businessId: $businessId');

      // Get from workers collection
      var snapshot = await _firestore
          .collection('workers')
          .where('businessId', isEqualTo: businessId)
          .get();
      var workers =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      print(
          '[WorkerRepo] Found ${workers.length} workers in workers collection');

      // Also get from users collection (workers might be stored as users)
      snapshot = await _firestore
          .collection('users')
          .where('businessId', isEqualTo: businessId)
          .where('isOwner',
              isEqualTo: false) // Exclude owners, only get workers/staff
          .get();
      final usersWorkers =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      print(
          '[WorkerRepo] Found ${usersWorkers.length} workers in users collection');

      // Merge and deduplicate (prefer users collection data as it's more up-to-date)
      String _dedupeKey(Map<String, dynamic> worker) {
        final email = ((worker['emailLowercase'] ?? worker['email']) as String?)
                ?.trim()
                .toLowerCase() ??
            '';
        if (email.isNotEmpty) {
          return 'email:$email';
        }
        return 'id:${(worker['id'] ?? '').toString()}';
      }

      final workerMap = <String, dynamic>{};
      for (var worker in workers) {
        workerMap[_dedupeKey(Map<String, dynamic>.from(worker))] = worker;
      }
      for (var worker in usersWorkers) {
        workerMap[_dedupeKey(Map<String, dynamic>.from(worker))] = worker;
      }

      final result = workerMap.values
          .where((worker) {
            final workerBusinessId =
                (worker['businessId'] ?? '').toString().trim();
            if (workerBusinessId != businessId) return false;

            final isActive = worker['isActive'];
            if (isActive is bool) return isActive;

            return true;
          })
          .toList();
      print('[WorkerRepo] Total active unique workers: ${result.length}');
      return result;
    } catch (e) {
      print('[WorkerRepo] Error fetching workers: $e');
      rethrow;
    }
  }

  @override
  Future<dynamic> getWorkerById(String workerId) async {
    try {
      print('[WorkerRepo] Fetching worker with ID: $workerId');

      // First try the workers collection
      var doc = await _firestore.collection('workers').doc(workerId).get();
      print('[WorkerRepo] Workers collection - Document exists: ${doc.exists}');

      if (doc.exists) {
        final result = {'id': doc.id, ...doc.data() ?? {}};
        print('[WorkerRepo] Retrieved worker from workers collection: $result');
        return result;
      }

      // If not in workers collection, try the users collection
      print(
          '[WorkerRepo] Worker not in workers collection, checking users collection...');
      doc = await _firestore.collection('users').doc(workerId).get();
      print('[WorkerRepo] Users collection - Document exists: ${doc.exists}');

      if (doc.exists) {
        final result = {'id': doc.id, ...doc.data() ?? {}};
        print('[WorkerRepo] Retrieved worker from users collection: $result');
        return result;
      }

      print(
          '[WorkerRepo] Document not found in either collection for ID: $workerId');
      return null;
    } catch (e) {
      print('[WorkerRepo] Error fetching worker: $e');
      rethrow;
    }
  }

  @override
  Future<void> recordAttendance(
      String workerId, Map<String, dynamic> attendanceData) async {
    try {
      attendanceData['timestamp'] = DateTime.now();
      await _firestore
          .collection('workers')
          .doc(workerId)
          .collection('attendance')
          .add(attendanceData);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getWorkerAttendance(String workerId) async {
    try {
      final snapshot = await _firestore
          .collection('workers')
          .doc(workerId)
          .collection('attendance')
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      rethrow;
    }
  }
}

