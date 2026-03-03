/// Service for handling receipt uploads and subscription payment via admin approval
library;

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/datetime_utils.dart';
import 'file_upload_service.dart';


class ReceiptUploadService {
  static final ReceiptUploadService _instance =
      ReceiptUploadService._internal();

  factory ReceiptUploadService() {
    return _instance;
  }

  ReceiptUploadService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Upload receipt and create pending subscription request
  Future<ReceiptUploadResult> uploadReceipt({
    required String userId,
    required String businessId,
    required String planId,
    required String planName,
    required double amount,
    required String currency,
    required File receiptFile,
    required String userEmail,
    required String userName,
  }) async {
    try {
      print('[ReceiptUploadService] ━━━━━━━ RECEIPT UPLOAD INITIATED ━━━━━━━');
      print('[ReceiptUploadService] User: $userId');
      print('[ReceiptUploadService] Plan: $planName ($planId)');
      print('[ReceiptUploadService] Amount: $amount $currency');

      // Generate unique receipt upload ID
      final uploadId = 'RCP_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      print('[ReceiptUploadService] Upload ID: $uploadId');

      // Validate file
      if (!receiptFile.existsSync()) {
        throw Exception('Receipt file not found');
      }

      final fileSize = receiptFile.lengthSync();
      const maxSize = 10 * 1024 * 1024; // 10 MB

      if (fileSize > maxSize) {
        throw Exception('File size exceeds 10 MB limit');
      }

      print(
          '[ReceiptUploadService] ✓ File validation passed (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');

      // Upload receipt to server using FileUploadService
      print('[ReceiptUploadService] ▶ Uploading receipt to server...');
      final uploader = FileUploadService();
      final downloadUrl = await uploader.uploadFile(receiptFile);

      if (downloadUrl == null) {
        throw Exception('Server upload failed or returned no URL');
      }

      print('[ReceiptUploadService] ✓ Receipt uploaded successfully');
      print('[ReceiptUploadService] Download URL: $downloadUrl');

      // Create pending subscription request in Firestore
      print(
          '[ReceiptUploadService] ▶ Creating pending subscription request...');

      final requestData = {
        'uploadId': uploadId,
        'userId': userId,
        'businessId': businessId,
        'planId': planId,
        'planName': planName,
        'amount': amount,
        'currency': currency,
        'userEmail': userEmail,
        'userName': userName,
        'receiptUrl': downloadUrl,
        'status': 'pending', // pending | approved | rejected
        'paymentMethod': 'receipt', // receipt | flutterwave
        'paymentProcessor': null,
        'processorTransactionId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'requestDate': FieldValue.serverTimestamp(), // For admin display
        'subscriptionRequestDate': FieldValue.serverTimestamp(), // Alias for consistency
        'subscriptionStatus': 'pending',
        'subscriptionAmount': amount,
        'subscriptionReceiptUrl': downloadUrl,
        'subscriptionPlan': planId,
        'notes': '',
        'receiptPath': null,
      };

      await _firestore
          .collection('subscription_requests')
          .doc(uploadId)
          .set(requestData);

      print('[ReceiptUploadService] ✓ Subscription request created');
      print('[ReceiptUploadService] Status: pending (awaiting admin approval)');

      return ReceiptUploadResult(
        success: true,
        uploadId: uploadId,
        message: 'Receipt uploaded successfully. Awaiting admin approval.',
        receiptUrl: downloadUrl,
      );
    } catch (e, stackTrace) {
      print('[ReceiptUploadService] ❌ ERROR: $e');
      print('[ReceiptUploadService] Stack trace: $stackTrace');
      return ReceiptUploadResult(
        success: false,
        uploadId: null,
        message: 'Failed to upload receipt: $e',
        receiptUrl: null,
      );
    }
  }

  /// Get subscription request status
  Future<SubscriptionRequestStatus?> getRequestStatus(String uploadId) async {
    try {
      final doc = await _firestore
          .collection('subscription_requests')
          .doc(uploadId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
        return SubscriptionRequestStatus(
        uploadId: uploadId,
        status: data['status'] as String,
        planName: data['planName'] as String,
        amount: (data['amount'] as num).toDouble(),
        currency: data['currency'] as String,
        createdAt: parseTimestamp(data['createdAt']),
        approvedAt: parseTimestamp(data['approvedAt']),
        notes: data['notes'] as String? ?? '',
      );
    } catch (e) {
      print('[ReceiptUploadService] Error getting request status: $e');
      return null;
    }
  }

  /// Listen to subscription request status changes
  Stream<SubscriptionRequestStatus?> watchRequestStatus(String uploadId) {
    return _firestore
        .collection('subscription_requests')
        .doc(uploadId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;

      final data = doc.data()!;
        return SubscriptionRequestStatus(
        uploadId: uploadId,
        status: data['status'] as String,
        planName: data['planName'] as String,
        amount: (data['amount'] as num).toDouble(),
        currency: data['currency'] as String,
        createdAt: parseTimestamp(data['createdAt']),
        approvedAt: parseTimestamp(data['approvedAt']),
        notes: data['notes'] as String? ?? '',
      );
    });
  }
}

class ReceiptUploadResult {
  final bool success;
  final String? uploadId;
  final String message;
  final String? receiptUrl;

  ReceiptUploadResult({
    required this.success,
    required this.uploadId,
    required this.message,
    required this.receiptUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'uploadId': uploadId,
      'message': message,
      'receiptUrl': receiptUrl,
    };
  }
}

class SubscriptionRequestStatus {
  final String uploadId;
  final String status; // pending | approved | rejected
  final String planName;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String notes;

  SubscriptionRequestStatus({
    required this.uploadId,
    required this.status,
    required this.planName,
    required this.amount,
    required this.currency,
    required this.createdAt,
    this.approvedAt,
    this.notes = '',
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  Map<String, dynamic> toMap() {
    return {
      'uploadId': uploadId,
      'status': status,
      'planName': planName,
      'amount': amount,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'notes': notes,
    };
  }
}

