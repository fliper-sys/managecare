import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_service.dart';
import 'sync_provider.dart';

class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();

  bool _isConnected = true;
  bool _wasOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  SyncProvider? _syncProvider;

  bool get isConnected => _isConnected;
  bool get wasOffline => _wasOffline;

  void setSyncProvider(SyncProvider syncProvider) {
    _syncProvider = syncProvider;
  }

  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isConnected = result != ConnectivityResult.none;
    notifyListeners();

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) => _updateConnectionStatus(results),
    );
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    final previousState = _isConnected;
    // Check if any result indicates connectivity (none = no connection)
    _isConnected = !results.contains(ConnectivityResult.none);

    // Track if we were offline
    if (!_isConnected) {
      _wasOffline = true;
    }

    // If we just came back online after being offline, attempt to sync sales
    if (!previousState && _isConnected && _wasOffline) {
      try {
        final syncService = SyncService();
        await syncService.syncSales();
        // Update sync provider state
        await _syncProvider?.checkPendingItems();
        // reset offline flag after attempting sync
        _wasOffline = false;
      } catch (e) {
        debugPrint('[ConnectivityProvider] Error syncing sales: $e');
      }
    }

    // Notify listeners if connection state changed
    if (previousState != _isConnected) {
      notifyListeners();
    }
  }

  Future<bool> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    _isConnected = result != ConnectivityResult.none;
    notifyListeners();
    return _isConnected;
  }

  void resetOfflineFlag() {
    _wasOffline = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

