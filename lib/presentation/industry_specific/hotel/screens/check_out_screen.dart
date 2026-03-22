import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../providers/hotel_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';

class CheckOutScreen extends StatelessWidget {
  const CheckOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HotelProvider>(context);
    final activeCheckIns = provider.checkedInReservations
      ..sort((a, b) => a.checkOut.compareTo(b.checkOut));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-Out'),
        backgroundColor: AppColors.primary,
      ),
      backgroundColor: Colors.grey[50],
      body: activeCheckIns.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.logout, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No active check-ins pending checkout',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: activeCheckIns.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final r = activeCheckIns[index];
                final room = provider.getRoomById(r.roomId) ??
                    Room(
                      id: '',
                      number: 'Unknown',
                      type: '',
                      capacity: 0,
                      pricePerNight: 0,
                      status: 'unknown',
                      amenities: const [],
                      images: const [],
                      floor: 0,
                    );
                final balance = provider.getReservationBalance(r);
                return Card(
                  child: ListTile(
                    title: Text('${r.guestName} - Room ${room.number}'),
                    subtitle: Text(
                      'Checkout: ${DateFormat('MMM d, h:mm a').format(r.checkOut)}\n'
                      'Balance: ${formatCurrency(balance)} - Payment: ${r.paymentStatus.toUpperCase()}',
                    ),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Check-out'),
                      onPressed: () async {
                        await provider.updateReservationStatus(
                          r.id,
                          'checked-out',
                        );
                        await provider.updatePaymentStatus(r.id, 'paid');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${r.guestName} checked out and payment updated',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
