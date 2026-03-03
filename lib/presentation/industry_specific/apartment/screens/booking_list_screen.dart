import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../data/models/booking_model.dart';
import 'booking_detail_screen.dart';

class BookingListScreen extends StatefulWidget {
  final String? apartmentId;
  const BookingListScreen({Key? key, this.apartmentId}) : super(key: key);

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> {
  List<Booking> bookings = [];
  bool _loading = true;

  Future<void> _load() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) return;
    final list = await context.read<BookingProvider>().fetchBookings(businessId: businessId, apartmentId: widget.apartmentId);
    setState(() {
      bookings = list;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemBuilder: (_, idx) {
                final b = bookings[idx];
                return ListTile(
                  title: Text('#${b.id} • ${b.status.toString().split('.').last}'),
                  subtitle: Text('${b.checkInDate.toLocal()} - ${b.checkOutDate.toLocal()} • ₦${b.total.toStringAsFixed(2)}'),
                  trailing: PopupMenuButton<String>(onSelected: (v) async {
                    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
                    if (businessId == null) return;
                    if (v == 'confirm') {
                      await context.read<BookingProvider>().updateBookingStatus(businessId: businessId, bookingId: b.id, status: 'confirmed');
                      _load();
                    } else if (v == 'cancel') {
                      await context.read<BookingProvider>().cancelBooking(businessId: businessId, bookingId: b.id);
                      _load();
                    } else if (v == 'checkin') {
                      await context.read<BookingProvider>().updateBookingStatus(businessId: businessId, bookingId: b.id, status: 'checkedIn');
                      _load();
                    } else if (v == 'checkout') {
                      await context.read<BookingProvider>().updateBookingStatus(businessId: businessId, bookingId: b.id, status: 'checkedOut');
                      _load();
                    }
                  }, itemBuilder: (_) => [
                    const PopupMenuItem(value: 'confirm', child: Text('Confirm')),
                    const PopupMenuItem(value: 'checkin', child: Text('Check-in')),
                    const PopupMenuItem(value: 'checkout', child: Text('Check-out')),
                    const PopupMenuItem(value: 'cancel', child: Text('Cancel', style: TextStyle(color: Colors.red))),
                    const PopupMenuItem(value: 'detail', child: Text('Details')),
                  ]),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b))),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: bookings.length,
            ),
    );
  }
}
