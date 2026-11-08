import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/hotel_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../data/models/payment_breakdown.dart';
import '../../../shared/payment_breakdown_fields.dart';

class CheckOutScreen extends StatefulWidget {
  const CheckOutScreen({super.key});

  @override
  State<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen> {
  Future<void> _confirmCheckout(Reservation reservation, double balance) async {
    final cashController = TextEditingController(
      text: balance > 0 ? balance.toStringAsFixed(2) : '',
    );
    final cardController = TextEditingController();
    final transferController = TextEditingController();
    final payment = await showDialog<PaymentBreakdown>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Confirm payment and check-out'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Balance due: ${formatCurrency(balance)}'),
                const SizedBox(height: 16),
                if (balance > 0) ...[
                  PaymentBreakdownFields(
                    cashController: cashController,
                    cardController: cardController,
                    transferController: transferController,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the full balance across cash, card, and transfer.',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (balance <= 0) {
                  Navigator.pop(dialogContext, const PaymentBreakdown());
                  return;
                }
                final entered = PaymentBreakdown(
                  cash: double.tryParse(cashController.text.trim()) ?? 0,
                  card: double.tryParse(cardController.text.trim()) ?? 0,
                  transfer:
                      double.tryParse(transferController.text.trim()) ?? 0,
                );
                if ((entered.total - balance).abs() > 0.01) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Payment total must equal the balance due.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, entered);
              },
              child: const Text('Confirm check-out'),
            ),
          ],
        ),
      ),
    );
    cashController.dispose();
    cardController.dispose();
    transferController.dispose();
    if (payment == null || !mounted) return;

    try {
      final provider = context.read<HotelProvider>();
      if (payment.total > 0) {
        await provider.recordReservationPayment(reservation.id, payment);
      }
      await provider.checkOutReservation(reservation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${reservation.guestName} checked out successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete check-out: $error')),
      );
    }
  }

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
                final billStatus = balance <= 0.01
                  ? 'Paid'
                  : r.paymentStatus.toLowerCase() == 'partial'
                    ? 'Partially paid'
                    : 'Due at checkout';
                final billStatusColor = balance <= 0.01
                  ? Colors.green
                  : r.paymentStatus.toLowerCase() == 'partial'
                    ? Colors.orange
                    : Colors.red;
                final attachedCharges = provider
                    .getFolioChargesForReservation(r.id)
                    .where((charge) => charge.source == 'bar_room_charge')
                    .toList();
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
                            child: const Text('Payment & Check-out'),
                            onPressed: !canManageCheckOut
                                ? null
                                : () => _confirmCheckout(r, balance),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: billStatusColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: billStatusColor.withOpacity(0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                balance <= 0.01
                                    ? Icons.check_circle_outline
                                    : Icons.receipt_long_outlined,
                                size: 18,
                                color: billStatusColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Bill status:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                billStatus,
                                style: TextStyle(
                                  color: billStatusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formatCurrency(balance),
                                style: TextStyle(
                                  color: billStatusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (attachedCharges.isNotEmpty) ...[
                          const Divider(),
                          const Text(
                            'Attached Orders & Sales',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...attachedCharges.take(3).map(
                            (charge) => Padding(
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
                                        '${charge.description} • Room charge',
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                  ),
                                  Text(
                                    formatCurrency(charge.amount),
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
