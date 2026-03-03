import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/models/booking_model.dart';
import '../data/repositories/booking_repository_impl.dart';
import '../services/flutterwave_payment_service.dart';
import '../services/enhanced_pdf_builder.dart';
import '../services/email_service.dart';

class PaymentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore;
  final BookingRepositoryImpl _bookingRepo;
  final FlutterwavePaymentService _flutterwave;
  final EmailService _emailService;

  bool _isProcessing = false;
  String? _error;

  bool get isProcessing => _isProcessing;
  String? get error => _error;

  PaymentProvider({FirebaseFirestore? firestore, BookingRepositoryImpl? bookingRepo, FlutterwavePaymentService? flutterwave, EmailService? emailService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _bookingRepo = bookingRepo ?? BookingRepositoryImpl(firestore: firestore),
        _flutterwave = flutterwave ?? FlutterwavePaymentService(),
        _emailService = emailService ?? EmailService();

  /// Process payment for a booking (deposit or full). Returns true on success.
  Future<bool> payForBooking({
    required BuildContext context,
    required Booking booking,
    required String businessId,
    String? customerEmail,
    String? customerName,
    bool depositOnly = false,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    final amount = depositOnly ? booking.depositAmount : booking.total;
    if (amount <= 0) {
      _error = 'Invalid payment amount';
      _isProcessing = false;
      notifyListeners();
      return false;
    }

    final txRef = 'bk-${booking.id}-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final result = await _flutterwave.processPayment(
        context: context,
        amount: amount,
        currency: booking.currency,
        email: customerEmail ?? 'customer@unknown.local',
        fullName: customerName ?? 'Guest',
        transactionId: txRef,
      );

      if (!result.success) {
        _error = result.message;
        _isProcessing = false;
        notifyListeners();
        return false;
      }

      // Write payment record into bookings/{bookingId}/payments
      final paymentsRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('bookings')
          .doc(booking.id)
          .collection('payments');

      final paymentData = {
        'amount': amount,
        'currency': booking.currency,
        'provider': 'flutterwave',
        'transactionId': result.transactionId,
        'processorResponse': result.processorResponse ?? {},
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await paymentsRef.add(paymentData);

      // Generate receipt PDF
      try {
        final items = [
          {
            'name': 'Booking ${booking.unitId} (${booking.nights} nights)',
            'quantity': booking.nights,
            'total': booking.total,
          }
        ];

        final bytes = await EnhancedPdfBuilder.buildPdf(
          businessName: customerName ?? 'Receipt',
          address: '',
          phone: '',
          orderId: txRef,
          date: DateTime.now(),
          items: items,
          subtotal: booking.subtotal,
          tax: 0.0,
          discount: booking.discount,
          total: amount,
          paymentMethod: 'Flutterwave',
          footerMessage: 'Thank you for your payment',
          currencySymbol: booking.currency,
          showQrCode: true,
          receiptUrlBase: '',
        );

        final filename = '$txRef.pdf';
        final uploadedUrl = await _emailService.uploadBytes(bytes, filename);

        // Update booking doc with payment status and receipt
        final updates = {
          'paymentStatus': 'paid',
          'providerTransactionId': result.transactionId,
          'paidAt': FieldValue.serverTimestamp(),
          'receiptPdfPath': uploadedUrl,
        };

        await _bookingRepo.updateBookingStatus(
          businessId: businessId,
          bookingId: booking.id,
          status: 'confirmed',
          updates: updates,
        );

        // Optionally send email receipt (best-effort)
        try {
          if (customerEmail != null && customerEmail.contains('@')) {
            await _emailService.sendReceiptEmail(
              recipient: customerEmail,
              businessName: 'Your Booking',
              receiptText: 'Payment received for booking ${booking.id}',
              orderId: txRef,
              items: items,
              subtotal: booking.subtotal,
              tax: 0.0,
              total: amount,
              paymentMethod: 'Flutterwave',
              generatePDF: false,
            );
          }
        } catch (e) {
          print('PaymentProvider: failed to send receipt email: $e');
        }

        _isProcessing = false;
        notifyListeners();
        return true;
      } catch (e) {
        print('PaymentProvider: receipt generation/upload failed: $e');
        // Even if receipt failed, mark booking as paid
        final updates = {
          'paymentStatus': 'paid',
          'providerTransactionId': result.transactionId,
          'paidAt': FieldValue.serverTimestamp(),
        };
        await _bookingRepo.updateBookingStatus(
          businessId: businessId,
          bookingId: booking.id,
          status: 'confirmed',
          updates: updates,
        );

        _isProcessing = false;
        notifyListeners();
        return true;
      }
    } catch (e, st) {
      print('PaymentProvider: payment exception: $e\n$st');
      _error = e.toString();
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }
}
