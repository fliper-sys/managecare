import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../providers/hotel_provider.dart';
import 'package:intl/intl.dart';
import '../../../../services/receipt_manager.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {

    // Section header widget for details modal
    Widget _buildSectionHeader(String title) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      );
    }
  String _filterStatus = 'all';
  String _searchQuery = '';
  String _roomSearchQuery = '';
  bool _initialized = false;
  bool _isCreatingReservation = false;
  bool _prefillDialogQueued = false;
  Map<String, dynamic>? _pendingPrefillGuest;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _roomSearchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['initialFilter'] is String) {
        _filterStatus = args['initialFilter'] as String;
      }
      if (args is Map && args['prefillGuest'] is Map) {
        _pendingPrefillGuest =
            Map<String, dynamic>.from(args['prefillGuest'] as Map);
      }
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = Provider.of<HotelProvider>(context);
    final auth = context.watch<AuthProvider>();
    final canManageBookings = auth.isOwnerUser ||
        WorkerPermissions.canManageGuestBookings(auth.currentUser?.role ?? '');
    List<Reservation> reservations = provider.reservations;
    List<Room> allRooms = provider.rooms;

    if (_pendingPrefillGuest != null && !_prefillDialogQueued) {
      _prefillDialogQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final guest = _pendingPrefillGuest;
        _pendingPrefillGuest = null;
        if (guest != null) {
          _showNewReservationDialog(
            context,
            provider,
            prefilledGuest: guest,
          );
        }
      });
    }

    // Apply status filter
    if (_filterStatus != 'all') {
      reservations =
          reservations.where((r) => r.status == _filterStatus).toList();
    }

    // Apply guest search filter
    if (_searchQuery.isNotEmpty) {
      final lower = _searchQuery.trim().toLowerCase();
      reservations = reservations.where((r) {
        return r.guestName.toLowerCase().contains(lower) ||
            r.roomId.toLowerCase().contains(lower) ||
            r.guestEmail.toLowerCase().contains(lower) ||
            r.guestPhone.toLowerCase().contains(lower);
      }).toList();
    }

    // Room search logic
    List<Room> filteredRooms = allRooms;
    if (_roomSearchQuery.isNotEmpty) {
      final lower = _roomSearchQuery.trim().toLowerCase();
      filteredRooms = allRooms.where((room) {
        return room.number.toLowerCase().contains(lower) ||
            room.type.toLowerCase().contains(lower);
      }).toList();
    }

    // Sort by check-in date
    reservations.sort((a, b) => b.checkIn.compareTo(a.checkIn));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Check-in & Reservations',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: theme.cardColor,
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

          // Guest/Reservation Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search guest, email, phone or room...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                fillColor: theme.cardColor,
                filled: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Room Status Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _roomSearchController,
              onChanged: (value) => setState(() => _roomSearchQuery = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.meeting_room_outlined),
                hintText: 'Search room number or type for status...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                fillColor: theme.cardColor,
                filled: true,
                suffixIcon: _roomSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _roomSearchController.clear();
                          setState(() => _roomSearchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Room Status List (if searching rooms)
          if (_roomSearchQuery.isNotEmpty)
            Expanded(
              child: filteredRooms.isEmpty
                  ? Center(child: Text('No rooms found'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredRooms.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final room = filteredRooms[index];
                        final status =
                            room.status.isNotEmpty ? room.status : 'free';
                        return ListTile(
                          leading: Icon(Icons.meeting_room_outlined,
                              color: Colors.blueGrey),
                          title: Text('Room ${room.number} (${room.type})'),
                          subtitle: Text(
                              'Status: ${status[0].toUpperCase()}${status.substring(1)}'),
                          trailing: ElevatedButton(
                            onPressed: canManageBookings && status == 'free'
                                ? () => _showNewReservationDialog(
                                    context, provider,
                                    preselectedRoomId: room.id)
                                : null,
                            child: const Text('Book'),
                          ),
                        );
                      },
                    ),
            ),

          // Reservations List (if not searching rooms)
          if (_roomSearchQuery.isEmpty)
            Expanded(
              child: reservations.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: reservations.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final reservation = reservations[index];
                        final room = provider.getRoomById(reservation.roomId) ??
                            Room(
                              id: '0',
                              number: '???',
                              type: 'Unknown',
                              capacity: 0,
                              pricePerNight: 0,
                              amenities: const [],
                              status: '',
                              images: const [],
                              floor: 0,
                            );
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
        onPressed: canManageBookings
            ? () => _showNewReservationDialog(context, provider)
            : null,
        label: const Text('Book/Check-in',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
      case 'confirmed':
        return Colors.blue;
      case 'checked-in':
        return Colors.green;
      case 'checked-out':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
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
        color: Theme.of(context).cardColor,
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
          onTap: () =>
              _showReservationDetails(context, reservation, room, provider),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
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
                          Icon(Icons.door_front_door_outlined,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Room ${room.number} (${room.type})',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.nights_stay_outlined,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${reservation.nights} nights',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatCurrency(reservation.totalPrice),
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
    final folioTotal = provider.getReservationBalance(reservation);
    final folioCharges = provider.getFolioChargesForReservation(reservation.id);

    final roomSales = provider.getSalesForRoom(room.id);
    final guestSales = provider.getSalesForGuest(reservation.guestId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                                    style:
                                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                                  _buildDetailRow('Guest Name', reservation.guestName,
                                      Icons.person_outline),
                                  _buildDetailRow(
                                      'Email', reservation.guestEmail, Icons.email_outlined),
                                  _buildDetailRow(
                                      'Phone', reservation.guestPhone, Icons.phone_outlined),
                                  _buildDetailRow(
                                      'Party Size',
                                      '${reservation.adults} Adults, ${reservation.children} Kids',
                                      Icons.group_outlined),
                                  _buildDetailRow(
                                      'Address',
                                      _displayValue(reservation.guestAddress),
                                      Icons.home_outlined),
                                  _buildDetailRow(
                                      'Booking Source',
                                      _displayValue(reservation.bookingSource),
                                      Icons.source_outlined),

                                  const SizedBox(height: 24),

                                  _buildSectionHeader('Identity & Emergency Contact'),
                                  _buildDetailRow(
                                      'Nationality',
                                      _displayValue(reservation.guestNationality),
                                      Icons.flag_outlined),
                                  _buildDetailRow(
                                      'ID Type',
                                      _displayValue(reservation.guestIdType),
                                      Icons.badge_outlined),
                                  _buildDetailRow(
                                      'ID Number',
                                      _displayValue(reservation.guestIdNumber),
                                      Icons.credit_card_outlined),
                                  _buildDetailRow(
                                      'Next of Kin',
                                      _displayValue(reservation.nextOfKinName),
                                      Icons.person_2_outlined),
                                  _buildDetailRow(
                                      'Next of Kin Phone',
                                      _displayValue(reservation.nextOfKinPhone),
                                      Icons.call_outlined),
                                  _buildDetailRow(
                                      'Relationship',
                                      _displayValue(reservation.nextOfKinRelationship),
                                      Icons.family_restroom_outlined),

                                  const SizedBox(height: 24),

                                  // Section 2: Stay
                                  _buildSectionHeader('Stay Details'),
                                  _buildDetailRow('Room', '${room.number} (${room.type})',
                                      Icons.meeting_room_outlined),
                                  Row(
                                    children: [
                                      Expanded(
                                          child:
                                              _buildDateBox('Check-in', reservation.checkIn)),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 12),
                                        child: Icon(Icons.arrow_forward, color: Colors.grey),
                                      ),
                                      Expanded(
                                          child: _buildDateBox(
                                              'Check-out', reservation.checkOut)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (reservation.specialRequests.isNotEmpty) ...[
                                    const Text('Special Requests:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 13)),
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
                                        children: reservation.specialRequests
                                            .map((req) => Text('- $req',
                                                style: TextStyle(color: Colors.orange[900])))
                                            .toList(),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 24),

                                  // --- SALES/ORDERS SECTION ---
                                  _buildSectionHeader('Sales / Orders'),
                                  if (roomSales.isEmpty && guestSales.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text('No sales or orders attached.', style: TextStyle(color: Colors.grey[600])),
                                    ),
                                  if (roomSales.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Room Sales:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ...roomSales.map((sale) => ListTile(
                                              leading: const Icon(Icons.shopping_cart_outlined, color: Colors.blue),
                                              title: Text(sale.description ?? 'Sale'),
                                              subtitle: Text('Amount: ${formatCurrency(sale.finalAmount)}'),
                                              trailing: Text(sale.status),
                                            )),
                                      ],
                                    ),
                                  if (guestSales.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 8),
                                        const Text('Guest Sales:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ...guestSales.map((sale) => ListTile(
                                              leading: const Icon(Icons.person, color: Colors.green),
                                              title: Text(sale.description ?? 'Sale'),
                                              subtitle: Text('Amount: ${formatCurrency(sale.finalAmount)}'),
                                              trailing: Text(sale.status),
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
                                        _buildPriceRow('Price per night',
                                            formatCurrency(room.pricePerNight)),
                                        _buildPriceRow('Nights', 'x ${reservation.nights}'),
                                        if (folioCharges.isNotEmpty) const Divider(),
                                        if (folioCharges.isNotEmpty)
                                          ...folioCharges.take(5).map(
                                                (charge) => _buildPriceRow(
                                                  charge.description,
                                                  formatCurrency(charge.amount),
                                                ),
                                              ),
                                        const Divider(),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Total',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16)),
                                            Text(formatCurrency(folioTotal),
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: AppColors.primary)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                                reservation.paymentStatus == 'paid'
                                                    ? Icons.check_circle
                                                    : Icons.pending,
                                                size: 16,
                                                color: reservation.paymentStatus == 'paid'
                                                    ? Colors.green
                                                    : Colors.orange),
                                            const SizedBox(width: 4),
                                            Text(
                                                'Status: ${reservation.paymentStatus.toUpperCase()}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold)),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 30),

                                  // Action Buttons
                                  if (reservation.status == 'confirmed' || reservation.status == 'checked-in')
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(color: AppColors.primary),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: () async {
                                          await _showAddChargeDialog(
                                            context,
                                            provider: provider,
                                            reservation: reservation,
                                            room: room,
                                          );
                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                        },
                                        icon: const Icon(Icons.receipt_long),
                                        label: const Text(
                                          'Add Extra Charge',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),

                                  if (reservation.status == 'confirmed' || reservation.status == 'checked-in')
                                    const SizedBox(height: 12),

                                  if (reservation.status == 'confirmed' || reservation.status == 'checked-in')
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.deepPurple,
                                          side: const BorderSide(color: Colors.deepPurple),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: () async {
                                          await _showExtendStayDialog(
                                            context,
                                            provider: provider,
                                            reservation: reservation,
                                          );
                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                        },
                                        icon: const Icon(Icons.hotel),
                                        label: const Text(
                                          'Extend Stay',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),

                                  if (reservation.status == 'confirmed' || reservation.status == 'checked-in')
                                    const SizedBox(height: 12),

                                  if (reservation.status == 'confirmed')
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () async {
                                          await provider.updateReservationStatus(
                                              reservation.id, 'checked-in');
                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                        },
                                        icon: const Icon(Icons.login, color: Colors.white),
                                        label: const Text('Check-in Guest',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),

                                  if (reservation.status == 'checked-in')
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.purple,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () async {
                                          await provider.updateReservationStatus(
                                              reservation.id, 'checked-out');

                                          final updatedReservation =
                                              provider.reservations.firstWhere(
                                            (item) => item.id == reservation.id,
                                            orElse: () =>
                                                reservation.copyWith(status: 'checked-out'),
                                          );
                                          final saleMap =
                                              provider.buildReservationSalePayload(
                                            updatedReservation,
                                            room: room,
                                            paymentMethod:
                                                updatedReservation.paymentStatus == 'paid'
                                                    ? 'hotel_checkout'
                                                    : 'pay_at_checkout',
                                          );

                                          await ReceiptManager.handlePostSale(
                                              context, saleMap);
                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                        },
                                        icon: const Icon(Icons.logout, color: Colors.white),
                                        label: const Text('Check-out & Invoice',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),

                                  if (reservation.status != 'cancelled' && reservation.status != 'checked-out')
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () async {
                                          await provider.cancelReservation(reservation.id);
                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                        },
                                        icon: const Icon(Icons.cancel, color: Colors.red),
                                        label: const Text('Cancel Booking',
                                            style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),

                                  if (reservation.paymentStatus != 'paid')
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blueAccent,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () async {
                                          await provider.updatePaymentStatus(
                                              reservation.id, 'paid');
                                          final updatedReservation =
                                              provider.reservations.firstWhere(
                                            (item) => item.id == reservation.id,
                                            orElse: () =>
                                                reservation.copyWith(paymentStatus: 'paid'),
                                          );
                                          final saleMap =
                                              provider.buildReservationSalePayload(
                                            updatedReservation,
                                            room: room,
                                            paymentMethod: 'hotel_billing',
                                          );
                                          if (!context.mounted) return;
                                          await ReceiptManager.handlePostSale(
                                              context, saleMap);
                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                        },
                                        icon: const Icon(Icons.payment, color: Colors.white),
                                        label: const Text('Mark as Paid',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
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
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Future<void> _showAddChargeDialog(
    BuildContext context, {
    required HotelProvider provider,
    required Reservation reservation,
    required Room room,
  }) async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    String category = 'extra_order';

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Add Extra Charge'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  items: const [
                    DropdownMenuItem(
                      value: 'extra_order',
                      child: Text('Extra Order'),
                    ),
                    DropdownMenuItem(
                      value: 'room_service',
                      child: Text('Room Service'),
                    ),
                    DropdownMenuItem(
                      value: 'mini_bar',
                      child: Text('Mini Bar'),
                    ),
                    DropdownMenuItem(
                      value: 'laundry',
                      child: Text('Laundry'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('Other'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) category = value;
                  },
                  decoration: const InputDecoration(labelText: 'Charge type'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the extra order or charge',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid charge amount')),
      );
      return;
    }

    await provider.addReservationCharge(
      reservationId: reservation.id,
      description: descriptionController.text.trim().isEmpty
          ? 'Extra charge for Room ${room.number}'
          : descriptionController.text.trim(),
      amount: amount,
      category: category,
      source: 'manual',
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${formatCurrency(amount)} to ${reservation.guestName}\'s folio',
        ),
      ),
    );
  }

  Future<void> _showExtendStayDialog(
    BuildContext context, {
    required HotelProvider provider,
    required Reservation reservation,
  }) async {
    final reasonController = TextEditingController();
    final nextDate = await showDatePicker(
      context: context,
      initialDate: reservation.checkOut.add(const Duration(days: 1)),
      firstDate: reservation.checkOut.add(const Duration(days: 1)),
      lastDate: reservation.checkOut.add(const Duration(days: 30)),
    );

    if (nextDate == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Extend Stay'),
            content: TextField(
              controller: reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Extension note',
                hintText: 'Optional reason or note for the extension',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Extend'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await provider.extendReservationStay(
      reservationId: reservation.id,
      newCheckOut: nextDate,
      extensionReason: reasonController.text.trim(),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${reservation.guestName} is now booked until ${DateFormat('MMM d, yyyy').format(nextDate)}',
        ),
      ),
    );
  }

  String _displayValue(String? value, {String fallback = 'Not provided'}) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  void _showNewReservationDialog(BuildContext context, HotelProvider provider,
      {String? preselectedRoomId, Map<String, dynamic>? prefilledGuest}) {
    _prefillDialogQueued = false;
    final _formKey = GlobalKey<FormState>();
    final registeredGuests = provider.guestProfiles;
    final guestNameCtrl = TextEditingController(
      text: (prefilledGuest?['guestName'] ?? '').toString(),
    );
    final guestEmailCtrl = TextEditingController(
      text: (prefilledGuest?['guestEmail'] ?? '').toString(),
    );
    final guestPhoneCtrl = TextEditingController(
      text: (prefilledGuest?['guestPhone'] ?? '').toString(),
    );
    final guestAddressCtrl = TextEditingController(
      text: (prefilledGuest?['guestAddress'] ?? '').toString(),
    );
    final guestNationalityCtrl = TextEditingController(
      text: (prefilledGuest?['guestNationality'] ?? '').toString(),
    );
    final guestIdTypeCtrl = TextEditingController(
      text: (prefilledGuest?['guestIdType'] ?? '').toString(),
    );
    final guestIdNumberCtrl = TextEditingController(
      text: (prefilledGuest?['guestIdNumber'] ?? '').toString(),
    );
    final nextOfKinNameCtrl = TextEditingController(
      text: (prefilledGuest?['nextOfKinName'] ?? '').toString(),
    );
    final nextOfKinPhoneCtrl = TextEditingController(
      text: (prefilledGuest?['nextOfKinPhone'] ?? '').toString(),
    );
    final nextOfKinRelationshipCtrl = TextEditingController(
      text: (prefilledGuest?['nextOfKinRelationship'] ?? '').toString(),
    );
    final bookingSourceCtrl = TextEditingController(
      text: (prefilledGuest?['bookingSource'] ?? 'walk-in').toString(),
    );
    final adultsCtrl = TextEditingController(text: '1');
    final childrenCtrl = TextEditingController(text: '0');
    final requestsCtrl = TextEditingController();
    // Vehicle info controllers
    final vehiclePlateCtrl = TextEditingController();
    final vehicleMakeCtrl = TextEditingController();
    final vehicleModelCtrl = TextEditingController();
    final vehicleColorCtrl = TextEditingController();

    DateTime checkIn = DateTime.now().add(const Duration(days: 1));
    DateTime checkOut = DateTime.now().add(const Duration(days: 2));
    String? selectedGuestKey = prefilledGuest == null
        ? null
        : provider.resolveGuestIdentityKey(
            guestName: (prefilledGuest['guestName'] ?? '').toString(),
            guestEmail: (prefilledGuest['guestEmail'] ?? '').toString(),
            guestPhone: (prefilledGuest['guestPhone'] ?? '').toString(),
          );
    String? selectedRoomId = preselectedRoomId ??
        (provider.getAvailableRoomsForDates(checkIn, checkOut).isNotEmpty
            ? provider.getAvailableRoomsForDates(checkIn, checkOut).first.id
            : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text('New Booking',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (registeredGuests.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            value: selectedGuestKey,
                            items: registeredGuests.map((guest) {
                              final key = provider.resolveGuestIdentityKey(
                                guestName: (guest['guestName'] ?? '').toString(),
                                guestEmail: (guest['guestEmail'] ?? '').toString(),
                                guestPhone: (guest['guestPhone'] ?? '').toString(),
                              );
                              final tier = (guest['guestTier'] ?? 'registered')
                                  .toString()
                                  .replaceAll('_', ' ')
                                  .toUpperCase();
                              return DropdownMenuItem(
                                value: key,
                                child: Text('${guest['guestName']} • $tier'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              final guest = registeredGuests.cast<Map<String, dynamic>?>().firstWhere(
                                    (item) =>
                                        item != null &&
                                        provider.resolveGuestIdentityKey(
                                          guestName: (item['guestName'] ?? '').toString(),
                                          guestEmail: (item['guestEmail'] ?? '').toString(),
                                          guestPhone: (item['guestPhone'] ?? '').toString(),
                                        ) ==
                                            value,
                                    orElse: () => null,
                                  );
                              setState(() {
                                selectedGuestKey = value;
                                guestNameCtrl.text =
                                    (guest?['guestName'] ?? '').toString();
                                guestEmailCtrl.text =
                                    (guest?['guestEmail'] ?? '').toString();
                                guestPhoneCtrl.text =
                                    (guest?['guestPhone'] ?? '').toString();
                                guestAddressCtrl.text =
                                    (guest?['guestAddress'] ?? '').toString();
                                guestNationalityCtrl.text =
                                    (guest?['guestNationality'] ?? '').toString();
                                guestIdTypeCtrl.text =
                                    (guest?['guestIdType'] ?? '').toString();
                                guestIdNumberCtrl.text =
                                    (guest?['guestIdNumber'] ?? '').toString();
                                nextOfKinNameCtrl.text =
                                    (guest?['nextOfKinName'] ?? '').toString();
                                nextOfKinPhoneCtrl.text =
                                    (guest?['nextOfKinPhone'] ?? '').toString();
                                nextOfKinRelationshipCtrl.text =
                                    (guest?['nextOfKinRelationship'] ?? '').toString();
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Registered Guest',
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Text(
                          'Primary Guest',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: guestNameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Guest Name'),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Guest name is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: guestEmailCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Guest Email'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Email is required';
                            if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}")
                                .hasMatch(value)) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: guestPhoneCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Guest Phone'),
                          keyboardType: TextInputType.phone,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Phone is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: guestAddressCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Guest Address'),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Address is required'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Vehicle Information',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: vehiclePlateCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Plate Number'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: vehicleMakeCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'Make'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: vehicleModelCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'Model'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: vehicleColorCtrl,
                          decoration: const InputDecoration(labelText: 'Color'),
                        ),
                        const Text(
                          'Identity & Emergency Contact',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: guestNationalityCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Nationality'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: guestIdTypeCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'ID Type'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: guestIdNumberCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'ID Number'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nextOfKinNameCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Next of Kin Name'),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Next of kin name is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: nextOfKinPhoneCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Next of Kin Phone'),
                                keyboardType: TextInputType.phone,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Phone is required'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: nextOfKinRelationshipCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Relationship'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: bookingSourceCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Booking Source'),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Stay Details',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedRoomId,
                          items: provider
                              .getAvailableRoomsForDates(checkIn, checkOut)
                              .map((room) {
                            return DropdownMenuItem(
                              value: room.id,
                              child: Text('${room.number} (${room.type})'),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => selectedRoomId = val),
                          hint: const Text('Select Room'),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Pick a room'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Check-in'),
                                subtitle: Text(
                                    DateFormat('yyyy-MM-dd').format(checkIn)),
                                trailing: const Icon(Icons.calendar_today),
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: checkIn,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      checkIn = date;
                                      if (!checkOut.isAfter(checkIn)) {
                                        checkOut = checkIn
                                            .add(const Duration(days: 1));
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Check-out'),
                                subtitle: Text(
                                    DateFormat('yyyy-MM-dd').format(checkOut)),
                                trailing: const Icon(Icons.calendar_today),
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: checkOut,
                                    firstDate:
                                        checkIn.add(const Duration(days: 1)),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 366)),
                                  );
                                  if (date != null) {
                                    setState(() => checkOut = date);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: adultsCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'Adults'),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty)
                                    return 'Enter adults';
                                  final val = int.tryParse(value);
                                  if (val == null || val < 1)
                                    return 'Must be at least 1 adult';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: childrenCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Children'),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty)
                                    return 'Enter count';
                                  final val = int.tryParse(value);
                                  if (val == null || val < 0)
                                    return 'Must be >=0';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: requestsCtrl,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Special requests (optional)'),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isCreatingReservation
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate())
                                      return;
                                    if (selectedRoomId == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Please select a room')));
                                      return;
                                    }
                                    setState(
                                        () => _isCreatingReservation = true);
                                    try {
                                      await provider.createReservation(
                                        roomId: selectedRoomId!,
                                        guestName: guestNameCtrl.text.trim(),
                                        guestEmail: guestEmailCtrl.text.trim(),
                                        guestPhone: guestPhoneCtrl.text.trim(),
                                        guestAddress:
                                            guestAddressCtrl.text.trim(),
                                        guestNationality:
                                            guestNationalityCtrl.text.trim(),
                                        guestIdType:
                                            guestIdTypeCtrl.text.trim(),
                                        guestIdNumber:
                                            guestIdNumberCtrl.text.trim(),
                                        nextOfKinName:
                                            nextOfKinNameCtrl.text.trim(),
                                        nextOfKinPhone:
                                            nextOfKinPhoneCtrl.text.trim(),
                                        nextOfKinRelationship:
                                            nextOfKinRelationshipCtrl.text
                                                .trim(),
                                        bookingSource:
                                            bookingSourceCtrl.text.trim(),
                                        vehiclePlateNumber:
                                            vehiclePlateCtrl.text.trim(),
                                        vehicleMake:
                                            vehicleMakeCtrl.text.trim(),
                                        vehicleModel:
                                            vehicleModelCtrl.text.trim(),
                                        vehicleColor:
                                            vehicleColorCtrl.text.trim(),
                                        checkIn: checkIn,
                                        checkOut: checkOut,
                                        adults: int.tryParse(
                                                adultsCtrl.text.trim()) ??
                                            1,
                                        children: int.tryParse(
                                                childrenCtrl.text.trim()) ??
                                            0,
                                        specialRequests: requestsCtrl.text
                                            .split(',')
                                            .map((s) => s.trim())
                                            .where((s) => s.isNotEmpty)
                                            .toList(),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Reservation created successfully')));
                                      Navigator.pop(context);
                                    } catch (err) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  'Failed to create reservation: $err')));
                                    } finally {
                                      if (mounted)
                                        setState(() =>
                                            _isCreatingReservation = false);
                                    }
                                  },
                            child: _isCreatingReservation
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Create Reservation',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
