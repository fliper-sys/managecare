/// Production-ready Flutterwave payment service
/// Reads keys from Firebase Firestore (secure/secure document)
/// Modeled after proven payment gateway pattern
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutterwave_standard/flutterwave.dart';

class FlutterwavePaymentService {
  static final FlutterwavePaymentService _instance =
      FlutterwavePaymentService._internal();

  factory FlutterwavePaymentService() {
    return _instance;
  }

  FlutterwavePaymentService._internal();

  /// Fetch Flutterwave public key from Firestore
  Future<String?> _getPublicKey() async {
    try {
      // LIVE MODE - Using production key
      const liveKey = 'FLWPUBK-2e37d7c18cafd58c18719349e17e75c1-X';

      print('[FlutterwavePaymentService] ⚠ USING LIVE KEY');
      print('[FlutterwavePaymentService] ✓ Public key fetched (hardcoded)');
      print(
          '[FlutterwavePaymentService] Key starts with: ${liveKey.substring(0, 20)}...');
      print('[FlutterwavePaymentService] Key length: ${liveKey.length}');

      // Analyze key format
      print('[FlutterwavePaymentService] ━━━━━━━ KEY FORMAT ANALYSIS ━━━━━━━');
      if (liveKey.startsWith('FLWPUBK_TEST')) {
        print('[FlutterwavePaymentService] ✓ TEST KEY DETECTED');
      } else if (liveKey.startsWith('FLWPUBK_LIVE')) {
        print('[FlutterwavePaymentService] ✓ LIVE KEY DETECTED');
      } else if (liveKey.startsWith('FLWPUBK-')) {
        print('[FlutterwavePaymentService] ✓ LIVE KEY FORMAT (FLWPUBK-)');
      }

      return liveKey;
    } catch (e) {
      print('[FlutterwavePaymentService] ❌ ERROR fetching public key: $e');
      return null;
    }
  }

