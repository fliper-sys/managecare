// ═══════════════════════════════════════════════════════════════════════════
// BOOKING DIALOGS
// ═══════════════════════════════════════════════════════════════════════════
//
// Shared dialogs used by the CheckInHubScreen (and, later, any other place
// in the hotel module that needs to open a booking form). Exposes three
// top-level functions:
//
//   * showBookingDialog(...)         — full New Booking / Reserve Room form
//   * showExtendStayDialog(...)      — extend an active reservation
//   * showGuestDetailsSheet(...)     — read-only guest info sheet
//
// The New Booking form matches the requirements doc exactly: name, sex,
// occupants, room selection from available rooms, phone/email (both
// optional unless it's a reservation — in which case phone is required),
// payment method (cash/card/transfer/mixed with a note), duration
// (half_day/full_day), and vehicle info if present.
//
// When called for a reservation (reservationOnly: true), the form
// simplifies to the smaller "Reserve Room" flow the doc describes:
// full name, phone (mandatory), estimated arrival, room, occupant count.
//
// When prefilledGuest contains a "_reservationId" key, the dialog knows
// it's being called to activate an existing reservation. On successful
// booking it will mark that reservation as consumed (status: checked-in)
// so it moves out of the Reserved tab.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/hotel_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 1) NEW BOOKING / RESERVE ROOM DIALOG
// ═══════════════════════════════════════════════════════════════════════════

Future<void> showBookingDialog(
  BuildContext context, {
  required HotelProvider provider,
  String? preselectedRoomId,
  Map<String, dynamic>? prefilledGuest,
  bool reservationOnly = false,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _BookingDialog(
      provider: provider,
      preselectedRoomId: preselectedRoomId,
      prefilledGuest: prefilledGuest,
      reservationOnly: reservationOnly,
    ),
  );
}

class _BookingDialog extends StatefulWidget {
  final HotelProvider provider;
  final String? preselectedRoomId;
  final Map<String, dynamic>? prefilledGuest;
  final bool reservationOnly;

  const _BookingDialog({
    required this.provider,
    this.preselectedRoomId,
    this.prefilledGuest,
    required this.reservationOnly,
  });

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  final _formKey = GlobalKey<FormState>();

  // Guest info
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  String _sex = 'male';
  int _occupants = 1;

  // Room
  String? _selectedRoomId;

  // Stay
  String _stayDuration = 'full_day'; // 'half_day' | 'full_day'
  DateTime _checkIn = DateTime.now();
  int _nights = 1;
  DateTime? _estimatedArrival;

  // Payment
  String _paymentMethod = 'cash'; // 'cash' | 'card' | 'transfer' | 'mixed'
  final TextEditingController _mixedNoteCtrl = TextEditingController();

