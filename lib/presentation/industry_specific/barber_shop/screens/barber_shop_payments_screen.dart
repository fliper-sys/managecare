import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../providers/barber_shop_provider.dart';

class BarberShopPaymentsScreen extends StatefulWidget {
  const BarberShopPaymentsScreen({super.key});

  @override
  State<BarberShopPaymentsScreen> createState() => _BarberShopPaymentsScreenState();
}

class _BarberShopPaymentsScreenState extends State<BarberShopPaymentsScreen> {
  String _paymentMethod = 'cash';
  List<Map<String, dynamic>> _payments = [];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarberShopProvider>();
    final appointments = provider.getTodayAppointments();

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today\'s Appointments', style: AppTextStyles.heading5),
            const SizedBox(height: 12),
            Expanded(
              child: appointments.isEmpty
                  ? const Center(child: Text('No appointments for today'))
                  : ListView.builder(
                      itemCount: appointments.length,
                      itemBuilder: (context, i) {
                        final appt = appointments[i];
                        return Card(
                          child: ListTile(
                            title: Text(appt.clientName),
                            subtitle: Text('${appt.serviceName} - ${appt.barberName}'),
                            trailing: ElevatedButton(
                              onPressed: () => _showPayDialog(appt.id, appt.servicePrice, appt.clientName, appt.barberName),
                              child: const Text('Pay'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayDialog(String appointmentId, double price, String clientName, String barberName) {
    _payments = [
      {'method': _paymentMethod, 'amount': price}
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double totalPaid = _payments.fold<double>(0.0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0.0));
            final bool hasInvalid = _payments.any((p) => ((p['amount'] as num?) == null) || ((p['amount'] as num?)?.toDouble() ?? 0.0) <= 0);

            return AlertDialog(
              title: const Text('Accept Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Client: $clientName'),
                  const SizedBox(height: 8),
                  ..._payments.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final p = Map<String, dynamic>.from(entry.value);
                    final amt = ((p['amount'] as num?)?.toDouble() ?? 0.0);
                    return Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: amt == 0.0 ? '' : amt.toString(),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(?:\.?\d{0,2})?'))
                            ],
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              errorText: (amt <= 0) ? 'Enter > 0' : null,
                            ),
                            onChanged: (v) {
                              final cleaned = v.replaceAll(',', '').replaceAll('₦', '');
                              final val = double.tryParse(cleaned) ?? 0.0;
                              setStateDialog(() => _payments[idx]['amount'] = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: p['method'] ?? 'cash',
                          items: const [
                            DropdownMenuItem(value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'pos', child: Text('POS')),
                            DropdownMenuItem(value: 'transfer', child: Text('Bank Transfer')),
                            DropdownMenuItem(value: 'credit', child: Text('Credit')),
                          ],
                          onChanged: (v) => setStateDialog(() => _payments[idx]['method'] = v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => setStateDialog(() => _payments.removeAt(idx)),
                        )
                      ],
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => setStateDialog(() => _payments.add({'method': 'cash', 'amount': 0.0})),
                        child: const Text('Add Payment'),
                      ),
                      const SizedBox(width: 12),
                      Text('Total: ${formatCurrency(totalPaid)}')
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (totalPaid < price)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Remaining: ${formatCurrency(price - totalPaid)}', style: const TextStyle(color: Colors.orange)),
                    )
                  else if (totalPaid == price)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Paid in full', style: const TextStyle(color: Colors.green)),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Change: ${formatCurrency(totalPaid - price)}', style: const TextStyle(color: Colors.green)),
                    )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: hasInvalid ? null : () async {
                    final provider = context.read<BarberShopProvider>();
                    final paid = _payments.fold<double>(0.0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0.0));

                    // Determine overall method: 'mixed' if different methods used
                    final methods = _payments.map((p) => (p['method'] ?? 'cash').toString()).toSet();
                    final overallMethod = methods.length == 1 ? methods.first : 'mixed';

                    // If paid exceeds price, record sale with full price and note change
                    final amountToRecord = paid < price ? paid : price;

                    await provider.completeAppointment(appointmentId, amountToRecord, overallMethod, payments: List.from(_payments));

                    if (mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

