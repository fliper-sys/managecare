import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';

import '../../../../providers/hotel_provider.dart';
import 'package:intl/intl.dart';
import '../../../../services/receipt_manager.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String _filterStatus = 'all'; 
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['initialFilter'] is String) {
        _filterStatus = args['initialFilter'] as String;
      }
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HotelProvider>(context);
    List<Reservation> reservations = provider.reservations;

    // Apply filters
    if (_filterStatus != 'all') {
      reservations =
          reservations.where((r) => r.status == _filterStatus).toList();
    }

    // Sort by check-in date
    reservations.sort((a, b) => b.checkIn.compareTo(a.checkIn));

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      appBar: AppBar(
        title: const Text(
          'Reservations',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterPill('All', 'all'),
                  _buildFilterPill('Confirmed', 'confirmed'),
                  _buildFilterPill('Checked-in', 'checked-in'),
                  _buildFilterPill('Checked-out', 'checked-out'),
                  _buildFilterPill('Cancelled', 'cancelled'),
                ],
              ),
            ),
          ),
          
          // Reservations List
          Expanded(
            child: reservations.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: reservations.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final reservation = reservations[index];
                      // Handle case where room might have been deleted/null safely
                      final room = provider.rooms.firstWhere(
                          (r) => r.id == reservation.roomId,
                          orElse: () => Room(id: '0', number: '???', type: 'Unknown', capacity: 0, pricePerNight: 0, amenities: [], status: '', images: [], floor: 0)); // Fallback
                      
                      return _buildTicketCard(
                        context,
                        reservation,
                        room,
                        provider,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 4,
        onPressed: () => _showNewReservationDialog(context, provider),
        label: const Text('New Booking', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterPill(String label, String value) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _filterStatus = value),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_today_outlined,
                size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            'No reservations found',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing filters or add a new one',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.blue;
      case 'checked-in': return Colors.green;
      case 'checked-out': return Colors.grey;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildTicketCard(
    BuildContext context,
    Reservation reservation,
    Room room,
    HotelProvider provider,
  ) {
    final statusColor = _getStatusColor(reservation.status);
    final checkInDay = DateFormat('d').format(reservation.checkIn);
    final checkInMonth = DateFormat('MMM').format(reservation.checkIn);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showReservationDetails(context, reservation, room, provider),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Left Side: Date Box
                Container(
                  width: 60,
                  height: 70,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        checkInDay,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        checkInMonth.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Middle: Guest & Room Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              reservation.guestName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              reservation.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.door_front_door_outlined, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Room ${room.number} (${room.type})',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.nights_stay_outlined, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${reservation.nights} nights',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${reservation.totalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Right Arrow
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReservationDetails(
    BuildContext context,
    Reservation reservation,
    Room room,
    HotelProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Reservation Details',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Guest
                    _buildSectionHeader('Guest Information'),
                    _buildDetailRow('Guest Name', reservation.guestName, Icons.person_outline),
                    _buildDetailRow('Email', reservation.guestEmail, Icons.email_outlined),
                    _buildDetailRow('Phone', reservation.guestPhone, Icons.phone_outlined),
                    _buildDetailRow('Party Size', 
                      '${reservation.adults} Adults, ${reservation.children} Kids', 
                      Icons.group_outlined
                    ),

                    const SizedBox(height: 24),
                    
                    // Section 2: Stay
                    _buildSectionHeader('Stay Details'),
                    _buildDetailRow('Room', '${room.emoji} ${room.number} (${room.type})', Icons.meeting_room_outlined),
                    Row(
                      children: [
                        Expanded(child: _buildDateBox('Check-in', reservation.checkIn)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.arrow_forward, color: Colors.grey),
                        ),
                        Expanded(child: _buildDateBox('Check-out', reservation.checkOut)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (reservation.specialRequests.isNotEmpty) ...[
                      const Text('Special Requests:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.yellow[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.yellow[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: reservation.specialRequests.map((req) => 
                            Text('• $req', style: TextStyle(color: Colors.orange[900]))
                          ).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Section 3: Financials
                    _buildSectionHeader('Payment Info'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          _buildPriceRow('Price per night', '\$${room.pricePerNight}'),
                          _buildPriceRow('Nights', 'x ${reservation.nights}'),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('\$${reservation.totalPrice.toStringAsFixed(2)}', 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(reservation.paymentStatus == 'paid' ? Icons.check_circle : Icons.pending, 
                                size: 16, 
                                color: reservation.paymentStatus == 'paid' ? Colors.green : Colors.orange
                              ),
                              const SizedBox(width: 4),
                              Text('Status: ${reservation.paymentStatus.toUpperCase()}', 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // Action Buttons
                    if (reservation.status == 'confirmed')
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            provider.updateReservationStatus(reservation.id, 'checked-in');
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.login, color: Colors.white),
                          label: const Text('Check-in Guest', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    
                    if (reservation.status == 'checked-in')
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            provider.updateReservationStatus(reservation.id, 'checked-out');
                            
                            // Prepare Sale Map
                            final saleMap = {
                              'id': reservation.id,
                              'items': [
                                {
                                  'name': 'Room ${room.number} (${room.type})',
                                  'quantity': reservation.nights,
                                  'price': room.pricePerNight,
                                }
                              ],
                              'total': reservation.totalPrice,
                              'paymentMethod': reservation.paymentStatus == 'paid' ? 'Card' : 'Cash',
                              'date': DateTime.now().toIso8601String(),
                              'customer': {
                                'name': reservation.guestName,
                                'email': reservation.guestEmail,
                                'phone': reservation.guestPhone,
                              },
                              'numberOfPersons': reservation.adults + reservation.children,
                            };

                            await ReceiptManager.handlePostSale(context, saleMap);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.logout, color: Colors.white),
                          label: const Text('Check-out & Invoice', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.grey[600]),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateBox(String label, DateTime date) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(DateFormat('MMM d').format(date), 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(DateFormat('yyyy').format(date), 
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showNewReservationDialog(BuildContext context, HotelProvider provider) {
    // Dialog logic remains the same, but you might want to replace this with a full screen form later
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Reservation'),
        content: const Text('Reservation creation form would go here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}