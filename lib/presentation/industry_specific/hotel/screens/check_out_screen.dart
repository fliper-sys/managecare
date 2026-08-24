import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/hotel_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';

class CheckOutScreen extends StatelessWidget {
  const CheckOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HotelProvider>(context);
    final auth = context.watch<AuthProvider>();
    final canManageCheckOut = auth.isOwnerUser ||
        WorkerPermissions.canManageGuestBookings(auth.currentUser?.role ?? '');
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
                final guestSales = provider.getSalesForGuest(r.guestId);
                final roomSales = provider.getSalesForRoom(r.roomId);
                final attachedSales = [...guestSales, ...roomSales]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
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
                            onPressed: !canManageCheckOut
                                ? null
                                : () async {
                                    await provider.checkOutReservationAsPaid(
                                      r.id,
                                    );
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
                        if (attachedSales.isNotEmpty) ...[
                          const Divider(),
                          const Text(
                            'Attached Orders & Sales',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...attachedSales.take(3).map(
                            (sale) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.linked_camera_outlined,
                                    size: 16,
                                    color: Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sale.description?.isNotEmpty == true
                                          ? sale.description!
                                          : 'Attached sale',
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                  ),
                                  Text(
                                    formatCurrency(sale.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
