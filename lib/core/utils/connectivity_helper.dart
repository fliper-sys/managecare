import 'package:connectivity_plus/connectivity_plus.dart';

/// Helper class to check network connectivity
class ConnectivityHelper {
  static final Connectivity _connectivity = Connectivity();

  static Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  static Stream<bool> observeConnectivity() {
    return _connectivity.onConnectivityChanged.map((result) {
      return result != ConnectivityResult.none;
    });
  }
}

