import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { pending, confirmed, checkedIn, checkedOut, cancelled }
enum PaymentStatus { none, pending, paid, failed }

class PolicySnapshot {
  final double depositPercent;
  final bool nonRefundable;
  final int freeCancelWindowHours;
  final String? notes;

  PolicySnapshot({
    required this.depositPercent,
    required this.nonRefundable,
    required this.freeCancelWindowHours,
    this.notes,
  });

  factory PolicySnapshot.fromMap(Map<String, dynamic>? m) {
    m ??= {};
    return PolicySnapshot(
      depositPercent: (m['depositPercent'] ?? 0.0).toDouble(),
      nonRefundable: m['nonRefundable'] ?? false,
      freeCancelWindowHours: (m['freeCancelWindowHours'] ?? 0) as int,
      notes: m['notes'],
    );
  }

  Map<String, dynamic> toMap() => {
        'depositPercent': depositPercent,
        'nonRefundable': nonRefundable,
        'freeCancelWindowHours': freeCancelWindowHours,
        'notes': notes,
      };
}

class Booking {
  final String id;
  final String unitId;
  final String apartmentId;
  final String tenantId;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int nights;
  final int guests;
  BookingStatus status;
  final DateTime createdAt;
  DateTime? updatedAt;

  // pricing
  final double subtotal;
  double depositAmount;
  final double discount;
  final double total;
  final String currency;

  // payment
  PaymentStatus paymentStatus;
  String? paymentMethod;
  String? providerTransactionId;
  DateTime? paidAt;

  // policy snapshot, receipt info
  final PolicySnapshot policySnapshot;
  String? receiptUrl;
  String? receiptPdfPath;

  // reminders
  DateTime? nextReminderAt;
  Map<String, bool>? reminderSentFlags;

  Booking({
    required this.id,
    required this.unitId,
    required this.apartmentId,
    required this.tenantId,
    required this.checkInDate,
    required this.checkOutDate,
    required this.nights,
    required this.guests,
    this.status = BookingStatus.pending,
    DateTime? createdAt,
    this.updatedAt,
    this.subtotal = 0.0,
    this.depositAmount = 0.0,
    this.discount = 0.0,
    this.total = 0.0,
    this.currency = '₦',
    this.paymentStatus = PaymentStatus.none,
    this.paymentMethod,
    this.providerTransactionId,
    this.paidAt,
    required this.policySnapshot,
    this.receiptUrl,
    this.receiptPdfPath,
    this.nextReminderAt,
    this.reminderSentFlags,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Booking(
      id: doc.id,
      unitId: data['unitId'] ?? '',
      apartmentId: data['apartmentId'] ?? '',
      tenantId: data['tenantId'] ?? '',
      checkInDate: _parseDate(data['checkInDate']) ?? DateTime.now(),
      checkOutDate: _parseDate(data['checkOutDate']) ?? DateTime.now(),
      nights: (data['nights'] ?? 0) as int,
      guests: (data['guests'] ?? 1) as int,
      status: _bookingStatusFromString(data['status'] ?? 'pending'),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']),
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      depositAmount: (data['depositAmount'] ?? 0.0).toDouble(),
      discount: (data['discount'] ?? 0.0).toDouble(),
      total: (data['total'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? '₦',
      paymentStatus: _paymentStatusFromString(data['paymentStatus'] ?? 'none'),
      paymentMethod: data['paymentMethod'],
      providerTransactionId: data['providerTransactionId'],
      paidAt: _parseDate(data['paidAt']),
      policySnapshot: PolicySnapshot.fromMap(data['policySnapshot'] ?? {}),
      receiptUrl: data['receiptUrl'],
      receiptPdfPath: data['receiptPdfPath'],
      nextReminderAt: _parseDate(data['nextReminderAt']),
      reminderSentFlags: (data['reminderSentFlags'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as bool)),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'unitId': unitId,
      'apartmentId': apartmentId,
      'tenantId': tenantId,
      'checkInDate': Timestamp.fromDate(checkInDate.toUtc()),
      'checkOutDate': Timestamp.fromDate(checkOutDate.toUtc()),
      'nights': nights,
      'guests': guests,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!.toUtc()) : FieldValue.serverTimestamp(),
      'subtotal': subtotal,
      'depositAmount': depositAmount,
      'discount': discount,
      'total': total,
      'currency': currency,
      'paymentStatus': paymentStatus.toString().split('.').last,
      'paymentMethod': paymentMethod,
      'providerTransactionId': providerTransactionId,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!.toUtc()) : null,
      'policySnapshot': policySnapshot.toMap(),
      'receiptUrl': receiptUrl,
      'receiptPdfPath': receiptPdfPath,
      'nextReminderAt': nextReminderAt != null ? Timestamp.fromDate(nextReminderAt!.toUtc()) : null,
      'reminderSentFlags': reminderSentFlags,
    };
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    if (v is DateTime) return v;
    return null;
  }

  static BookingStatus _bookingStatusFromString(String s) {
    switch (s) {
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'checkedIn':
        return BookingStatus.checkedIn;
      case 'checkedOut':
        return BookingStatus.checkedOut;
      case 'cancelled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }

  static PaymentStatus _paymentStatusFromString(String s) {
    switch (s) {
      case 'pending':
        return PaymentStatus.pending;
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.none;
    }
  }
}
