import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/models/inventory_alert_model.dart';

class InventoryAlertsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _businessId;
  List<InventoryAlert> _activeAlerts = [];
  List<InventoryAlert> _allAlerts = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String? _indexCreateUrl;

  String? get indexCreateUrl => _indexCreateUrl;
  int _criticalCount = 0;
  int _warningCount = 0;

  // Getters
  List<InventoryAlert> get activeAlerts => _activeAlerts;
  List<InventoryAlert> get allAlerts => _allAlerts;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get criticalCount => _criticalCount;
  int get warningCount => _warningCount;

  void setBusinessId(String businessId) {
    _businessId = businessId;
    notifyListeners();
  }

  /// Load all inventory alerts
  Future<void> loadAlerts() async {
    if (_businessId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory_alerts')
          .orderBy('severity', descending: true)
          .orderBy('updatedAt', descending: true)
          .get();

      _allAlerts = snapshot.docs
          .map((doc) => InventoryAlert.fromJson(doc.data()))
          .toList();

      // Filter active (unacknowledged) alerts
      _activeAlerts = _allAlerts.where((alert) => !alert.acknowledged).toList();

      // Count by severity
      _criticalCount =
          _activeAlerts.where((a) => a.severity == 'critical').length;
      _warningCount =
          _activeAlerts.where((a) => a.severity == 'warning').length;

      _errorMessage = '';
      print('[InventoryAlertsProvider] Loaded ${_allAlerts.length} alerts');
    } catch (e) {
      // Detect Firestore index error and surface an actionable URL if present
      if (e is FirebaseException && e.code == 'failed-precondition' && (e.message ?? '').contains('create_composite')) {
        final msg = e.message ?? '';
        final match = RegExp(r'https?://\S*create_composite=\S+').firstMatch(msg);
        _indexCreateUrl = match?.group(0);
        _errorMessage = 'Failed to load alerts: the query requires a composite index. Create it using the console link below.';
        if (_indexCreateUrl != null) {
          _errorMessage = 'Failed to load alerts: the query requires a composite index. Create it here: $_indexCreateUrl';
        }
      } else {
        _errorMessage = 'Failed to load alerts: $e';
      }

      _allAlerts = [];
      _activeAlerts = [];
      debugPrint('[InventoryAlertsProvider] Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check inventory and create alerts
  Future<void> checkInventoryThresholds() async {
    if (_businessId == null) return;

    try {
      final productsSnapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .get();

      for (var productDoc in productsSnapshot.docs) {
        final data = productDoc.data();
        final productId = productDoc.id;
        final productName = data['name'] ?? 'Unknown';
        final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
        final minThreshold = (data['minStock'] as num?)?.toInt() ?? 10;
        final reorderQty = (data['reorderQuantity'] as num?)?.toInt() ?? 50;

        if (quantity <= minThreshold) {
          final severity = _calculateSeverity(quantity, minThreshold);

          // Check if alert already exists
          final existingAlert = _allAlerts.firstWhere(
            (a) => a.productId == productId,
            orElse: () => InventoryAlert(
              id: 'temp',
              businessId: '',
              productId: '',
              productName: '',
              currentStock: 0,
              minimumThreshold: 0,
              reorderQuantity: 0,
              severity: '',
              isActive: false,
              acknowledged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          if (existingAlert.id == 'temp') {
            // Create new alert
            await _createAlert(
              productId,
              productName,
              quantity,
              minThreshold,
              reorderQty,
              severity,
            );
          } else if (existingAlert.severity != severity) {
            // Update severity if changed
            await _updateAlertSeverity(existingAlert.id, severity, quantity);
          }
        }
      }

      await loadAlerts();
    } catch (e) {
      debugPrint('[InventoryAlertsProvider] Error checking thresholds: $e');
    }
  }

  /// Create a new alert
  Future<void> _createAlert(
    String productId,
    String productName,
    int currentStock,
    int minimumThreshold,
    int reorderQuantity,
    String severity,
  ) async {
    try {
      final alertId = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory_alerts')
          .doc()
          .id;

      final alert = InventoryAlert(
        id: alertId,
        businessId: _businessId!,
        productId: productId,
        productName: productName,
        currentStock: currentStock,
        minimumThreshold: minimumThreshold,
        reorderQuantity: reorderQuantity,
        severity: severity,
        isActive: true,
        acknowledged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory_alerts')
          .doc(alertId)
          .set(alert.toJson());

      print(
          '[InventoryAlertsProvider] Created $severity alert for $productName');
    } catch (e) {
      debugPrint('[InventoryAlertsProvider] Error creating alert: $e');
    }
  }

  /// Update alert severity
  Future<void> _updateAlertSeverity(
    String alertId,
    String newSeverity,
    int currentStock,
  ) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory_alerts')
          .doc(alertId)
          .update({
        'severity': newSeverity,
        'currentStock': currentStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('[InventoryAlertsProvider] Updated alert $alertId to $newSeverity');
    } catch (e) {
      debugPrint('[InventoryAlertsProvider] Error updating alert: $e');
    }
  }

  /// Acknowledge an alert (mark as seen)
  Future<void> acknowledgeAlert(String alertId) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory_alerts')
          .doc(alertId)
          .update({
        'acknowledged': true,
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });

      // Update local state
      final index = _allAlerts.indexWhere((a) => a.id == alertId);
      if (index >= 0) {
        _allAlerts[index] = _allAlerts[index].copyWith(
          acknowledged: true,
          acknowledgedAt: DateTime.now(),
        );
      }

      _activeAlerts.removeWhere((a) => a.id == alertId);
      _criticalCount =
          _activeAlerts.where((a) => a.severity == 'critical').length;
      _warningCount =
          _activeAlerts.where((a) => a.severity == 'warning').length;

      print('[InventoryAlertsProvider] Acknowledged alert: $alertId');
      notifyListeners();
    } catch (e) {
      debugPrint('[InventoryAlertsProvider] Error acknowledging alert: $e');
    }
  }

  /// Place reorder for product (from an existing alert)
  Future<void> placeReorder(String alertId, InventoryAlert alert) async {
    try {
      final reorderId = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('reorders')
          .doc()
          .id;

      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('reorders')
          .doc(reorderId)
          .set({
        'id': reorderId,
        'alertId': alertId,
        'productId': alert.productId,
        'productName': alert.productName,
        'quantity': alert.reorderQuantity,
        'status': 'pending', // pending, ordered, received
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Acknowledge the alert
      await acknowledgeAlert(alertId);

      print(
          '[InventoryAlertsProvider] Reorder placed for ${alert.productName}: ${alert.reorderQuantity} units');
    } catch (e) {
      debugPrint('[InventoryAlertsProvider] Error placing reorder: $e');
      rethrow;
    }
  }

  /// Place a direct reorder for a product (without a pre-existing alert)
  Future<void> placeDirectReorderForProduct(
      String productId, String productName, int quantity) async {
    try {
      final reorderId = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('reorders')
          .doc()
          .id;

      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('reorders')
          .doc(reorderId)
          .set({
        'id': reorderId,
        'alertId': null,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'status': 'pending',
        'source': 'direct',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(
          '[InventoryAlertsProvider] Direct reorder placed for $productName: $quantity units');
      notifyListeners();
    } catch (e) {
      debugPrint('[InventoryAlertsProvider] Error placing direct reorder: $e');
      rethrow;
    }
  }

  /// Get alerts by severity
  List<InventoryAlert> getAlertsBySeverity(String severity) {
    return _activeAlerts.where((a) => a.severity == severity).toList();
  }

  /// Get critical alerts
  List<InventoryAlert> getCriticalAlerts() {
    return getAlertsBySeverity('critical');
  }

  /// Get warning alerts
  List<InventoryAlert> getWarningAlerts() {
    return getAlertsBySeverity('warning');
  }

  /// Get products needing reorder
  Future<List<Map<String, dynamic>>> getProductsNeedingReorder() async {
    if (_businessId == null) return [];

    try {
      final reorderDocs = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('reorders')
          .where('status', isNotEqualTo: 'received')
          .get();

      return reorderDocs.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[InventoryAlertsProvider] Error getting reorders: $e');
      return [];
    }
  }

  /// Mark reorder as received
  Future<void> markReorderReceived(String reorderId) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('reorders')
          .doc(reorderId)
          .update({
        'status': 'received',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('[InventoryAlertsProvider] Marked reorder $reorderId as received');
    } catch (e) {
      debugPrint(
          '[InventoryAlertsProvider] Error marking reorder received: $e');
    }
  }

  /// Calculate severity level
  String _calculateSeverity(int currentStock, int minimumThreshold) {
    final percentage = (currentStock / minimumThreshold) * 100;
    if (percentage <= 25) return 'critical';
    if (percentage <= 50) return 'warning';
    return 'normal';
  }

  /// Clear all
  void clear() {
    _activeAlerts.clear();
    _allAlerts.clear();
    _errorMessage = '';
    notifyListeners();
  }
}

