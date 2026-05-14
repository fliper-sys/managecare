import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../providers/hotel_provider.dart';
import '../widgets/guest_card.dart';

class GuestManagementScreen extends StatefulWidget {
  const GuestManagementScreen({super.key});

  @override
  State<GuestManagementScreen> createState() => _GuestManagementScreenState();
}

class _GuestManagementScreenState extends State<GuestManagementScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<HotelProvider>(
      builder: (context, provider, _) {
        final guests = provider.guestProfiles.where((guest) {
          if (_query.trim().isEmpty) return true;
          final q = _query.trim().toLowerCase();
          return (guest['guestName'] as String).toLowerCase().contains(q) ||
              (guest['guestEmail'] as String).toLowerCase().contains(q) ||
              (guest['guestPhone'] as String).toLowerCase().contains(q);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Guest Management'),
            backgroundColor: AppColors.primary,
          ),
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by guest name, email or phone',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: guests.isEmpty
                    ? Center(
                        child: Text(
                          'No guests found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: guests.length,
                        itemBuilder: (context, index) {
                          final guest = guests[index];
                          final reservation =
                              guest['lastReservation'] as Reservation;
                          return GuestCard(
                            guestName: guest['guestName'] as String,
                            room: guest['roomNumber'] as String,
                            checkIn: reservation.checkIn,
                            checkOut: reservation.checkOut,
                            onTap: () => _showGuestDetails(
                              context,
                              guest,
                              provider,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGuestDetails(
    BuildContext context,
    Map<String, dynamic> guest,
    HotelProvider provider,
  ) {
    final reservation = guest['lastReservation'] as Reservation;
    final room = provider.getRoomById(reservation.roomId);
    final guestEmail = (guest['guestEmail'] as String).trim();
    final guestPhone = (guest['guestPhone'] as String).trim();
    final guestName = (guest['guestName'] as String).trim().toLowerCase();
    final relatedReservations = provider.reservations.where((item) {
      if (guestEmail.isNotEmpty) {
        return item.guestEmail.trim().toLowerCase() == guestEmail.toLowerCase();
      }
      if (guestPhone.isNotEmpty) {
        return item.guestPhone.trim() == guestPhone;
      }
      return item.guestName.trim().toLowerCase() == guestName;
    }).toList();

    // --- SALES/ORDERS SECTION PATCH START ---
    final guestSales = provider.getSalesForGuest(reservation.guestId);
    final roomSales = provider.getSalesForRoom(reservation.roomId);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  guest['guestName'] as String,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(guest['guestEmail'] as String),
                const SizedBox(height: 4),
                Text(guest['guestPhone'] as String),
                if ((guest['guestAddress'] as String?)?.trim().isNotEmpty ??
                    false) ...[
                  const SizedBox(height: 4),
                  Text(guest['guestAddress'] as String),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        label: 'Reservations',
                        value: '${guest['reservationCount']}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoTile(
                        label: 'Checked-In',
                        value: '${guest['checkedInCount']}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoTile(
                        label: 'Spend',
                        value:
                            '₦${(guest['totalSpend'] as num).toStringAsFixed(0)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // --- SALES/ORDERS SECTION ---
                const Text('Sales / Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (guestSales.isEmpty && roomSales.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No sales or orders attached.', style: TextStyle(color: Colors.grey)),
                  ),
                if (guestSales.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Guest Sales:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...guestSales.map((sale) => ListTile(
                            leading: const Icon(Icons.person, color: Colors.green),
                            title: Text(sale.description ?? 'Sale'),
                            subtitle: Text('Amount: ₦${sale.amount.toStringAsFixed(2)}'),
                            trailing: Text(sale.status ?? ''),
                          )),
                    ],
                  ),
                if (roomSales.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text('Room Sales:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...roomSales.map((sale) => ListTile(
                            leading: const Icon(Icons.shopping_cart_outlined, color: Colors.blue),
                            title: Text(sale.description ?? 'Sale'),
                            subtitle: Text('Amount: ₦${sale.amount.toStringAsFixed(2)}'),
                            trailing: Text(sale.status ?? ''),
                          )),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Attach Sale/Order'),
                      onPressed: () {
                        // TODO: Implement attach sale/order dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Attach Sale/Order dialog coming soon!')),
                        );
                      },
                    ),
                  ),
                ),
                // --- END SALES/ORDERS SECTION ---

                Text(
                  'Latest Stay',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Room ${room?.number ?? reservation.roomId}'),
                        const SizedBox(height: 8),
                        Text(
                          'Check-in: ${DateFormat('MMM d, yyyy').format(reservation.checkIn)}',
                        ),
                        Text(
                          'Check-out: ${DateFormat('MMM d, yyyy').format(reservation.checkOut)}',
                        ),
                        Text('Status: ${reservation.status}'),
                        Text('Payment: ${reservation.paymentStatus}'),
                        if (reservation.guestNationality.trim().isNotEmpty)
                          Text('Nationality: ${reservation.guestNationality}'),
                        if (reservation.guestIdType.trim().isNotEmpty ||
                            reservation.guestIdNumber.trim().isNotEmpty)
                          Text(
                              'ID: ${reservation.guestIdType} ${reservation.guestIdNumber}'.trim()),
                        if (reservation.nextOfKinName.trim().isNotEmpty)
                          Text(
                              'Next of kin: ${reservation.nextOfKinName} (${reservation.nextOfKinRelationship})'),
                        if (reservation.nextOfKinPhone.trim().isNotEmpty)
                          Text(
                              'Emergency phone: ${reservation.nextOfKinPhone}'),
                        if (reservation.specialRequests.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Special Requests',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...reservation.specialRequests
                              .map((request) => Text(request)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reservation History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 10),
                ...relatedReservations.map((item) {
                  final reservationRoom = provider.getRoomById(item.roomId);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Room ${reservationRoom?.number ?? item.roomId}',
                    ),
                    subtitle: Text(
                      '${DateFormat('MMM d, yyyy').format(item.checkIn)} - ${DateFormat('MMM d, yyyy').format(item.checkOut)}',
                    ),
                    trailing: Text(item.status),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}
