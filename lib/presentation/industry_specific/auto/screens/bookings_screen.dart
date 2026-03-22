import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/auto_provider.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings'), backgroundColor: AppColors.primary),
      body: Consumer<AutoProvider>(builder: (context, provider, _) {
        if (provider.isLoadingData) return const Center(child: CircularProgressIndicator());
        if (provider.dataError != null) return Center(child: Text(provider.dataError!));
        final bookings = provider.bookings;
        if (bookings.isEmpty) return const Center(child: Text('No bookings'));
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: bookings.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final b = bookings[index];
            final date = (b['bookingDate'] is Timestamp)
                ? (b['bookingDate'] as Timestamp).toDate().toString().split(' ')[0]
                : (b['bookingDate']?.toString() ?? '');
            return ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text('Booking #${b['bookingId'] as String? ?? b['id']}'),
              subtitle: Text('Date: $date'),
              trailing: ElevatedButton(
                onPressed: () => _showBookingDetails(context, b),
                child: const Text('Details'),
              ),
              onTap: () => _showBookingDetails(context, b),
            );
          },
        );
      }),
    );
  }

  void _showBookingDetails(BuildContext context, Map<String, dynamic> booking) {
    DateTime? bookingDate;
    final rawDate = booking['bookingDate'];
    if (rawDate is Timestamp) {
      bookingDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      bookingDate = rawDate;
    } else if (rawDate is String) {
      bookingDate = DateTime.tryParse(rawDate);
    }

    final vehicleText = [
      booking['vehicleMake'],
      booking['vehicleModel'],
      booking['licensePlate']
    ].where((e) => (e ?? '').toString().trim().isNotEmpty).join(' ');

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Booking #${booking['bookingId'] as String? ?? booking['id']}',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (bookingDate != null)
                Text('Date: ${DateFormat('MMM d, yyyy h:mm a').format(bookingDate)}'),
              if ((booking['customerName'] ?? '').toString().isNotEmpty)
                Text('Customer: ${booking['customerName']}'),
              if ((booking['customerPhone'] ?? '').toString().isNotEmpty)
                Text('Phone: ${booking['customerPhone']}'),
              if (vehicleText.isNotEmpty) Text('Vehicle: $vehicleText'),
              if ((booking['serviceType'] ?? '').toString().isNotEmpty)
                Text('Service: ${booking['serviceType']}'),
              if ((booking['status'] ?? '').toString().isNotEmpty)
                Text('Status: ${booking['status']}'),
              if ((booking['notes'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Notes: ${booking['notes']}'),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

