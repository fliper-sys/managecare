import 'package:business_manager/core/extensions/list_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../core/constants/routes.dart';
import '../../../../services/receipt_manager.dart';
import '../../../../services/web_email_receipt_service.dart';
import '../../../../services/email_service.dart';
import '../../../../services/managecare_api_client.dart';
import '../../../../services/notification_and_email_service.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/connectivity_provider.dart';
import '../../../../core/utils/receipt_utility.dart';
import '../../../shared/payment_method_sheet.dart';
import '../utils/pump_config_cache.dart';
import '../utils/pump_row_mapper.dart';

class GasPumpScreen extends StatefulWidget {
  const GasPumpScreen({super.key});

  @override
  State<GasPumpScreen> createState() => _GasPumpScreenState();
}

class _GasPumpScreenState extends State<GasPumpScreen> {
  String? _selectedProductId;
  String? _selectedPumpId;
  String? _selectedPumpNumber;
  String? _selectedPumpName;
  final Set<String> _assignedPumpIds = {};
  List<Map<String, dynamic>> _cachedPumps = [];
  bool _pumpCacheLoaded = false;
  bool _assignmentLoaded = false;
  bool _syncingPendingSales = false;
  bool _sellByAmount = true;
  final _amountController = TextEditingController();
  final _qtyController = TextEditingController();
  bool _processing = false;

