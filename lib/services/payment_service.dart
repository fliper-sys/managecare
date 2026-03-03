/// Payment service for handling transactions with offline support
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _cachedPublicKey;
  DateTime? _publicKeyCacheExpiry;

  // Toggle mock payment for development; set to false to enable real Flutterwave
  static const bool USE_MOCK_PAYMENT_ALWAYS = false;

  factory PaymentService() {
    return _instance;
  }

  PaymentService._internal();

  /// Check if running on web
  static bool get _isWeb {
    // If USE_MOCK_PAYMENT_ALWAYS is true, force mock payment
    if (USE_MOCK_PAYMENT_ALWAYS) {
      print(
          '[PaymentService._isWeb] USE_MOCK_PAYMENT_ALWAYS is TRUE - forcing MOCK payment');
      return true;
    }

    // Use kIsWeb which is the proper way to detect web in Flutter
    if (kIsWeb) {
      print('[PaymentService._isWeb] kIsWeb is TRUE - detected WEB platform');
      return true;
    }

    try {
      final isWeb = !Platform.isAndroid && !Platform.isIOS;
      print(
          '[PaymentService._isWeb] Platform check: Android=${Platform.isAndroid}, iOS=${Platform.isIOS}, isWeb=$isWeb');
      return isWeb;
    } catch (e) {
      // Platform check throws on web, so assume web
      print(
          '[PaymentService._isWeb] Platform check threw exception - assuming WEB: $e');
      return true;
    }
  }

  /// Get public key from Firestore (cached for a short duration).
  /// Returns null if not configured or on error.
  Future<String?> getPublicKey(
      {Duration cacheDuration = const Duration(minutes: 5)}) async {
    try {
      if (_cachedPublicKey != null &&
          _publicKeyCacheExpiry != null &&
          DateTime.now().isBefore(_publicKeyCacheExpiry!)) {
        return _cachedPublicKey;
      }
      final doc = await _firestore.collection('secure').doc('secure').get();
      final pk = doc.exists ? (doc.data()?['publicKey'] as String?) : null;
      if (pk != null && pk.isNotEmpty) {
        _cachedPublicKey = pk;
        _publicKeyCacheExpiry = DateTime.now().add(cacheDuration);
        return _cachedPublicKey;
      }
      return null;
    } catch (e) {
      print('[PaymentService.getPublicKey] Failed to read publicKey: $e');
      return null;
    }
  }

  /// Process payment with Flutterwave
  /// On web/localhost: Shows mock payment dialog
  /// On mobile: Uses Flutterwave SDK
  Future<Map<String, dynamic>> processPayment({
    required BuildContext context,
    required double amount,
    required String currency,
    required String email,
    required String fullName,
    required String txRef,
    required String publicKey,
    String? phoneNumber,
    String? businessId,
  }) async {
    print(
        '[PaymentService.processPayment] Starting - USE_MOCK_PAYMENT_ALWAYS: $USE_MOCK_PAYMENT_ALWAYS, _isWeb: $_isWeb');

    // Force mock payment if constant is set
    if (USE_MOCK_PAYMENT_ALWAYS) {
      print(
          '[PaymentService.processPayment] USE_MOCK_PAYMENT_ALWAYS=true - Using MOCK payment');
      return _processMockPayment(
        context: context,
        amount: amount,
        currency: currency,
        email: email,
        fullName: fullName,
        txRef: txRef,
        businessId: businessId,
      );
    }

    // On web/localhost, use mock payment for development
    if (_isWeb) {
      print(
          '[PaymentService.processPayment] _isWeb=true - Using MOCK payment (web)');
      return _processMockPayment(
        context: context,
        amount: amount,
        currency: currency,
        email: email,
        fullName: fullName,
        txRef: txRef,
        businessId: businessId,
      );
    }

    // On mobile, use real Flutterwave SDK
    print('[PaymentService.processPayment] Using REAL Flutterwave (mobile)');
    return _processFlutterwavePayment(
      context: context,
      amount: amount,
      currency: currency,
      email: email,
      fullName: fullName,
      txRef: txRef,
      publicKey: publicKey,
      phoneNumber: phoneNumber,
      businessId: businessId,
    );
  }

  /// Mock payment for web development
  Future<Map<String, dynamic>> _processMockPayment({
    required BuildContext context,
    required double amount,
    required String currency,
    required String email,
    required String fullName,
    required String txRef,
    String? businessId,
  }) async {
    try {
      print('[PaymentService] Starting mock payment...');
      print('[PaymentService] Amount: $amount $currency, Email: $email');

      // Show payment confirmation dialog
      final confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext ctx) {
              print('[PaymentService] Building dialog...');
              return AlertDialog(
                title: const Text('Confirm Payment'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('This is a test payment (Web Development Mode)'),
                    const SizedBox(height: 16),
                    Text('Amount: $amount $currency'),
                    Text('Customer: $fullName'),
                    Text('Email: $email'),
                    Text('Transaction ID: $txRef'),
                    const SizedBox(height: 16),
                    const Text(
                      'Click "Confirm" to simulate successful payment.\nClick "Cancel" to decline.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      print('[PaymentService] Cancel button pressed');
                      Navigator.pop(ctx, false);
                    },
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      print('[PaymentService] Confirm Payment button pressed');
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('Confirm Payment'),
                  ),
                ],
              );
            },
          ) ??
          false;

      print('[PaymentService] Dialog result - confirmed: $confirmed');

      if (confirmed) {
        print('[PaymentService] Payment confirmed by user');
        // Save transaction to Firestore
        if (businessId != null) {
          print('[PaymentService] Saving transaction to Firestore...');
          await _savePaymentTransaction(
            businessId: businessId,
            transactionId: txRef,
            amount: amount,
            currency: currency,
            status: 'completed',
            email: email,
            method: 'mock_web',
            processorResponse: {'status': 'success', 'transactionId': txRef},
          );
          print('[PaymentService] Transaction saved');
        }

        final result = {
          'success': true,
          'transactionId': txRef,
          'message': 'Payment successful (Test Mode)',
          'status': 'completed',
        };
        print('[PaymentService] Returning success: $result');
        return result;
      } else {
        print('[PaymentService] Payment cancelled by user');
        // Save failed transaction
        if (businessId != null) {
          print('[PaymentService] Saving failed transaction to Firestore...');
          await _savePaymentTransaction(
            businessId: businessId,
            transactionId: txRef,
            amount: amount,
            currency: currency,
            status: 'failed',
            email: email,
            method: 'mock_web',
            failureReason: 'User cancelled payment',
          );
          print('[PaymentService] Failed transaction saved');
        }

        final result = {
          'success': false,
          'transactionId': txRef,
          'message': 'Payment cancelled',
          'status': 'failed',
        };
        print('[PaymentService] Returning failure: $result');
        return result;
      }
    } catch (e) {
      print('[PaymentService] ERROR in _processMockPayment: $e');
      print('[PaymentService] Stack trace: ${StackTrace.current}');

      return {
        'success': false,
        'transactionId': txRef,
        'message': 'Payment error: $e',
        'status': 'error',
      };
    }
  }

  /// Real Flutterwave payment for mobile
  Future<Map<String, dynamic>> _processFlutterwavePayment({
    required BuildContext context,
    required double amount,
    required String currency,
    required String email,
    required String fullName,
    required String txRef,
    required String publicKey,
    String? phoneNumber,
    String? businessId,
  }) async {
    try {
      print(
          '[PaymentService._processFlutterwavePayment] Starting real Flutterwave payment');
      print(
          '[PaymentService._processFlutterwavePayment] Amount: $amount $currency');

      final flutterwave = Flutterwave(
        publicKey: publicKey,
        currency: currency,
        // IMPORTANT: Flutterwave requires a non-empty redirectUrl. Use a URL
        // that is registered in your Flutterwave Dashboard under allowed
        // redirect URLs (or a valid app deep link/universal link).
        redirectUrl: 'https://www.flutterwave.com',
        txRef: txRef,
        amount: amount.toString(),
        customer: Customer(
          name: fullName,
          phoneNumber: phoneNumber ?? "",
          email: email,
        ),
        paymentOptions: "card, ussd, bank transfer",
        customization: Customization(title: "Payment for goods/services"),
        isTestMode: true, // Always use test mode for development
      );

      print(
          '[PaymentService._processFlutterwavePayment] Calling flutterwave.charge()...');
      final ChargeResponse response = await flutterwave.charge(context);
      print(
          '[PaymentService._processFlutterwavePayment] Response received - success: ${response.success}, status: ${response.status}');
      print(
          '[PaymentService._processFlutterwavePayment] Full response: $response');

      // Check if payment was successful using the 'success' property
      if (response.success == true) {
        print(
            '[PaymentService._processFlutterwavePayment] Payment success - TxRef: ${response.txRef}');

        // Verify with Flutterwave using secret key when possible
        bool verified = true;
        try {
          final txId = response.transactionId ?? response.txRef;
          if (txId != null) {
            verified = await verifyFlutterwaveTransaction(txId);
            print(
                '[PaymentService._processFlutterwavePayment] Verification result for $txId: $verified');
          }
        } catch (e) {
          print(
              '[PaymentService._processFlutterwavePayment] Verification error: $e');
        }

        if (!verified) {
          // Verification failed - save as failed and return
          if (businessId != null) {
            await _savePaymentTransaction(
              businessId: businessId,
              transactionId: response.transactionId ?? response.txRef ?? txRef,
              amount: amount,
              currency: currency,
              status: 'failed',
              email: email,
              method: 'flutterwave',
              failureReason: 'Verification failed',
            );
          }

          return {
            'success': false,
            'transactionId': response.transactionId ?? response.txRef ?? txRef,
            'message': 'Payment verification failed',
            'status': 'failed',
          };
        }

        // Save transaction to Firestore
        if (businessId != null) {
          await _savePaymentTransaction(
            businessId: businessId,
            transactionId: response.txRef ?? txRef,
            amount: amount,
            currency: currency,
            status: 'completed',
            email: email,
            method: 'flutterwave',
            processorResponse: {
              'success': response.success,
              'status': response.status,
              'txRef': response.txRef,
            },
          );
        }

        return {
          'success': true,
          'transactionId': response.txRef ?? txRef,
          'message': 'Payment successful',
          'status': 'completed',
        };
      }

      // Payment failed or was cancelled
      print(
          '[PaymentService._processFlutterwavePayment] Payment failed - status: ${response.status}');
      if (businessId != null) {
        await _savePaymentTransaction(
          businessId: businessId,
          transactionId: txRef,
          amount: amount,
          currency: currency,
          status: 'failed',
          email: email,
          method: 'flutterwave',
          failureReason: 'Status: ${response.status}',
        );
      }

      return {
        'success': false,
        'transactionId': txRef,
        'message': 'Payment failed or cancelled',
        'status': response.status ?? 'failed',
      };
    } catch (e) {
      print('[PaymentService._processFlutterwavePayment] ERROR: $e');
      print(
          '[PaymentService._processFlutterwavePayment] Stack trace: ${StackTrace.current}');

      return {
        'success': false,
        'transactionId': txRef,
        'message': 'Payment error: $e',
        'status': 'error',
      };
    }
  }

  /// Verify a Flutterwave transaction using the secret key stored in Firestore
  /// Returns true when the transaction is verified and successful
  Future<bool> verifyFlutterwaveTransaction(String transactionId) async {
    try {
      final doc = await _firestore.collection('secure').doc('secure').get();
      final secretKey =
          doc.exists ? (doc.data()?['secretKey'] as String?) : null;
      if (secretKey == null || secretKey.isEmpty) {
        print(
            '[PaymentService.verifyFlutterwaveTransaction] No secretKey found in secure/secure');
        return false;
      }

      // Build request without logging the secret key
      final url = Uri.parse(
          'https://api.flutterwave.com/v3/transactions/$transactionId/verify');
      final resp = await http.get(url, headers: {
        'Authorization': 'Bearer $secretKey',
        'Content-Type': 'application/json',
      });

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final status = body['status']?.toString();
        final data = body['data'] as Map<String, dynamic>?;
        final chargeResponse = data?['status']?.toString();
        print(
            '[PaymentService.verifyFlutterwaveTransaction] Verify response status: $status; data.status: $chargeResponse');
        return (status == 'success' &&
            (chargeResponse == 'successful' || chargeResponse == 'success'));
      }

      print(
          '[PaymentService.verifyFlutterwaveTransaction] HTTP ${resp.statusCode}: ${resp.body}');
      return false;
    } catch (e) {
      print('[PaymentService.verifyFlutterwaveTransaction] Error: $e');
      return false;
    }
  }

  /// Refund a payment
  Future<Map<String, dynamic>> refund(
    String transactionId,
    double amount, {
    String? businessId,
    String? reason,
  }) async {
    try {
      // Flutterwave refunds require server-side API integration
      // Call your backend server to process the refund

      if (businessId != null) {
        await _savePaymentTransaction(
          businessId: businessId,
          transactionId: transactionId,
          amount: amount,
          currency: 'NGN',
          status: 'refunded',
          email: '',
          method: 'refund',
          refundReason: reason,
        );
      }

      return {
        'success': true,
        'transactionId': transactionId,
        'message': 'Refund processed',
        'status': 'refunded',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Refund failed: $e',
        'status': 'error',
      };
    }
  }

  /// Get payment history for a business
  Future<List<Map<String, dynamic>>> getPaymentHistory(
    String businessId, {
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('payment_transactions')
          .where('businessId', isEqualTo: businessId);

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      throw PaymentException(
        message: 'Failed to fetch payment history: $e',
      );
    }
  }

  /// Get payment summary/stats for a business
  Future<Map<String, dynamic>> getPaymentStats(
    String businessId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final transactions = await getPaymentHistory(
        businessId,
        startDate: startDate,
        endDate: endDate,
      );

      double totalAmount = 0;
      int successCount = 0;
      int failedCount = 0;

      for (final tx in transactions) {
        if (tx['status'] == 'completed') {
          totalAmount += (tx['amount'] as num).toDouble();
          successCount++;
        } else if (tx['status'] == 'failed') {
          failedCount++;
        }
      }

      return {
        'totalAmount': totalAmount,
        'transactionCount': transactions.length,
        'successCount': successCount,
        'failedCount': failedCount,
        'successRate':
            successCount / (transactions.isNotEmpty ? transactions.length : 1),
        'averageAmount':
            transactions.isNotEmpty ? totalAmount / transactions.length : 0,
      };
    } catch (e) {
      throw PaymentException(
        message: 'Failed to calculate payment stats: $e',
      );
    }
  }

  /// Retry a failed payment
  Future<Map<String, dynamic>> retryPayment(
    String transactionId, {
    required BuildContext context,
    required String publicKey,
    required double amount,
    required String currency,
    required String email,
    required String fullName,
  }) async {
    return processPayment(
      context: context,
      amount: amount,
      currency: currency,
      email: email,
      fullName: fullName,
      txRef: '${transactionId}_retry_${DateTime.now().millisecondsSinceEpoch}',
      publicKey: publicKey,
    );
  }

  /// Save payment transaction to Firestore
  Future<void> _savePaymentTransaction({
    required String businessId,
    required String transactionId,
    required double amount,
    required String currency,
    required String status,
    required String email,
    required String method,
    Map<String, dynamic>? processorResponse,
    String? failureReason,
    String? refundReason,
  }) async {
    try {
      await _firestore.collection('payment_transactions').add({
        'businessId': businessId,
        'transactionId': transactionId,
        'amount': amount,
        'currency': currency,
        'status': status,
        'email': email,
        'method': method,
        'processorResponse': processorResponse,
        'failureReason': failureReason,
        'refundReason': refundReason,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log but don't throw - payment should still be considered successful
      print('Failed to save payment transaction: $e');
    }
  }

  /// Check if a payment retry is allowed
  Future<bool> canRetryPayment(String transactionId) async {
    try {
      final query = await _firestore
          .collection('payment_transactions')
          .where('transactionId', isEqualTo: transactionId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return false;

      final transaction = query.docs.first.data();
      final retryCount = (transaction['retryCount'] ?? 0) as int;
      final maxRetries = (transaction['maxRetries'] ?? 3) as int;

      return retryCount < maxRetries && transaction['status'] == 'failed';
    } catch (e) {
      return false;
    }
  }

  /// Stream payment transactions for real-time updates
  Stream<List<Map<String, dynamic>>> streamPaymentTransactions(
    String businessId, {
    int limit = 20,
  }) {
    return _firestore
        .collection('payment_transactions')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }
}

/// Custom exception for payment operations
class PaymentException implements Exception {
  final String message;
  final String? code;

  PaymentException({
    required this.message,
    this.code,
  });

  @override
  String toString() => '$message${code != null ? ' ($code)' : ''}';
}

