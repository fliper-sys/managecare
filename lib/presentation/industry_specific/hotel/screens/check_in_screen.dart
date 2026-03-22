import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../providers/hotel_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';

class CheckInScreen extends StatelessWidget {
  const CheckInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HotelProvider>(context);
    final upcoming = provider
        .getUpcomingCheckIns(const Duration(days: 1))
      ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-In'),
        backgroundColor: AppColors.primary,
      ),
      backgroundColor: Colors.grey[50],
      body: upcoming.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.calendar_today_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No guests ready to check in',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: upcoming.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final r = upcoming[index];
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
                return Card(
                  child: ListTile(
                    title: Text('${r.guestName} - Room ${room.number}'),
                    subtitle: Text(
                      'Check-in: ${DateFormat('MMM d, h:mm a').format(r.checkIn)}\n'
                      'Stay: ${r.nights} night${r.nights == 1 ? '' : 's'} - ${formatCurrency(r.totalPrice)}',
                    ),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text('Check-in'),
                      onPressed: () async {
                        await provider.updateReservationStatus(
                          r.id,
                          'checked-in',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${r.guestName} checked in successfully',
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