  /// Process payment with Flutterwave - Robust implementation
  Future<PaymentResult> processPayment({
    required BuildContext context,
    required double amount,
    required String currency,
    required String email,
    required String fullName,
    required String transactionId,
    String? phoneNumber,
  }) async {
    String? transactionIdRef;

    try {
      print('[FlutterwavePaymentService] ━━━━━━━ PAYMENT INITIATED ━━━━━━━');
      print('[FlutterwavePaymentService] Amount: $amount $currency');
      print('[FlutterwavePaymentService] Customer: $fullName ($email)');
      print('[FlutterwavePaymentService] Transaction ID: $transactionId');

      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Initializing payment...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Fetch and validate public key
      final publicKey = await _getPublicKey();
      if (publicKey == null || publicKey.isEmpty) {
        print('[FlutterwavePaymentService] ❌ ERROR: Public key not found');
        throw Exception('Payment configuration error: Missing public key');
      }

      // Validate public key format
      if (!publicKey.startsWith('FLWPUBK')) {
        print('[FlutterwavePaymentService] ❌ ERROR: Invalid public key format');
        print('[FlutterwavePaymentService] Key should start with FLWPUBK');
        throw Exception('Invalid payment gateway key format');
      }

      // Check for correct key format (accepts _TEST, _LIVE, or legacy FLWPUBK- format)
      final hasValidFormat = publicKey.contains('_TEST') ||
          publicKey.contains('_LIVE') ||
          publicKey.startsWith('FLWPUBK-');

      if (!hasValidFormat) {
        print('[FlutterwavePaymentService] ❌ ERROR: Key format incorrect');
        print(
            '[FlutterwavePaymentService] Key must match one of these formats:');
        print(
            '[FlutterwavePaymentService]   - FLWPUBK_TEST-[key]-X (TEST mode)');
        print(
            '[FlutterwavePaymentService]   - FLWPUBK_LIVE-[key]-X (LIVE mode)');
        print(
            '[FlutterwavePaymentService]   - FLWPUBK-[key]-X (Legacy LIVE format)');
        print('[FlutterwavePaymentService] Current key: $publicKey');
        throw Exception('Public key format invalid');
      }

      // Determine test mode
      final isTestMode = publicKey.toLowerCase().contains('test');
      print('[FlutterwavePaymentService] ✓ Test Mode: $isTestMode');
      print(
          '[FlutterwavePaymentService] ✓ Public Key Valid: ${publicKey.substring(0, 20)}...');

      // Configure payment
      print('[FlutterwavePaymentService] Configuring payment parameters...');

      final customer = Customer(
        name: fullName,
        email: email,
        phoneNumber: phoneNumber ?? '',
      );

      final customization = Customization(
        title: 'Manage Care Subscription',
        description: 'Payment of $currency ${amount.toStringAsFixed(2)}',
        logo: '',
      );

      // Initialize Flutterwave
      final flutterwave = Flutterwave(
        publicKey: publicKey,
        currency: currency,
        amount: amount.toStringAsFixed(2),
        txRef: transactionId,
        customer: customer,
        paymentOptions: 'card, ussd, bank transfer',
        customization: customization,
        redirectUrl: 'https://www.flutterwave.com',
        isTestMode: isTestMode,
      );

      print('[FlutterwavePaymentService] ✓ Flutterwave instance configured');
      print('[FlutterwavePaymentService] ━━━━━━━ INITIATING CHARGE ━━━━━━━');
      print(
          '[FlutterwavePaymentService] Context is mounted: ${context.mounted}');
      print(
          '[FlutterwavePaymentService] About to call flutterwave.charge()...');

      // Extra validation before charge
      print('[FlutterwavePaymentService] Final validation before charge:');
      print(
          '[FlutterwavePaymentService]   Public Key: ${publicKey.substring(0, 30)}...');
      print('[FlutterwavePaymentService]   Amount: $amount $currency');
      print('[FlutterwavePaymentService]   Email: $email');
      print('[FlutterwavePaymentService]   Customer: $fullName');
      print('[FlutterwavePaymentService]   TxRef: $transactionId');
      print('[FlutterwavePaymentService]   Is Test Mode: $isTestMode');

      // Process charge
      final ChargeResponse response = await flutterwave.charge(context);
      transactionIdRef = response.txRef;

      print('[FlutterwavePaymentService] Charge call returned (dialog closed)');

      print('[FlutterwavePaymentService] ━━━━━━━ RESPONSE RECEIVED ━━━━━━━');
      print('[FlutterwavePaymentService] Status: ${response.status}');
      print('[FlutterwavePaymentService] Success: ${response.success}');
      print('[FlutterwavePaymentService] TxRef: ${response.txRef}');
      print('[FlutterwavePaymentService] Full Response: $response');

      // Deep inspection of response object
      print('[FlutterwavePaymentService] ━━━━━━━ RESPONSE INSPECTION ━━━━━━━');

      // Check for error messages in response
      if (response.status?.toLowerCase() == 'error') {
        print('[FlutterwavePaymentService] ⚠ FLUTTERWAVE ERROR DETECTED');
        print(
            '[FlutterwavePaymentService] This means Flutterwave rejected the payment request');
        print('[FlutterwavePaymentService] ');
        print('[FlutterwavePaymentService] POSSIBLE CAUSES:');
        print(
            '[FlutterwavePaymentService] 1. Account not fully activated on Flutterwave');
        print(
            '[FlutterwavePaymentService] 2. Payment methods not enabled in Flutterwave');
        print(
            '[FlutterwavePaymentService] 3. Business details incomplete on Flutterwave');
        print(
            '[FlutterwavePaymentService] 4. Account has payment restrictions');
        print(
            '[FlutterwavePaymentService] 5. API key permissions are insufficient');
        print('[FlutterwavePaymentService] ');
        print('[FlutterwavePaymentService] ACTION REQUIRED:');
        print(
            '[FlutterwavePaymentService] 1. Visit: https://app.flutterwave.com/dashboard');
        print('[FlutterwavePaymentService] 2. Go to Settings → Account Setup');
        print('[FlutterwavePaymentService] 3. Complete all required fields:');
        print('[FlutterwavePaymentService]    - Business name');
        print('[FlutterwavePaymentService]    - Business type');
        print('[FlutterwavePaymentService]    - Business address');
        print('[FlutterwavePaymentService]    - Bank account details');
        print(
            '[FlutterwavePaymentService] 4. Enable payment methods: Cards, USSD, Bank Transfer');
        print(
            '[FlutterwavePaymentService] 5. Verify account email if requested');
        print(
            '[FlutterwavePaymentService] 6. Contact Flutterwave support if still blocked');
      }
      print(
          '[FlutterwavePaymentService] Response type: ${response.runtimeType}');

      print(
          '[FlutterwavePaymentService] Response toString: ${response.toString()}');

      // Try to extract all properties
      try {
        print('[FlutterwavePaymentService] Response properties:');
        print('[FlutterwavePaymentService]   - status: ${response.status}');
        print('[FlutterwavePaymentService]   - success: ${response.success}');
        print('[FlutterwavePaymentService]   - txRef: ${response.txRef}');
      } catch (e) {
        print('[FlutterwavePaymentService] Could not extract properties: $e');
      }

      // Validate response thoroughly - matching reference implementation
      final respStatus = (response.status ?? '').toString().toLowerCase();
      final respSuccessFlag = response.success == true;
      final hasValidTxId = response.txRef?.isNotEmpty == true;

      print('[FlutterwavePaymentService] ━━━━━━━ RESPONSE VALIDATION ━━━━━━━');
      print('[FlutterwavePaymentService] respStatus: "$respStatus"');
      print('[FlutterwavePaymentService] respSuccessFlag: $respSuccessFlag');
      print('[FlutterwavePaymentService] hasValidTxId: $hasValidTxId');
      print(
          '[FlutterwavePaymentService] Status matches success: ${respStatus == 'success' || respStatus == 'successful'}');

      final isSuccessful = (respSuccessFlag ||
              respStatus == 'success' ||
              respStatus == 'successful') &&
          hasValidTxId;

      print('[FlutterwavePaymentService] Final isSuccessful: $isSuccessful');

      if (isSuccessful) {
        print('[FlutterwavePaymentService] ✓ PAYMENT SUCCESSFUL');
        print('[FlutterwavePaymentService] Transaction ID: ${response.txRef}');

        // Clear snackbars
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
        }

        return PaymentResult(
          success: true,
          transactionId: response.txRef ?? transactionId,
          message: 'Payment successful',
          status: 'completed',
          processorResponse: {
            'success': response.success,
            'status': response.status,
            'txRef': response.txRef,
          },
        );
      }

      // Handle failure
      final failureMessage = response.status == 'cancelled'
          ? 'Payment was cancelled'
          : 'Payment failed: ${response.status ?? 'Unknown error'}';

      print('[FlutterwavePaymentService] ✗ PAYMENT FAILED');
      print('[FlutterwavePaymentService] Reason: $failureMessage');

      return PaymentResult(
        success: false,
        transactionId: transactionIdRef ?? transactionId,
        message: failureMessage,
        status: response.status ?? 'failed',
      );
    } catch (e, stackTrace) {
      print('[FlutterwavePaymentService] ❌ EXCEPTION OCCURRED');
      print('[FlutterwavePaymentService] Error Type: ${e.runtimeType}');
      print('[FlutterwavePaymentService] Error: $e');
      print('[FlutterwavePaymentService] Stack Trace:');
      print(stackTrace);

      final errorMessage = transactionIdRef != null
          ? 'Payment error (ID: $transactionIdRef): ${e.toString()}'
          : 'Payment error: ${e.toString()}';

      return PaymentResult(
        success: false,
        transactionId: transactionIdRef ?? transactionId,
        message: errorMessage,
        status: 'error',
      );
    }
  }
}

/// Payment result model
class PaymentResult {
  final bool success;
  final String transactionId;
  final String message;
  final String status;
  final Map<String, dynamic>? processorResponse;

  PaymentResult({
    required this.success,
    required this.transactionId,
    required this.message,
    required this.status,
    this.processorResponse,
  });

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'transactionId': transactionId,
      'message': message,
      'status': status,
      'processorResponse': processorResponse,
    };
  }

  @override
  String toString() =>
      'PaymentResult(success: $success, status: $status, message: $message)';
}

