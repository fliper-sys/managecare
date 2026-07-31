import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/utils/connectivity_helper.dart';
import 'sync_provider.dart';

class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();

  bool _isConnected = true;
  bool _wasOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _pollTimer;
  SyncProvider? _syncProvider;

  bool get isConnected => _isConnected;
  bool get wasOffline => _wasOffline;

  void setSyncProvider(SyncProvider syncProvider) {
    _syncProvider = syncProvider;
  }

  Future<void> initialize() async {
    // connectivity_plus only reports whether a network interface is
    // attached, and on Windows neither half of that report can be trusted:
    // checkConnectivity() can claim "none" for a genuinely-connected
    // machine, and onConnectivityChanged's platform channel can outright
    // throw (NetworkManager::StartListen) instead of ever delivering
    // events. So the interface plugin is never the source of truth here -
    // ConnectivityHelper's real DNS lookup against our own backend is. The
    // plugin is only used, best-effort, as a hint to re-check sooner; a
    // periodic poll is the fallback for when it can't even do that much.
    await checkConnection();

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (_) => checkConnection(),
      onError: (_) {},
    );

    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkConnection();
    });
  }

  Future<bool> checkConnection() async {
    final previousState = _isConnected;
    _isConnected = await ConnectivityHelper.hasInternetConnection();

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

    if (previousState != _isConnected) {
      notifyListeners();
    }
    return _isConnected;
  }

  void resetOfflineFlag() {
    _wasOffline = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}

