/// Network information interface
abstract class NetworkInfo {
  Future<bool> isConnected();
  Stream<bool> onConnectivityChanged();
}

