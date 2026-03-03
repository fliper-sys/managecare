import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/auto_repository.dart';

class AutoRepositoryImpl implements AutoRepository {
  final FirebaseFirestore _firestore;

  AutoRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>> getDashboardStats(String businessId) async {
    final snap = await _firestore
        .collection('serviceOrders')
        .where('businessId', isEqualTo: businessId)
        .get();

    final active = snap.docs
        .where((d) => (d['status'] as String? ?? '') == 'In Progress')
        .length;
    final pending = snap.docs
        .where((d) => (d['status'] as String? ?? '') == 'Pending')
        .length;
    final completed = snap.docs
        .where((d) => (d['status'] as String? ?? '') == 'Completed')
        .length;

    return <String, dynamic>{
      'active': active,
      'pending': pending,
      'completed': completed,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getServiceOrders(String businessId) async {
    try {
      final snap = await _firestore
          .collection('serviceOrders')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final List<Map<String, dynamic>> result = snap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList()
          .cast<Map<String, dynamic>>();
      return result;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' || (e.message ?? '').contains('requires an index')) {
        // Composite index missing — retry a simpler query without ordering/limit
        print('[AutoRepositoryImpl] Composite index missing for serviceOrders query, retrying simpler query: $e');
        final snap = await _firestore
            .collection('serviceOrders')
            .where('businessId', isEqualTo: businessId)
            .get();
        return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList().cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getJobCards(String businessId) async {
    try {
      final snap = await _firestore
          .collection('jobCards')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final List<Map<String, dynamic>> result = snap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList()
          .cast<Map<String, dynamic>>();
      return result;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' || (e.message ?? '').contains('requires an index')) {
        print('[AutoRepositoryImpl] Composite index missing for jobCards query, retrying simpler query: $e');
        final snap = await _firestore
            .collection('jobCards')
            .where('businessId', isEqualTo: businessId)
            .get();
        return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList().cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getVehicles(String businessId) async {
    try {
      final snap = await _firestore
          .collection('vehicles')
          .where('businessId', isEqualTo: businessId)
          .orderBy('lastServiceDate', descending: true)
          .limit(50)
          .get();

      final List<Map<String, dynamic>> result = snap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList()
          .cast<Map<String, dynamic>>();
      return result;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' || (e.message ?? '').contains('requires an index')) {
        print('[AutoRepositoryImpl] Composite index missing for vehicles query, retrying simpler query: $e');
        final snap = await _firestore
            .collection('vehicles')
            .where('businessId', isEqualTo: businessId)
            .get();
        return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList().cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getInvoices(String businessId) async {
    try {
      final snap = await _firestore
          .collection('invoices')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final List<Map<String, dynamic>> result = snap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList()
          .cast<Map<String, dynamic>>();
      return result;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' || (e.message ?? '').contains('requires an index')) {
        print('[AutoRepositoryImpl] Composite index missing for invoices query, retrying simpler query: $e');
        final snap = await _firestore
            .collection('invoices')
            .where('businessId', isEqualTo: businessId)
            .get();
        return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList().cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getBookings(String businessId) async {
    try {
      final snap = await _firestore
          .collection('bookings')
          .where('businessId', isEqualTo: businessId)
          .orderBy('bookingDate', descending: true)
          .limit(50)
          .get();

      final List<Map<String, dynamic>> result = snap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList()
          .cast<Map<String, dynamic>>();
      return result;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' || (e.message ?? '').contains('requires an index')) {
        print('[AutoRepositoryImpl] Composite index missing for bookings query, retrying simpler query: $e');
        final snap = await _firestore
            .collection('bookings')
            .where('businessId', isEqualTo: businessId)
            .get();
        return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList().cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getParts(String businessId) async {
    try {
      final snap = await _firestore
          .collection('parts')
          .where('businessId', isEqualTo: businessId)
          .orderBy('name')
          .limit(200)
          .get();

      final List<Map<String, dynamic>> result = snap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList()
          .cast<Map<String, dynamic>>();
      return result;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' || (e.message ?? '').contains('requires an index')) {
        print('[AutoRepositoryImpl] Composite index missing for parts query, retrying simpler query: $e');
        final snap = await _firestore
            .collection('parts')
            .where('businessId', isEqualTo: businessId)
            .get();
        return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList().cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getServices(String businessId) async {
    try {
      final snap = await _firestore
          .collection('services')
          .where('businessId', isEqualTo: businessId)
          .orderBy('name')
          .limit(200)
          .get();

      final List<Map<String, dynamic>> result = snap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList()
          .cast<Map<String, dynamic>>();
      return result;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' || (e.message ?? '').contains('requires an index')) {
        print('[AutoRepositoryImpl] Composite index missing for services query, retrying simpler query: $e');
        final snap = await _firestore
            .collection('services')
            .where('businessId', isEqualTo: businessId)
            .get();
        return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList().cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }
}

