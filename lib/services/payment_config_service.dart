import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to retrieve payment gateway credentials from Firestore
class PaymentConfigService {
  final FirebaseFirestore _firestore;

  // Fallback demo public key (for development/testing)
  static const String _fallbackDemoPublicKey =
      'FLWPUBK_TEST-8db0e8d8a9c7b5f3e2d1c0b9a8f7e6d5c';

  PaymentConfigService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// Retrieve Flutterwave public key from Firestore 'secure' document
  /// Falls back to demo key if not found
  Future<String?> getFlutterwavePublicKey() async {
    try {
      final doc = await _firestore.collection('secure').doc('secure').get();
      if (doc.exists) {
        final key = doc.data()?['publicKey'];
        if (key != null && key.toString().isNotEmpty) {
          return key.toString();
        }
      }
      // Fallback to demo key for development
      print(
          'Warning: Flutterwave publicKey not found in Firestore. Using demo key.');
      return _fallbackDemoPublicKey;
    } catch (e) {
      print('Error retrieving Flutterwave public key: $e. Using demo key.');
      // Return demo key on error to allow testing
      return _fallbackDemoPublicKey;
    }
  }

  /// Retrieve Flutterwave secret key from Firestore 'secure' document
  /// Note: Secret keys should NEVER be used client-side; this is for server-side reference only
  Future<String?> getFlutterwaveSecretKey() async {
    try {
      final doc = await _firestore.collection('secure').doc('secure').get();
      if (doc.exists) {
        final key = doc.data()?['secretKey'];
        if (key != null && key.toString().isNotEmpty) {
          return key.toString();
        }
      }
      return null;
    } catch (e) {
      print('Error retrieving Flutterwave secret key: $e');
      return null;
    }
  }

  /// Retrieve all payment gateway credentials
  Future<Map<String, dynamic>?> getPaymentCredentials() async {
    try {
      final doc = await _firestore.collection('secure').doc('secure').get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error retrieving payment credentials: $e');
      return null;
    }
  }

  /// Cache for credentials (optional: to reduce Firestore reads)
  static Map<String, dynamic>? _cachedCredentials;
  static DateTime? _credentialsCacheTime;
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Retrieve payment credentials with caching
  Future<Map<String, dynamic>?> getPaymentCredentialsWithCache() async {
    final now = DateTime.now();

    // Check if cache is still valid
    if (_cachedCredentials != null &&
        _credentialsCacheTime != null &&
        now.difference(_credentialsCacheTime!).inMilliseconds <
            _cacheDuration.inMilliseconds) {
      return _cachedCredentials;
    }

    // Fetch fresh credentials
    final credentials = await getPaymentCredentials();
    if (credentials != null) {
      _cachedCredentials = credentials;
      _credentialsCacheTime = now;
    }
    return credentials;
  }

  /// Clear the credential cache (call after updating credentials)
  static void clearCache() {
    _cachedCredentials = null;
    _credentialsCacheTime = null;
  }
}

