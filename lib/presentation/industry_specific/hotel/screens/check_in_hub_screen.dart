// ═══════════════════════════════════════════════════════════════════════════
// CHECK-IN HUB SCREEN
// ═══════════════════════════════════════════════════════════════════════════
//
// The central reception hub for hotel operations. Replaces the old thin
// CheckInScreen and consolidates flows that used to live on separate screens
// (bookings, front desk, check-in, guest arrival).
//
// Layout:
//   - AppBar with global "History" action
//   - 3 tabs:
//       [ Available (rooms) ][ Reserved ][ Checked-In ]
//   - Two FABs:
//       * "Reserve Room"  – lightweight reservation form
//       * "New Booking"   – full guest + payment + vehicle form
//
// Behaviour per tab:
//   - Available: rooms whose status is not occupied/reserved. Tap a row
//     to open "New Booking" with that room preselected.
//   - Reserved: reservations with status=='confirmed' but not yet
//     checked-in. Each row has an "Activate" button that opens the full
//     booking dialog with the reservation's data pre-filled, so on guest
//     arrival the receptionist only needs to add the missing pieces.
//   - Checked-In: reservations with status=='checked-in'. Each row shows
//     a live countdown to the scheduled checkout time. Once past checkout,
//     the timer flips to an "OVERDUE" counter (delay) that keeps ticking
//     until the receptionist taps "Check-Out". Rows also expose
//     "Extend Stay" and "View Details" / per-room history.
//
// Everything renders on top of the existing HotelProvider — no schema
// changes needed. The new dialogs are extracted in a follow-up stage to
// booking_dialogs.dart so the old bookings_screen.dart can be phased out
// without breaking anything meanwhile.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/hotel_provider.dart';
import '../dialogs/booking_dialogs.dart';

class CheckInHubScreen extends StatefulWidget {
  const CheckInHubScreen({super.key});

  @override
  State<CheckInHubScreen> createState() => _CheckInHubScreenState();
}

