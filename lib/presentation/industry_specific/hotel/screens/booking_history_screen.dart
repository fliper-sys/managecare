import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/hotel_provider.dart';

class BookingHistoryScreen extends StatefulWidget {
  final String? roomId;

  const BookingHistoryScreen({super.key, this.roomId});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  String _status = 'all';
  String _period = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HotelProvider>();
    final room = widget.roomId == null
        ? null
        : provider.getRoomById(widget.roomId!);
    final cutoff = switch (_period) {
      '30d' => DateTime.now().subtract(const Duration(days: 30)),
      '90d' => DateTime.now().subtract(const Duration(days: 90)),
      'year' => DateTime.now().subtract(const Duration(days: 365)),
      _ => null,
    };
    final history = provider.reservations.where((reservation) {
      if (widget.roomId != null && reservation.roomId != widget.roomId) {
        return false;
      }
      if (_status != 'all' && reservation.status != _status) return false;
      if (cutoff != null && reservation.checkIn.isBefore(cutoff)) return false;
      if (_query.trim().isNotEmpty) {
        final query = _query.trim().toLowerCase();
        final roomNumber =
            provider.getRoomById(reservation.roomId)?.number.toLowerCase() ??
                '';
        if (!reservation.guestName.toLowerCase().contains(query) &&
            !reservation.guestPhone.toLowerCase().contains(query) &&
            !roomNumber.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => b.checkIn.compareTo(a.checkIn));
    final paid = history.fold<double>(
      0,
      (sum, booking) => sum + booking.amountPaid,
    );
    final completed = history.where((b) => b.status == 'checked-out').length;
    final cancelled = history.where((b) => b.status == 'cancelled').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(room == null
            ? 'Booking History'
            : 'Room ${room.number} History'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search guest, phone, or room',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        decoration:
                            const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(
                              value: 'confirmed', child: Text('Confirmed')),
                          DropdownMenuItem(
                              value: 'checked-in', child: Text('Checked in')),
                          DropdownMenuItem(
                              value: 'checked-out', child: Text('Checked out')),
                          DropdownMenuItem(
                              value: 'cancelled', child: Text('Cancelled')),
                        ],
                        onChanged: (value) =>
                            setState(() => _status = value ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _period,
                        decoration:
                            const InputDecoration(labelText: 'Date range'),
                        items: const [
                          DropdownMenuItem(
                              value: 'all', child: Text('All time')),
                          DropdownMenuItem(
                              value: '30d', child: Text('Last 30 days')),
                          DropdownMenuItem(
                              value: '90d', child: Text('Last 90 days')),
                          DropdownMenuItem(
                              value: 'year', child: Text('Last year')),
                        ],
                        onChanged: (value) =>
                            setState(() => _period = value ?? 'all'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                _MetricCard(label: 'Bookings', value: '${history.length}'),
                _MetricCard(label: 'Checked out', value: '$completed'),
                _MetricCard(label: 'Cancelled', value: '$cancelled'),
                _MetricCard(label: 'Payments received', value: formatCurrency(paid)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: history.isEmpty
                ? const Center(child: Text('No bookings match these filters.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final booking = history[index];
                      final bookingRoom =
                          provider.getRoomById(booking.roomId);
                      final balance = provider.getReservationBalance(booking);
                      return Card(
                        child: ListTile(
                          title: Text(booking.guestName),
                          subtitle: Text(
                            'Room ${bookingRoom?.number ?? booking.roomId} • '
                            '${booking.checkIn.toLocal().toString().split(' ').first} - '
                            '${booking.checkOut.toLocal().toString().split(' ').first}\n'
                            '${booking.status.toUpperCase()} • '
                            'Paid ${formatCurrency(booking.amountPaid)} • '
                            'Due ${formatCurrency(balance)}',
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            formatCurrency(booking.totalPrice),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
