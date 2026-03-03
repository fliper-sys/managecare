import 'package:cloud_firestore/cloud_firestore.dart';

class AutoRepositoryImpl {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch jobs
  Future<List<Map<String, dynamic>>> fetchJobs() async {
    try {
      final snapshot = await _firestore.collection('auto_jobs').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching jobs: $e');
      return [];
    }
  }

  // Create job
  Future<void> createJob(Map<String, dynamic> jobData) async {
    try {
      await _firestore.collection('auto_jobs').add(jobData);
    } catch (e) {
      print('Error creating job: $e');
    }
  }

  // Fetch vehicles
  Future<List<Map<String, dynamic>>> fetchVehicles() async {
    try {
      final snapshot = await _firestore.collection('auto_vehicles').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching vehicles: $e');
      return [];
    }
  }

  // Fetch parts inventory
  Future<List<Map<String, dynamic>>> fetchParts() async {
    try {
      final snapshot = await _firestore.collection('auto_parts').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching parts: $e');
      return [];
    }
  }

  // Update part quantity
  Future<void> updatePartQuantity(String partId, int newQuantity) async {
    try {
      await _firestore
          .collection('auto_parts')
          .doc(partId)
          .update({'quantity': newQuantity});
    } catch (e) {
      print('Error updating part quantity: $e');
    }
  }
}

