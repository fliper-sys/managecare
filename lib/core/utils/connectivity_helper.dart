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
  /// full network path and sat through Firestore's connect timeouts/stream
  /// retries instead of the instant cached-data path. A cheap DNS lookup
  /// confirms there's somewhere to actually reach.
  static Future<bool> hasInternetConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) return false;
    } catch (_) {
      return false;
    }

    try {
      final lookup = await InternetAddress.lookup('firebase.google.com')
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