  static const _pollInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAssignedPumps();
      _loadCachedPumps();
      _syncPendingPumpSales();
    });
  }

  Future<void> _syncPendingPumpSales() async {
    if (_syncingPendingSales) return;
    _syncingPendingSales = true;
    try {
      final synced = await context.read<RetailProvider>().syncPendingPumpSales();
      if (!mounted || synced <= 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$synced pending pump sale(s) synced')),
      );
    } catch (e) {
      debugPrint('[GasPump] Pending pump sale sync skipped: $e');
    } finally {
      _syncingPendingSales = false;
    }
  }

  Future<void> _loadCachedPumps() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;
    final cachedPumps = await PumpConfigCache.load(businessId);
    if (!mounted) return;
    setState(() {
      _cachedPumps = cachedPumps;
      _pumpCacheLoaded = true;
    });
  }

  void _syncCacheFromRows(String businessId, List<Map<String, dynamic>> rows) {
    final remotePumps = PumpConfigCache.sort(rows);
    if (remotePumps.isEmpty || PumpConfigCache.same(remotePumps, _cachedPumps)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PumpConfigCache.save(businessId, remotePumps);
      if (!mounted) return;
      setState(() {
        _cachedPumps = remotePumps;
        _pumpCacheLoaded = true;
      });
    });
  }

  Stream<List<Map<String, dynamic>>> _pumpsStream(String businessId) async* {
    while (true) {
      try {
        final response = await ManagecareApiClient.instance
            .get('/api/pumps/$businessId/pumps', query: {'isActive': 'true'});
        final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        yield rows.map(pumpRowToJson).toList();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
  }

  Future<void> _loadAssignedPumps() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    final user = context.read<AuthProvider>().currentUser;
    if (businessId == null ||
        businessId.isEmpty ||
        user == null ||
        user.id.isEmpty) {
      if (mounted) setState(() => _assignmentLoaded = true);
      return;
    }
    try {
      final response = await ManagecareApiClient.instance
          .get('/api/workers/$businessId/${user.id}');
      final permissions = response == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(response['permissions'] as Map? ?? {});
      final ids = ((permissions['assignedPumpIds'] as List<dynamic>?) ?? [])
          .map((id) => id.toString())
          .where((id) => id.isNotEmpty);
      if (!mounted) return;
      setState(() {
        _assignedPumpIds
          ..clear()
          ..addAll(ids);
        _assignmentLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _assignmentLoaded = true);
    }
  }

  Widget _buildPumpSelector({
    required bool isPumpOperator,
    required String businessId,
  }) {
    if (isPumpOperator && !_assignmentLoaded) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: LinearProgressIndicator(),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _pumpsStream(businessId),
      builder: (context, snapshot) {
        final pumpRows = snapshot.data ?? [];
        _syncCacheFromRows(businessId, pumpRows);
        final remotePumps = PumpConfigCache.sort(pumpRows);
        final allPumps = remotePumps.isNotEmpty ? remotePumps : _cachedPumps;
        final pumps = isPumpOperator && _assignedPumpIds.isNotEmpty
            ? allPumps
                .where((pump) => _assignedPumpIds.contains(pump['id']))
                .toList()
            : allPumps;

        if (snapshot.connectionState == ConnectionState.waiting &&
            pumps.isEmpty &&
            !_pumpCacheLoaded) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(),
          );
        }

        if (isPumpOperator && pumps.isEmpty) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange),
            ),
            child: const Text(
              'No pump is assigned to this account. Ask the owner or manager to assign a pump before recording sales.',
            ),
          );
        }

        if (pumps.isEmpty) return const SizedBox.shrink();

        final selectedPump = pumps.firstWhereOrNull(
              (pump) => pump['id'] == _selectedPumpId,
            ) ??
            pumps.first;
        if (_selectedPumpId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedPumpId = selectedPump['id']?.toString();
              _selectedPumpNumber = selectedPump['pumpNumber']?.toString();
              _selectedPumpName =
                  'Pump ${selectedPump['pumpNumber'] ?? ''}';
              _selectedProductId = selectedPump['productId']?.toString();
            });
          });
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            value: selectedPump['id']?.toString(),
            decoration: const InputDecoration(
              labelText: 'Select Pump',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: pumps.map((data) {
              return DropdownMenuItem(
                value: data['id']?.toString(),
                child: Text(
                  'Pump ${data['pumpNumber'] ?? ''} - ${data['productName'] ?? 'Fuel'}',
                ),
              );
            }).toList(),
            onChanged: (value) {
              final pump = pumps.firstWhereOrNull(
                (item) => item['id'] == value,
              );
              setState(() {
                _selectedPumpId = value;
                _selectedPumpNumber = pump?['pumpNumber']?.toString();
                _selectedPumpName =
                    pump == null ? null : 'Pump ${pump['pumpNumber'] ?? ''}';
                _selectedProductId = pump?['productId']?.toString();
              });
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final retail = context.watch<RetailProvider>();
    final auth = context.watch<AuthProvider>();
    final connectivity = context.watch<ConnectivityProvider>();
    final business = context.watch<BusinessProvider>().currentBusiness;
    final isPumpOperator =
        (auth.currentUser?.role.toLowerCase() ?? '') == 'pump_operator';
    final products = retail.products.where((p) {
      final category = p.category.toLowerCase();
      return category == 'fuel' ||
          category == 'petrol' ||
          category == 'petroleum' ||
          category == 'diesel' ||
          category == 'kerosene' ||
          category == 'gas';
    }).toList();

    final selected = products.firstWhereOrNull((p) => p.id == _selectedProductId) ?? (products.isNotEmpty ? products.first : null);

    if (connectivity.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPendingPumpSales();
      });
    }

    if (business == null) {
      return const Scaffold(
        body: Center(child: Text('No business selected')),
      );
    }

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
    final theme = Theme.of(context);
    final summaryColor = theme.cardColor;
    final summaryBorderColor = theme.dividerColor.withOpacity(0.35);

    return Scaffold(
      appBar: AppBar(title: const Text('Pump Sale')),
      body: products.isEmpty
          ? const Center(child: Text('No fuel products configured. Add a Product with category `Fuel`.'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPumpSelector(
                    isPumpOperator: isPumpOperator,
                    businessId: business.id,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Fuel Product',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    value: selected?.id,
                    items: products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} • ${p.price.toStringAsFixed(2)}/${p.unit}'))).toList(),
                    onChanged: _selectedPumpId == null
                        ? (v) => setState(() => _selectedProductId = v)
                        : null,
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
                        color: summaryColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: summaryBorderColor),
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
                        color: summaryColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: summaryBorderColor),
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
                  const SizedBox(height: 24),
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
                                  if (isPumpOperator &&
                                      (_selectedPumpId == null ||
                                          _selectedPumpId!.isEmpty)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Select an assigned pump before recording this sale',
                                        ),
                                      ),
                                    );
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
                                    storeId: business.id,
                                    pumpId: _selectedPumpId,
                                    pumpNumber: _selectedPumpNumber,
                                    pumpName: _selectedPumpName,
                                  );

                                  // Immediate feedback
                                  final offlineQueued =
                                      res['offlineQueued'] == true;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        offlineQueued
                                            ? 'Sale completed offline • queued for sync • ${res['quantity']} ${selected.unit} • ${res['total']}'
                                            : 'Sale recorded • ${res['quantity']} ${selected.unit} • ${res['total']} (Cashier: $workerName)',
                                      ),
                                      backgroundColor: offlineQueued
                                          ? Colors.orange
                                          : null,
                                    ),
                                  );
                                  if (mounted) {
                                    setState(() => _processing = false);
                                  }

                                  // Build a sale map similar to SalesScreen
                                  final pm = (selectedPayment.isNotEmpty) ? (selectedPayment[0].toUpperCase() + selectedPayment.substring(1)) : 'Cash';

                                  final receiptItems =
                                      ((res['items'] as List?) ?? const [])
                                          .map((item) {
                                    final map = item is Map
                                        ? Map<String, dynamic>.from(item)
                                        : <String, dynamic>{};
                                    final quantity = map['quantity'] ??
                                        map['qty'] ??
                                        res['quantity'] ??
                                        computedQty;
                                    final unitPrice = map['unitPrice'] ??
                                        map['price'] ??
                                        selected.price;
                                    final total =
                                        map['total'] ?? res['total'] ?? computedAmt;
                                    return {
                                      ...map,
                                      'name': map['name'] ??
                                          map['productName'] ??
                                          selected.name,
                                      'productName': map['productName'] ??
                                          map['name'] ??
                                          selected.name,
                                      'quantity': quantity,
                                      'qty': quantity,
                                      'unit': map['unit'] ?? selected.unit,
                                      'unitPrice': unitPrice,
                                      'price': unitPrice,
                                      'total': total,
                                    };
                                  }).toList();

                                  final saleMap = {
                                    ...res,
                                    'id': res['id'] ??
                                        res['orderId'] ??
                                        'SALE-${DateTime.now().millisecondsSinceEpoch}',
                                    'orderId': res['orderId'] ?? res['id'],
                                    'referenceId': ReceiptUtility.generateReferenceId(business.name),
                                    'items': receiptItems,
                                    'subtotal': res['total'],
                                    'tax': 0.0,
                                    'taxRate': 0.0,
                                    'discount': 0.0,
                                    'total': res['total'],
                                    'totalAmount': res['total'],
                                    'paymentMethod': pm,
                                    'customerEmail': res['customerEmail'],
                                    'customerName': res['customerName'],
                                    'createdAt': res['createdAt'] ?? DateTime.now(),
                                    'cashier': workerName,
                                    'workerName': res['workerName'] ?? workerName,
                                    'createdBy': workerId,
                                    'workerId': res['workerId'] ?? workerId,
                                    'businessLocation': business.address,
                                    'pumpId': res['pumpId'] ?? _selectedPumpId,
                                    'pumpNumber': res['pumpNumber'] ?? _selectedPumpNumber,
                                    'pumpName': res['pumpName'] ?? _selectedPumpName,
                                    'category': res['category'] ?? 'Fuel',
                                    'status': res['status'] ?? 'completed',
                                    'saleStatus': res['saleStatus'] ?? 'completed',
                                    'paymentStatus': res['paymentStatus'] ?? 'paid',
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

                                    // Stay on the pump screen after completion.
                                    // Receipt and printing are handled by the
                                    // post-sale action sheet above; forcing the
                                    // receipt route here can leave the worker
                                    // staring at a loader while Firestore
                                    // catches up.
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale failed: $e')));
                                  } finally {
                                    if (mounted && _processing) {
                                      setState(() => _processing = false);
                                    }
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
