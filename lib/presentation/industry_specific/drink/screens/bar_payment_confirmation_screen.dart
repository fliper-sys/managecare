import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../data/models/payment_breakdown.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/drink_provider.dart';
import '../../../../services/receipt_manager.dart';
import '../../../shared/payment_breakdown_fields.dart';

class BarPaymentConfirmationScreen extends StatefulWidget {
  final String invoiceId;

  const BarPaymentConfirmationScreen({
    super.key,
    required this.invoiceId,
  });

  @override
  State<BarPaymentConfirmationScreen> createState() =>
      _BarPaymentConfirmationScreenState();
}

class _BarPaymentConfirmationScreenState
    extends State<BarPaymentConfirmationScreen> {
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();
  final _transferController = TextEditingController();
  bool _processing = false;
  String? _initializedInvoiceId;

  @override
  void dispose() {
    _cashController.dispose();
    _cardController.dispose();
    _transferController.dispose();
    super.dispose();
  }

  Future<void> _confirmPayment(BarInvoice invoice) async {
    final payment = PaymentBreakdown(
      cash: double.tryParse(_cashController.text.trim()) ?? 0,
      card: double.tryParse(_cardController.text.trim()) ?? 0,
      transfer: double.tryParse(_transferController.text.trim()) ?? 0,
    );
    if (!payment.isValid || (payment.total - invoice.total).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Payment total must equal the order total.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>().currentUser;
    setState(() => _processing = true);
    try {
      final sale = await context.read<DrinkProvider>().convertInvoiceToSale(
            invoice.id,
            payment.method,
            paymentBreakdown: payment.toJson(),
            workerId: auth?.id,
            workerName: auth?.fullName ?? auth?.id,
          );
      if (!mounted) return;
      await ReceiptManager.handlePostSale(context, sale);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${invoice.invoiceNumber} payment confirmed.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment confirmation failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>().currentUser;
    final canConfirmPayment = auth != null &&
        (auth.isOwner ||
            WorkerPermissions.hasEffectivePermission(
              auth.role,
              auth.permissions,
              'confirm_bar_payments',
            ));

    return Consumer<DrinkProvider>(
      builder: (context, provider, _) {
        final invoice = provider.getInvoiceById(widget.invoiceId);
        if (invoice != null && _initializedInvoiceId != invoice.id) {
          _initializedInvoiceId = invoice.id;
          _cashController.text = invoice.total.toStringAsFixed(2);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Confirm Bar Payment')),
          body: invoice == null
              ? const Center(child: Text('Order not found.'))
              : invoice.status != 'collected'
                  ? Center(
                      child: Text(
                        'Payment is available after bottle collection '
                        '(current status: ${invoice.status}).',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: ListTile(
                            title: Text(invoice.invoiceNumber),
                            subtitle: Text(
                              '${invoice.customerName} • ${invoice.itemCount} bottles',
                            ),
                            trailing: Text(
                              formatCurrency(invoice.total),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Payment amounts',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PaymentBreakdownFields(
                          cashController: _cashController,
                          cardController: _cardController,
                          transferController: _transferController,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: !canConfirmPayment || _processing
                              ? null
                              : () => _confirmPayment(invoice),
                          icon: _processing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.verified),
                          label: Text(
                            canConfirmPayment
                                ? 'Confirm payment'
                                : 'Cashier permission required',
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}
