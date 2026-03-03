import 'package:cloud_firestore/cloud_firestore.dart';
import 'alert_repository.dart';

class AlertRepositoryImpl implements AlertRepository {
  final FirebaseFirestore _firestore;

  AlertRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  @override
  Future<List<Map<String, dynamic>>> getAlerts(
    String businessId, {
    String? type,
  }) async {
    try {
      Query query = _firestore
          .collection('alerts')
          .where('businessId', isEqualTo: businessId)
          .where('isResolved', isEqualTo: false)
          .orderBy('createdAt', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> createAlert(
    String businessId,
    Map<String, dynamic> alertData,
  ) async {
    try {
      await _firestore.collection('alerts').add({
        'businessId': businessId,
        ...alertData,
        'isResolved': false,
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> dismissAlert(String alertId) async {
    try {
      await _firestore.collection('alerts').doc(alertId).update({
        'isDismissed': true,
        'dismissedAt': DateTime.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> resolveAlert(String alertId) async {
    try {
      await _firestore.collection('alerts').doc(alertId).update({
        'isResolved': true,
        'resolvedAt': DateTime.now(),
      });
    } catch (e) {
      rethrow;
    }
  }
}

