import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Helper class to check network connectivity
class ConnectivityHelper {
  static final Connectivity _connectivity = Connectivity();

  /// `connectivity_plus` only reports whether a network interface is
  /// attached (Wi-Fi/cellular/none), and that report is not trustworthy in
  /// either direction: it can say "connected" while the interface has no
  /// actual route to the internet (captive portals, a disconnected router),
  /// and on Windows it can also say "none" - or throw
  /// (NetworkManager::StartListen) - for a machine that's genuinely online,
  /// especially right after app startup. An earlier version of this method
  /// trusted a "none" verdict from the plugin as final and returned false
  /// without ever attempting the DNS lookup below, which meant the one
  /// signal that actually matters never got a chance to override a bogus
  /// platform report - exactly the "shows offline while online" failure
  /// mode. So the interface check is never used to declare offline by
  /// itself; a real DNS lookup against our own backend is the only thing
  /// that decides that.
  static Future<bool> hasInternetConnection() async {
    try {
      // The app's own backend, not a Firebase domain it no longer depends
      // on for anything - what matters is whether *this* host is reachable.
      final lookup = await InternetAddress.lookup('backend.managecare.info')
          .timeout(const Duration(seconds: 5));
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

