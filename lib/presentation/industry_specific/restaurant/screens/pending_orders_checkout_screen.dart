import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/async_button.dart';
import '../../../../widgets/custom_button.dart';
import '../../../../services/receipt_manager.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../services/payment_service.dart';
import '../../../../services/offline_sales_service.dart';
import '../../../../data/repositories/sales_repository_impl.dart';
import '../../../../providers/connectivity_provider.dart';
import '../providers/restaurant_provider.dart';
import '../../../../services/pdf_invoice_generator.dart';
import '../../../../services/web_download.dart' as web_download;

class PendingOrdersAndCheckoutScreen extends StatefulWidget {
  const PendingOrdersAndCheckoutScreen({super.key});

  @override
  State<PendingOrdersAndCheckoutScreen> createState() =>
      _PendingOrdersAndCheckoutScreenState();
}

class _PendingOrdersAndCheckoutScreenState
    extends State<PendingOrdersAndCheckoutScreen> {
  String? _selectedOrderId;
  // double _appliedDiscount = 0;
  final String _paymentMethod = 'cash';
  String? _dialogSelectedStore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      if (business != null) {
        context.read<RestaurantProvider>().setBusinessId(business.id);
        context.read<RestaurantProvider>().initializeOrders(businessId: business.id);
      } else {
        context.read<RestaurantProvider>().initializeOrders();
      }
    });
  }

  void _processCheckout(BuildContext context) {
    if (_selectedOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an order to checkout')),
      );
      return;
    }

    final provider = context.read<RestaurantProvider>();
    final order = provider.orders.firstWhere((o) => o.id == _selectedOrderId);

    // Show payment confirmation
    _showPaymentConfirmation(context, order);
  }

  void _showPaymentConfirmation(BuildContext context, RestaurantOrder order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle,
                        color: AppColors.success, size: 48),
                    SizedBox(height: 12),
                    Text('Payment Confirmation', style: AppTextStyles.heading3),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Details
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Order ID:',
                                  style: AppTextStyles.body1),
                              Text(
                                order.id.length >= 6 ? order.id.substring(order.id.length - 6) : order.id,
                                style: AppTextStyles.body1
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Table:', style: AppTextStyles.body1),
                              Text(
                                'Table ${order.tableNumber ?? 'N/A'}',
                                style: AppTextStyles.body1
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Items:', style: AppTextStyles.body1),
                              Text(
                                '${order.items.length} items (${order.items.fold(0, (sum, item) => sum + item.quantity)} qty)',
                                style: AppTextStyles.body1
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal:',
                                  style: AppTextStyles.body2),
                              Text('\$${order.subtotal.toStringAsFixed(2)}',
                                  style: AppTextStyles.body2),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tax:', style: AppTextStyles.body2),
                              Text('\$${order.tax.toStringAsFixed(2)}',
                                  style: AppTextStyles.body2),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount:',
                                  style: AppTextStyles.body2),
                              Text('-\$${order.discount.toStringAsFixed(2)}',
                                  style: AppTextStyles.body2
                                      .copyWith(color: AppColors.success)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('TOTAL:',
                                  style: AppTextStyles.heading4
                                      .copyWith(fontWeight: FontWeight.w600)),
                              Text(
                                '\$${order.total.toStringAsFixed(2)}',
                                style: AppTextStyles.heading4.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Store selector
                    Consumer<RetailProvider>(builder: (context, retail, _) {
                      final stores = retail.stores;
                      if (stores.isEmpty) return const SizedBox.shrink();
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      String selectedStore = auth.currentUser?.storeId ?? '';

                      return StatefulBuilder(builder: (ctx, setState) {
                        selectedStore = selectedStore.isEmpty && stores.isNotEmpty ? stores.first.id : selectedStore;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              const Expanded(child: Text('Store', style: AppTextStyles.body1)),
                              SizedBox(
                                width: 220,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedStore,
                                      isExpanded: true,
                                      items: stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                                      onChanged: (val) => setState(() {
                                        selectedStore = val ?? selectedStore;
                                        _dialogSelectedStore = selectedStore;
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      });
                    }),

                    const SizedBox(height: 20),

                    // Payment Method
                    Text('Payment Method:',
                        style: AppTextStyles.body1
                            .copyWith(fontWeight: FontWeight.w600)),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _paymentMethod == 'cash'
                            ? 'Cash Payment'
                            : 'Card Payment',
                        style: AppTextStyles.body1
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Success Message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.success),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Payment confirmed! Receipt will be printed.',
                              style: AppTextStyles.body2
                                  .copyWith(color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CustomButton(
                      text: 'Generate PDF Invoice',
                      backgroundColor: Colors.blue,
                      onPressed: () => _generatePdfInvoice(order),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Print Receipt',
                            backgroundColor: Colors.blue,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Receipt sent to printer')),
                              );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AsyncCustomButton(
                        text: 'Confirm & Close',
                        onPressed: () async => await _confirmAndCompleteOrder(context, order),
                      ),
                    ),
                  ],
                ),
            ] ),
          )],
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdfInvoice(RestaurantOrder order) async {
    try {
      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final business = businessProvider.currentBusiness;

      // Convert order items to cart items format
      final cartItems = order.items.map((item) {
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

      final invoiceNumber = 'INV-${order.id.split('-').last}';

      final pdfBytes = await PdfInvoiceGenerator.generateInvoicePdfBytes(
        businessName: business?.name ?? 'Restaurant',
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(),
        cartItems: cartItems,
        subtotal: order.subtotal,
        tax: order.tax,
        discount: order.discount,
        total: order.total,
        customerName: order.customerName ?? 'Customer',
        customerEmail: order.customerEmail,
        businessAddress: business?.address,
        businessPhone: business?.phone,
        businessEmail: business?.email,
        cashierName: authProvider.currentUser?.fullName,
      );

      final filename = PdfInvoiceGenerator.getInvoiceFilename(invoiceNumber);

      if (kIsWeb) {
        web_download.downloadBytes(pdfBytes, filename, 'application/pdf');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice PDF downloaded: $filename')),
        );
      } else {
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
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice PDF',
        subject: 'Invoice',
      );
    } catch (e) {
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

  Future<void> _confirmAndCompleteOrder(
      BuildContext context, RestaurantOrder order) async {
    try {
      // Get business ID from BusinessProvider, fallback to auth
      final businessProvider =
          Provider.of<BusinessProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final businessId = businessProvider.currentBusiness?.id ??
          authProvider.currentUser?.businessId;

      if (businessId == null || businessId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business ID not found')),
        );
        return;
      }

      // Create sale record in Firestore
      final itemsList = order.items.map((item) {
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

      // If payment method is card, attempt to process payment first
      if (_paymentMethod == 'card') {
        try {
          final publicKey = await PaymentService().getPublicKey() ?? '';
          final txRef = 'rest-${DateTime.now().millisecondsSinceEpoch}';
          final pmResult = await PaymentService().processPayment(
            context: context,
            amount: order.total,
            currency: 'USD',
            email: order.customerEmail ?? '',
            fullName: order.customerName ?? (authProvider.currentUser?.fullName ?? 'Guest'),
            txRef: txRef,
            publicKey: publicKey,
            businessId: businessId,
          );

          if (pmResult['success'] != true) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Payment failed: ${pmResult['message'] ?? 'unknown'}'), backgroundColor: AppColors.error),
            );
            return;
          }
        } catch (e) {
          debugPrint('[RestaurantPOS] Payment error during checkout: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment error: $e'), backgroundColor: AppColors.error),
          );
          return;
        }
      }

      final saleData = {
        'businessId': businessId,
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
        'paymentMethod': _paymentMethod,
        'category': 'Restaurant',
        'status': 'completed',
        if ((_dialogSelectedStore ?? '').isNotEmpty)
          'storeId': _dialogSelectedStore!,
        if ((_dialogSelectedStore ?? '').isEmpty && (authProvider.currentUser?.storeId ?? '').isNotEmpty)
          'storeId': authProvider.currentUser!.storeId,
        if (authProvider.currentUser?.id != null)
          'workerId': authProvider.currentUser!.id,
        if (authProvider.currentUser?.fullName != null)
          'workerName': authProvider.currentUser!.fullName,
      };

      // Save sale using offline-aware service
      final firestore = FirebaseFirestore.instance;
      final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
      final salesRepository = SalesRepositoryImpl(firestore: firestore);
      final offlineSalesService = OfflineSalesService(
        salesRepository: salesRepository,
        connectivityProvider: connectivityProvider,
      );

      final result = await offlineSalesService.createSale(saleData);

      if (!result['success']) {
        throw Exception(result['error'] ?? 'Failed to save sale');
      }

      final isOffline = result['mode'] == 'offline';

      // Update order status to completed
      context
          .read<RestaurantProvider>()
          .updateOrderStatus(_selectedOrderId!, 'completed');

      // Attempt to deduct inventory where menu items map to inventory products
      try {
        final retail = Provider.of<RetailProvider>(context, listen: false);
        for (final item in order.items) {
          final pid = item.inventoryProductId;
          if (pid != null && pid.isNotEmpty) {
            final prod = retail.products.firstWhere((p) => p.id == pid, orElse: () => Product(id: '', name: '', price: 0, stock: 0, category: ''));
            if (prod.id.isNotEmpty) {
              final newStock = (prod.stock - item.quantity) < 0 ? 0 : (prod.stock - item.quantity);
              final updated = Product(
                id: prod.id,
                name: prod.name,
                price: prod.price,
                  cost: prod.cost.toDouble(),
                stock: newStock.toDouble(),
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
        debugPrint('[RestaurantPOS] Inventory deduction failed: $e');
      }

      if (!mounted) return;

      // Show receipt with options
      final saleMap = {
        'id': order.id,
        'items': itemsList,
        'subtotal': order.subtotal,
        'tax': order.tax,
        'discount': order.discount,
        'total': order.total,
        'totalAmount': order.total,
        'finalAmount': order.total,
        'paymentMethod': _paymentMethod,
        'timestamp': DateTime.now().toIso8601String(),
        if ((_dialogSelectedStore ?? '').isNotEmpty)
          'storeId': _dialogSelectedStore!,
        if ((_dialogSelectedStore ?? '').isEmpty && (authProvider.currentUser?.storeId ?? '').isNotEmpty)
          'storeId': authProvider.currentUser!.storeId,
        if (authProvider.currentUser?.id != null)
          'workerId': authProvider.currentUser!.id,
        if (authProvider.currentUser?.fullName != null)
          'workerName': authProvider.currentUser!.fullName,
      };
      try {
        await ReceiptManager.handlePostSale(context, saleMap);
      } catch (e) {
        debugPrint('[RestaurantPOS] Receipt error: $e');
      }

      // Close dialog
      Navigator.pop(context);

      final successMessage = isOffline
        ? '✓ Order completed and saved offline (will sync when online)'
        : '✓ Order completed and payment recorded';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('[RestaurantPOS] Checkout error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pending Orders & Checkout'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<RestaurantProvider>(
        builder: (context, provider, _) {
          final pendingOrders = provider.getOrdersByStatus('pending');
          final preparingOrders = provider.getOrdersByStatus('preparing');
          final readyOrders = provider.getOrdersByStatus('ready');

          return Row(
            children: [
              // Left: All Orders
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Tabs
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border:
                            Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Active Orders',
                                style: AppTextStyles.heading3),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _OrderStatusBadge(
                                    label: 'Pending',
                                    count: pendingOrders.length,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 12),
                                  _OrderStatusBadge(
                                    label: 'Preparing',
                                    count: preparingOrders.length,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  _OrderStatusBadge(
                                    label: 'Ready to Serve',
                                    count: readyOrders.length,
                                    color: AppColors.success,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Orders List
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Pending Orders
                          if (pendingOrders.isNotEmpty) ...[
                            const Text('Pending Orders',
                                style: AppTextStyles.heading3),
                            const SizedBox(height: 12),
                            ...pendingOrders.map(
                                (order) => _buildOrderCard(order, context)),
                            const SizedBox(height: 24),
                          ],

                          // Preparing Orders
                          if (preparingOrders.isNotEmpty) ...[
                            const Text('Preparing',
                                style: AppTextStyles.heading3),
                            const SizedBox(height: 12),
                            ...preparingOrders.map(
                                (order) => _buildOrderCard(order, context)),
                            const SizedBox(height: 24),
                          ],

                          // Ready Orders
                          if (readyOrders.isNotEmpty) ...[
                            const Text('Ready to Serve',
                                style: AppTextStyles.heading3),
                            const SizedBox(height: 12),
                            ...readyOrders.map(
                                (order) => _buildOrderCard(order, context)),
                          ],

                          if (pendingOrders.isEmpty &&
                              preparingOrders.isEmpty &&
                              readyOrders.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  'No active orders',
                                  style: AppTextStyles.body1
                                      .copyWith(color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Right: Checkout Panel
              Container(
                width: 320,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(left: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        border: const Border(
                            bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Text('Checkout',
                          style: AppTextStyles.heading3
                              .copyWith(color: AppColors.primary)),
                    ),

                    // Selected Order Details
                    if (_selectedOrderId != null)
                      Expanded(
                        child: Consumer<RestaurantProvider>(
                          builder: (context, provider, _) {
                            final order = provider.orders
                                .firstWhere((o) => o.id == _selectedOrderId);
                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Order Details',
                                      style: AppTextStyles.body1.copyWith(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 12),
                                  _DetailRow(
                                      label: 'Table',
                                      value: 'Table ${order.tableNumber ?? 'N/A'}'),
                                  _DetailRow(
                                      label: 'Items',
                                      value: '${order.items.length}'),
                                  _DetailRow(
                                      label: 'Status',
                                      value: order.status.toUpperCase()),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  Text('Items',
                                      style: AppTextStyles.body1.copyWith(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  ...order.items.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                                '${item.quantity}x ${item.menuItemName}',
                                                style: AppTextStyles.caption),
                                          ),
                                          Text(
                                              '\$${item.subtotal.toStringAsFixed(2)}',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                        ],
                                      ),
                                    );
                                  }),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  _DetailRow(
                                      label: 'Subtotal',
                                      value:
                                          '\$${order.subtotal.toStringAsFixed(2)}'),
                                  _DetailRow(
                                      label: 'Tax',
                                      value:
                                          '\$${order.tax.toStringAsFixed(2)}'),
                                  _DetailRow(
                                      label: 'Discount',
                                      value:
                                          '-\$${order.discount.toStringAsFixed(2)}'),
                                  const Divider(),
                                  _DetailRow(
                                    label: 'TOTAL',
                                    value:
                                        '\$${order.total.toStringAsFixed(2)}',
                                    isBold: true,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Expanded(
                        child: Center(
                          child: Text(
                            'Select an order to checkout',
                            style: AppTextStyles.body1
                                .copyWith(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                    // Checkout Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: AsyncCustomButton(
                        text: 'Process Payment',
                        onPressed: _selectedOrderId != null
                            ? () async =>  _processCheckout(context)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(RestaurantOrder order, BuildContext context) {
    final isSelected = _selectedOrderId == order.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOrderId = order.id;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Table ${order.tableNumber ?? 'N/A'}',
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.w600)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.status,
                    style: AppTextStyles.caption
                        .copyWith(color: _getStatusColor(order.status)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                '${order.items.length} items • \$${order.total.toStringAsFixed(2)}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'preparing':
        return AppColors.primary;
      case 'ready':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _OrderStatusBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _OrderStatusBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: AppTextStyles.caption
                  .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: isBold
                  ? AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)
                  : AppTextStyles.body2),
          Text(value,
              style: isBold
                  ? AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)
                  : AppTextStyles.body2),
        ],
      ),
    );
  }
}
