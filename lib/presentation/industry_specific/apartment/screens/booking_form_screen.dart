import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/apartment_model.dart';
import '../../../../data/models/unit_model.dart';
import '../../../../data/models/booking_model.dart';
import '../../../../data/repositories/apartment_repository_impl.dart';
import '../../../../data/repositories/booking_repository_impl.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../providers/business_provider.dart';
import 'booking_detail_screen.dart';

class BookingFormScreen extends StatefulWidget {
  final String? apartmentId;
  const BookingFormScreen({Key? key, this.apartmentId}) : super(key: key);

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Apartment> _apartments = [];
  List<Unit> _units = [];
  Apartment? _selectedApartment;
  Unit? _selectedUnit;
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _guests = 1;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _checking = false;
  bool _datesLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final bid = context.read<BusinessProvider>().currentBusiness?.id;
    if (bid == null) return;
    final repo = ApartmentRepositoryImpl();
    final list = await repo.fetchApartments(businessId: bid);
    setState(() {
      _apartments = list;
      if (_apartments.isNotEmpty) {
        if (widget.apartmentId != null) {
          _selectedApartment = _apartments.firstWhere((a) => a.id == widget.apartmentId, orElse: () => _apartments.first);
        } else {
          _selectedApartment = _apartments.first;
        }
      }
    });

