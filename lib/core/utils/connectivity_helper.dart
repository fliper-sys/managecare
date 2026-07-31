import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Helper class to check network connectivity
class ConnectivityHelper {
  static final Connectivity _connectivity = Connectivity();

  /// `connectivity_plus` only reports whether a network interface is
  /// attached (Wi-Fi/cellular/none) — it stays "connected" even when that
  /// interface has no actual route to the internet (captive portals, a
  /// disconnected router, or an emulator with networking torn down). Relying
  /// on it alone made offline startup think it was online, so it took the
  /// full network path and sat through connect timeouts/stream retries
  /// instead of the instant cached-data path. A cheap DNS lookup confirms
  /// there's somewhere to actually reach.
  ///
  /// The interface check itself is best-effort, not authoritative: on
  /// Windows, `connectivity_plus`'s platform channel can throw
  /// (NetworkManager::StartListen) even while the machine is genuinely
  /// online, especially right after app startup — treating that as "offline"
  /// stuck the app in offline mode permanently despite a real connection. If
  /// the interface check itself fails, fall through to the DNS lookup rather
  /// than assuming the worst; the lookup is the fact that actually matters.
  static Future<bool> hasInternetConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) return false;
    } catch (_) {
      // Platform channel error, not a connectivity fact - fall through to
      // the DNS lookup instead of assuming offline.
    }

    try {
      // The app's own backend, not a Firebase domain it no longer depends
      // on for anything - what matters is whether *this* host is reachable.
      final lookup = await InternetAddress.lookup('backend.managecare.info')
          .timeout(const Duration(seconds: 3));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Stream<bool> observeConnectivity() {
    return _connectivity.onConnectivityChanged.map((results) {
      return results.any((r) => r != ConnectivityResult.none);
    });
  }
}

