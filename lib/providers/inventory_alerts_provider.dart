import 'package:flutter/material.dart';
import '../data/models/inventory_alert_model.dart';
import '../services/managecare_api_client.dart';

class InventoryAlertsProvider extends ChangeNotifier {
  final ManagecareApiClient _api = ManagecareApiClient.instance;

  String? _businessId;
  List<InventoryAlert> _activeAlerts = [];
  List<InventoryAlert> _allAlerts = [];
  bool _isLoading = false;
  String _errorMessage = '';

  // Kept for API compatibility with the alerts screen's "create a Firestore
  // composite index" banner, which no longer applies against Postgres.
  String? get indexCreateUrl => null;
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

  /// Load all inventory alerts. Alerts are computed fresh on the backend
  /// from current stock vs minimum threshold - there's no separate synced
  /// alert record to fall out of date, so there's no equivalent of the old
  /// "check thresholds" pass needed before this.
  Future<void> loadAlerts() async {
    if (_businessId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.get('/api/inventory-alerts/$_businessId');
      final data = (response['data'] as List?) ?? [];

      _allAlerts =
          data.map((raw) => InventoryAlert.fromJson(raw as Map<String, dynamic>)).toList();

      _activeAlerts = _allAlerts.where((alert) => !alert.acknowledged).toList();
      _criticalCount = _activeAlerts.where((a) => a.severity == 'critical').length;
      _warningCount = _activeAlerts.where((a) => a.severity == 'warning').length;

      _errorMessage = '';
      debugPrint('[InventoryAlertsProvider] Loaded ${_allAlerts.length} alerts');
    } catch (e) {
      _errorMessage = 'Failed to load alerts: $e';
      _allAlerts = [];
      _activeAlerts = [];
      debugPrint('[InventoryAlertsProvider] Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Alerts are computed live on every loadAlerts() call now, so there's no
  /// separate "create/update alert records" step to run first. Kept as a
  /// thin alias so existing call sites don't need to change.
  Future<void> checkInventoryThresholds() async {
    await loadAlerts();
  }

  /// Acknowledge an alert (mark as seen) for the current severity level.
  /// If the stock condition worsens/improves to a different severity later,
  /// it re-surfaces as unacknowledged.
  Future<void> acknowledgeAlert(String alertId) async {
    if (_businessId == null) return;
    try {
      await _api.post('/api/inventory-alerts/$_businessId/$alertId/acknowledge');

      final index = _allAlerts.indexWhere((a) => a.id == alertId);
      if (index >= 0) {
        _allAlerts[index] = _allAlerts[index].copyWith(
          acknowledged: true,
          acknowledgedAt: DateTime.now(),
        );
      }

      _activeAlerts.removeWhere((a) => a.id == alertId);
      _criticalCount = _activeAlerts.where((a) => a.severity == 'critical').length;
      _warningCount = _activeAlerts.where((a) => a.severity == 'warning').length;

      debugPrint('[InventoryAlertsProvider] Acknowledged alert: $alertId');
      notifyListeners();
    } catch (e) {
      debugPrint('[InventoryAlertsProvider] Error acknowledging alert: $e');
    }
  }

  /// Place reorder for product (from an existing alert)
  Future<void> placeReorder(String alertId, InventoryAlert alert) async {
    if (_businessId == null) return;
    try {
      await _api.post('/api/reorders/$_businessId', body: {
        'product_id': alert.productId,
        'product_name': alert.productName,
        'quantity': alert.reorderQuantity,
        'source': 'alert',
      });

      await acknowledgeAlert(alertId);

      debugPrint(
          '[InventoryAlertsProvider] Reorder placed for ${alert.productName}: ${alert.reorderQuantity} units');
    } catch (e) {
      debugPrint('[InventoryAlertsProvider] Error placing reorder: $e');
      rethrow;
    }
  }

  /// Place a direct reorder for a product (without a pre-existing alert)
  Future<void> placeDirectReorderForProduct(
      String productId, String productName, int quantity) async {
    if (_businessId == null) return;
    try {
      await _api.post('/api/reorders/$_businessId', body: {
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'source': 'direct',
      });

      debugPrint(
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
      final response = await _api.get('/api/reorders/$_businessId');
      final data = (response['data'] as List?) ?? [];
      return data
          .where((r) => (r as Map)['status'] != 'received')
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('[InventoryAlertsProvider] Error getting reorders: $e');
      return [];
    }
  }

  /// Mark reorder as received
  Future<void> markReorderReceived(String reorderId) async {
    if (_businessId == null) return;
    try {
      await _api.patch('/api/reorders/$_businessId/$reorderId/receive');

      debugPrint('[InventoryAlertsProvider] Marked reorder $reorderId as received');
    } catch (e) {
      debugPrint('[InventoryAlertsProvider] Error marking reorder received: $e');
    }
  }

  /// Clear all
  void clear() {
    _activeAlerts.clear();
    _allAlerts.clear();
    _errorMessage = '';
    notifyListeners();
  }
}
