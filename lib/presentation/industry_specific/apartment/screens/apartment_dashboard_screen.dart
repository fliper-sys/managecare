import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/apartment_provider.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../data/models/booking_model.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../data/models/apartment_model.dart';
import 'unit_management_screen.dart';
import 'booking_list_screen.dart';
import 'booking_form_screen.dart';
import '../../../../core/theme/colors.dart';

class ApartmentDashboardScreen extends StatefulWidget {
  const ApartmentDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ApartmentDashboardScreen> createState() => _ApartmentDashboardScreenState();
}

class _ApartmentDashboardScreenState extends State<ApartmentDashboardScreen> with SingleTickerProviderStateMixin {
  int _bookingsCount = 0;
  int _unitsCount = 0;
  List<dynamic> _recentBookings = [];
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadData();
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final bp = context.read<BusinessProvider>();
    final businessId = bp.currentBusiness?.id;
    if (businessId != null) {
      // Load apartments first
      await context.read<ApartmentProvider>().loadApartments(businessId);

      // Load units for each apartment (in parallel)
      final aptProv = context.read<ApartmentProvider>();
      final futures = <Future>[];
      for (final a in aptProv.apartments) {
        futures.add(aptProv.loadUnits(businessId, a.id));
      }
      await Future.wait(futures);

      // Fetch bookings count
      try {
        final bookings = await context.read<BookingProvider>().fetchBookings(businessId: businessId);
        if (mounted) setState(() {
          _bookingsCount = bookings.length;
          _recentBookings = bookings.take(3).toList();
        });
      } catch (e) {
        debugPrint('[ApartmentDashboard] Failed to fetch bookings: $e');
      }

      // Compute units count
      final unitsMap = context.read<ApartmentProvider>().units;
      final unitsTotal = unitsMap.values.fold<int>(0, (prev, list) => prev + (list.length));
      if (mounted) setState(() => _unitsCount = unitsTotal);

      // Listen for subsequent unit changes and bookings refreshes
      // so the header stats remain up-to-date while the screen is visible.
      // We don't hold the returned listeners here because ApartmentProvider
      // and BookingProvider update via ChangeNotifier which will rebuild
      // this widget when needed.
    }
  }

  Future<void> _handleLogout() async {
    try {
      await context.read<AuthProvider>().logout();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }


  @override
  Widget build(BuildContext context) {
    final aptProv = context.watch<ApartmentProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Stack(
            children: [
              // Top gradient
              Container(
                height: 260,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.9),
                      Colors.blueAccent.shade700,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Apartment', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
                              const SizedBox(height: 4),
                              const Text('Overview', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Row(children: [
                            Container(
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), shape: BoxShape.circle),
                              child: IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), shape: BoxShape.circle),
                              child: IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _handleLogout),
                            ),
                          ])
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Hero card
                      _HeroValueCard(value: _unitsCount, label: 'Total Units'),

                      const SizedBox(height: 18),

                      // Stats row
                      Row(
                        children: [
                          Expanded(child: _CompactStatCard(label: 'Apartments', value: '${aptProv.apartments.length}', icon: Icons.business, color: Colors.blue)),
                          const SizedBox(width: 12),
                          Expanded(child: _CompactStatCard(label: 'Units', value: '$_unitsCount', icon: Icons.meeting_room, color: Colors.orange)),
                          const SizedBox(width: 12),
                          Expanded(child: _CompactStatCard(label: 'Bookings', value: '$_bookingsCount', icon: Icons.calendar_today, color: Colors.green)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Operations
                      const Text('Operations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: [
                          _OperationCard(title: 'Create Booking', icon: Icons.add, color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingFormScreen()))),
                          _OperationCard(title: 'Bookings', icon: Icons.receipt_long, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingListScreen(apartmentId: '',)))),
                          _OperationCard(title: 'Manage Units', icon: Icons.apartment_outlined, color: Colors.blue, onTap: _showManageUnitsSheet),
                          _OperationCard(title: 'Add Apartment', icon: Icons.add_business, color: Colors.deepOrange, onTap: _showAddApartmentDialog),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Recent Bookings
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Recent Bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        TextButton(onPressed: () async {
                          final bp = context.read<BusinessProvider>();
                          final businessId = bp.currentBusiness?.id;
                          if (businessId != null) {
                            final bookings = await context.read<BookingProvider>().fetchBookings(businessId: businessId);
                            if (mounted) {
                              setState(() => _recentBookings = bookings);
                            }
                          }
                        }, child: const Text('Refresh'))
                      ]),

                      const SizedBox(height: 8),

                      if (_recentBookings.isEmpty)
                        const _EmptyState()
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentBookings.length,
                          itemBuilder: (ctx, i) => _BookingListTile(booking: _recentBookings[i]),
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingFormScreen())),
      ),
    );
  }

  Future<void> _showAddApartmentDialog() async {
    final bp = context.read<BusinessProvider>();
    final businessId = bp.currentBusiness?.id;
    if (businessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No business selected')));
      return;
    }

    final authProv = context.read<AuthProvider>();

    final titleCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('Add Apartment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      final address = addressCtrl.text.trim();
                      final desc = descCtrl.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
                        return;
                      }

                      setState(() => isLoading = true);
                      try {
                        final apt = Apartment(id: '', title: title, description: desc, ownerId: authProv.currentUser?.id ?? '', address: address);
                        final id = await context.read<ApartmentProvider>().createApartment(businessId: businessId, apartment: apt);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Apartment added • $id')));
                        await _loadData();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add apartment: $e')));
                        setState(() => isLoading = false);
                      }
                    },
              child: isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
            ),
          ],
        );
      }),
    );

    // Dispose controllers
    titleCtrl.dispose();
    addressCtrl.dispose();
    descCtrl.dispose();
  }

  void _showManageUnitsSheet() {
    final aptProv = context.read<ApartmentProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Manage Units', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                if (aptProv.apartments.isEmpty) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Text('No apartments available. Add an apartment first.')),
                ] else ...[
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: aptProv.apartments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final a = aptProv.apartments[i];
                        return ListTile(
                          title: Text(a.title),
                          subtitle: Text(a.address),
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => UnitManagementScreen(apartment: a)));
                            },
                            child: const Text('Manage Units'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
// --- WIDGETS ---

class _HeroValueCard extends StatelessWidget {
  final int value;
  final String label;
  const _HeroValueCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.home, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text('$value', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87)),
        ],
      ),
    );
  }
}

class _CompactStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CompactStatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppColors.cardShadow),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))])),
        ],
      ),
    );
  }
}

class _OperationCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OperationCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppColors.cardShadow),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text('', style: TextStyle(color: Colors.grey[600]))]),
            CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color)),
          ],
        ),
      ),
    );
  }
}

class _BookingListTile extends StatelessWidget {
  final Booking booking;
  const _BookingListTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      title: Text('Unit: ${booking.unitId}'),
      subtitle: Text('${booking.checkInDate.toLocal().toString().split(' ').first} → ${booking.checkOutDate.toLocal().toString().split(' ').first} • ${booking.nights} nights'),
      trailing: Column(mainAxisSize: MainAxisSize.min, children: [Text('${booking.currency}${booking.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(booking.status.toString().split('.').last)]),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingListScreen(apartmentId: booking.apartmentId))),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.calendar_month_outlined, size: 52, color: Colors.grey[300]), const SizedBox(height: 12), Text('No recent bookings', style: TextStyle(color: Colors.grey[600]))]),
    );
  }
}


