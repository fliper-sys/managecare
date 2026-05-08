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
import '../../../../core/utils/currency.dart';
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
    final order = _selectedOrderFromProvider(provider);
    if (order == null) {
      setState(() {
        _selectedOrderId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The selected order is no longer available')),
      );
      return;
    }

    // Show payment confirmation
    _showPaymentConfirmation(context, order);
  }

  RestaurantOrder? _selectedOrderFromProvider(RestaurantProvider provider) {
    final selectedId = _selectedOrderId;
    if (selectedId == null) return null;

    for (final order in provider.orders) {
      if (order.id == selectedId) {
        return order;
      }
    }

    return null;
  }

  void _showPaymentConfirmation(BuildContext context, RestaurantOrder order) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final isCompact = size.width < 560;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 16,
            vertical: 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: size.height * 0.92,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 16 : 24,
                      20,
                      isCompact ? 16 : 24,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              _DetailRow(
                                label: 'Order ID',
                                value: order.id.length >= 6
                                    ? order.id.substring(order.id.length - 6)
                                    : order.id,
                              ),
                              _DetailRow(
                                label: 'Table',
                                value: 'Table ${order.tableNumber ?? 'N/A'}',
                              ),
                              _DetailRow(
                                label: 'Items',
                                value:
                                    '${order.items.length} items (${order.items.fold<int>(0, (sum, item) => sum + item.quantity)} qty)',
                              ),
                              const Divider(),
                              _DetailRow(
                                label: 'Subtotal',
                                value: formatCurrency(order.subtotal),
                              ),
                              _DetailRow(
                                label: 'Tax',
                                value: formatCurrency(order.tax),
                              ),
                              _DetailRow(
                                label: 'Discount',
                                value: '-${formatCurrency(order.discount)}',
                              ),
                              const Divider(),
                              _DetailRow(
                                label: 'TOTAL',
                                value: formatCurrency(order.total),
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Consumer<RetailProvider>(builder: (context, retail, _) {
                          final stores = retail.stores;
                          if (stores.isEmpty) return const SizedBox.shrink();
                          final auth =
                              Provider.of<AuthProvider>(context, listen: false);
                          String selectedStore = auth.currentUser?.storeId ?? '';

                          return StatefulBuilder(builder: (ctx, setState) {
                            selectedStore = selectedStore.isEmpty && stores.isNotEmpty
                                ? stores.first.id
                                : selectedStore;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Wrap(
                                runSpacing: 12,
                                spacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Store',
                                    style: AppTextStyles.body1.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: isCompact ? size.width * 0.55 : 220,
                                      maxWidth: isCompact ? size.width * 0.72 : 260,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedStore,
                                          isExpanded: true,
                                          items: stores
                                              .map((s) => DropdownMenuItem(
                                                    value: s.id,
                                                    child: Text(
                                                      s.name,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ))
                                              .toList(),
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
                        const SizedBox(height: 8),
                        Text(
                          'Payment Method',
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            _paymentMethod == 'cash'
                                ? 'Cash Payment'
                                : 'Card Payment',
                            style: AppTextStyles.body1.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.success.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: AppColors.success),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Payment confirmed. Receipt and invoice actions are ready.',
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
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 16 : 20,
                      0,
                      isCompact ? 16 : 20,
                      16,
                    ),
                    child: Column(
                      children: [
                        CustomButton(
                          text: 'Generate PDF Invoice',
                          backgroundColor: Colors.blue,
                          onPressed: () => _generatePdfInvoice(order),
                        ),
                        const SizedBox(height: 8),
                        if (isCompact) ...[
                          CustomButton(
                            text: 'Print Receipt',
                            backgroundColor: Colors.blue,
                            onPressed: () {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Receipt sent to printer'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          AsyncCustomButton(
                            text: 'Confirm & Close',
                            onPressed: () async =>
                                await _confirmAndCompleteOrder(dialogContext, order),
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: CustomButton(
                                  text: 'Print Receipt',
                                  backgroundColor: Colors.blue,
                                  onPressed: () {
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                                      const SnackBar(
                                        content: Text('Receipt sent to printer'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AsyncCustomButton(
                                  text: 'Confirm & Close',
                                  onPressed: () async => await _confirmAndCompleteOrder(
                                    dialogContext,
                                    order,
                                  ),
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
        );
      },
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
        businessLogoUrl: business?.photoUrl ?? business?.logoUrl,
        subscriptionTier: business?.subscriptionTier,
        businessClass: business?.businessClass,
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
      String? paymentTransactionId;

      // If payment method is card, attempt to process payment first
      if (_paymentMethod == 'card') {
        try {
          final publicKey = await PaymentService().getPublicKey() ?? '';
          final txRef = 'rest-${DateTime.now().millisecondsSinceEpoch}';
          final pmResult = await PaymentService().processPayment(
            context: context,
            amount: order.total,
            currency: 'NGN',
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
          paymentTransactionId =
              (pmResult['transactionId'] ?? pmResult['txRef'] ?? txRef)
                  .toString();
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
        'customerName': order.customerName,
        'customerEmail': order.customerEmail,
        'customerPhone': order.customerPhone,
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
        'paymentMethod': _paymentMethod,
        'paymentMethods': [_paymentMethod],
        'paymentBreakdown': [
          {
            'method': _paymentMethod,
            'amount': order.total,
            'transactionId': paymentTransactionId ?? order.id,
          }
        ],
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

      // Update order status and payment state
      await context.read<RestaurantProvider>().updateOrderPaymentStatus(
            _selectedOrderId!,
            paymentStatus: 'paid',
            status: 'completed',
            paymentMethods: [_paymentMethod],
            paymentBreakdown: [
              {
                'method': _paymentMethod,
                'amount': order.total,
                'transactionId': paymentTransactionId ?? order.id,
              }
            ],
          );

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
                wholesalePrice: prod.wholesalePrice,
                stock: newStock.toDouble(),
                category: prod.category,
                imageUrl: prod.imageUrl,
                barcode: prod.barcode,
                emoji: prod.emoji,
                unit: prod.unit,
                saleUnit: prod.resolvedSaleUnit,
                saleUnitMultiplier: prod.resolvedSaleUnitMultiplier,
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
        'orderId': order.id,
        'customerName': order.customerName,
        'items': itemsList,
        'subtotal': order.subtotal,
        'tax': order.tax,
        'discount': order.discount,
        'total': order.total,
        'totalAmount': order.total,
        'finalAmount': order.total,
        'paymentStatus': 'paid',
        'paymentMethod': _paymentMethod,
        'paymentMethods': [_paymentMethod],
        'paymentBreakdown': [
          {
            'method': _paymentMethod,
            'amount': order.total,
            'transactionId': paymentTransactionId ?? order.id,
          }
        ],
        'category': 'Restaurant',
        'tableNumber': order.tableNumber,
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

      if (mounted) {
        setState(() {
          _selectedOrderId = null;
        });
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
          final unpaidOrders = provider.pendingPaymentOrders;
          final pendingOrders =
              unpaidOrders.where((o) => o.status == 'pending').toList();
          final preparingOrders =
              unpaidOrders.where((o) => o.status == 'preparing').toList();
          final readyOrders =
              unpaidOrders.where((o) => o.status == 'ready').toList();
          final awaitingPaymentOrders = unpaidOrders
              .where((o) => o.status == 'served' || o.status == 'completed')
              .toList();
          return LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 960;
              final checkoutHeight = _selectedOrderId == null ? 180.0 : 320.0;
              final checkoutWidth =
                  (constraints.maxWidth * 0.34).clamp(320.0, 380.0).toDouble();

              final ordersPane = _buildOrdersPane(
                context: context,
                unpaidOrders: unpaidOrders,
                pendingOrders: pendingOrders,
                preparingOrders: preparingOrders,
                readyOrders: readyOrders,
                awaitingPaymentOrders: awaitingPaymentOrders,
              );

              final checkoutPane = _buildCheckoutPanel(
                context: context,
                provider: provider,
                isCompact: isCompact,
              );

              if (isCompact) {
                return Column(
                  children: [
                    Expanded(child: ordersPane),
                    SafeArea(
                      top: false,
                      child: SizedBox(
                        height: checkoutHeight,
                        child: checkoutPane,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 2, child: ordersPane),
                  SizedBox(width: checkoutWidth, child: checkoutPane),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOrdersPane({
    required BuildContext context,
    required List<RestaurantOrder> unpaidOrders,
    required List<RestaurantOrder> pendingOrders,
    required List<RestaurantOrder> preparingOrders,
    required List<RestaurantOrder> readyOrders,
    required List<RestaurantOrder> awaitingPaymentOrders,
  }) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Orders Awaiting Payment',
                  style: AppTextStyles.heading3,
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep service moving while you settle all unpaid tables in one place.',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _OrderStatusBadge(
                        label: 'Payment Queue',
                        count: unpaidOrders.length,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 12),
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
                      const SizedBox(width: 12),
                      _OrderStatusBadge(
                        label: 'Awaiting Payment',
                        count: awaitingPaymentOrders.length,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pendingOrders.isNotEmpty) ...[
                const Text('Pending Orders', style: AppTextStyles.heading3),
                const SizedBox(height: 12),
                ...pendingOrders.map((order) => _buildOrderCard(order, context)),
                const SizedBox(height: 24),
              ],
              if (preparingOrders.isNotEmpty) ...[
                const Text('Preparing', style: AppTextStyles.heading3),
                const SizedBox(height: 12),
                ...preparingOrders.map((order) => _buildOrderCard(order, context)),
                const SizedBox(height: 24),
              ],
              if (readyOrders.isNotEmpty) ...[
                const Text('Ready to Serve', style: AppTextStyles.heading3),
                const SizedBox(height: 12),
                ...readyOrders.map((order) => _buildOrderCard(order, context)),
                const SizedBox(height: 24),
              ],
              if (awaitingPaymentOrders.isNotEmpty) ...[
                const Text('Awaiting Payment', style: AppTextStyles.heading3),
                const SizedBox(height: 12),
                ...awaitingPaymentOrders.map(
                  (order) => _buildOrderCard(order, context),
                ),
              ],
              if (pendingOrders.isEmpty &&
                  preparingOrders.isEmpty &&
                  readyOrders.isEmpty &&
                  awaitingPaymentOrders.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No unpaid active orders',
                      style: AppTextStyles.body1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutPanel({
    required BuildContext context,
    required RestaurantProvider provider,
    required bool isCompact,
  }) {
    final selectedOrder = _selectedOrderFromProvider(provider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: isCompact
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
          top: isCompact
              ? const BorderSide(color: AppColors.border)
              : BorderSide.none,
        ),
        borderRadius: isCompact
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.zero,
        boxShadow: isCompact
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, -6),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              border: const Border(
                bottom: BorderSide(color: AppColors.border),
              ),
              borderRadius: isCompact
                  ? const BorderRadius.vertical(top: Radius.circular(24))
                  : BorderRadius.zero,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isCompact ? 'Checkout Summary' : 'Checkout',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selectedOrder != null)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Details',
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Table',
                      value: 'Table ${selectedOrder.tableNumber ?? 'N/A'}',
                    ),
                    _DetailRow(
                      label: 'Items',
                      value: '${selectedOrder.items.length}',
                    ),
                    _DetailRow(
                      label: 'Status',
                      value: selectedOrder.status.toUpperCase(),
                    ),
                    _DetailRow(
                      label: 'Payment',
                      value: selectedOrder.paymentStatus.toUpperCase(),
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Items',
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...selectedOrder.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity}x ${item.menuItemName}',
                                style: AppTextStyles.caption,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              formatCurrency(item.subtotal),
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Subtotal',
                      value: formatCurrency(selectedOrder.subtotal),
                    ),
                    _DetailRow(
                      label: 'Tax',
                      value: formatCurrency(selectedOrder.tax),
                    ),
                    _DetailRow(
                      label: 'Discount',
                      value: '-${formatCurrency(selectedOrder.discount)}',
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'TOTAL',
                      value: formatCurrency(selectedOrder.total),
                      isBold: true,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Select an order to checkout',
                    style: AppTextStyles.body1.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AsyncCustomButton(
              text: 'Process Payment',
              onPressed: selectedOrder != null
                  ? () async => _processCheckout(context)
                  : null,
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Table ${order.tableNumber ?? 'N/A'}',
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: order.paymentStatus == 'paid'
                            ? AppColors.success.withOpacity(0.12)
                            : AppColors.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        order.paymentStatus,
                        style: AppTextStyles.caption.copyWith(
                          color: order.paymentStatus == 'paid'
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                '${order.items.length} items • ${order.customerName ?? 'Walk-in'} • ${formatCurrency(order.total)}',
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: isBold
                  ? AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)
                  : AppTextStyles.body2,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: isBold
                  ? AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)
                  : AppTextStyles.body2,
            ),
          ),
        ],
      ),
    );
  }
}