  // Vehicle
  bool _hasVehicle = false;
  final TextEditingController _vehicleMakeCtrl = TextEditingController();
  final TextEditingController _vehicleModelCtrl = TextEditingController();
  final TextEditingController _vehicleYearCtrl = TextEditingController();
  final TextEditingController _vehiclePlateCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pf = widget.prefilledGuest;
    _nameCtrl = TextEditingController(text: (pf?['guestName'] ?? '').toString());
    _phoneCtrl = TextEditingController(text: (pf?['guestPhone'] ?? '').toString());
    _emailCtrl = TextEditingController(text: (pf?['guestEmail'] ?? '').toString());
    final sexRaw = (pf?['guestSex'] ?? 'male').toString().toLowerCase();
    _sex = (sexRaw == 'female' || sexRaw == 'male' || sexRaw == 'other')
        ? sexRaw
        : 'male';
    _occupants = pf?['occupantCount'] is int
        ? pf!['occupantCount'] as int
        : int.tryParse((pf?['occupantCount'] ?? '1').toString()) ?? 1;
    _selectedRoomId = widget.preselectedRoomId;
    // For pure reservations, default to full-day; ETA today.
    if (widget.reservationOnly) {
      _estimatedArrival = DateTime.now().add(const Duration(hours: 2));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _mixedNoteCtrl.dispose();
    _vehicleMakeCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleYearCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────── save ───────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoomId == null || _selectedRoomId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final checkIn = widget.reservationOnly
          ? (_estimatedArrival ?? DateTime.now())
          : _checkIn;
      final checkOut = _stayDuration == 'half_day'
          ? checkIn.add(const Duration(hours: 12))
          : checkIn.add(Duration(days: _nights));

      await widget.provider.createReservation(
        roomId: _selectedRoomId!,
        guestName: _nameCtrl.text.trim(),
        guestEmail: _emailCtrl.text.trim(),
        guestPhone: _phoneCtrl.text.trim(),
        guestSex: _sex,
        occupantCount: _occupants,
        paymentMethod: widget.reservationOnly ? 'cash' : _paymentMethod,
        mixedPaymentNote:
            widget.reservationOnly ? '' : _mixedNoteCtrl.text.trim(),
        stayDurationType: widget.reservationOnly ? 'full_day' : _stayDuration,
        estimatedArrivalAt: widget.reservationOnly ? _estimatedArrival : null,
        checkIn: checkIn,
        checkOut: checkOut,
        adults: _occupants,
        children: 0,
        specialRequests: const [],
        status: widget.reservationOnly ? 'confirmed' : 'checked-in',
        vehiclePlateNumber:
            _hasVehicle ? _vehiclePlateCtrl.text.trim() : '',
        vehicleMake: _hasVehicle ? _vehicleMakeCtrl.text.trim() : '',
        vehicleModel: _hasVehicle ? _vehicleModelCtrl.text.trim() : '',
        vehicleYear: _hasVehicle ? _vehicleYearCtrl.text.trim() : '',
      );

      // If we were activating a reservation, mark the old reservation as
      // consumed so it drops out of the Reserved tab.
      final consumedId = widget.prefilledGuest?['_reservationId'] as String?;
      if (consumedId != null && consumedId.isNotEmpty && !widget.reservationOnly) {
        await widget.provider
            .updateReservationStatus(consumedId, 'checked-in');
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.reservationOnly
              ? 'Room reserved for ${_nameCtrl.text.trim()}'
              : '${_nameCtrl.text.trim()} checked in'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ─────────────────────── build ───────────────────────
  @override
  Widget build(BuildContext context) {
    final rooms = widget.provider.rooms;
    // Available rooms only, plus the preselected room (if any) so it's still
    // in the dropdown when opened for activation.
    final available = rooms.where((r) {
      if (r.id == _selectedRoomId) return true;
      final anyBlocking = widget.provider.reservations.any((res) =>
          res.roomId == r.id &&
          (res.status == 'checked-in' || res.status == 'confirmed'));
      return !anyBlocking;
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        widget.reservationOnly
                            ? Icons.event_available
                            : Icons.person_add_alt_1,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.reservationOnly ? 'Reserve Room' : 'New Booking',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Guest name
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: widget.reservationOnly
                          ? 'Phone Number *'
                          : 'Phone Number (optional)',
                      prefixIcon: const Icon(Icons.phone),
                      border: const OutlineInputBorder(),
                    ),
                    validator: widget.reservationOnly
                        ? (v) => (v == null || v.trim().isEmpty)
                            ? 'Required for reservations'
                            : null
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Email (only for full booking)
                  if (!widget.reservationOnly) ...[
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sex
                    DropdownButtonFormField<String>(
                      value: _sex,
                      decoration: const InputDecoration(
                        labelText: 'Sex',
                        prefixIcon: Icon(Icons.wc),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(
                            value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) =>
                          setState(() => _sex = v ?? _sex),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Occupants
                  Row(
                    children: [
                      const Icon(Icons.group, color: Colors.grey),
                      const SizedBox(width: 12),
                      const Text('Occupants:',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _occupants > 1
                            ? () => setState(() => _occupants--)
                            : null,
                      ),
                      Text('$_occupants',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => _occupants++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Room selection
                  DropdownButtonFormField<String>(
                    value: available.any((r) => r.id == _selectedRoomId)
                        ? _selectedRoomId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Room *',
                      prefixIcon: Icon(Icons.meeting_room),
                      border: OutlineInputBorder(),
                    ),
                    items: available
                        .map((r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(
                                'Room ${r.number} • ${r.type.isEmpty ? '—' : r.type} • '
                                '${formatCurrency(r.pricePerNight)}/day',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRoomId = v),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Choose a room' : null,
                  ),
                  const SizedBox(height: 12),

                  // Reservation-specific: ETA
                  if (widget.reservationOnly) ...[
                    _dateTimeTile(
                      label: 'Estimated Arrival *',
                      icon: Icons.schedule,
                      value: _estimatedArrival,
                      onChange: (dt) =>
                          setState(() => _estimatedArrival = dt),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Duration + stay (full booking only)
                  if (!widget.reservationOnly) ...[
                    DropdownButtonFormField<String>(
                      value: _stayDuration,
                      decoration: const InputDecoration(
                        labelText: 'Duration of Stay',
                        prefixIcon: Icon(Icons.timelapse),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'half_day', child: Text('Half Day')),
                        DropdownMenuItem(
                            value: 'full_day', child: Text('Full Day(s)')),
                      ],
                      onChanged: (v) =>
                          setState(() => _stayDuration = v ?? 'full_day'),
                    ),
                    const SizedBox(height: 12),
                    if (_stayDuration == 'full_day')
                      Row(
                        children: [
                          const Icon(Icons.bed, color: Colors.grey),
                          const SizedBox(width: 12),
                          const Text('Nights:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _nights > 1
                                ? () => setState(() => _nights--)
                                : null,
                          ),
                          Text('$_nights',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => _nights++),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),

                    // Payment method
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        prefixIcon: Icon(Icons.payments),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'card', child: Text('Card')),
                        DropdownMenuItem(
                            value: 'transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(
                            value: 'mixed', child: Text('Mixed / Split')),
                      ],
                      onChanged: (v) =>
                          setState(() => _paymentMethod = v ?? 'cash'),
                    ),
                    if (_paymentMethod == 'mixed') ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _mixedNoteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Mixed payment breakdown',
                          hintText: 'e.g. ₦20,000 cash + ₦30,000 transfer',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Vehicle info toggle
                    SwitchListTile(
                      title: const Text('Guest has vehicle',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Capture make, model, plate number'),
                      value: _hasVehicle,
                      onChanged: (v) => setState(() => _hasVehicle = v),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_hasVehicle) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _vehicleMakeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Make',
                                hintText: 'Toyota',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _vehicleModelCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Model',
                                hintText: 'Camry',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _vehicleYearCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Year',
                                hintText: '2020',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _vehiclePlateCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Registration No.',
                                hintText: 'ABC-123-XY',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],

                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(widget.reservationOnly
                                ? Icons.event_available
                                : Icons.check),
                        label: Text(_saving
                            ? 'Saving...'
                            : widget.reservationOnly
                                ? 'Reserve Room'
                                : 'Confirm Booking'),
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateTimeTile({
    required String label,
    required IconData icon,
    required DateTime? value,
    required void Function(DateTime) onChange,
  }) {
    final display = value == null
        ? 'Tap to select'
        : DateFormat('EEE, d MMM • h:mm a').format(value);
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: now.subtract(const Duration(days: 1)),
          lastDate: now.add(const Duration(days: 365)),
        );
        if (date == null) return;
        if (!mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value ?? now),
        );
        if (time == null) return;
        onChange(DateTime(
            date.year, date.month, date.day, time.hour, time.minute));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        child: Text(display),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2) EXTEND STAY DIALOG
// ═══════════════════════════════════════════════════════════════════════════

Future<void> showExtendStayDialog(
  BuildContext context, {
  required HotelProvider provider,
  required Reservation reservation,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _ExtendStayDialog(
      provider: provider,
      reservation: reservation,
    ),
  );
}

class _ExtendStayDialog extends StatefulWidget {
  final HotelProvider provider;
  final Reservation reservation;
  const _ExtendStayDialog({
    required this.provider,
    required this.reservation,
  });

  @override
  State<_ExtendStayDialog> createState() => _ExtendStayDialogState();
}

class _ExtendStayDialogState extends State<_ExtendStayDialog> {
  String _extensionType = 'full_day'; // 'half_day' | 'full_day'
  int _days = 1;
  String _paymentMethod = 'cash';
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Compute the new checkout time from the current one.
      // Half-day = +12 hours, Full day(s) = +N * 24 hours.
      final currentCheckOut = widget.reservation.checkOut;
      final newCheckOut = _extensionType == 'half_day'
          ? currentCheckOut.add(const Duration(hours: 12))
          : currentCheckOut.add(Duration(days: _days));

      await widget.provider.extendReservationStay(
        reservationId: widget.reservation.id,
        newCheckOut: newCheckOut,
        extensionReason:
            'Extended by receptionist (${_extensionType.replaceAll('_', ' ')}, paid via $_paymentMethod)',
      );

      // Record the extension payment as a charge on the reservation folio
      // so billing stays accurate.
      final room = widget.provider.getRoomById(widget.reservation.roomId);
      if (room != null) {
        final extraCharge = _extensionType == 'half_day'
            ? (room.halfDayPrice > 0
                ? room.halfDayPrice
                : room.pricePerNight / 2)
            : room.pricePerNight * _days;
        try {
          await widget.provider.addReservationCharge(
            reservationId: widget.reservation.id,
            description:
                'Stay extension (${_extensionType.replaceAll('_', ' ')}) — paid via $_paymentMethod',
            amount: extraCharge,
            category: 'extension',
            metadata: {
              'paymentMethod': _paymentMethod,
              'extensionType': _extensionType,
              'additionalDays': _extensionType == 'full_day' ? _days : 0,
            },
          );
        } catch (_) {
          // Non-fatal — extension itself succeeded even if the charge log
          // couldn't be written (e.g. offline).
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${widget.reservation.guestName}\'s stay extended (${_extensionType.replaceAll('_', ' ')})'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.provider.getRoomById(widget.reservation.roomId);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.schedule, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Extend Stay')),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guest: ${widget.reservation.guestName}'),
            Text('Room: ${room?.number ?? '—'}'),
            Text(
                'Current checkout: ${DateFormat('EEE d MMM, h:mm a').format(widget.reservation.checkOut)}'),
            const Divider(height: 20),
            DropdownButtonFormField<String>(
              value: _extensionType,
              decoration: const InputDecoration(
                labelText: 'Extension type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'half_day', child: Text('Half Day')),
                DropdownMenuItem(
                    value: 'full_day', child: Text('Full Day(s)')),
              ],
              onChanged: (v) => setState(() => _extensionType = v ?? 'full_day'),
            ),
            if (_extensionType == 'full_day') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Extra days:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed:
                        _days > 1 ? () => setState(() => _days--) : null,
                  ),
                  Text('$_days',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _days++),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment method',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(
                    value: 'transfer', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'mixed', child: Text('Mixed / Split')),
              ],
              onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: Text(_saving ? 'Saving...' : 'Extend'),
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3) GUEST DETAILS SHEET (read-only view of a booking)
// ═══════════════════════════════════════════════════════════════════════════

void showGuestDetailsSheet(
  BuildContext context, {
  required HotelProvider provider,
  required Reservation reservation,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      final room = provider.getRoomById(reservation.roomId);
      return DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(reservation.guestName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Room ${room?.number ?? '—'} • ${reservation.status.replaceAll('-', ' ')}',
                    style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 20),
                _sectionTitle('Guest Info'),
                _kvRow('Phone', reservation.guestPhone),
                _kvRow('Email', reservation.guestEmail),
                _kvRow('Sex', reservation.guestSex),
                _kvRow('Occupants', '${reservation.occupantCount}'),
                const SizedBox(height: 16),
                _sectionTitle('Stay'),
                _kvRow('Check-in',
                    DateFormat('EEE d MMM y, h:mm a').format(reservation.checkIn)),
                _kvRow('Check-out',
                    DateFormat('EEE d MMM y, h:mm a').format(reservation.checkOut)),
                _kvRow(
                    'Duration', reservation.stayDurationType.replaceAll('_', ' ')),
                _kvRow('Total', formatCurrency(reservation.totalPrice)),
                const SizedBox(height: 16),
                _sectionTitle('Payment'),
                _kvRow('Method', reservation.paymentMethod.toUpperCase()),
                if (reservation.mixedPaymentNote.isNotEmpty)
                  _kvRow('Breakdown', reservation.mixedPaymentNote),
                _kvRow('Status', reservation.paymentStatus),
                if (reservation.vehiclePlateNumber.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('Vehicle'),
                  _kvRow('Make',
                      reservation.vehicleMake.isEmpty ? '—' : reservation.vehicleMake),
                  _kvRow(
                      'Model',
                      reservation.vehicleModel.isEmpty
                          ? '—'
                          : reservation.vehicleModel),
                  _kvRow(
                      'Year',
                      reservation.vehicleYear.isEmpty
                          ? '—'
                          : reservation.vehicleYear),
                  _kvRow('Reg. No.', reservation.vehiclePlateNumber),
                ],
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _sectionTitle(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5)),
  );
}

Widget _kvRow(String key, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(key, style: TextStyle(color: Colors.grey[700])),
        ),
        Expanded(
          child: Text(value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