    if (_selectedApartment != null) await _loadUnits();
  }

  Future<void> _loadUnits() async {
    final bid = context.read<BusinessProvider>().currentBusiness?.id;
    if (bid == null || _selectedApartment == null) return;
    setState(() => _checking = true);
    final repo = ApartmentRepositoryImpl();
    _units = await repo.fetchUnits(businessId: bid, apartmentId: _selectedApartment!.id);
    setState(() => _checking = false);
  }

  Future<void> _createAndProceed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApartment == null || _selectedUnit == null || _checkIn == null || _checkOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select apartment, unit and dates')));
      return;
    }

    final bid = context.read<BusinessProvider>().currentBusiness?.id;
    if (bid == null) return;

    // availability check
    final available = await BookingRepositoryImpl().checkAvailability(businessId: bid, unitId: _selectedUnit!.id, checkIn: _checkIn!, checkOut: _checkOut!);
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected dates are not available')));
      return;
    }

    final nights = _checkOut!.difference(_checkIn!).inDays;
    final subtotal = _selectedUnit!.pricePerNight * nights;
    final deposit = subtotal * 0.3; // default deposit percent 30%

    setState(() => _checking = true);
    final booking = Booking(
      id: '',
      unitId: _selectedUnit!.id,
      apartmentId: _selectedApartment!.id,
      tenantId: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : 'guest',
      checkInDate: _checkIn!,
      checkOutDate: _checkOut!,
      nights: nights,
      guests: _guests,
      subtotal: subtotal,
      depositAmount: deposit,
      discount: 0.0,
      total: subtotal,
      currency: '₦',
      policySnapshot: PolicySnapshot(depositPercent: 30.0, nonRefundable: false, freeCancelWindowHours: 24),
    );

    try {
      final bookingId = await context.read<BookingProvider>().createBooking(
            businessId: bid,
            booking: booking,
            requirePayment: deposit > 0,
          );
      final created = await BookingRepositoryImpl().getBooking(
        businessId: bid,
        bookingId: bookingId,
      );
      if (created != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookingDetailScreen(
              booking: created,
              autoStartPayment: true,
            ),
          ),
        );
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking created but could not fetch details')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create booking: $e')));
    } finally {
      setState(() => _checking = false);
    }
  }


  Future<void> _pickCheckIn() async {
    if (_selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a unit first')));
      return;
    }
    final bid = context.read<BusinessProvider>().currentBusiness?.id;
    if (bid == null) return;

    setState(() => _datesLoading = true);
    List<DateTimeRange> blockedRanges = [];
    try {
      final repo = BookingRepositoryImpl();
      final existing = await repo.fetchBookings(businessId: bid, unitId: _selectedUnit!.id, limit: 500);
      blockedRanges = existing
          .where((b) => ['pending', 'confirmed', 'checkedIn'].contains(b.status.toString().split('.').last))
          .map((b) => DateTimeRange(start: b.checkInDate, end: b.checkOutDate))
          .toList();
    } catch (e) {
      debugPrint('[BookingForm] Error fetching bookings for date picker: $e');
    } finally {
      setState(() => _datesLoading = false);
    }

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkIn ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: (day) {
        for (final r in blockedRanges) {
          final start = DateTime(r.start.year, r.start.month, r.start.day);
          final end = DateTime(r.end.year, r.end.month, r.end.day);
          if (!day.isBefore(start) && day.isBefore(end)) return false;
        }
        return true;
      },
    );

    if (picked != null) {
      setState(() {
        _checkIn = picked;
        // Default check-out to next day if not set or earlier than check-in
        if (_checkOut == null || !_checkOut!.isAfter(_checkIn!)) {
          _checkOut = _checkIn!.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _pickCheckOut() async {
    if (_selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a unit first')));
      return;
    }
    if (_checkIn == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick a check-in date first')));
      return;
    }

    final bid = context.read<BusinessProvider>().currentBusiness?.id;
    if (bid == null) return;

    setState(() => _datesLoading = true);
    List<DateTimeRange> blockedRanges = [];
    try {
      final repo = BookingRepositoryImpl();
      final existing = await repo.fetchBookings(businessId: bid, unitId: _selectedUnit!.id, limit: 500);
      blockedRanges = existing
          .where((b) => ['pending', 'confirmed', 'checkedIn'].contains(b.status.toString().split('.').last))
          .map((b) => DateTimeRange(start: b.checkInDate, end: b.checkOutDate))
          .toList();
    } catch (e) {
      debugPrint('[BookingForm] Error fetching bookings for date picker: $e');
    } finally {
      setState(() => _datesLoading = false);
    }

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkOut ?? _checkIn!.add(const Duration(days: 1)),
      firstDate: _checkIn!.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: (day) {
        for (final r in blockedRanges) {
          final start = DateTime(r.start.year, r.start.month, r.start.day);
          final end = DateTime(r.end.year, r.end.month, r.end.day);
          if (!day.isBefore(start) && day.isBefore(end)) return false;
        }
        return true;
      },
    );

    if (picked != null) setState(() => _checkOut = picked);
  }

  Future<void> _submit() async {
    await _createAndProceed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Booking')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _checking
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    DropdownButtonFormField<Apartment>(
                      value: _selectedApartment,
                      items: _apartments.map((a) => DropdownMenuItem(value: a, child: Text(a.title))).toList(),
                      onChanged: (v) async {
                        setState(() => _selectedApartment = v);
                        await _loadUnits();
                      },
                      decoration: const InputDecoration(labelText: 'Apartment'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Unit>(
                      value: _selectedUnit,
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text('${u.name} - ₦${u.pricePerNight.toStringAsFixed(0)}/night'))).toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v),
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          onTap: () { if (!_datesLoading) _pickCheckIn(); },
                          decoration: InputDecoration(
                            labelText: 'Check-in',
                            hintText: _checkIn == null ? 'Select' : DateFormat.yMMMd().format(_checkIn!),
                            suffixIcon: SizedBox(
                              width: 74,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (_checkIn != null)
                                    IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() { _checkIn = null; _checkOut = null; })),
                                  IconButton(icon: _datesLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.calendar_today, size: 18), onPressed: () { if (!_datesLoading) _pickCheckIn(); }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          onTap: () { if (!_datesLoading) _pickCheckOut(); },
                          decoration: InputDecoration(
                            labelText: 'Check-out',
                            hintText: _checkOut == null ? 'Select' : DateFormat.yMMMd().format(_checkOut!),
                            suffixIcon: SizedBox(
                              width: 74,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (_checkOut != null)
                                    IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _checkOut = null)),
                                  IconButton(icon: _datesLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.calendar_today, size: 18), onPressed: () { if (!_datesLoading) _pickCheckOut(); }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (_checkIn != null && _checkOut != null) Text('Nights: ${_checkOut!.difference(_checkIn!).inDays}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Guests'),
                        const Spacer(),
                        IconButton(
                          onPressed: _guests > 1 ? () => setState(() => _guests--) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$_guests'),
                        IconButton(
                          onPressed: () => setState(() => _guests++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Your name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                    const SizedBox(height: 8),
                    TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _submit, child: const Text('Check availability & Book')),
                  ],
                ),
              ),
      ),
    );
  }
}

class BookingSubmittedScreen extends StatelessWidget {
  final String bookingId;
  final String businessId;
  const BookingSubmittedScreen({Key? key, required this.bookingId, required this.businessId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Submitted')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, size: 72, color: Colors.green),
          const SizedBox(height: 12),
          const Text('Booking created. You can pay a deposit from the booking details.'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), child: const Text('Done')),
        ]),
      ),
    );
  }
}
