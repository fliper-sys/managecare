import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/hotel_provider.dart';

class FrontDeskScreen extends StatelessWidget {
  const FrontDeskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HotelProvider>(
      builder: (context, provider, _) {
        final arrivals = provider.getArrivalsForDate(DateTime.now());
        final departures = provider.getTodayCheckOuts();
        final checkedIn = provider.checkedInReservations;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Front Desk'),
            backgroundColor: AppColors.primary,
          ),
          backgroundColor: Colors.grey[50],
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Arrivals',
                      value: arrivals.length.toString(),
                      icon: Icons.login,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Departures',
                      value: departures.length.toString(),
                      icon: Icons.logout,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'In-House',
                      value: checkedIn.length.toString(),
                      icon: Icons.hotel,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Today\'s Arrivals',
                actionLabel: 'Reservations',
                onTap: () => Navigator.pushNamed(
                  context,
                  Routes.hotelBookings,
                  arguments: {'initialFilter': 'confirmed'},
                ),
              ),
              const SizedBox(height: 10),
              if (arrivals.isEmpty)
                const _EmptyTile(message: 'No confirmed arrivals for today.')
              else
                ...arrivals.map((reservation) {
                  final room = provider.getRoomById(reservation.roomId);
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F0FF),
                        child: Icon(Icons.person_outline, color: AppColors.primary),
                      ),
                      title: Text(reservation.guestName),
                      subtitle: Text(
                        'Room ${room?.number ?? reservation.roomId} • ${DateFormat('MMM d, h:mm a').format(reservation.checkIn)}',
                      ),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          await provider.updateReservationStatus(
                            reservation.id,
                            'checked-in',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${reservation.guestName} checked in successfully',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Check In'),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Today\'s Departures',
                actionLabel: 'Billing',
                onTap: () => Navigator.pushNamed(context, Routes.hotelBilling),
              ),
              const SizedBox(height: 10),
              if (departures.isEmpty)
                const _EmptyTile(message: 'No guests scheduled for checkout today.')
              else
                ...departures.map((reservation) {
                  final room = provider.getRoomById(reservation.roomId);
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFF3E8),
                        child: Icon(Icons.receipt_long, color: Colors.orange),
                      ),
                      title: Text(reservation.guestName),
                      subtitle: Text(
                        'Room ${room?.number ?? reservation.roomId} • Balance: ₦${provider.getReservationBalance(reservation).toStringAsFixed(0)}',
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        onPressed: () async {
                          await provider.updateReservationStatus(
                            reservation.id,
                            'checked-out',
                          );
                          await provider.updatePaymentStatus(
                            reservation.id,
                            'paid',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${reservation.guestName} checked out successfully',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Check Out'),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'In-House Guests',
                actionLabel: 'Guests',
                onTap: () => Navigator.pushNamed(context, Routes.hotelGuests),
              ),
              const SizedBox(height: 10),
              if (checkedIn.isEmpty)
                const _EmptyTile(message: 'No active guests in house right now.')
              else
                ...checkedIn.take(5).map((reservation) {
                  final room = provider.getRoomById(reservation.roomId);
                  return Card(
                    child: ListTile(
                      title: Text(reservation.guestName),
                      subtitle: Text(
                        'Room ${room?.number ?? reservation.roomId} • Checkout ${DateFormat('MMM d').format(reservation.checkOut)}',
                      ),
                      trailing: Chip(
                        label: Text(
                          reservation.paymentStatus.toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: reservation.paymentStatus == 'paid'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _EmptyTile extends StatelessWidget {
  final String message;

  const _EmptyTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: TextStyle(color: Colors.grey[600])),
    );
  }
}
