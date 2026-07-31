import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
    // Check initial connectivity. connectivity_plus's platform channel can
    // throw here (observed on Windows: NetworkManager::StartListen) even
    // while the machine is genuinely online - if that happens at startup and
    // is left uncaught, this whole method aborts before the stream listener
    // below is even registered, so the app never finds out connectivity is
    // actually fine and the "working offline" banner sticks permanently.
    // Assume online rather than propagating the platform error as a fact.
    try {
      final result = await _connectivity.checkConnectivity();
      _isConnected = !result.contains(ConnectivityResult.none);
    } catch (_) {
      _isConnected = true;
    }
    notifyListeners();

    // The very first check above runs before the OS network stack /
    // platform plugin has necessarily finished settling right after process
    // launch, so a genuinely-connected device can still read "none" for a
    // moment. One short delayed re-check corrects that false negative
    // instead of leaving the "working offline" banner up for a connection
    // that's actually fine.
    if (!_isConnected) {
      Future.delayed(const Duration(seconds: 2), () async {
        final stillOffline = !(await checkConnection());
        if (!stillOffline) {
          debugPrint('[ConnectivityProvider] Startup connectivity re-check corrected false "offline"');
        }
      });
    }

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) => _updateConnectionStatus(results),
      onError: (_) {},
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
        // Delegate to SyncProvider which uses the correct SyncService setup
        await _syncProvider?.syncNow();
        // reset offline flag after successful sync
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
    try {
      final result = await _connectivity.checkConnectivity();
      _isConnected = !result.contains(ConnectivityResult.none);
    } catch (_) {
      _isConnected = true;
    }
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

