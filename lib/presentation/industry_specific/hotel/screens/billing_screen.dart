import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/hotel_provider.dart';
import '../../../../services/receipt_manager.dart';
import '../widgets/folio_widget.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canManageBilling = auth.isOwnerUser ||
        WorkerPermissions.canManageGuestBookings(auth.currentUser?.role ?? '');
    return Consumer<HotelProvider>(
      builder: (context, provider, _) {
        final billableReservations = provider
            .getReservationsByStatuses(['confirmed', 'checked-in', 'checked-out'])
          ..sort((a, b) => b.checkIn.compareTo(a.checkIn));

        final outstanding = billableReservations
            .where((reservation) => reservation.paymentStatus != 'paid')
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Billing'),
            backgroundColor: AppColors.primary,
          ),
          backgroundColor: Colors.grey[50],
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _BillingStat(
                      label: 'Open Folios',
                      value: billableReservations.length.toString(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BillingStat(
                      label: 'Outstanding',
                      value: outstanding.toString(),
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BillingStat(
                      label: 'Today',
                      value:
                          '₦${provider.getTodayCheckOuts().fold<double>(0.0, (sum, item) => sum + provider.getReservationBalance(item)).toStringAsFixed(0)}',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (billableReservations.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'No folios available yet.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                ...billableReservations.map((reservation) {
                  final room = provider.getRoomById(reservation.roomId);
                  final charges = provider.buildFolioCharges(reservation);
                  final total = provider.getReservationBalance(reservation);
                  final guestSales = provider.getSalesForGuest(reservation.guestId);
                  final roomSales = provider.getSalesForRoom(reservation.roomId);
                  final linkedSales = [...guestSales, ...roomSales]
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${reservation.guestName} • Room ${room?.number ?? reservation.roomId}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  reservation.paymentStatus.toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor:
                                    reservation.paymentStatus == 'paid'
                                        ? Colors.green
                                        : reservation.paymentStatus == 'partial'
                                            ? Colors.orange
                                            : Colors.red,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FolioWidget(
                            guestName: reservation.guestName,
                            charges: charges,
                            total: total,
                          ),
                          if (linkedSales.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Linked Orders & Sales',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...linkedSales.take(4).map(
                              (sale) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 16,
                                      color: Colors.blueGrey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        sale.description?.isNotEmpty == true
                                            ? sale.description!
                                            : 'Attached sale',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(sale.amount),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: !canManageBilling
                                      ? null
                                      : () async {
                                    await provider.updatePaymentStatus(
                                      reservation.id,
                                      'partial',
                                    );
                                  },
                                  child: const Text('Mark Partial'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: !canManageBilling
                                      ? null
                                      : () async {
                                    await provider.updatePaymentStatus(
                                      reservation.id,
                                      'paid',
                                    );
                                    if (reservation.status == 'checked-in') {
                                      await provider.updateReservationStatus(
                                        reservation.id,
                                        'checked-out',
                                      );
                                    }
                                    final updatedReservation = provider.reservations
                                        .firstWhere(
                                      (item) => item.id == reservation.id,
                                      orElse: () => reservation.copyWith(
                                        paymentStatus: 'paid',
                                        status: reservation.status == 'checked-in'
                                            ? 'checked-out'
                                            : reservation.status,
                                      ),
                                    );
                                    final saleMap =
                                        provider.buildReservationSalePayload(
                                      updatedReservation,
                                      room: room,
                                      paymentMethod: 'hotel_billing',
                                    );
                                    if (context.mounted) {
                                      await ReceiptManager.handlePostSale(
                                        context,
                                        saleMap,
                                      );
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Payment updated for ${reservation.guestName}',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Text('Mark Paid'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _BillingStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BillingStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}
