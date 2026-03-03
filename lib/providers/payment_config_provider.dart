import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/payment_config_service.dart';

/// Provider for accessing payment configuration credentials
class PaymentConfigProvider extends ChangeNotifier {
  final PaymentConfigService _configService;

  String? _flutterwavePublicKey;
  String? _flutterwaveSecretKey;
  Map<String, dynamic>? _credentials;
  bool _isLoading = false;
  String? _error;

  PaymentConfigProvider({PaymentConfigService? configService})
      : _configService = configService ??
            PaymentConfigService(firestore: FirebaseFirestore.instance);

  // Getters
  String? get flutterwavePublicKey => _flutterwavePublicKey;
  String? get flutterwaveSecretKey => _flutterwaveSecretKey;
  Map<String, dynamic>? get credentials => _credentials;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch Flutterwave public key
  Future<String?> fetchFlutterwavePublicKey() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _flutterwavePublicKey = await _configService.getFlutterwavePublicKey();
      return _flutterwavePublicKey;
    } catch (e) {
      _error = 'Failed to fetch Flutterwave public key: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch Flutterwave secret key (server-side reference only)
  Future<String?> fetchFlutterwaveSecretKey() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _flutterwaveSecretKey = await _configService.getFlutterwaveSecretKey();
      return _flutterwaveSecretKey;
    } catch (e) {
      _error = 'Failed to fetch Flutterwave secret key: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch all payment credentials
  Future<Map<String, dynamic>?> fetchPaymentCredentials() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _credentials = await _configService.getPaymentCredentials();
      // Also update individual keys if available
      if (_credentials != null) {
        _flutterwavePublicKey = _credentials!['flutterwave_public_key'];
        _flutterwaveSecretKey = _credentials!['flutterwave_secret_key'];
      }
      return _credentials;
    } catch (e) {
      _error = 'Failed to fetch payment credentials: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch credentials with caching enabled
  Future<Map<String, dynamic>?> fetchPaymentCredentialsWithCache() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _credentials = await _configService.getPaymentCredentialsWithCache();
      if (_credentials != null) {
        _flutterwavePublicKey = _credentials!['flutterwave_public_key'];
        _flutterwaveSecretKey = _credentials!['flutterwave_secret_key'];
      }
      return _credentials;
    } catch (e) {
      _error = 'Failed to fetch payment credentials: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

