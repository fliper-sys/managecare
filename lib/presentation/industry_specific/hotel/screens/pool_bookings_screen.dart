import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/hotel_provider.dart';

class PoolBookingsScreen extends StatelessWidget {
  const PoolBookingsScreen({super.key});

  CollectionReference<Map<String, dynamic>> _collection(String businessId) {
    return FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('pool_bookings');
  }

  Future<bool> _ensureAccess(BuildContext context) async {
    final businessProvider = context.read<BusinessProvider>();
    final access = await businessProvider.canAccessFeatureEnhanced(
      'pool_booking',
      context: 'hotel_pool_bookings',
    );
    if (!context.mounted) return false;
    if (!(access['ok'] as bool? ?? false)) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Upgrade required'),
          content: Text(
            businessProvider.getSubscriptionBlockedMessage(
              feature: 'pool_booking',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _showAddBookingDialog(
    BuildContext context,
    String businessId,
  ) async {
    if (!await _ensureAccess(context)) return;

    final customerNameCtrl = TextEditingController();
    final customerPhoneCtrl = TextEditingController();
    final customerEmailCtrl = TextEditingController();
    final personsCtrl = TextEditingController(text: '1');
    final hoursCtrl = TextEditingController(text: '1');
    final amountCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    final hotelProvider = context.read<HotelProvider>();
    final registeredGuests = hotelProvider.guestProfiles;
    String? selectedGuestKey;
    DateTime bookingDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 12, minute: 0);

    double computeAmount() {
      final persons = int.tryParse(personsCtrl.text.trim()) ?? 1;
      final hours = double.tryParse(hoursCtrl.text.trim()) ?? 1.0;
      final base = persons * hours * 5000;
      return hotelProvider.calculateTieredHospitalityPrice(
        base.toDouble(),
        guestName: customerNameCtrl.text.trim(),
        guestEmail: customerEmailCtrl.text.trim(),
        guestPhone: customerPhoneCtrl.text.trim(),
      );
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setState) => AlertDialog(
              title: const Text('New Pool Booking'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (registeredGuests.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedGuestKey,
                        decoration: const InputDecoration(
                          labelText: 'Registered Guest',
                        ),
                        items: registeredGuests.map((guest) {
                          final key = hotelProvider.resolveGuestIdentityKey(
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
                                    hotelProvider.resolveGuestIdentityKey(
                                      guestName: (item['guestName'] ?? '').toString(),
                                      guestEmail: (item['guestEmail'] ?? '').toString(),
                                      guestPhone: (item['guestPhone'] ?? '').toString(),
                                    ) ==
                                        value,
                                orElse: () => null,
                              );
                          setState(() {
                            selectedGuestKey = value;
                            customerNameCtrl.text =
                                (guest?['guestName'] ?? '').toString();
                            customerPhoneCtrl.text =
                                (guest?['guestPhone'] ?? '').toString();
                            customerEmailCtrl.text =
                                (guest?['guestEmail'] ?? '').toString();
                            amountCtrl.text = computeAmount().toStringAsFixed(2);
                          });
                        },
                      ),
                    if (registeredGuests.isNotEmpty) const SizedBox(height: 12),
                    TextField(
                      controller: customerNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Customer Name'),
                    ),
                    TextField(
                      controller: customerPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Customer Phone'),
                    ),
                    TextField(
                      controller: customerEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'Customer Email'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Booking Date'),
                      subtitle: Text(
                        '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}',
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: bookingDate,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 1)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) {
                          setState(() => bookingDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start Time'),
                      subtitle: Text(startTime.format(dialogContext)),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: dialogContext,
                          initialTime: startTime,
                        );
                        if (picked != null) {
                          setState(() => startTime = picked);
                        }
                      },
                    ),
                    TextField(
                      controller: personsCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Number of Persons'),
                      onChanged: (_) => setState(
                        () => amountCtrl.text = computeAmount().toStringAsFixed(2),
                      ),
                    ),
                    TextField(
                      controller: hoursCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Booked Hours'),
                      onChanged: (_) => setState(
                        () => amountCtrl.text = computeAmount().toStringAsFixed(2),
                      ),
                    ),
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    final customerName = customerNameCtrl.text.trim();
    if (customerName.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer name is required')),
        );
      }
      return;
    }

    await _collection(businessId).add({
      'customerName': customerName,
      'customerPhone': customerPhoneCtrl.text.trim(),
      'customerEmail': customerEmailCtrl.text.trim(),
      'guestTier': hotelProvider.getGuestTier(
        guestName: customerNameCtrl.text.trim(),
        guestEmail: customerEmailCtrl.text.trim(),
        guestPhone: customerPhoneCtrl.text.trim(),
      ),
      'bookingDate': Timestamp.fromDate(bookingDate),
      'startTime': startTime.format(context),
      'persons': int.tryParse(personsCtrl.text.trim()) ?? 1,
      'hours': double.tryParse(hoursCtrl.text.trim()) ?? 1.0,
      'amount': double.tryParse(amountCtrl.text.trim()) ?? 0.0,
      'notes': notesCtrl.text.trim(),
      'status': 'scheduled',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateStatus(
    BuildContext context,
    String businessId,
    String bookingId,
    String status,
  ) async {
    await _collection(businessId).doc(bookingId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pool booking marked as $status')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>().currentBusiness;
    final businessId = business?.id;
    final auth = context.watch<AuthProvider>();
    final canManagePoolBookings = auth.isOwnerUser ||
        WorkerPermissions.canManagePoolBookings(auth.currentUser?.role ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text('Pool Bookings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: businessId == null || businessId.isEmpty
          ? const Center(child: Text('Select a business to continue'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _collection(businessId)
                  .orderBy('bookingDate', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pool_outlined,
                            size: 72,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No pool bookings yet',
                            style: AppTextStyles.heading4,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Track pool reservations by number of persons and number of booked hours.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final bookingDate =
                        (data['bookingDate'] as Timestamp?)?.toDate();
                    final status = (data['status'] ?? 'scheduled').toString();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (data['customerName'] ?? 'Pool Booking')
                                      .toString(),
                                  style: AppTextStyles.heading5,
                                ),
                              ),
                              PopupMenuButton<String>(
                                enabled: canManagePoolBookings,
                                onSelected: (value) => _updateStatus(
                                  context,
                                  businessId,
                                  doc.id,
                                  value,
                                ),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'scheduled',
                                    child: Text('Mark Scheduled'),
                                  ),
                                  PopupMenuItem(
                                    value: 'completed',
                                    child: Text('Mark Completed'),
                                  ),
                                  PopupMenuItem(
                                    value: 'cancelled',
                                    child: Text('Mark Cancelled'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _PoolInfoPill(
                                icon: Icons.event,
                                label: bookingDate == null
                                    ? 'Date not set'
                                    : '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}',
                              ),
                              _PoolInfoPill(
                                icon: Icons.schedule,
                                label: (data['startTime'] ?? '--').toString(),
                              ),
                              _PoolInfoPill(
                                icon: Icons.group_outlined,
                                label: '${data['persons'] ?? 0} persons',
                              ),
                              _PoolInfoPill(
                                icon: Icons.hourglass_bottom,
                                label: '${data['hours'] ?? 0} hrs',
                              ),
                              _PoolInfoPill(
                                icon: Icons.payments_outlined,
                                label: formatCurrency(
                                  (data['amount'] as num?)?.toDouble() ?? 0.0,
                                ),
                              ),
                              if ((data['guestTier'] ?? '').toString().isNotEmpty)
                                _PoolInfoPill(
                                  icon: Icons.workspace_premium_outlined,
                                  label: (data['guestTier'] ?? '')
                                      .toString()
                                      .replaceAll('_', ' ')
                                      .toUpperCase(),
                                ),
                            ],
                          ),
                          if ((data['notes'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              (data['notes'] ?? '').toString(),
                              style: AppTextStyles.body2,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'completed'
                                      ? Colors.green.withOpacity(0.12)
                                      : status == 'cancelled'
                                          ? Colors.red.withOpacity(0.12)
                                          : Colors.blue.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: status == 'completed'
                                        ? Colors.green.shade700
                                        : status == 'cancelled'
                                            ? Colors.red.shade700
                                            : Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if ((data['customerPhone'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(
                                  (data['customerPhone'] ?? '').toString(),
                                  style: AppTextStyles.caption,
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: businessId == null || businessId.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: canManagePoolBookings
                  ? () => _showAddBookingDialog(context, businessId)
                  : null,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add),
              label: const Text('New Pool Booking'),
            ),
    );
  }
}

class _PoolInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PoolInfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
