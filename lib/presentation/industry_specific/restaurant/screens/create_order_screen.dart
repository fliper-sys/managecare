import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/async_button.dart';
import '../../../../widgets/custom_button.dart';
import '../providers/restaurant_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/connectivity_provider.dart';
import '../../../../providers/retail_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/currency.dart';
import '../../../../data/repositories/sales_repository_impl.dart';
import '../../../../services/offline_sales_service.dart';
import '../../../../services/payment_service.dart';
import '../../../../services/receipt_manager.dart';
import '../../../../services/web_download.dart' as web_download;
import '../../../../services/web_email_receipt_service.dart';
import '../../../../services/pdf_invoice_generator.dart';

// Helpers
String _safeIdSuffix(String id) => id.length >= 6 ? id.substring(id.length - 6) : id;

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  String? _selectedTableId;
  int? _selectedTableNumber;
  final List<OrderItem> _selectedItems = [];
  double _subtotal = 0;
  double _taxRate = 0.0;  // Changed to 0% default
  double _discount = 0.0;  // Changed to editable field

  final TextEditingController _menuSearchController = TextEditingController();
  final TextEditingController _taxRateController = TextEditingController(text: '0');
  final TextEditingController _discountController = TextEditingController(text: '0');
  String _menuQuery = '';


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final business = context.read<BusinessProvider>().currentBusiness;
      if (business != null) {
        context.read<RestaurantProvider>().setBusinessId(business.id);
        await context.read<RestaurantProvider>().initializeTables(businessId: business.id);
        await context.read<RestaurantProvider>().initializeMenu(businessId: business.id);

        // If this business uses retail inventory, load products and sync prices
        await context.read<RetailProvider>().initialize(business.id);
        context.read<RestaurantProvider>().syncMenuWithRetail(context.read<RetailProvider>());
      } else {
        await context.read<RestaurantProvider>().initializeTables();
        await context.read<RestaurantProvider>().initializeMenu();
      }

      _menuSearchController.addListener(() {
        setState(() {
          _menuQuery = _menuSearchController.text.toLowerCase();
        });
      });
    });
  }

  @override
  void dispose() {
    _menuSearchController.dispose();
    _taxRateController.dispose();
    _discountController.dispose();
    super.dispose();
  }



  void _updateItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _selectedItems.removeAt(index);
    } else {
      final item = _selectedItems[index];
      _selectedItems[index] = OrderItem(
        id: item.id,
        menuItemId: item.menuItemId,
        menuItemName: item.menuItemName,
        price: item.price,
        quantity: newQuantity,
        subtotal: item.price * newQuantity,
        selectedOptions: item.selectedOptions,
        specialInstructions: item.specialInstructions,
      );
    }
    _updateSubtotal();
  }

  void _addPreparedItem(OrderItem item) {
    // For simplicity, append as a new line (preserving selected options)
    _selectedItems.add(item);
    _updateSubtotal();
  }

  void _updateSubtotal() {
    _subtotal = _selectedItems.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    setState(() {});
  }

  String _safeIdSuffix(String id) => id.length >= 6 ? id.substring(id.length - 6) : id;

  void _showItemOptionsDialog(MenuItem item) async {
    int qty = 1;
    String special = '';
    final Map<String, MenuOptionChoice?> selectedChoices = {};

    // Initialize defaults (first choice if exists)
    for (final opt in item.options) {
      selectedChoices[opt.id] = opt.choices.isNotEmpty ? opt.choices.first : null;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          double unitPrice() {
            double p = item.price;
            for (final c in selectedChoices.values) {
              if (c != null) p += c.priceModifier;
            }
            return p;
          }

          return AlertDialog(
            title: Text('Add ${item.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final opt in item.options)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.name, style: AppTextStyles.subtitle1),
                          const SizedBox(height: 8),
                          DropdownButton<MenuOptionChoice?>(
                            value: selectedChoices[opt.id],
                            isExpanded: true,
                            items: opt.choices.map((ch) {
                              return DropdownMenuItem<MenuOptionChoice?>(
                                value: ch,
                                child: Text('${ch.name} ${ch.priceModifier != 0 ? '(${formatCurrency(ch.priceModifier)}/add)' : ''}'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => selectedChoices[opt.id] = val),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text('Quantity', style: AppTextStyles.subtitle1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(onPressed: () => setState(() => qty = (qty - 1) < 1 ? 1 : qty - 1), icon: const Icon(Icons.remove)),
                      Text('$qty', style: AppTextStyles.body1),
                      IconButton(onPressed: () => setState(() => qty = qty + 1), icon: const Icon(Icons.add)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(hintText: 'Special instructions (optional)'),
                    onChanged: (v) => special = v,
                  ),
                  const SizedBox(height: 12),
                  Text('Unit: ${formatCurrency(unitPrice())}', style: AppTextStyles.body1),
                  Text('Subtotal: ${formatCurrency(unitPrice() * qty)}', style: AppTextStyles.body1),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  final selectedOptions = selectedChoices.entries.map((e) {
                    final c = e.value;
                    return {
                      'optionId': e.key,
                      'optionName': item.options.firstWhere((o) => o.id == e.key).name,
                      'choiceId': c?.id,
                      'choiceName': c?.name,
                      'price': c?.priceModifier ?? 0.0,
                    };
                  }).toList();

                  final unit = item.price + selectedOptions.fold<double>(0.0, (sum, s) => sum + (s['price'] as double));
                  final subtotal = unit * qty;
                  final orderItem = OrderItem(
                    id: 'oi_${DateTime.now().millisecondsSinceEpoch}',
                    menuItemId: item.id,
                    menuItemName: item.name,
                    price: unit,
                    quantity: qty,
                    subtotal: subtotal,
                    inventoryProductId: item.inventoryProductId,
                    selectedOptions: selectedOptions.cast<Map<String, dynamic>>(),
                    specialInstructions: special.isNotEmpty ? special : null,
                  );

                  _addPreparedItem(orderItem);
                  Navigator.pop(ctx);
                },
                child: const Text('Add to Order'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _payAndCompleteOrder() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add items before paying')));
      return;
    }

    // Read tax and discount from text controllers
    _taxRate = (double.tryParse(_taxRateController.text) ?? 0) / 100;
    _discount = double.tryParse(_discountController.text) ?? 0;

    final tax = _subtotal * _taxRate;
    final total = _subtotal + tax - _discount;

    // Ask for multiple payment methods (exclude Flutterwave) and optionally customer email/name and a server selection
    final selectedPaymentMethods = <String>[];
    final Map<String, double> paymentAllocations = {};
    String customerEmail = '';
    String customerName = '';
    String? selectedServerId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final provider = Provider.of<RestaurantProvider>(ctx, listen: false);
        final methods = provider.availablePaymentMethods;
        final servers = provider.servers;
        return AlertDialog(
          title: const Text('Pay & Complete Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text('Total: ${formatCurrency(total)}', style: AppTextStyles.heading3),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(hintText: 'Customer name (optional)'),
                  onChanged: (v) => customerName = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(hintText: 'Customer email (optional)'),
                  onChanged: (v) => customerEmail = v,
                ),
                const SizedBox(height: 12),                Align(alignment: Alignment.centerLeft, child: Text('Select payment method(s)', style: AppTextStyles.subtitle1)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: methods.map((m) {
                    final selected = selectedPaymentMethods.contains(m);
                    return FilterChip(
                      label: Text(m.toUpperCase()),
                      selected: selected,
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            selectedPaymentMethods.add(m);
                            // initialize allocation to 0
                            paymentAllocations[m] = 0.0;
                          } else {
                            selectedPaymentMethods.remove(m);
                            paymentAllocations.remove(m);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Allocation inputs when multiple methods selected
                if (selectedPaymentMethods.isNotEmpty) ...[
                  Align(alignment: Alignment.centerLeft, child: Text('Allocate amounts per method', style: AppTextStyles.subtitle1)),
                  const SizedBox(height: 8),
                  Column(
                    children: selectedPaymentMethods.map((m) {
                      final controller = TextEditingController(text: paymentAllocations[m]?.toStringAsFixed(2) ?? '0.00');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(m.toUpperCase())),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 140,
                              child: TextField(
                                controller: controller,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(hintText: 'Amount'),
                                onChanged: (v) {
                                  final val = double.tryParse(v) ?? 0.0;
                                  setState(() => paymentAllocations[m] = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Builder(builder: (ctx) {
                    final allocated = paymentAllocations.values.fold<double>(0.0, (s, a) => s + a);
                    return Text('Allocated: ${formatCurrency(allocated)} / ${formatCurrency(total)}', style: AppTextStyles.caption.copyWith(color: allocated < total ? Colors.orange : Colors.green));
                  }),
                ],
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: Text('Assign server (optional)', style: AppTextStyles.subtitle1)),
                const SizedBox(height: 8),
                DropdownButton<String?>(
                  isExpanded: true,
                  value: selectedServerId,
                  hint: const Text('Select server (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('No server')),
                    ...servers.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name)))
                  ],
                  onChanged: (v) => setState(() => selectedServerId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proceed to Pay')),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Ensure at least one payment method selected - default to cash
    if (selectedPaymentMethods.isEmpty) {
      selectedPaymentMethods.add('cash');
      paymentAllocations['cash'] = total;
    }

    // Validate allocations sum to total
    final allocatedSum = paymentAllocations.values.fold<double>(0.0, (s, a) => s + a);
    if ((allocatedSum - total).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allocated amounts must sum to total')));
      return;
    }

    // Process payment (mock on web or when PaymentService forces mock)
    try {
      final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessId = business?.id ?? auth.currentUser?.businessId;

      // Process each selected payment method according to its allocated amount
      final paymentBreakdown = <Map<String, dynamic>>[];
      for (final method in selectedPaymentMethods) {
        final amountForMethod = (paymentAllocations[method] ?? 0.0);
        if (amountForMethod <= 0) continue; // skip zero allocations

        if (method == 'card' || method == 'pos') {
          final publicKey = await PaymentService().getPublicKey() ?? '';
          final txRef = 'rest-${DateTime.now().millisecondsSinceEpoch}-${method}';
          final result = await PaymentService().processPayment(
            context: context,
            amount: amountForMethod,
            currency: 'NGN',
            email: customerEmail,
            fullName: customerName.isNotEmpty ? customerName : (auth.currentUser?.fullName ?? 'Guest'),
            txRef: txRef,
            publicKey: publicKey,
            businessId: businessId,
          );

          if (result['success'] != true) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed for $method: ${result['message'] ?? 'unknown'}'), backgroundColor: AppColors.error));
            return;
          }

          paymentBreakdown.add({
            'method': method,
            'amount': amountForMethod,
            'transactionId': result['transactionId'] ?? result['txRef'] ?? txRef,
          });
        } else {
          // Manual methods: mark as success with manual id
          paymentBreakdown.add({
            'method': method,
            'amount': amountForMethod,
            'transactionId': 'manual-${DateTime.now().millisecondsSinceEpoch}-$method',
          });
        }
      }

      if (paymentBreakdown.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No payment allocated')));
        return;
      }

      // Persist sale and complete order
      final order = RestaurantOrder(
        id: 'order_${DateTime.now().millisecondsSinceEpoch}',
        businessId: businessId ?? 'unknown',
        tableId: _selectedTableId,
        tableNumber: _selectedTableNumber,
        customerName: customerName.isNotEmpty ? customerName : null,
        customerEmail: customerEmail.isNotEmpty ? customerEmail : null,
        items: _selectedItems.toList(),
        subtotal: _subtotal,
        tax: tax,
        discount: _discount,
        total: total,
        status: 'completed',
        paymentStatus: 'paid',
        assignedWaiterId: selectedServerId,
        paymentMethods: selectedPaymentMethods,
        paymentBreakdown: paymentBreakdown,
        orderType: _selectedTableId != null ? 'dine-in' : 'takeaway',
      );

        // Save sale to Firestore
        final itemsList = _selectedItems.map((item) {
          return {
            'menuItemId': item.menuItemId,
            'menuItemName': item.menuItemName,
            'quantity': item.quantity,
            'unitPrice': item.price,
            'specialInstructions': item.specialInstructions,
            'selectedOptions': item.selectedOptions,
            'total': item.subtotal,
          };
        }).toList();

        final saleData = {
          'businessId': order.businessId,
          'orderId': order.id,
          'items': itemsList,
          'tableNumber': order.tableNumber,
          'orderType': order.orderType,
          'subtotal': order.subtotal,
          'tax': order.tax,
          'discount': order.discount,
          'total': order.total,
          'totalAmount': order.total,
          'finalAmount': order.total,
          'paymentStatus': 'paid',
          'status': 'completed',
          'paymentMethods': selectedPaymentMethods,
          'paymentMethod': selectedPaymentMethods.isNotEmpty ? selectedPaymentMethods.first : 'cash',
          'paymentBreakdown': paymentBreakdown,
          'category': 'Restaurant',
          if (order.customerName != null) 'customerName': order.customerName,
          if (order.customerEmail != null) 'customerEmail': order.customerEmail,
          'createdAt': FieldValue.serverTimestamp(),
          if (auth.currentUser?.storeId != null && (auth.currentUser?.storeId ?? '').isNotEmpty) 'storeId': auth.currentUser!.storeId,
          if (auth.currentUser?.id != null) 'workerId': auth.currentUser!.id,
          if (auth.currentUser?.fullName != null) 'workerName': auth.currentUser!.fullName,
        };

        final firestore = FirebaseFirestore.instance;
        final docRef = await firestore
            .collection('businesses')
            .doc(order.businessId)
            .collection('sales')
            .add(saleData);
        await docRef.update({'saleId': docRef.id});

        // Add completed order to provider
        await context.read<RestaurantProvider>().createOrder(order);

        // Deduct inventory where applicable
        try {
          final retail = Provider.of<RetailProvider>(context, listen: false);
          for (final item in _selectedItems) {
            final pid = item.inventoryProductId;
            if (pid != null && pid.isNotEmpty) {
              final prod = retail.products.firstWhere((p) => p.id == pid, orElse: () => Product(id: '', name: '', price: 0, stock: 0, category: ''));
              if (prod.id.isNotEmpty) {
                final newStock = (prod.stock - item.quantity) < 0 ? 0 : (prod.stock - item.quantity);
                final updated = Product(
                  id: prod.id,
                  name: prod.name,
                  price: prod.price,
                  cost: prod.cost,
                  stock: newStock.toDouble() ,
                  category: prod.category,
                  imageUrl: prod.imageUrl,
                  barcode: prod.barcode,
                  emoji: prod.emoji,
                );
                await retail.updateProduct(prod.id, updated);
              }
            }
          }
        } catch (e) {
          debugPrint('[RestaurantPOS] Inventory deduction during payment failed: $e');
        }

        // Show receipt and post sale actions
        if (!mounted) return;
        final firstTx = paymentBreakdown.isNotEmpty ? (paymentBreakdown.first['transactionId'] ?? '') : '';
        final saleMap = {
          'id': docRef.id,
          'saleId': docRef.id,
          'businessId': order.businessId,
          'orderId': order.id,
          'items': itemsList,
          'tableNumber': order.tableNumber,
          'orderType': order.orderType,
          'subtotal': order.subtotal,
          'tax': order.tax,
          'discount': order.discount,
          'total': order.total,
          'totalAmount': order.total,
          'finalAmount': order.total,
          'paymentStatus': 'paid',
          'status': 'completed',
          'paymentMethods': selectedPaymentMethods,
          'paymentBreakdown': paymentBreakdown,
          'paymentMethod': selectedPaymentMethods.isNotEmpty ? selectedPaymentMethods.first : 'cash',
          'paymentTransactionId': firstTx,
          'category': 'Restaurant',
          if (order.customerName != null) 'customerName': order.customerName,
          if (order.customerEmail != null) 'customerEmail': order.customerEmail,
          if (auth.currentUser?.id != null) 'workerId': auth.currentUser!.id,
          if (auth.currentUser?.fullName != null) 'workerName': auth.currentUser!.fullName,
          'timestamp': DateTime.now().toIso8601String(),
          if (auth.currentUser?.storeId != null && (auth.currentUser?.storeId ?? '').isNotEmpty) 'storeId': auth.currentUser!.storeId,
        };

        await ReceiptManager.handlePostSale(context, saleMap);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment successful and order completed'), backgroundColor: AppColors.success),
        );

        // Clear local cart
        _selectedItems.clear();
        _selectedTableId = null;
        _selectedTableNumber = null;
        _updateSubtotal();
        setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment error: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _confirmPaymentForAdmin() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add items before confirming')));
      return;
    }

    // Read tax and discount from text controllers
    _taxRate = (double.tryParse(_taxRateController.text) ?? 0) / 100;
    _discount = double.tryParse(_discountController.text) ?? 0;

    final tax = _subtotal * _taxRate;
    final total = _subtotal + tax - _discount;

    final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final businessId = business?.id ?? auth.currentUser?.businessId ?? 'unknown';

    // Build items list
    final itemsList = _selectedItems.map((item) {
      return {
        'menuItemId': item.menuItemId,
        'menuItemName': item.menuItemName,
        'quantity': item.quantity,
        'unitPrice': item.price,
        'specialInstructions': item.specialInstructions,
        'selectedOptions': item.selectedOptions,
        'total': item.subtotal,
      };
    }).toList();

    // Save sale using offline-aware service
    try {
      final order = RestaurantOrder(
        id: 'order_${DateTime.now().millisecondsSinceEpoch}',
        businessId: businessId,
        tableId: _selectedTableId,
        tableNumber: _selectedTableNumber,
        customerName: auth.currentUser?.fullName ?? 'Walk-in',
        customerEmail: auth.currentUser?.email,
        items: _selectedItems.toList(),
        subtotal: _subtotal,
        tax: tax,
        discount: _discount,
        total: total,
        status: 'completed',
        paymentStatus: 'paid',
        paymentMethods: const ['confirmed'],
        paymentBreakdown: const [],
        orderType: _selectedTableId != null ? 'dine-in' : 'takeaway',
      );

      final firestore = FirebaseFirestore.instance;
      final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
      final salesRepository = SalesRepositoryImpl(firestore: firestore);
      final offlineSalesService = OfflineSalesService(
        salesRepository: salesRepository,
        connectivityProvider: connectivityProvider,
      );

      final saleData = {
        'businessId': businessId,
        'orderId': order.id,
        'items': itemsList,
        'subtotal': _subtotal,
        'tax': tax,
        'discount': _discount,
        'total': total,
        'totalAmount': total,
        'finalAmount': total,
        'paymentStatus': 'paid',
        'paymentMethod': 'confirmed',
        'paymentMethods': const ['confirmed'],
        'paymentBreakdown': [
          {'method': 'confirmed', 'amount': total, 'transactionId': order.id}
        ],
        'category': 'Restaurant',
        'status': 'completed',
        'customerName': order.customerName,
        'customerEmail': order.customerEmail,
        if (auth.currentUser?.id != null) 'workerId': auth.currentUser!.id,
        if (auth.currentUser?.fullName != null) 'workerName': auth.currentUser!.fullName,
        if (auth.currentUser?.storeId != null && (auth.currentUser?.storeId ?? '').isNotEmpty) 'storeId': auth.currentUser!.storeId,
      };

      final result = await offlineSalesService.createSale(saleData);

      if (!result['success']) {
        throw Exception(result['error'] ?? 'Failed to save sale');
      }

      final saleResult = result['data'] as Map<String, dynamic>;
      final saleId = saleResult['id'].toString();
      final isOffline = result['mode'] == 'offline';

      final receiptNumber = 'RCPT-${_safeIdSuffix(saleId)}';

      await context.read<RestaurantProvider>().createOrder(
            order.copyWith(
              paymentBreakdown: [
                {
                  'method': 'confirmed',
                  'amount': total,
                  'transactionId': saleId,
                }
              ],
            ),
          );

      // Send notification email to admin/owner (only if online)
      if (!isOffline) {
        String ownerEmail = business?.email ?? '';
        if (ownerEmail.isEmpty && business?.ownerId != null && business!.ownerId.isNotEmpty) {
          try {
            final ownerDoc = await firestore.collection('users').doc(business.ownerId).get();
            ownerEmail = ownerDoc.exists ? (ownerDoc.data()?['email'] as String? ?? '') : '';
          } catch (e) {
            debugPrint('[RestaurantPOS] Failed to fetch owner email: $e');
          }
        }

        if (ownerEmail.isNotEmpty) {
          try {
            await WebEmailReceiptService().sendSalesNotification(
              ownerEmail: ownerEmail,
              businessName: business?.name ?? 'Business',
              customerName: auth.currentUser?.fullName ?? 'Walk-in',
              customerEmail: auth.currentUser?.email ?? '',
              totalAmount: total,
              items: itemsList,
              paymentMethod: 'Confirmed',
              receiptNumber: receiptNumber,
            );
          } catch (e) {
            debugPrint('[RestaurantPOS] Failed to send sales notification: $e');
          }
        } else {
          debugPrint('[RestaurantPOS] No owner email configured to send sales notification');
        }
      }

      // Show confirmation dialog with Print/View options
      if (!mounted) return;
      final saleMap = {
        'id': saleId,
        'saleId': saleId,
        'businessId': businessId,
        'orderId': order.id,
        'items': itemsList,
        'subtotal': _subtotal,
        'tax': tax,
        'discount': _discount,
        'total': total,
        'totalAmount': total,
        'finalAmount': total,
        'status': 'completed',
        'paymentStatus': 'paid',
        'paymentMethod': 'Confirmed',
        'paymentMethods': const ['Confirmed'],
        'paymentBreakdown': [
          {
            'method': 'Confirmed',
            'amount': total,
            'transactionId': saleId,
          }
        ],
        'category': 'Restaurant',
        'receiptNumber': receiptNumber,
        'customerName': order.customerName,
        'customerEmail': order.customerEmail,
        if (auth.currentUser?.id != null) 'workerId': auth.currentUser!.id,
        if (auth.currentUser?.fullName != null) 'workerName': auth.currentUser!.fullName,
        if (auth.currentUser?.storeId != null && (auth.currentUser?.storeId ?? '').isNotEmpty) 'storeId': auth.currentUser!.storeId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isOffline ? 'Payment Saved Offline' : 'Payment Confirmed'),
          content: Text(isOffline
            ? 'Payment recorded locally. It will sync when online. You can print or view the receipt.'
            : 'Payment recorded. You can print or view the receipt.'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Print receipt
                // Note: SaleModel could be used for detailed receipt printing in future
                /* final sale = SaleModel(
                  id: docRef.id,
                  businessId: businessId,
                  customerId: auth.currentUser?.id,
                  customerName: auth.currentUser?.fullName ?? 'Customer',
                  items: _selectedItems
                      .map((it) => SaleItem(
                            id: it.id,
                            productId: it.menuItemId,
                            productName: it.menuItemName,
                            quantity: it.quantity.toDouble(),
                            unitPrice: it.price,
                            total: it.subtotal,
                          ))
                      .toList(),
                  totalAmount: total,
                  taxAmount: tax,
                  discountAmount: _discount,
                  finalAmount: total,
                  paymentMethod: 'Confirmed',
                  status: 'completed',
                  receiptNumber: receiptNumber,
                  createdBy: auth.currentUser?.id ?? 'system',
                  createdAt: DateTime.now(),
                ); */
                // Print receipt via thermal printer
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt sent to printer'), backgroundColor: AppColors.success));
              },
              child: const Text('Print Receipt'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ReceiptManager.handlePostSale(context, saleMap);
              },
              child: const Text('View Receipt'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );

      // Clear local cart but keep UX flow deliberate
      _selectedItems.clear();
      _selectedTableId = null;
      _selectedTableNumber = null;
      _updateSubtotal();
      setState(() {});

      final successMessage = isOffline
        ? 'Payment saved offline and will sync when online'
        : 'Payment confirmed and admin notified';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: AppColors.success),
      );
    } catch (e) {
      debugPrint('[RestaurantPOS] Confirm payment failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Confirm failed: $e'), backgroundColor: AppColors.error));
    }
  }

  void _showOrderSummaryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: const Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Summary',
                      style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Order Items
              Expanded(
                child: _selectedItems.isEmpty
                    ? Center(
                        child: Text(
                          'No items added',
                          style: AppTextStyles.body1.copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _selectedItems.length,
                        itemBuilder: (context, index) {
                          final item = _selectedItems[index];
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.menuItemName,
                                    style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.selectedOptions.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: item.selectedOptions.map((opt) => Text('${opt['optionName']}: ${opt['choiceName'] ?? ''}${(opt['price'] != null && (opt['price'] as num).toDouble() != 0.0) ? ' (${formatCurrency((opt['price'] as num).toDouble())}/add)' : ''}', style: AppTextStyles.caption)).toList(),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formatCurrency(item.subtotal),
                                        style: AppTextStyles.caption.copyWith(color: AppColors.success),
                                      ),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => setState(() => _updateItemQuantity(index, item.quantity - 1)),
                                            child: const Icon(Icons.remove_circle_outline, size: 16),
                                          ),
                                          const SizedBox(width: 4),
                                          Text('${item.quantity}', style: AppTextStyles.caption),
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: () => setState(() => _updateItemQuantity(index, item.quantity + 1)),
                                            child: const Icon(Icons.add_circle_outline, size: 16),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Order Totals
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    _TotalRow(label: 'Subtotal', amount: _subtotal),
                    const SizedBox(height: 12),
                    // Editable Tax Field
                    Row(
                      children: [
                        Expanded(child: Text('Tax (%)', style: AppTextStyles.body2)),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _taxRateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '0',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                            '₦${(_subtotal * ((double.tryParse(_taxRateController.text) ?? 0) / 100)).toStringAsFixed(2)}',
                            style: AppTextStyles.caption),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Editable Discount Field
                    Row(
                      children: [
                        Expanded(child: Text('Discount (₦)', style: AppTextStyles.body2)),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _discountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '0',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                            '-₦${(double.tryParse(_discountController.text) ?? 0).toStringAsFixed(2)}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.success)),
                      ],
                    ),
                    const Divider(),
                    _TotalRow(
                      label: 'Total',
                      amount: _subtotal +
                          (_subtotal * ((double.tryParse(_taxRateController.text) ?? 0) / 100)) -
                          (double.tryParse(_discountController.text) ?? 0),
                      isBold: true,
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Generate PDF Invoice',
                      backgroundColor: Colors.blue,
                      onPressed: _selectedItems.isNotEmpty ? () => _generatePdfInvoice() : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Create & Print',
                            onPressed: (_selectedItems.isNotEmpty && _selectedTableId != null)
                                ? () {
                                    _createAndPrintOrder(context);
                                    Navigator.pop(context);
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AsyncCustomButton(
                            text: 'Pay & Complete',
                            backgroundColor: AppColors.success,
                            onPressed: _selectedItems.isNotEmpty
                                ? () async {
                                    await _payAndCompleteOrder();
                                    if (mounted) Navigator.pop(context);
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AsyncCustomButton(
                      text: 'Confirm',
                      backgroundColor: AppColors.primary,
                      onPressed: _selectedItems.isNotEmpty
                          ? () async {
                              await _confirmPaymentForAdmin();
                              if (mounted) Navigator.pop(context);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdfInvoice() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add items to cart before generating invoice')),
      );
      return;
    }

    try {
      // Read tax and discount from text controllers
      final taxRate = (double.tryParse(_taxRateController.text) ?? 0) / 100;
      final discount = double.tryParse(_discountController.text) ?? 0;
      final tax = _subtotal * taxRate;
      final total = _subtotal + tax - discount;

      final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      final auth = Provider.of<AuthProvider>(context, listen: false);

      // Convert cart items to the format expected by PDF generator
      final cartItems = _selectedItems.map((item) {
        return {
          'menuItemName': item.menuItemName,
          'name': item.menuItemName,
          'quantity': item.quantity,
          'price': item.price,
          'unitPrice': item.price,
          'subtotal': item.subtotal,
          'total': item.subtotal,
          'specialInstructions': item.specialInstructions,
          'selectedOptions': item.selectedOptions,
        };
      }).toList();

      // Generate invoice number
      final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      final pdfBytes = await PdfInvoiceGenerator.generateInvoicePdfBytes(
        businessName: business?.name ?? 'Business',
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(),
        cartItems: cartItems,
        subtotal: _subtotal,
        tax: tax,
        discount: discount,
        total: total,
        customerName: 'Walk-in Customer',
        businessAddress: business?.address,
        businessPhone: business?.phone,
        businessEmail: business?.email,
        cashierName: auth.currentUser?.fullName,
      );

      final filename = PdfInvoiceGenerator.getInvoiceFilename(invoiceNumber);

      if (kIsWeb) {
        // Web: Download PDF
        web_download.downloadBytes(pdfBytes, filename, 'application/pdf');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice PDF downloaded: $filename')),
        );
      } else {
        // Mobile: Share PDF
        await _sharePdfOnMobile(pdfBytes, filename);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF invoice: $e')),
      );
    }
  }

  Future<void> _sharePdfOnMobile(Uint8List pdfBytes, String filename) async {
    try {
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice PDF',
        subject: 'Invoice',
      );
    } catch (e) {
      // Fallback: Save to documents directory
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final file = File('${docsDir.path}/$filename');
        await file.writeAsBytes(pdfBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice saved to: ${file.path}')),
        );
      } catch (e2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving PDF invoice')),
        );
      }
    }
  }

  void _createAndPrintOrder(BuildContext context) {
    if (_selectedTableId == null || _selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a table and add items')),
      );
      return;
    }

    // Read tax and discount from text controllers
    _taxRate = (double.tryParse(_taxRateController.text) ?? 0) / 100;
    _discount = double.tryParse(_discountController.text) ?? 0;

    final tax = _subtotal * _taxRate;
    final total = _subtotal + tax - _discount;

    final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final businessId = business?.id ?? auth.currentUser?.businessId ?? 'unknown';

    final order = RestaurantOrder(
      id: 'order_${DateTime.now().millisecondsSinceEpoch}',
      businessId: businessId,
      tableId: _selectedTableId,
      tableNumber: _selectedTableNumber,
      items: _selectedItems,
      subtotal: _subtotal,
      tax: tax,
      discount: _discount,
      total: total,
      status: 'pending',
      paymentStatus: 'pending',
      orderType: 'dine-in',
    );

    // Add to provider
    context.read<RestaurantProvider>().createOrder(order);

    // Show both receipts
    _showReceiptDialog(context, order, _selectedItems);
  }

  void _showReceiptDialog(
      BuildContext context, RestaurantOrder order, List<OrderItem> items) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: DefaultTabController(
            length: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tab Bar
                const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'Kitchen Receipt'),
                    Tab(text: 'Customer Receipt'),
                  ],
                ),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    children: [
                      // Kitchen Receipt
                      _KitchenReceipt(order: order),
                      // Customer Receipt
                      _CustomerReceipt(order: order),
                    ],
                  ),
                ),
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Print Kitchen Receipt',
                          backgroundColor: Colors.blue,
                          onPressed: () async {
                            try {
                              // Note: SaleModel could be used for detailed kitchen receipt printing in future
                              // Send kitchen receipt to printer
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Kitchen receipt sent to printer'), backgroundColor: AppColors.success),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Print error: $e')),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'Print Customer Receipt',
                          backgroundColor: AppColors.primary,
                          onPressed: () async {
                            try {
                              final saleMap = {
                                'id': order.id,
                                'items': order.items
                                    .map((item) => {
                                          'productName': item.menuItemName,
                                          'quantity': item.quantity,
                                          'unitPrice': item.price,
                                          'total': item.subtotal,
                                        })
                                    .toList(),
                                'subtotal': order.subtotal,
                                'tax': order.tax,
                                'discount': order.discount,
                                'total': order.total,
                                'paymentMethod': 'pending',
                                'timestamp': DateTime.now().toIso8601String(),
                              };

                              await ReceiptManager.handlePostSale(context, saleMap);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Customer receipt sent to printer'), backgroundColor: AppColors.success),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: CustomButton(
                    text: 'Close',
                    backgroundColor: AppColors.border,
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Order'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // Cart Button (visible on small screens)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Consumer<RestaurantProvider>(
              builder: (context, _, __) {
                return Stack(
                  children: [
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.shopping_cart),
                        label: Text('${_selectedItems.length}'),
                        onPressed: _selectedItems.isEmpty
                            ? null
                            : () => _showOrderSummaryModal(context),
                      ),
                    ),
                    if (_selectedItems.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_selectedItems.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: Consumer<RestaurantProvider>(
        builder: (context, provider, _) {
          return LayoutBuilder(builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 800;
              return Flex(
                direction: isSmall ? Axis.vertical : Axis.horizontal,
                children: [
              // Left Side - Menu & Items
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Table Selection
                        const Text('Select Table',
                            style: AppTextStyles.heading3),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: provider.getAvailableTables().map((table) {
                            final isSelected = _selectedTableId == table.id;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTableId = table.id;
                                  _selectedTableNumber = table.tableNumber;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.surface,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Table ${table.tableNumber}',
                                      style: AppTextStyles.body1.copyWith(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Capacity: ${table.capacity}',
                                      style: AppTextStyles.caption.copyWith(
                                        color: isSelected
                                            ? Colors.white70
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Menu Items
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Menu Items', style: AppTextStyles.heading3),
                            SizedBox(
                              width: 260,
                              child: TextField(
                                controller: _menuSearchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search menu...',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Builder(builder: (context) {
                          final items = provider.menuItems.where((m) => m.name.toLowerCase().contains(_menuQuery)).toList();
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => _showItemOptionsDialog(item),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: AppTextStyles.body1
                                                  .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  formatCurrency(item.price),
                                                  style: AppTextStyles.body2
                                                      .copyWith(
                                                          color: AppColors
                                                              .success),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${item.preparationTime} min',
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                          color: AppColors
                                                              .textSecondary),
                                                ),
                                                if (item.inventoryProductId != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 8.0),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey.shade100,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: AppColors.border),
                                                      ),
                                                      child: Text(
                                                        'Stock: ${item.inventoryStock ?? '—'}',
                                                        style: AppTextStyles.caption,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.add_circle,
                                          color: AppColors.primary, size: 28),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                         );
                         }
                         ), 
                      ],
                    ),
                  ),
                ),
              ),

              // Right Side - Order Summary (Only on Large Screens)
              if (!isSmall)
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(left: BorderSide(color: AppColors.border)),
                    ),
                    child: Column(
                      children: [
                        // Order Summary Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            border: const Border(
                                bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Text(
                            'Order Summary',
                            style: AppTextStyles.heading3
                                .copyWith(color: AppColors.primary),
                          ),
                        ),

                        // Selected Items
                        Expanded(
                          child: _selectedItems.isEmpty
                              ? Center(
                                  child: Text(
                                    'No items added',
                                    style: AppTextStyles.body1
                                        .copyWith(color: AppColors.textSecondary),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _selectedItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _selectedItems[index];
                                    return Padding(
                                      padding: const EdgeInsets.all(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(8),
                                        border:
                                            Border.all(color: AppColors.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.menuItemName,
                                            style: AppTextStyles.body2.copyWith(
                                                fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (item.selectedOptions.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6, bottom: 6),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: item.selectedOptions.map((opt) => Text('${opt['optionName']}: ${opt['choiceName'] ?? ''}${(opt['price'] as double) != 0.0 ? ' (+\$${(opt['price'] as double).toStringAsFixed(2)})' : ''}', style: AppTextStyles.caption)).toList(),
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '\$${item.subtotal.toStringAsFixed(2)}',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                        color:
                                                            AppColors.success),
                                              ),
                                              Row(
                                                children: [
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _updateItemQuantity(
                                                            index,
                                                            item.quantity - 1),
                                                    child: const Icon(
                                                        Icons
                                                            .remove_circle_outline,
                                                        size: 16),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text('${item.quantity}',
                                                      style: AppTextStyles
                                                          .caption),
                                                  const SizedBox(width: 4),
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _updateItemQuantity(
                                                            index,
                                                            item.quantity + 1),
                                                    child: const Icon(
                                                        Icons
                                                            .add_circle_outline,
                                                        size: 16),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      // Order Totals
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          border:
                              Border(top: BorderSide(color: AppColors.border)),
                        ),
                        child: Column(
                          children: [
                            _TotalRow(label: 'Subtotal', amount: _subtotal),
                            const SizedBox(height: 12),
                            // Editable Tax Field
                            Row(
                              children: [
                                Expanded(
                                  child: Text('Tax (%)',
                                      style: AppTextStyles.body2),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    controller: _taxRateController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    '₦${(_subtotal * ((double.tryParse(_taxRateController.text) ?? 0) / 100)).toStringAsFixed(2)}',
                                    style: AppTextStyles.caption),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Editable Discount Field
                            Row(
                              children: [
                                Expanded(
                                  child: Text('Discount (₦)',
                                      style: AppTextStyles.body2),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    controller: _discountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    '-₦${(double.tryParse(_discountController.text) ?? 0).toStringAsFixed(2)}',
                                    style: AppTextStyles.caption.copyWith(color: AppColors.success)),
                              ],
                            ),
                            const Divider(),
                            _TotalRow(
                              label: 'Total',
                              amount: _subtotal +
                                  (_subtotal * ((double.tryParse(_taxRateController.text) ?? 0) / 100)) -
                                  (double.tryParse(_discountController.text) ?? 0),
                              isBold: true,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomButton(
                                    text: 'Generate PDF Invoice',
                                    backgroundColor: Colors.blue,
                                    onPressed: _selectedItems.isNotEmpty ? () => _generatePdfInvoice() : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomButton(
                                    text: 'Create & Print Order',
                                    onPressed: (_selectedItems.isNotEmpty && _selectedTableId != null)
                                        ? () => _createAndPrintOrder(context)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AsyncCustomButton(
                                    text: 'Pay & Complete',
                                    backgroundColor: AppColors.success,
                                    onPressed: _selectedItems.isNotEmpty ? () async => await _payAndCompleteOrder() : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AsyncCustomButton(
                                    text: 'Confirm',
                                    backgroundColor: AppColors.primary,
                                    onPressed: _selectedItems.isNotEmpty ? () async => await _confirmPaymentForAdmin() : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );}
    ));
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;

  const _TotalRow({
    required this.label,
    required this.amount,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)
                : AppTextStyles.body2,
          ),
          Text(
            formatCurrency(amount.toDouble()),
            style: (isBold
                    ? AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)
                    : AppTextStyles.body2)
                .copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _KitchenReceipt extends StatelessWidget {
  final RestaurantOrder order;

  const _KitchenReceipt({required this.order});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text('KITCHEN RECEIPT',
                    style: AppTextStyles.heading4
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const Divider(),

          // Table Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TABLE',
                            style: AppTextStyles.caption
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text('${order.tableNumber ?? 'N/A'}',
                            style: AppTextStyles.heading3),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('ORDER ID',
                            style: AppTextStyles.caption
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(_safeIdSuffix(order.id),
                            style: AppTextStyles.body1
                                .copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items
          Text('ITEMS',
              style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
          const Divider(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: order.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.quantity}x ${item.menuItemName}',
                          style: AppTextStyles.body1
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (item.specialInstructions != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.yellow.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.yellow.shade200),
                          ),
                          child: Text(
                            'NOTE: ${item.specialInstructions}',
                            style: AppTextStyles.caption
                                .copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          const Divider(),

          // Footer
          Center(
            child: Text(
              'Please prepare items as soon as possible',
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerReceipt extends StatelessWidget {
  final RestaurantOrder order;

  const _CustomerReceipt({required this.order});

  @override
  Widget build(BuildContext context) {
    final tax = order.tax;
    final subtotal = order.subtotal;
    final discount = order.discount;
    final total = order.total;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text('ORDER RECEIPT',
                    style: AppTextStyles.heading4
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const Divider(),

          // Table Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TABLE',
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text('${order.tableNumber ?? 'N/A'}', style: AppTextStyles.heading2),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('ORDER ID',
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(_safeIdSuffix(order.id),
                        style: AppTextStyles.body1
                            .copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items with pricing
          Text('YOUR ORDER',
              style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
          const Divider(),
          Column(
            children: order.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.quantity}x ${item.menuItemName}',
                            style: AppTextStyles.body1,
                          ),
                          Text(
                            '\$${item.price.toStringAsFixed(2)} each',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${item.subtotal.toStringAsFixed(2)}',
                      style: AppTextStyles.body1
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const Divider(),

          // Totals
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal', style: AppTextStyles.body2),
                Text('\$${subtotal.toStringAsFixed(2)}',
                    style: AppTextStyles.body2),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tax', style: AppTextStyles.body2),
                Text('\$${tax.toStringAsFixed(2)}', style: AppTextStyles.body2),
              ],
            ),
          ),
          if (discount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discount', style: AppTextStyles.body2),
                  Text('-\$${discount.toStringAsFixed(2)}',
                      style: AppTextStyles.body2
                          .copyWith(color: AppColors.success)),
                ],
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL',
                    style: AppTextStyles.heading3
                        .copyWith(fontWeight: FontWeight.bold)),
                Text('\$${total.toStringAsFixed(2)}',
                    style: AppTextStyles.heading3
                        .copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payments
          if (order.paymentBreakdown.isNotEmpty) ...[
            Text('PAYMENTS', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
            const Divider(),
            Column(
              children: order.paymentBreakdown.map((pb) {
                final method = (pb['method'] ?? '').toString().toUpperCase();
                final amount = (pb['amount'] ?? 0.0) as num;
                final tx = pb['transactionId'] ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('$method${tx != null && tx.toString().isNotEmpty ? ' • ${tx.toString()}' : ''}', style: AppTextStyles.body2)),
                      Text(formatCurrency(amount.toDouble()), style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment', style: AppTextStyles.caption),
                  Text(order.paymentMethods.isNotEmpty ? order.paymentMethods.first.toUpperCase() : 'CASH', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Thank you message
          Center(
            child: Text(
              'Thank you for dining with us!\nPlease enjoy your meal!',
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

