import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../data/models/apartment_model.dart';
import '../../../../data/models/booking_model.dart';
import '../../../../data/models/unit_model.dart';
import '../../../../providers/apartment_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../providers/business_provider.dart';
import 'booking_form_screen.dart';
import 'booking_list_screen.dart';
import 'unit_management_screen.dart';

class ApartmentDashboardScreen extends StatefulWidget {
  const ApartmentDashboardScreen({super.key});

  @override
  State<ApartmentDashboardScreen> createState() => _ApartmentDashboardScreenState();
}

class _ApartmentDashboardScreenState extends State<ApartmentDashboardScreen> {
  bool _isLoading = true;
  int _bookingsCount = 0;
  int _unitsCount = 0;
  int _occupiedUnits = 0;
  int _upcomingCheckIns = 0;
  double _monthRevenue = 0;
  List<Booking> _allBookings = const [];
  List<Booking> _recentBookings = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    final apartmentProvider = context.read<ApartmentProvider>();
    await apartmentProvider.loadApartments(businessId);
    await Future.wait(
      apartmentProvider.apartments
          .map((apartment) => apartmentProvider.loadUnits(businessId, apartment.id)),
    );

    final bookings =
        await context.read<BookingProvider>().fetchBookings(businessId: businessId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 7));
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);
    final occupiedUnitIds = <String>{};
    var upcomingCheckIns = 0;
    var monthRevenue = 0.0;

    for (final booking in bookings) {
      final checkIn = DateTime(
        booking.checkInDate.year,
        booking.checkInDate.month,
        booking.checkInDate.day,
      );
      final checkOut = DateTime(
        booking.checkOutDate.year,
        booking.checkOutDate.month,
        booking.checkOutDate.day,
      );

      if ((booking.status == BookingStatus.checkedIn ||
              booking.status == BookingStatus.confirmed) &&
          !today.isBefore(checkIn) &&
          today.isBefore(checkOut)) {
        occupiedUnitIds.add(booking.unitId);
      }

      if ((booking.status == BookingStatus.pending ||
              booking.status == BookingStatus.confirmed) &&
          !checkIn.isBefore(today) &&
          checkIn.isBefore(nextWeek)) {
        upcomingCheckIns++;
      }

      if (booking.status != BookingStatus.cancelled &&
          !booking.createdAt.isBefore(currentMonthStart) &&
          booking.createdAt.isBefore(nextMonthStart)) {
        monthRevenue += booking.total;
      }
    }

    final unitsTotal = apartmentProvider.units.values.fold<int>(
      0,
      (previousValue, list) => previousValue + list.length,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _bookingsCount = bookings.length;
      _unitsCount = unitsTotal;
      _occupiedUnits = occupiedUnitIds.length;
      _upcomingCheckIns = upcomingCheckIns;
      _monthRevenue = monthRevenue;
      _allBookings = bookings;
      _recentBookings = bookings.take(5).toList();
      _isLoading = false;
    });
  }

  Future<void> _showApartmentDialog({Apartment? apartment}) async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No business selected')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: apartment?.title ?? '');
    final addressController =
        TextEditingController(text: apartment?.address ?? '');
    final descriptionController =
        TextEditingController(text: apartment?.description ?? '');
    final amenitiesController = TextEditingController(
      text: apartment?.amenities.join(', ') ?? '',
    );
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> handleSave() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              setDialogState(() => isSaving = true);
              final amenities = amenitiesController.text
                  .split(',')
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList();

              try {
                if (apartment == null) {
                  await context.read<ApartmentProvider>().createApartment(
                        businessId: businessId,
                        apartment: Apartment(
                          id: '',
                          title: titleController.text.trim(),
                          description: descriptionController.text.trim(),
                          ownerId: authProvider.currentUser?.id ?? '',
                          address: addressController.text.trim(),
                          amenities: amenities,
                        ),
                      );
                } else {
                  await context.read<ApartmentProvider>().updateApartment(
                        businessId,
                        apartment.id,
                        {
                          'title': titleController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'address': addressController.text.trim(),
                          'amenities': amenities,
                        },
                      );
                }

                if (!mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                await _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      apartment == null
                          ? 'Apartment added successfully'
                          : 'Apartment updated successfully',
                    ),
                  ),
                );
              } catch (error) {
                setDialogState(() => isSaving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unable to save apartment: $error')),
                );
              }
            }

            return AlertDialog(
              title: Text(apartment == null ? 'Add Apartment' : 'Edit Apartment'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amenitiesController,
                        decoration: const InputDecoration(
                          labelText: 'Amenities',
                          hintText: 'Wi-Fi, Parking, Security',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : handleSave,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(apartment == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    addressController.dispose();
    descriptionController.dispose();
    amenitiesController.dispose();
  }

  Future<void> _deleteApartment(Apartment apartment) async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) {
      return;
    }

    final activeBookings = _allBookings.where((booking) {
      return booking.apartmentId == apartment.id &&
          (booking.status == BookingStatus.pending ||
              booking.status == BookingStatus.confirmed ||
              booking.status == BookingStatus.checkedIn);
    }).length;

    if (activeBookings > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This apartment has $activeBookings active bookings. Clear them first before deleting it.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete apartment'),
              content: Text('Delete ${apartment.title}? Its units will also be removed.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await context.read<ApartmentProvider>().deleteApartment(businessId, apartment.id);
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apartment deleted')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete apartment: $error')),
      );
    }
  }

  int _unitCountFor(String apartmentId, ApartmentProvider provider) {
    return provider.units[apartmentId]?.length ?? 0;
  }

  int _occupiedCountFor(String apartmentId) {
    final occupied = <String>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final booking in _allBookings) {
      if (booking.apartmentId != apartmentId) {
        continue;
      }
      final checkIn = DateTime(
        booking.checkInDate.year,
        booking.checkInDate.month,
        booking.checkInDate.day,
      );
      final checkOut = DateTime(
        booking.checkOutDate.year,
        booking.checkOutDate.month,
        booking.checkOutDate.day,
      );
      if ((booking.status == BookingStatus.checkedIn ||
              booking.status == BookingStatus.confirmed) &&
          !today.isBefore(checkIn) &&
          today.isBefore(checkOut)) {
        occupied.add(booking.unitId);
      }
    }

    return occupied.length;
  }

  double _startingRateFor(String apartmentId, ApartmentProvider provider) {
    final units = provider.units[apartmentId] ?? const <Unit>[];
    if (units.isEmpty) {
      return 0;
    }
    final prices = units.map((unit) => unit.pricePerNight).toList()..sort();
    return prices.first;
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return AppColors.warning;
      case BookingStatus.confirmed:
        return AppColors.info;
      case BookingStatus.checkedIn:
        return AppColors.success;
      case BookingStatus.checkedOut:
        return Colors.grey;
      case BookingStatus.cancelled:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apartmentProvider = context.watch<ApartmentProvider>();
    final apartments = apartmentProvider.apartments;
    final business = context.watch<BusinessProvider>().currentBusiness;
    final isWide = MediaQuery.of(context).size.width > 720;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business?.name ?? 'Apartment Business',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage apartments, units, occupancy, and guest bookings in one place.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _TopMetric(label: 'Apartments', value: apartments.length.toString()),
                        _TopMetric(label: 'Units', value: _unitsCount.toString()),
                        _TopMetric(label: 'Occupied', value: _occupiedUnits.toString()),
                        _TopMetric(label: 'Upcoming', value: _upcomingCheckIns.toString()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(
                    width: isWide ? (MediaQuery.of(context).size.width - 56) / 2 : double.infinity,
                    title: 'Bookings',
                    value: _bookingsCount.toString(),
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.info,
                  ),
                  _StatCard(
                    width: isWide ? (MediaQuery.of(context).size.width - 56) / 2 : double.infinity,
                    title: 'Month Revenue',
                    value: formatCurrency(_monthRevenue, decimalDigits: 0),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Quick Actions',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionCard(
                    width: isWide ? (MediaQuery.of(context).size.width - 56) / 2 : double.infinity,
                    label: 'Add Apartment',
                    icon: Icons.add_business_rounded,
                    color: AppColors.primary,
                    onTap: () => _showApartmentDialog(),
                  ),
                  _ActionCard(
                    width: isWide ? (MediaQuery.of(context).size.width - 56) / 2 : double.infinity,
                    label: 'New Booking',
                    icon: Icons.playlist_add_check_circle_rounded,
                    color: AppColors.secondary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BookingFormScreen()),
                    ),
                  ),
                  _ActionCard(
                    width: isWide ? (MediaQuery.of(context).size.width - 56) / 2 : double.infinity,
                    label: 'All Bookings',
                    icon: Icons.event_note_rounded,
                    color: AppColors.accent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BookingListScreen()),
                    ),
                  ),
                  _ActionCard(
                    width: isWide ? (MediaQuery.of(context).size.width - 56) / 2 : double.infinity,
                    label: 'Refresh',
                    icon: Icons.sync_rounded,
                    color: Colors.deepPurple,
                    onTap: _loadData,
                  ),
                  _ActionCard(
                    width: isWide ? (MediaQuery.of(context).size.width - 56) / 2 : double.infinity,
                    label: 'Customer Care',
                    icon: Icons.support_agent_rounded,
                    color: Colors.green,
                    onTap: () => WhatsAppUtils.openCustomerSupport(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Apartments',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoading && apartments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (apartments.isEmpty)
                _EmptySection(
                  title: 'No apartments yet',
                  subtitle:
                      'Add your first apartment, then create units and start receiving bookings.',
                  actionLabel: 'Add Apartment',
                  onTap: () => _showApartmentDialog(),
                )
              else
                ...apartments.map((apartment) {
                  final unitCount = _unitCountFor(apartment.id, apartmentProvider);
                  final occupiedCount = _occupiedCountFor(apartment.id);
                  final availableCount = (unitCount - occupiedCount).clamp(0, 9999);
                  final bookingCount = _allBookings
                      .where((booking) => booking.apartmentId == apartment.id)
                      .length;
                  final startingRate = _startingRateFor(apartment.id, apartmentProvider);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.home_work_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    apartment.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    apartment.address.isEmpty
                                        ? 'No address yet'
                                        : apartment.address,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showApartmentDialog(apartment: apartment);
                                } else if (value == 'delete') {
                                  _deleteApartment(apartment);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit apartment'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete apartment'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (apartment.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(apartment.description),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoPill(icon: Icons.meeting_room_rounded, label: '$unitCount units'),
                            _InfoPill(icon: Icons.hotel_rounded, label: '$availableCount available'),
                            _InfoPill(icon: Icons.receipt_long_rounded, label: '$bookingCount bookings'),
                            _InfoPill(
                              icon: Icons.payments_rounded,
                              label: startingRate > 0
                                  ? '${formatCurrency(startingRate, decimalDigits: 0)}/night'
                                  : 'No price yet',
                            ),
                          ],
                        ),
                        if (apartment.amenities.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: apartment.amenities.map((amenity) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  amenity,
                                  style: const TextStyle(
                                    color: AppColors.secondaryDark,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => UnitManagementScreen(apartment: apartment),
                                ),
                              ),
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('Manage Units'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BookingListScreen(apartmentId: apartment.id),
                                ),
                              ),
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('View Bookings'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BookingFormScreen(apartmentId: apartment.id),
                                ),
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('New Booking'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),
              Text(
                'Recent Bookings',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (_recentBookings.isEmpty)
                _EmptySection(
                  title: 'No bookings yet',
                  subtitle: 'Bookings will appear here once guests start reserving your units.',
                  actionLabel: 'Create Booking',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BookingFormScreen()),
                  ),
                )
              else
                ..._recentBookings.map((booking) {
                  final statusColor = _statusColor(booking.status);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      title: Text(
                        'Booking ${booking.id}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${DateFormat.yMMMd().format(booking.checkInDate)} - ${DateFormat.yMMMd().format(booking.checkOutDate)}',
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    booking.status.name,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${booking.guests} guest(s)'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      trailing: Text(
                        formatCurrency(booking.total, decimalDigits: 0),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookingListScreen(apartmentId: booking.apartmentId),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopMetric extends StatelessWidget {
  final String label;
  final String value;

  const _TopMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final double width;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.width,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _EmptySection({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.home_work_outlined, size: 48, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTap,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
