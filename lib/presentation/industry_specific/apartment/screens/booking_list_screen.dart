import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/currency.dart';
import '../../../../data/models/booking_model.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../providers/business_provider.dart';
import 'booking_detail_screen.dart';

class BookingListScreen extends StatefulWidget {
  final String? apartmentId;

  const BookingListScreen({super.key, this.apartmentId});

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> {
  List<Booking> bookings = [];
  bool _loading = true;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) {
      return;
    }

    setState(() => _loading = true);
    final list = await context.read<BookingProvider>().fetchBookings(
          businessId: businessId,
          apartmentId: widget.apartmentId,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      bookings = list;
      _loading = false;
    });
  }

  List<Booking> get _filteredBookings {
    if (_statusFilter == 'all') {
      return bookings;
    }
    return bookings.where((booking) => booking.status.name == _statusFilter).toList();
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.confirmed:
        return Colors.blue;
      case BookingStatus.checkedIn:
        return Colors.green;
      case BookingStatus.checkedOut:
        return Colors.grey;
      case BookingStatus.cancelled:
        return Colors.red;
    }
  }

  Future<void> _handleAction(Booking booking, String value) async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) {
      return;
    }

    if (value == 'detail') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: booking)),
      );
      return;
    }

    if (value == 'confirm') {
      await context.read<BookingProvider>().updateBookingStatus(
            businessId: businessId,
            bookingId: booking.id,
            status: 'confirmed',
          );
    } else if (value == 'cancel') {
      await context.read<BookingProvider>().cancelBooking(
            businessId: businessId,
            bookingId: booking.id,
          );
    } else if (value == 'checkin') {
      await context.read<BookingProvider>().updateBookingStatus(
            businessId: businessId,
            bookingId: booking.id,
            status: 'checkedIn',
          );
    } else if (value == 'checkout') {
      await context.read<BookingProvider>().updateBookingStatus(
            businessId: businessId,
            bookingId: booking.id,
            status: 'checkedOut',
          );
    }

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visibleBookings = _filteredBookings;

    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in const [
                  'all',
                  'pending',
                  'confirmed',
                  'checkedIn',
                  'checkedOut',
                  'cancelled',
                ])
                  ChoiceChip(
                    label: Text(status == 'all' ? 'All' : status),
                    selected: _statusFilter == status,
                    onSelected: (_) => setState(() => _statusFilter = status),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: visibleBookings.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('No bookings found')),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: visibleBookings.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              final booking = visibleBookings[index];
                              final statusColor = _statusColor(booking.status);
                              return Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: statusColor.withOpacity(0.12),
                                    child: Icon(Icons.home_work_rounded, color: statusColor),
                                  ),
                                  title: Text(
                                    'Booking ${booking.id}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${DateFormat.yMMMd().format(booking.checkInDate)} - ${DateFormat.yMMMd().format(booking.checkOutDate)}',
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${booking.guests} guest(s) • ${formatCurrency(booking.total, decimalDigits: 0)}',
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            booking.status.name,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) => _handleAction(booking, value),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'detail', child: Text('Details')),
                                      PopupMenuItem(value: 'confirm', child: Text('Confirm')),
                                      PopupMenuItem(value: 'checkin', child: Text('Check-in')),
                                      PopupMenuItem(value: 'checkout', child: Text('Check-out')),
                                      PopupMenuItem(
                                        value: 'cancel',
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BookingDetailScreen(booking: booking),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
