import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Helper class to check network connectivity
class ConnectivityHelper {
  static final Connectivity _connectivity = Connectivity();

  /// `connectivity_plus` only reports whether a network interface is
  /// attached (Wi-Fi/cellular/none), and that report is not trustworthy in
  /// either direction: it can say "connected" while the interface has no
  /// actual route to the internet (captive portals, a disconnected router),
  /// and on Windows it can also say "none" - or throw
  /// (NetworkManager::StartListen) - for a machine that's genuinely online,
  /// especially right after app startup. So the interface check is never
  /// used to declare offline by itself; a real request against our own
  /// backend is the only thing that decides that.
  ///
  /// A prior version used dart:io's InternetAddress.lookup() for that real
  /// check, but dart:io has no raw DNS resolution on Flutter Web (browsers
  /// can't do that) - it throws there immediately, so this always returned
  /// false on every deployed web build regardless of actual connectivity.
  /// An HTTP request works the same way on every platform (native sockets
  /// on io platforms, fetch/XHR under the hood on web), so it replaces the
  /// DNS lookup here.
  static Future<bool> hasInternetConnection() async {
    try {
      // The app's own backend, not a Firebase domain it no longer depends
      // on for anything - what matters is whether *this* host is reachable.
      final response = await http
          .get(Uri.parse('https://backend.managecare.info/api/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode > 0;
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