class _CheckInHubScreenState extends State<CheckInHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Rebuild every 30 seconds so countdown timers on checked-in rooms
    // stay accurate without needing a per-row Ticker.
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────── build ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HotelProvider>();
    final auth = context.read<AuthProvider>();
    final canManage =
        WorkerPermissions.canManageGuestBookings(auth.currentUser?.role ?? '');

    final rooms = provider.rooms;
    final reservations = provider.reservations;

    // Split reservations into buckets. A room is:
    //   - reserved  = has a 'confirmed' reservation that isn't yet checked-in
    //   - occupied  = has a 'checked-in' reservation
    //   - available = neither of the above
    final reservedByRoom = <String, Reservation>{};
    final checkedInByRoom = <String, Reservation>{};
    for (final r in reservations) {
      if (r.status == 'confirmed') {
        reservedByRoom[r.roomId] = r;
      } else if (r.status == 'checked-in') {
        checkedInByRoom[r.roomId] = r;
      }
    }

    final availableRooms = rooms
        .where((room) =>
            !reservedByRoom.containsKey(room.id) &&
            !checkedInByRoom.containsKey(room.id) &&
            (room.status.isEmpty ||
                room.status == 'available' ||
                room.status == 'clean' ||
                room.status == 'ready'))
        .toList();

    final reservedList = reservations
        .where((r) => r.status == 'confirmed')
        .toList()
      ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

    final checkedInList = reservations
        .where((r) => r.status == 'checked-in')
        .toList()
      ..sort((a, b) => a.checkOut.compareTo(b.checkOut));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Check-In Guest',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'All booking history',
            icon: const Icon(Icons.history),
            onPressed: () => _openHistory(context, provider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Available (${availableRooms.length})'),
            Tab(text: 'Reserved (${reservedList.length})'),
            Tab(text: 'Checked-In (${checkedInList.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AvailableTab(
            rooms: availableRooms,
            canManage: canManage,
            onBook: (roomId) => _openNewBooking(context, provider,
                preselectedRoomId: roomId),
          ),
          _ReservedTab(
            reservations: reservedList,
            provider: provider,
            canManage: canManage,
            onActivate: (reservation) =>
                _openActivateReservation(context, provider, reservation),
            onCancel: (reservation) =>
                _cancelReservation(context, provider, reservation),
          ),
          _CheckedInTab(
            reservations: checkedInList,
            provider: provider,
            canManage: canManage,
            onExtend: (r) => _openExtendStay(context, provider, r),
            onCheckOut: (r) => _confirmCheckOut(context, provider, r),
            onViewDetails: (r) => _openGuestDetails(context, provider, r),
            onRoomHistory: (roomId) => _openRoomHistory(context, provider, roomId),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'reserve_room_fab',
                  backgroundColor: Colors.orange,
                  onPressed: () => _openReserveRoom(context, provider),
                  icon: const Icon(Icons.event_available),
                  label: const Text('Reserve Room',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'new_booking_fab',
                  backgroundColor: AppColors.primary,
                  onPressed: () => _openNewBooking(context, provider),
                  icon: const Icon(Icons.add),
                  label: const Text('New Booking',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            )
          : null,
    );
  }

  // ─────────────────────────── actions ───────────────────────────────
  void _openNewBooking(BuildContext context, HotelProvider provider,
      {String? preselectedRoomId, Map<String, dynamic>? prefilledGuest}) {
    showBookingDialog(
      context,
      provider: provider,
      preselectedRoomId: preselectedRoomId,
      prefilledGuest: prefilledGuest,
      reservationOnly: false,
    );
  }

  void _openReserveRoom(BuildContext context, HotelProvider provider) {
    showBookingDialog(
      context,
      provider: provider,
      reservationOnly: true,
    );
  }

  void _openActivateReservation(
    BuildContext context,
    HotelProvider provider,
    Reservation reservation,
  ) {
    // Move the reservation forward into an active booking by opening the
    // full New Booking form pre-filled with everything the reservation
    // already captured. The receptionist just needs to top up the missing
    // fields (payment method, vehicle, occupant details) and submit.
    _openNewBooking(
      context,
      provider,
      preselectedRoomId: reservation.roomId,
      prefilledGuest: {
        'guestName': reservation.guestName,
        'guestPhone': reservation.guestPhone,
        'guestEmail': reservation.guestEmail,
        'guestSex': reservation.guestSex,
        'guestAddress': reservation.guestAddress,
        'guestNationality': reservation.guestNationality,
        'guestIdType': reservation.guestIdType,
        'guestIdNumber': reservation.guestIdNumber,
        'nextOfKinName': reservation.nextOfKinName,
        'nextOfKinPhone': reservation.nextOfKinPhone,
        'nextOfKinRelationship': reservation.nextOfKinRelationship,
        'bookingSource': reservation.bookingSource,
        'companyName': reservation.companyName,
        'occupantCount': reservation.occupantCount,
        'adults': reservation.adults,
        'children': reservation.children,
        // Reservation ID so the dialog can mark the reservation as
        // consumed once the booking is created.
        '_reservationId': reservation.id,
      },
    );
  }

  Future<void> _cancelReservation(
    BuildContext context,
    HotelProvider provider,
    Reservation reservation,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: Text(
            'This will remove the reservation for ${reservation.guestName} on room ${provider.getRoomById(reservation.roomId)?.number ?? '—'}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel it',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await provider.updateReservationStatus(reservation.id, 'cancelled');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reservation cancelled')),
    );
  }

  void _openExtendStay(
    BuildContext context,
    HotelProvider provider,
    Reservation reservation,
  ) {
    showExtendStayDialog(
      context,
      provider: provider,
      reservation: reservation,
    );
  }

  Future<void> _confirmCheckOut(
    BuildContext context,
    HotelProvider provider,
    Reservation reservation,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Check-out guest?'),
        content: Text(
            'Mark ${reservation.guestName} as checked out from room ${provider.getRoomById(reservation.roomId)?.number ?? '—'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not yet')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Check-out')),
        ],
      ),
    );
    if (confirm != true) return;
    await provider.updateReservationStatus(reservation.id, 'checked-out');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${reservation.guestName} checked out')),
    );
  }

  void _openGuestDetails(
    BuildContext context,
    HotelProvider provider,
    Reservation reservation,
  ) {
    showGuestDetailsSheet(
      context,
      provider: provider,
      reservation: reservation,
    );
  }

  void _openRoomHistory(
    BuildContext context,
    HotelProvider provider,
    String roomId,
  ) {
    final roomReservations =
        provider.reservations.where((r) => r.roomId == roomId).toList()
          ..sort((a, b) => b.checkIn.compareTo(a.checkIn));
    _showHistorySheet(context, provider,
        title: 'History — Room ${provider.getRoomById(roomId)?.number ?? '—'}',
        reservations: roomReservations);
  }

  void _openHistory(BuildContext context, HotelProvider provider) {
    final all = [...provider.reservations]
      ..sort((a, b) => b.checkIn.compareTo(a.checkIn));
    _showHistorySheet(context, provider,
        title: 'All Booking History', reservations: all);
  }

  void _showHistorySheet(
    BuildContext context,
    HotelProvider provider, {
    required String title,
    required List<Reservation> reservations,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                if (reservations.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No history yet.',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: reservations.length,
                      separatorBuilder: (_, __) => const Divider(height: 20),
                      itemBuilder: (_, index) {
                        final r = reservations[index];
                        final room = provider.getRoomById(r.roomId);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _statusColor(r.status).withOpacity(0.15),
                            child: Icon(_statusIcon(r.status),
                                color: _statusColor(r.status), size: 20),
                          ),
                          title: Text(r.guestName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Room ${room?.number ?? '—'} • '
                              '${DateFormat('d MMM y').format(r.checkIn)}'
                              ' → '
                              '${DateFormat('d MMM y').format(r.checkOut)}\n'
                              'Status: ${r.status.replaceAll('-', ' ')} • '
                              '${formatCurrency(r.totalPrice)}'),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _openGuestDetails(context, provider, r);
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — AVAILABLE ROOMS
// ═══════════════════════════════════════════════════════════════════════════

class _AvailableTab extends StatelessWidget {
  final List<Room> rooms;
  final bool canManage;
  final void Function(String roomId) onBook;

  const _AvailableTab({
    required this.rooms,
    required this.canManage,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return _emptyState(
        icon: Icons.hotel_outlined,
        title: 'No rooms available',
        subtitle:
            'Every room is currently reserved or checked-in.\nCheck the other tabs.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final room = rooms[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.green.shade100),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade50,
              child: Icon(Icons.meeting_room_rounded,
                  color: Colors.green.shade600),
            ),
            title: Text('Room ${room.number}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                '${room.type.isEmpty ? '—' : room.type} • capacity ${room.capacity}\n'
                '${formatCurrency(room.pricePerNight)} / full day'),
            isThreeLine: true,
            trailing: canManage
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Book'),
                    onPressed: () => onBook(room.id),
                  )
                : null,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — RESERVED ROOMS
// ═══════════════════════════════════════════════════════════════════════════

class _ReservedTab extends StatelessWidget {
  final List<Reservation> reservations;
  final HotelProvider provider;
  final bool canManage;
  final void Function(Reservation) onActivate;
  final void Function(Reservation) onCancel;

  const _ReservedTab({
    required this.reservations,
    required this.provider,
    required this.canManage,
    required this.onActivate,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) {
      return _emptyState(
        icon: Icons.event_available_outlined,
        title: 'No reservations',
        subtitle:
            'Tap "Reserve Room" below to hold a room for a guest arriving later.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reservations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final r = reservations[index];
        final room = provider.getRoomById(r.roomId);
        final eta = r.estimatedArrivalAt ?? r.checkIn;
        final untilArrival = eta.difference(DateTime.now());
        final arrivalLabel = untilArrival.isNegative
            ? 'Arrival overdue by ${_shortDuration(untilArrival.abs())}'
            : 'Arrives in ${_shortDuration(untilArrival)}';
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange.shade50,
                      child: Icon(Icons.event_available,
                          color: Colors.orange.shade700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.guestName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            'Room ${room?.number ?? '—'} • '
                            '${r.occupantCount} occupant${r.occupantCount == 1 ? '' : 's'}',
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: untilArrival.isNegative
                            ? Colors.red.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        arrivalLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: untilArrival.isNegative
                              ? Colors.red.shade700
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      r.guestPhone.isEmpty ? 'No phone' : r.guestPhone,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'ETA ${DateFormat('d MMM, h:mm a').format(eta)}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canManage)
                      TextButton.icon(
                        icon: const Icon(Icons.cancel_outlined,
                            size: 16, color: Colors.red),
                        label: const Text('Cancel',
                            style: TextStyle(color: Colors.red)),
                        onPressed: () => onCancel(r),
                      ),
                    const SizedBox(width: 8),
                    if (canManage)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                        ),
                        icon: const Icon(Icons.login, size: 16),
                        label: const Text('Activate'),
                        onPressed: () => onActivate(r),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 — CHECKED-IN ROOMS (with countdown)
// ═══════════════════════════════════════════════════════════════════════════

class _CheckedInTab extends StatelessWidget {
  final List<Reservation> reservations;
  final HotelProvider provider;
  final bool canManage;
  final void Function(Reservation) onExtend;
  final void Function(Reservation) onCheckOut;
  final void Function(Reservation) onViewDetails;
  final void Function(String roomId) onRoomHistory;

  const _CheckedInTab({
    required this.reservations,
    required this.provider,
    required this.canManage,
    required this.onExtend,
    required this.onCheckOut,
    required this.onViewDetails,
    required this.onRoomHistory,
  });

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) {
      return _emptyState(
        icon: Icons.night_shelter_outlined,
        title: 'No checked-in guests',
        subtitle: 'When a guest checks in, they will appear here with a\n'
            'live countdown to their scheduled checkout.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reservations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final r = reservations[index];
        final room = provider.getRoomById(r.roomId);
        final now = DateTime.now();
        final remaining = r.checkOut.difference(now);
        final overdue = remaining.isNegative;
        final countdownLabel = overdue
            ? 'OVERDUE by ${_shortDuration(remaining.abs())}'
            : 'Checks out in ${_shortDuration(remaining)}';
        final countdownColor = overdue ? Colors.red : Colors.blue;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: overdue ? Colors.red.shade200 : Colors.blue.shade100),
          ),
          child: InkWell(
            onTap: () => onViewDetails(r),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: countdownColor.withOpacity(0.1),
                        child: Icon(
                            overdue
                                ? Icons.access_time_filled_rounded
                                : Icons.hotel_rounded,
                            color: countdownColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.guestName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(
                              'Room ${room?.number ?? '—'} • '
                              '${r.occupantCount} occupant${r.occupantCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Room history',
                        icon: const Icon(Icons.history, size: 20),
                        onPressed: () => onRoomHistory(r.roomId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: countdownColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: countdownColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            overdue
                                ? Icons.warning_amber_rounded
                                : Icons.timer_outlined,
                            color: countdownColor,
                            size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            countdownLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: countdownColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('d MMM, h:mm a').format(r.checkOut),
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (canManage)
                        TextButton.icon(
                          icon: const Icon(Icons.schedule, size: 16),
                          label: const Text('Extend Stay'),
                          onPressed: () => onExtend(r),
                        ),
                      const SizedBox(width: 8),
                      if (canManage)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                overdue ? Colors.red : AppColors.primary,
                          ),
                          icon: const Icon(Icons.logout, size: 16),
                          label: const Text('Check-Out'),
                          onPressed: () => onCheckOut(r),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ═══════════════════════════════════════════════════════════════════════════

Widget _emptyState({
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700])),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    ),
  );
}

/// Format a short, human-friendly duration ("3d 4h", "2h 15m", "45m").
String _shortDuration(Duration d) {
  if (d.inDays > 0) {
    final hours = d.inHours - (d.inDays * 24);
    return '${d.inDays}d${hours > 0 ? ' ${hours}h' : ''}';
  }
  if (d.inHours > 0) {
    final mins = d.inMinutes - (d.inHours * 60);
    return '${d.inHours}h${mins > 0 ? ' ${mins}m' : ''}';
  }
  if (d.inMinutes > 0) return '${d.inMinutes}m';
  return 'now';
}

Color _statusColor(String status) {
  switch (status) {
    case 'checked-in':
      return Colors.blue;
    case 'checked-out':
      return Colors.grey;
    case 'confirmed':
      return Colors.orange;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'checked-in':
      return Icons.hotel;
    case 'checked-out':
      return Icons.logout;
    case 'confirmed':
      return Icons.event_available;
    case 'cancelled':
      return Icons.cancel;
    default:
      return Icons.help_outline;
  }
}
