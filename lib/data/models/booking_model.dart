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

  factory Booking.fromMap(Map<String, dynamic> data) {
    return Booking(
      id: data['id']?.toString() ?? '',
      unitId: data['unitId'] ?? data['unit_id'] ?? '',
      apartmentId: data['apartmentId'] ?? data['apartment_id'] ?? '',
      tenantId: data['tenantId'] ?? data['tenant_id'] ?? '',
      checkInDate:
          _parseDate(data['checkInDate'] ?? data['check_in_date']) ??
              DateTime.now(),
      checkOutDate:
          _parseDate(data['checkOutDate'] ?? data['check_out_date']) ??
              DateTime.now(),
      nights: _readInt(data['nights']),
      guests: _readInt(data['guests'], fallback: 1),
      status: _bookingStatusFromString(data['status'] ?? 'pending'),
      createdAt:
          _parseDate(data['createdAt'] ?? data['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt'] ?? data['updated_at']),
      subtotal: _readDouble(data['subtotal']),
      depositAmount: _readDouble(data['depositAmount'] ?? data['deposit_amount']),
      discount: _readDouble(data['discount']),
      total: _readDouble(data['total']),
      currency: data['currency'] ?? 'â‚¦',
      paymentStatus: _paymentStatusFromString(
        data['paymentStatus'] ?? data['payment_status'] ?? 'none',
      ),
      paymentMethod: data['paymentMethod'] ?? data['payment_method'],
      providerTransactionId:
          data['providerTransactionId'] ?? data['provider_transaction_id'],
      paidAt: _parseDate(data['paidAt'] ?? data['paid_at']),
      policySnapshot: PolicySnapshot.fromMap(
        data['policySnapshot'] ?? data['policy_snapshot'] ?? {},
      ),
      receiptUrl: data['receiptUrl'] ?? data['receipt_url'],
      receiptPdfPath: data['receiptPdfPath'] ?? data['receipt_pdf_path'],
      nextReminderAt:
          _parseDate(data['nextReminderAt'] ?? data['next_reminder_at']),
      reminderSentFlags:
          (data['reminderSentFlags'] ?? data['reminder_sent_flags']) is Map
              ? Map<String, bool>.from(
                  data['reminderSentFlags'] ?? data['reminder_sent_flags'],
                )
              : null,
    );
  }

  Map<String, dynamic> toApi() {
    return {
      'unitId': unitId,
      'apartmentId': apartmentId,
      'tenantId': tenantId,
      'checkInDate': checkInDate.toUtc().toIso8601String(),
      'checkOutDate': checkOutDate.toUtc().toIso8601String(),
      'nights': nights,
      'guests': guests,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
      'subtotal': subtotal,
      'depositAmount': depositAmount,
      'discount': discount,
      'total': total,
      'currency': currency,
      'paymentStatus': paymentStatus.toString().split('.').last,
      'paymentMethod': paymentMethod,
      'providerTransactionId': providerTransactionId,
      'paidAt': paidAt?.toUtc().toIso8601String(),
      'policySnapshot': policySnapshot.toMap(),
      'receiptUrl': receiptUrl,
      'receiptPdfPath': receiptPdfPath,
      'nextReminderAt': nextReminderAt?.toUtc().toIso8601String(),
      'reminderSentFlags': reminderSentFlags,
    };
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    if (v is DateTime) return v;
    return null;
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value == null) return fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
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
