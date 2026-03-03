import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/booking_model.dart';
import '../../../../providers/payment_provider.dart';
import '../../../../providers/business_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/repositories/booking_repository_impl.dart';

class BookingDetailScreen extends StatefulWidget {
  final Booking booking;
  final bool autoStartPayment;
  const BookingDetailScreen({Key? key, required this.booking, this.autoStartPayment = false}) : super(key: key);

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late Booking _booking;
  bool _autoPayInProgress = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    if (widget.autoStartPayment) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPay());
    }
  }

  Future<void> _maybeAutoPay() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id ?? '';
    if (businessId.isEmpty) return;
    final depositOnly = _booking.depositAmount > 0 && _booking.depositAmount < _booking.total;
    setState(() => _autoPayInProgress = true);

    final pp = context.read<PaymentProvider>();
    final success = await pp.payForBooking(
      context: context,
      booking: _booking,
      businessId: businessId,
      customerEmail: _booking.tenantId.contains('@') ? _booking.tenantId : null,
      customerName: null,
      depositOnly: depositOnly,
    );

    if (success) {
      // Refresh booking from server to reflect updates
      try {
        final repo = BookingRepositoryImpl();
        final refreshed = await repo.getBooking(businessId: businessId, bookingId: _booking.id);
        if (refreshed != null) {
          setState(() => _booking = refreshed);
        }
      } catch (e) {
        // ignore
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successful')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pp.error ?? 'Payment failed')));
    }

    setState(() => _autoPayInProgress = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Booking #${_booking.id}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_autoPayInProgress) const LinearProgressIndicator(),
          Text('Guest: ${_booking.tenantId}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Period: ${_booking.checkInDate.toLocal()} — ${_booking.checkOutDate.toLocal()}'),
          const SizedBox(height: 8),
          Text('Nights: ${_booking.nights}  Guests: ${_booking.guests}'),
          const SizedBox(height: 16),
          Text('Total: ₦${_booking.total.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          Text('Payment status: ${_booking.paymentStatus.toString().split('.').last}'),
          const SizedBox(height: 16),
          if (_booking.receiptPdfPath != null) ElevatedButton.icon(onPressed: () async {
                final url = _booking.receiptPdfPath!;
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open receipt')));
                }
              }, icon: const Icon(Icons.picture_as_pdf), label: const Text('Open Receipt')),
          const SizedBox(height: 8),
          Consumer<PaymentProvider>(builder: (context, pp, _) {
            final isPaid = _booking.paymentStatus.toString().split('.').last == 'paid';
            final businessId = context.read<BusinessProvider>().currentBusiness?.id ?? '';
            if (isPaid) return const SizedBox.shrink();
            return pp.isProcessing
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: () async {
                      final success = await pp.payForBooking(
                        context: context,
                        booking: _booking,
                        businessId: businessId,
                        customerEmail: _booking.tenantId.contains('@') ? _booking.tenantId : null,
                        customerName: null,
                        depositOnly: _booking.depositAmount > 0 && _booking.depositAmount < _booking.total,
                      );
                      if (success) {
                        // Refresh booking
                        try {
                          final repo = BookingRepositoryImpl();
                          final refreshed = await repo.getBooking(businessId: businessId, bookingId: _booking.id);
                          if (refreshed != null) setState(() => _booking = refreshed);
                        } catch (e) {}
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successful')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pp.error ?? 'Payment failed')));
                      }
                    },
                    icon: const Icon(Icons.payment),
                    label: const Text('Pay Now'),
                  );
          }),
        ]),
      ),
    );
  }
}
