import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/datetime_utils.dart';

/// Universal payment transaction model across all industries
/// Tracks status, methods, retries, and compliance data
class PaymentTransaction {
  final String id;
  final String businessId;
  final String? orderId; // POS order, hotel reservation, etc.
  final String? invoiceId; // For invoice generation

  // Amount & Currency
  final double amount;
  final double? tax;
  final double? discount;
  final double? totalAmount; // amount + tax - discount
  final String currency; // NGN, USD, etc.

  // Status & Tracking
  final String status; // pending, processing, completed, failed, refunded
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? failureDate;
  final String? failureReason; // e.g., "Card declined", "Insufficient funds"

  // Payment Method
  final String method; // cash, card, bank_transfer, mobile_money, stripe
  final String? paymentProcessor; // stripe, paypal, flutterwave, etc.
  final String? processorTransactionId; // For reconciliation

  // Retry Logic (Pro Feature)
  final bool canRetry;
  final int retryCount;
  final int maxRetries; // Default: 3
  final DateTime? nextRetryDate;
  final List<String>? retryAttempts; // Array of attempt dates

  // Additional Info
  final String? receiptUrl;
  final String? invoiceUrl;
  final String? notes;
  final Map<String, dynamic>? metadata; // Custom fields

  // Refund Info
  final bool isRefunded;
  final DateTime? refundDate;
  final String? refundReason;
  final double? refundAmount;

  // Pro Features
  final bool isPro; // If Pro payment

  PaymentTransaction({
    required this.id,
    required this.businessId,
    this.orderId,
    this.invoiceId,
    required this.amount,
    this.tax,
    this.discount,
    this.totalAmount,
    this.currency = 'NGN',
    this.status = 'pending',
    required this.createdAt,
    this.completedAt,
    this.failureDate,
    this.failureReason,
    this.method = 'cash',
    this.paymentProcessor,
    this.processorTransactionId,
    this.canRetry = false,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.nextRetryDate,
    this.retryAttempts,
    this.receiptUrl,
    this.invoiceUrl,
    this.notes,
    this.metadata,
    this.isRefunded = false,
    this.refundDate,
    this.refundReason,
    this.refundAmount,
    this.isPro = false,
  });

  /// Factory from Firestore document
  factory PaymentTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentTransaction(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      orderId: data['orderId'],
      invoiceId: data['invoiceId'],
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      tax: (data['tax'] as num?)?.toDouble(),
      discount: (data['discount'] as num?)?.toDouble(),
      totalAmount: (data['totalAmount'] as num?)?.toDouble(),
      currency: data['currency'] ?? 'NGN',
      status: data['status'] ?? 'pending',
      createdAt: parseTimestamp(data['createdAt']),
      completedAt: parseTimestamp(data['completedAt']),
      failureDate: parseTimestamp(data['failureDate']),
      failureReason: data['failureReason'],
      method: data['method'] ?? 'cash',
      paymentProcessor: data['paymentProcessor'],
      processorTransactionId: data['processorTransactionId'],
      canRetry: data['canRetry'] ?? false,
      retryCount: data['retryCount'] ?? 0,
      maxRetries: data['maxRetries'] ?? 3,
      nextRetryDate: parseTimestamp(data['nextRetryDate']),
      retryAttempts: List<String>.from(data['retryAttempts'] ?? []),
      receiptUrl: data['receiptUrl'],
      invoiceUrl: data['invoiceUrl'],
      notes: data['notes'],
      metadata: data['metadata'],
      isRefunded: data['isRefunded'] ?? false,
      refundDate: parseTimestamp(data['refundDate']),
      refundReason: data['refundReason'],
      refundAmount: (data['refundAmount'] as num?)?.toDouble(),
      isPro: data['isPro'] ?? false,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'orderId': orderId,
      'invoiceId': invoiceId,
      'amount': amount,
      'tax': tax,
      'discount': discount,
      'totalAmount': totalAmount,
      'currency': currency,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'failureDate':
          failureDate != null ? Timestamp.fromDate(failureDate!) : null,
      'failureReason': failureReason,
      'method': method,
      'paymentProcessor': paymentProcessor,
      'processorTransactionId': processorTransactionId,
      'canRetry': canRetry,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'nextRetryDate':
          nextRetryDate != null ? Timestamp.fromDate(nextRetryDate!) : null,
      'retryAttempts': retryAttempts,
      'receiptUrl': receiptUrl,
      'invoiceUrl': invoiceUrl,
      'notes': notes,
      'metadata': metadata,
      'isRefunded': isRefunded,
      'refundDate': refundDate != null ? Timestamp.fromDate(refundDate!) : null,
      'refundReason': refundReason,
      'refundAmount': refundAmount,
      'isPro': isPro,
    };
  }

  /// Create copy with changes
  PaymentTransaction copyWith({
    String? id,
    String? businessId,
    String? orderId,
    String? invoiceId,
    double? amount,
    double? tax,
    double? discount,
    double? totalAmount,
    String? currency,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? failureDate,
    String? failureReason,
    String? method,
    String? paymentProcessor,
    String? processorTransactionId,
    bool? canRetry,
    int? retryCount,
    int? maxRetries,
    DateTime? nextRetryDate,
    List<String>? retryAttempts,
    String? receiptUrl,
    String? invoiceUrl,
    String? notes,
    Map<String, dynamic>? metadata,
    bool? isRefunded,
    DateTime? refundDate,
    String? refundReason,
    double? refundAmount,
    bool? isPro,
  }) {
    return PaymentTransaction(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      orderId: orderId ?? this.orderId,
      invoiceId: invoiceId ?? this.invoiceId,
      amount: amount ?? this.amount,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      failureDate: failureDate ?? this.failureDate,
      failureReason: failureReason ?? this.failureReason,
      method: method ?? this.method,
      paymentProcessor: paymentProcessor ?? this.paymentProcessor,
      processorTransactionId:
          processorTransactionId ?? this.processorTransactionId,
      canRetry: canRetry ?? this.canRetry,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      nextRetryDate: nextRetryDate ?? this.nextRetryDate,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      invoiceUrl: invoiceUrl ?? this.invoiceUrl,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      isRefunded: isRefunded ?? this.isRefunded,
      refundDate: refundDate ?? this.refundDate,
      refundReason: refundReason ?? this.refundReason,
      refundAmount: refundAmount ?? this.refundAmount,
      isPro: isPro ?? this.isPro,
    );
  }

  /// Check if payment is overdue
  bool get isOverdue => status == 'failed' && retryCount < maxRetries;

  /// Check if retry available
  bool get canRetryNow =>
      canRetry &&
      retryCount < maxRetries &&
      (nextRetryDate == null || DateTime.now().isAfter(nextRetryDate!));

  /// Get status display text
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing...';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }

  /// Get method display icon
  String get methodIcon {
    switch (method.toLowerCase()) {
      case 'cash':
        return '💵';
      case 'card':
        return '💳';
      case 'bank_transfer':
        return '🏦';
      case 'mobile_money':
        return '📱';
      case 'stripe':
        return '🔘';
      default:
        return '💰';
    }
  }
}

