import 'package:flutter/material.dart';
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
              trailing: ElevatedButton(onPressed: () {}, child: const Text('Details')),
            );
          },
        );
      }),
    );
  }
}

