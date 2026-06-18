import 'package:business_manager/core/extensions/list_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../core/constants/routes.dart';
import '../../../../services/receipt_manager.dart';
import '../../../../services/web_email_receipt_service.dart';
import '../../../../services/email_service.dart';
import '../../../../services/notification_and_email_service.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/connectivity_provider.dart';
import '../../../../core/utils/receipt_utility.dart';
import '../../../shared/payment_method_sheet.dart';

class GasPumpScreen extends StatefulWidget {
  const GasPumpScreen({super.key});

  @override
  State<GasPumpScreen> createState() => _GasPumpScreenState();
}

class _GasPumpScreenState extends State<GasPumpScreen> {
  String? _selectedProductId;
  bool _sellByAmount = true;
  final _amountController = TextEditingController();
  final _qtyController = TextEditingController();
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final retail = context.watch<RetailProvider>();
    final products = retail.products.where((p) => p.category.toLowerCase() == 'fuel' || p.category.toLowerCase() == 'petrol' || p.category.toLowerCase() == 'gas').toList();

    final selected = products.firstWhereOrNull((p) => p.id == _selectedProductId) ?? (products.isNotEmpty ? products.first : null);

    double computedQty = 0.0;
    double computedAmt = 0.0;
    if (selected != null) {
      final price = selected.price;
      final unit = selected.unit.toLowerCase();
      if (_sellByAmount) {
        final amt = double.tryParse(_amountController.text) ?? 0.0;
        var qty = price > 0 ? (amt / price) : 0.0;
        // For cylindrical units, round down to whole cylinders
        if (unit == 'cyl' || unit == 'cylinder') qty = qty.floorToDouble();
        computedQty = qty;
        computedAmt = qty * price; // reflect actual charge for whole units
      } else {
        var q = double.tryParse(_qtyController.text) ?? 0.0;
        // For cylinders enforce integer quantity
        if (unit == 'cyl' || unit == 'cylinder') q = q.toInt().toDouble();
        computedAmt = q * price;
        computedQty = q;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pump Sale')),
      body: products.isEmpty
          ? const Center(child: Text('No fuel products configured. Add a Product with category `Fuel`.'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Fuel Product',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    value: _selectedProductId ?? (products.isNotEmpty ? products.first.id : null),
                    items: products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} • ${p.price.toStringAsFixed(2)}/${p.unit}'))).toList(),
                    onChanged: (v) => setState(() => _selectedProductId = v),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ToggleButtons(
                      borderRadius: BorderRadius.circular(8),
                      isSelected: [_sellByAmount, !_sellByAmount],
                      onPressed: (i) => setState(() => _sellByAmount = i == 0),
                      children: const [Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Text('Sell by Amount')), Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Text('Sell by Volume'))],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_sellByAmount) ...[
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount to Pay',
                        prefixText: '₦',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Volume:', style: TextStyle(fontSize: 16)),
                          Text(
                            '${computedQty.toStringAsFixed((selected != null && (selected.unit.toLowerCase() == 'cyl' || selected.unit.toLowerCase() == 'cylinder')) ? 0 : 3)} ${selected?.unit ?? ''}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Volume to Dispense',
                        suffixText: selected?.unit ?? 'units',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Cost:', style: TextStyle(fontSize: 16)),
                          Text(
                            '₦${computedAmt.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _processing || selected == null
                              ? null
                              : () async {
                                  // Validate inputs
                                  final amt = _sellByAmount ? (double.tryParse(_amountController.text) ?? 0.0) : computedAmt;
                                  final qty = !_sellByAmount ? (double.tryParse(_qtyController.text) ?? 0.0) : computedQty;
                                  if ((_sellByAmount && amt <= 0) || (!_sellByAmount && qty <= 0)) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount or volume')));
                                    return;
                                  }

                                  // Show payment-method sheet and perform the sale using the selected method
                                  final selectedPayment = await showModalBottomSheet<String?>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (ctx) => PaymentMethodSheet(amount: computedAmt),
                                  );

                                  if (selectedPayment == null) return; // user cancelled

                                  setState(() => _processing = true);
                                  try {
                                    final auth = Provider.of<AuthProvider>(context, listen: false);
                                  final workerId = auth.currentUser?.id;
                                  final workerName = auth.currentUser?.fullName ?? auth.currentUser?.email ?? 'Pump';

                                  final res = await retail.fuelSale(
                                    productId: selected.id,
                                    amountPaid: _sellByAmount ? (double.tryParse(_amountController.text) ?? 0.0) : null,
                                    quantity: !_sellByAmount ? (double.tryParse(_qtyController.text) ?? 0.0) : null,
                                    paymentMethod: selectedPayment,
                                    workerId: workerId,
                                    workerName: workerName,
                                    storeId: Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.id,
                                  );

                                  // Immediate feedback
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale recorded • ${res['quantity']} ${selected.unit} • ${res['total']} (Cashier: $workerName)')));

                                  // Build a sale map similar to SalesScreen
                                  final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
                                  final pm = (selectedPayment.isNotEmpty) ? (selectedPayment[0].toUpperCase() + selectedPayment.substring(1)) : 'Cash';

                                  final saleMap = {
                                    'id': res['id'] ?? 'SALE-${DateTime.now().millisecondsSinceEpoch}',
                                    'referenceId': ReceiptUtility.generateReferenceId(business?.name),
                                    'items': res['items'],
                                    'subtotal': res['total'],
                                    'tax': 0.0,
                                    'taxRate': 0.0,
                                    'discount': 0.0,
                                    'total': res['total'],
                                    'paymentMethod': pm,
                                    'customerEmail': null,
                                    'customerName': null,
                                    'createdAt': DateTime.now(),
                                    'cashier': workerName,
                                    'createdBy': workerId,
                                    'businessLocation': business?.address ?? '',
                                  }; 

                                    // Attempt to send receipt email and owner notification (if online)
                                    try {
                                      final connectivity = Provider.of<ConnectivityProvider>(context, listen: false);
                                      final isConnected = connectivity.isConnected;

                                      if (business != null && isConnected) {
                                        final emailService = WebEmailReceiptService();
                                        final customerEmail = saleMap['customerEmail'] as String?;

                                        if (customerEmail != null && customerEmail.isNotEmpty) {
                                          await emailService.sendReceiptEmail(
                                            recipientEmail: customerEmail,
                                            receiptNumber: saleMap['id'].toString(),
                                            businessName: business.name,
                                            customerName: saleMap['customerName'] ?? 'Valued Customer',
                                            totalAmount: (saleMap['total'] as double),
                                            subtotal: (saleMap['subtotal'] as double),
                                            tax: (saleMap['tax'] as double),
                                            items: (saleMap['items'] as List)
                                                .map((item) => {
                                                  'name': item['productName'] ?? item['name'] ?? 'Item',
                                                  'quantity': item['quantity'] ?? item['qty'] ?? 0,
                                                  'price': item['unitPrice'] ?? item['price'] ?? 0,
                                                })
                                                .toList(),
                                            paymentMethod: pm,
                                            businessLogo: business.logoUrl,
                                            businessContact: business.phone,
                                          );

                                          final ownerEmail = Provider.of<AuthProvider>(context, listen: false).currentUser?.email ?? business.email ?? '';
                                          if (ownerEmail.isNotEmpty) {
                                            final ownerSuccess = await emailService.sendSalesNotification(
                                              ownerEmail: ownerEmail,
                                              businessName: business.name,
                                              customerName: saleMap['customerName'] ?? 'Walk-in Customer',
                                              customerEmail: customerEmail,
                                              totalAmount: (saleMap['total'] as double),
                                              items: (saleMap['items'] as List)
                                                  .map((item) => {
                                                        'name': item['productName'] ?? item['name'] ?? 'Item',
                                                        'quantity': item['quantity'] ?? item['qty'] ?? 0,
                                                        'price': item['unitPrice'] ?? item['price'] ?? 0,
                                                      })
                                                  .toList(),
                                              paymentMethod: pm,
                                              receiptNumber: saleMap['id'].toString(),
                                            );

                                            try {
                                              final notif = NotificationAndEmailService();
                                              final businessId = business.id;
                                              await notif.logNotificationEvent(
                                                businessId: businessId,
                                                type: 'sale',
                                                channel: 'email',
                                                recipient: ownerEmail,
                                                success: ownerSuccess,
                                                orderId: saleMap['id'].toString(),
                                              );
                                            } catch (e) {
                                              debugPrint('[GasPump] Notification log failed: $e');
                                            }
                                          }

                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Receipt and notification emails sent!'),
                                                backgroundColor: Colors.green,
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint('[GasPump] Error sending emails: $e');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Sale completed but emails failed: $e'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    }

                                    // Small delay to ensure any modal is dismissed
                                    await Future.delayed(const Duration(milliseconds: 500));

                                    // Send order success alert to staff user if Pro
                                    try {
                                      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
                                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                      final canSendOrderEmail =
                                          businessProvider.hasFeatureAccess(
                                        'email_receipts',
                                      );
                                      final userEmail = authProvider.currentUser?.email;
                                      if (canSendOrderEmail &&
                                          userEmail != null &&
                                          userEmail.isNotEmpty) {
                                        await EmailService().sendOrderSuccessAlert(
                                          userEmail,
                                          {
                                            'order_type': 'fuel_sale',
                                            'itemsCount': (res['items'] as List).length.toString(),
                                            'total': (res['total'] ?? 0).toString(),
                                          },
                                        );
                                      }
                                    } catch (_) {}

                                    // Show receipt dialog / actions
                                    try {
                                      if (mounted) {
                                        await ReceiptManager.handlePostSale(
                                          context,
                                          saleMap,
                                          invoiceGeneratedBeforeCheckout: true,
                                        );
                                      } else {
                                        debugPrint('[GasPump] Skipping post-sale UI because widget is unmounted');
                                      }
                                    } catch (e) {
                                      debugPrint('[GasPump] Receipt handling error: $e');
                                    }

                                    // Navigate to receipt loader
                                    Navigator.pushNamed(context, Routes.salesReceipt, arguments: res['id']);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale failed: $e')));
                                  } finally {
                                    setState(() => _processing = false);
                                  }
                                },
                          child: _processing ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator()) : const Text('Confirm Sale'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
