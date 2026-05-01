import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/constants/routes.dart';
import '../../../services/receipt_manager.dart';
import '../../../services/email_service.dart';
import '../../../services/pdf_invoice_generator.dart';
import '../../../services/web_download.dart' as web_download;
import '../../../services/web_email_receipt_service.dart';
import '../../../services/notification_and_email_service.dart';
import '../../../services/barcode_service.dart';
import '../../../services/analytics_service.dart';
import '../../../core/utils/currency.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/async_button.dart';
import '../../../widgets/app_header.dart';
import '../../../providers/retail_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/pharmacy_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../core/utils/receipt_utility.dart';
import '../../../core/utils/search_utils.dart';
import '../../../core/utils/inventory_utils.dart';
import '../../../data/models/customer_model.dart';
import '../../widgets/product_view_switcher.dart';
import 'customer_tracking_screen.dart';
import 'receipt_detail_screen.dart';
import 'sales_history_screen.dart';

class SalesScreen extends StatefulWidget {
  final String title;
  final bool enableStoreSwitcher;

  const SalesScreen({
    super.key,
    this.title = 'New Sale',
    this.enableStoreSwitcher = false,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  static const String _allStoresValue = '__all_stores__';

  late TabController _tabController;
  final _mainSearchController = TextEditingController();
  final _historySearchController = TextEditingController();
  String _historyQuery = '';
  String _selectedStoreFilterId = _allStoresValue;

  // Handheld scanner mode (keyboard wedge) and controller
  bool _handheldMode = false;
  final _handheldController = TextEditingController();
  final _handheldFocusNode = FocusNode();

  // History tab variables
  List<Map<String, dynamic>> _salesHistory = [];
  bool _loadingHistory = false;
  bool _hasMoreHistory = true;
  // Pagination: current fetch limit
  int _historyLimit = _historyPageSize;
  // int _historyPage = 0;
  static const int _historyPageSize = 50;

  // Product filters
  bool _filterInStockOnly = false;
  String _productSort = 'none'; // 'none' | 'priceAsc' | 'priceDesc' | 'name'
  bool _isGridView = true; // Toggle between grid and list view
  String _globalPricingMode = 'retail'; // 'retail' | 'wholesale' - global mode for all items

  // Save reference to RetailProvider for safe cleanup in dispose()
  late RetailProvider _retailProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Save reference to RetailProvider for safe cleanup later
    _retailProvider = context.read<RetailProvider>();

    // Initialize RetailProvider with business ID and load products
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final business = context.read<BusinessProvider>().currentBusiness;

      if (business != null) {
        final businessId = business.id;
        _retailProvider.initialize(businessId).then((_) {
          if (!mounted) return;
          setState(() {
            _globalPricingMode = _retailProvider.activeCartPricingMode;
          });
        });
        // Subscribe to realtime sales history updates
        _retailProvider.subscribeToSalesHistory((sales) {
          if (!mounted) return;
          setState(() {
            _salesHistory = sales;
            _hasMoreHistory = sales.length >= _historyLimit;
          });
          print('[SalesScreen] Realtime sales update: ${sales.length}');
        }, limit: _historyLimit);
      }
    });
  }

  @override
  void dispose() {
    // unsubscribe from provider using saved reference (safe during dispose)
    _retailProvider.unsubscribeFromSalesHistory();
    _tabController.dispose();
    _mainSearchController.dispose();
    _historySearchController.dispose();
    _handheldController.dispose();
    _handheldFocusNode.dispose();
    super.dispose();
  }

  void _showCheckout(BuildContext context, RetailProvider retail) {
    final cartItemCountBeforeCheckout = retail.cartCount;
    final cartTotalBeforeCheckout = retail.cartTotal;
    final cartLabelBeforeCheckout = retail.activeCartLabel;
    final checkoutStoreId = widget.enableStoreSwitcher &&
            _selectedStoreFilterId != _allStoresValue
        ? _selectedStoreFilterId
        : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (sheetContext, scrollController) => _CheckoutSheet(
          items: retail.cartItems,
          total: retail.cartTotal,
          scrollController: scrollController,
          initialStoreId: checkoutStoreId,
          onComplete: (
            customerId,
            customerEmail,
            customerName,
            customerPhone,
            paymentMethod,
            storeId,
            taxRate,
            discount,
            priceOverrides,
          ) async {
            // Capture sale data before clearing cart
            final business =
                Provider.of<BusinessProvider>(context, listen: false)
                    .currentBusiness;
            final pm = (paymentMethod.isNotEmpty)
                ? (paymentMethod[0].toUpperCase() + paymentMethod.substring(1))
                : 'Cash';

            // Build items using provided price overrides
            double subtotal = 0.0;
            final items = retail.cartItems.entries.map((e) {
              final unitPrice = priceOverrides[e.key.id] ??
                  retail.getEffectivePriceForCartItem(e.key.id);
              final total = unitPrice * e.value;
              final pricingMode = retail.getPricingModeForCartItem(e.key.id);
              final saleUnit = retail.getEffectiveSaleUnitForCartItem(e.key.id);
              final saleUnitMultiplier =
                  retail.getEffectiveSaleUnitMultiplierForCartItem(e.key.id);
              subtotal += total;
              return {
                'productId': e.key.id,
                'productName': e.key.name,
                'name': e.key.name,
                'quantity': e.value,
                'unitPrice': unitPrice,
                'price': unitPrice,
                'cost': e.key.cost,
                'costPrice': e.key.cost,
                'pricingMode': pricingMode,
                'inventoryUnit': e.key.unit,
                'saleUnit': saleUnit,
                'saleUnitMultiplier': saleUnitMultiplier,
                'inventoryQuantity': saleUnitMultiplier * e.value,
                'total': total,
              };
            }).toList();

            // Calculate tax and discount amounts
            final taxAmount = subtotal * (taxRate / 100);
            final discountAmount = discount;
            final finalTotal = subtotal + taxAmount - discountAmount;
            String? storeName;
            if (storeId != null && storeId.isNotEmpty) {
              for (final store in retail.stores) {
                if (store.id == storeId) {
                  storeName = store.name;
                  break;
                }
              }
            }

            final saleMap = {
              'id': 'SALE-${DateTime.now().millisecondsSinceEpoch}',
              // Human friendly reference id for display and quick ref
              'referenceId': ReceiptUtility.generateReferenceId(business?.name),
              'cartId': retail.activeCartId,
              'cartLabel': cartLabelBeforeCheckout,
              'items': items,
              'subtotal': subtotal,
              'tax': taxAmount,
              'taxRate': taxRate,
              'discount': discountAmount,
              'total': finalTotal,
              'paymentMethod': pm,
              'paymentBreakdown': [
                {'method': pm, 'amount': finalTotal}
              ],
              'customerId': customerId,
              'customerEmail': customerEmail,
              'customerName': customerName,
              'createdAt': DateTime.now(),
              if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
              if (storeName != null && storeName.isNotEmpty)
                'storeName': storeName,
            };

            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);

            final savedOffline = await retail.checkout(
              paymentMethod: pm,
              customerId: customerId,
              customerEmail: customerEmail,
              customerName: customerName,
              workerId: authProvider.currentUser?.id,
              workerName: authProvider.currentUser?.fullName,
              storeId: storeId,
              tax: taxAmount,
              discount: discountAmount,
              priceOverrides: priceOverrides,
            );

            // Close sheet using sheet context
            if (sheetContext.mounted) Navigator.pop(sheetContext);

            // Use the main screen context for notifications
            if (!context.mounted) return;

            if (savedOffline) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Sale recorded offline and will sync when online'),
                  backgroundColor: AppColors.warning,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sale completed successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
            }

            if (!savedOffline && customerId != null && customerId.isNotEmpty) {
              try {
                final customerProvider =
                    Provider.of<CustomerProvider>(context, listen: false);
                await customerProvider.updateCustomerAfterPurchase(
                  customerId,
                  finalTotal,
                );
              } catch (e) {
                debugPrint(
                    '[SalesScreen] Failed to update customer summary: $e');
              }
            }

            try {
              final businessProvider =
                  Provider.of<BusinessProvider>(context, listen: false);
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              final connectivity =
                  Provider.of<ConnectivityProvider>(context, listen: false);
              final isConnected = connectivity.isConnected;
              final business = businessProvider.currentBusiness;

              if (business != null && isConnected) {
                final emailService = WebEmailReceiptService();
                final saleItems = (saleMap['items'] as List)
                    .map((item) => Map<String, dynamic>.from(item as Map))
                    .toList();
                bool receiptSent = false;

                // Only send receipt email if customer email is provided
                if (customerEmail != null && customerEmail.isNotEmpty) {
                  receiptSent = await emailService.sendReceiptEmail(
                    recipientEmail: customerEmail,
                    receiptNumber: saleMap['id'].toString(),
                    businessName: business.name,
                    customerName: customerName ?? 'Valued Customer',
                    totalAmount: saleMap['total'] as double,
                    subtotal: saleMap['subtotal'] as double,
                    tax: saleMap['tax'] as double,
                    items: saleItems
                        .map((item) => {
                              'name': item['name'],
                              'quantity': item['quantity'],
                              'price': item['price'],
                            })
                        .toList(),
                    paymentMethod: pm,
                    paymentBreakdown:
                        (saleMap['paymentBreakdown'] as List<dynamic>?)
                            ?.map((entry) =>
                                Map<String, dynamic>.from(entry as Map))
                            .toList(),
                    businessLogo: business.logoUrl,
                    businessContact: business.phone,
                  );
                }

                String ownerEmail = '';
                if (business.ownerId.isNotEmpty) {
                  try {
                    final ownerDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(business.ownerId)
                        .get();
                    ownerEmail =
                        ((ownerDoc.data() ?? const <String, dynamic>{})['email']
                                    as String? ??
                                '')
                            .trim();
                  } catch (e) {
                    debugPrint(
                        '[SalesScreen] Failed to resolve owner email: $e');
                  }
                }
                if (ownerEmail.isEmpty) {
                  ownerEmail = (business.email ?? '').trim();
                }
                if (ownerEmail.isEmpty &&
                    authProvider.currentUser?.id == business.ownerId) {
                  ownerEmail = (authProvider.currentUser?.email ?? '').trim();
                }

                bool ownerNotificationSent = false;
                if (ownerEmail.isNotEmpty) {
                  final notif = NotificationAndEmailService();
                  ownerNotificationSent = await notif.sendSalesNotification(
                    ownerEmail: ownerEmail,
                    businessName: business.name,
                    customerName: customerName ?? 'Walk-in Customer',
                    customerEmail: customerEmail ?? '',
                    customerPhone: customerPhone,
                    totalAmount: saleMap['total'] as double,
                    items: saleItems,
                    paymentMethod: pm,
                    receiptNumber:
                        (saleMap['referenceId'] ?? saleMap['id']).toString(),
                    businessId: business.id,
                    cashierName: authProvider.currentUser?.fullName,
                    cashierEmail: authProvider.currentUser?.email,
                    storeName: saleMap['storeName']?.toString(),
                    cartLabel: saleMap['cartLabel']?.toString(),
                    subtotal: saleMap['subtotal'] as double,
                    tax: saleMap['tax'] as double,
                    discount: saleMap['discount'] as double,
                    paymentBreakdown:
                        (saleMap['paymentBreakdown'] as List<dynamic>?)
                            ?.map((entry) =>
                                Map<String, dynamic>.from(entry as Map))
                            .toList(),
                    saleTime: saleMap['createdAt'] as DateTime?,
                  );

                  // Log notification attempt
                  try {
                    final businessId = business.id;
                    await notif.logNotificationEvent(
                      businessId: businessId,
                      type: 'sale',
                      channel: 'email',
                      recipient: ownerEmail,
                      success: ownerNotificationSent,
                      orderId: saleMap['id'].toString(),
                    );
                  } catch (e) {
                    debugPrint('[SalesScreen] Notification log failed: $e');
                  }
                }

                if (receiptSent && ownerNotificationSent) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Receipt and owner notification emails sent!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else if (ownerNotificationSent) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Owner sale alert email sent successfully!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else if (receiptSent) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Customer receipt email sent successfully!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            } catch (e) {
              debugPrint('[SalesScreen] Error sending emails: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sale completed but emails failed: $e'),
                  backgroundColor: Colors.orange,
                ),
              );
            }

            // Small delay to ensure sheet is closed
            await Future.delayed(const Duration(milliseconds: 500));

            // Send order success email if business is on Pro tier (existing behavior)
            try {
              final businessProvider =
                  Provider.of<BusinessProvider>(context, listen: false);
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              final canSendOrderEmail =
                  businessProvider.hasFeatureAccess('email_receipts');
              final userEmail = authProvider.currentUser?.email;
              if (canSendOrderEmail &&
                  userEmail != null &&
                  userEmail.isNotEmpty) {
                await EmailService().sendOrderSuccessAlert(
                  userEmail,
                  {
                    'order_type': 'retail_sale',
                    'itemsCount': cartItemCountBeforeCheckout.toString(),
                    'total': cartTotalBeforeCheckout.toStringAsFixed(2),
                    'cartLabel': cartLabelBeforeCheckout,
                  },
                );
              }
            } catch (_) {}

            // Post-sale receipt actions - Show receipt options dialog
            if (!context.mounted) {
              debugPrint(
                  '[SalesScreen] Context not mounted for receipt dialog');
              return;
            }

            try {
              debugPrint('[SalesScreen] Showing receipt dialog');
              await ReceiptManager.handlePostSale(context, saleMap);
              debugPrint('[SalesScreen] Receipt dialog completed');
            } catch (e) {
              debugPrint('[SalesScreen] Receipt handling error: $e');
            }
          },
        ),
      ),
    );
  }

  Future<void> _generateInvoice(RetailProvider retail) async {
    try {
      if (retail.cartItems.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add items to cart before generating an invoice.')),
        );
        return;
      }

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
      final selectedCustomer = customerProvider.selectedCustomer;

      double subtotal = 0.0;
      final cartItems = retail.cartItems.entries.map((entry) {
        final price = entry.key.price;
        final itemTotal = price * entry.value;
        subtotal += itemTotal;
        return {
          'name': entry.key.name,
          'menuItemName': entry.key.name,
          'quantity': entry.value,
          'price': price,
          'unitPrice': price,
          'subtotal': itemTotal,
          'total': itemTotal,
          'specialInstructions': null,
          'selectedOptions': [],
        };
      }).toList();

      final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';
      final tax = 0.0;
      final discount = 0.0;
      final total = subtotal + tax - discount;

      final pdfBytes = await PdfInvoiceGenerator.generateInvoicePdfBytes(
        businessName: business?.name ?? 'Manage Care',
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(),
        cartItems: cartItems,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total,
        customerName: selectedCustomer?.name ?? 'Walk-in Customer',
        customerEmail: selectedCustomer?.email,
        businessAddress: business?.address,
        businessPhone: business?.phone,
        businessEmail: business?.email,
        cashierName: auth.currentUser?.fullName,
        businessLogoUrl: business?.logoUrl,
        subscriptionTier: business?.subscriptionTier,
        businessClass: business?.businessClass,
      );

      final filename = PdfInvoiceGenerator.getInvoiceFilename(invoiceNumber);
      if (kIsWeb) {
        web_download.downloadBytes(pdfBytes, filename, 'application/pdf');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice downloaded: $filename')),
        );
      } else {
        await _sharePdfOnMobile(pdfBytes, filename);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice generation failed: $e')),
      );
    }
  }

  Future<void> _sharePdfOnMobile(Uint8List pdfBytes, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Invoice PDF', subject: 'Invoice');
    } catch (e) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final file = File('${docsDir.path}/$filename');
        await file.writeAsBytes(pdfBytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice saved: ${file.path}')),
        );
      } catch (e2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving invoice PDF')),
        );
      }
    }
  }

  Future<void> _loadSalesHistory() async {
    if (_loadingHistory) return;

    setState(() => _loadingHistory = true);

    try {
      final retail = context.read<RetailProvider>();
      final history = await retail.getSalesHistory(
        limit: _historyLimit,
      );

      if (mounted) {
        setState(() {
          _salesHistory = history;
          _hasMoreHistory = history.length >= _historyLimit;
          _loadingHistory = false;
          print(
              '[SalesScreen] Loaded ${history.length} sales records (limit: $_historyLimit)');
        });
      }
    } catch (e) {
      print('[SalesScreen] Error loading sales history: $e');
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  Future<void> _promptNewCart(
      BuildContext context, RetailProvider retail) async {
    final controller = TextEditingController(
      text: 'Cart ${retail.cartSessions.length + 1}',
    );
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Open New Cart'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Cart label',
                hintText: 'Customer or table name',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Create'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await retail.createCartSession(label: controller.text.trim());
    if (!mounted) return;
    setState(() {
      _globalPricingMode = retail.activeCartPricingMode;
    });
  }

  Future<void> _promptRenameCart(
    BuildContext context,
    RetailProvider retail,
    CartSessionSummary session,
  ) async {
    final controller = TextEditingController(text: session.label);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Rename Cart'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Cart label',
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
        ) ??
        false;
    if (!confirmed) return;
    retail.renameCart(session.id, controller.text);
  }

  void _toggleGlobalPricingMode(RetailProvider retail) {
    final newMode =
        _globalPricingMode == 'retail' ? 'wholesale' : 'retail';
    setState(() {
      _globalPricingMode = newMode;
    });

    retail.setActiveCartPricingMode(
      newMode,
      applyToExistingItems: true,
    );

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Switched to ${_globalPricingMode == 'wholesale' ? 'Wholesale' : 'Retail'} pricing'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildCartSessionStrip(BuildContext context, RetailProvider retail) {
    final sessions = retail.cartSessions;
    if (sessions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Theme.of(context).cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Open Carts',
                style:
                    AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _promptNewCart(context, retail),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('New Cart'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sessions.map((session) {
                final chip = InputChip(
                  selected: session.isActive,
                  label: Text('${session.label} (${session.itemCount})'),
                  avatar: Icon(
                    session.isActive
                        ? Icons.shopping_bag
                        : Icons.shopping_bag_outlined,
                    size: 18,
                  ),
                  onPressed: () {
                    retail.switchCart(session.id);
                    if (!mounted) return;
                    setState(() {
                      _globalPricingMode = retail.activeCartPricingMode;
                    });
                  },
                  onDeleted: sessions.length > 1
                      ? () {
                          retail.closeCart(session.id);
                          if (!mounted) return;
                          setState(() {
                            _globalPricingMode =
                                retail.activeCartPricingMode;
                          });
                        }
                      : null,
                  deleteIcon: const Icon(Icons.close, size: 18),
                );

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onLongPress: () =>
                        _promptRenameCart(context, retail, session),
                    child: chip,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle a scanned barcode (either from camera or handheld keyboard scanner)
  Future<void> _handleScannedBarcode(String barcode,
      {String source = 'camera'}) async {
    final b = barcode.trim();
    if (b.isEmpty) return;

    final retail = context.read<RetailProvider>();
    final bs = BarcodeService();

    // Optional: validate barcode format
    final isValid = await bs.validateBarcode(b);
    if (!isValid) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid barcode: $b'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Attempt to find product by barcode with exact and fuzzy matching
    Product? product;
    Product? fuzzyMatch; // Fallback for close matches
    double bestFuzzyScore = 0.0;

    for (final p in retail.products) {
      if ((p.barcode ?? '').trim().isNotEmpty) {
        // Try exact match first
        if (SearchUtils.matchesBarcode(p.barcode, b)) {
          // Prefer exact numeric match
          if (SearchUtils.extractNumeric(p.barcode!) ==
              SearchUtils.extractNumeric(b)) {
            product = p;
            break; // Exact match found, use it
          }
          // Track fuzzy matches
          final score =
              SearchUtils.areBarcodesSimilar(p.barcode!, b, threshold: 2)
                  ? 0.9
                  : 0.7;
          if (score > bestFuzzyScore) {
            bestFuzzyScore = score;
            fuzzyMatch = p;
          }
        }
      }
    }

    // If no exact match, try fuzzy match
    if (product == null && fuzzyMatch != null && bestFuzzyScore >= 0.7) {
      product = fuzzyMatch;
    }

    if (product != null) {
      retail.addToCart(product.id, pricingMode: _globalPricingMode);

      // Log analytics
      final analyticsService = AnalyticsService();
      try {
        await analyticsService.logEvent('barcode_scanned', {
          'barcode': b,
          'productId': product.id,
          'productName': product.name,
          'business_type': 'retail',
          'source': source,
          'matchType': product.barcode?.trim() == b ? 'exact' : 'fuzzy',
        });
      } catch (_) {}

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${product.name} to cart'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product found for barcode: $b'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final retail = context.watch<RetailProvider>();
    if (_globalPricingMode != retail.activeCartPricingMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latestMode = context.read<RetailProvider>().activeCartPricingMode;
        if (_globalPricingMode != latestMode) {
          setState(() {
            _globalPricingMode = latestMode;
          });
        }
      });
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh products',
            onPressed: () async {
              try {
                final business =
                    Provider.of<BusinessProvider>(context, listen: false)
                        .currentBusiness;
                if (business != null) {
                  await retail.loadProducts(
                    storeId: widget.enableStoreSwitcher &&
                            _selectedStoreFilterId != _allStoresValue
                        ? _selectedStoreFilterId
                        : null,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Products refreshed'),
                      duration: Duration(seconds: 1),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error refreshing products: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () async {
              final barcodeService = BarcodeService();
              try {
                final barcode = await barcodeService.scanBarcode(context);
                if (barcode != null && barcode.isNotEmpty) {
                  await _handleScannedBarcode(barcode, source: 'camera');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Scan error: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          ),
          // Toggle handheld scanner mode (keyboard-wedge style)
          IconButton(
            icon: Icon(_handheldMode ? Icons.keyboard : Icons.keyboard_hide),
            tooltip: 'Toggle handheld scanner mode',
            onPressed: () {
              setState(() {
                _handheldMode = !_handheldMode;
              });
              if (_handheldMode) {
                Future.delayed(const Duration(milliseconds: 200), () {
                  _handheldFocusNode.requestFocus();
                });
              }
            },
          ),
          Builder(builder: (context) {
            final business =
                Provider.of<BusinessProvider>(context, listen: false)
                    .currentBusiness;
            if (business != null && business.businessType == 'restaurant') {
              return IconButton(
                icon: const Icon(Icons.menu_book),
                tooltip: 'Open Menu',
                onPressed: () =>
                    Navigator.pushNamed(context, Routes.restaurantMenu),
              );
            }
            return const SizedBox.shrink();
          }),
          // Global pricing mode toggle
          Consumer<RetailProvider>(
            builder: (context, retail, _) => IconButton(
              icon: Icon(
                _globalPricingMode == 'wholesale' 
                  ? Icons.business_center 
                  : Icons.shopping_cart,
                color: _globalPricingMode == 'wholesale' 
                  ? Colors.orange 
                  : null,
              ),
              tooltip: 'Toggle ${_globalPricingMode == 'retail' ? 'Wholesale' : 'Retail'} Mode',
              onPressed: () => _toggleGlobalPricingMode(retail),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const SalesHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.people_rounded),
            tooltip: 'Customer Tracking',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CustomerTrackingScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const AppHeader(showBusinessSwitcher: false),
          _buildCartSessionStrip(context, retail),
          if (widget.enableStoreSwitcher)
            _buildStoreSwitcher(retail),
          // Handheld scanner input (keyboard wedge)
          if (_handheldMode)
            Container(
              color: theme.cardColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _handheldController,
                      focusNode: _handheldFocusNode,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Scan barcode with handheld scanner...',
                      ),
                      onSubmitted: (value) async {
                        if (value.trim().isEmpty) return;
                        await _handleScannedBarcode(value.trim(),
                            source: 'handheld');
                        _handheldController.clear();
                        // keep focus for next scan
                        Future.delayed(const Duration(milliseconds: 50),
                            () => _handheldFocusNode.requestFocus());
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _handheldMode = false),
                  ),
                ],
              ),
            ),
          // Search Bar
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: TextField(
              controller: _mainSearchController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withOpacity(0.7)),
                prefixIcon: Icon(Icons.search,
                    color: Theme.of(context).colorScheme.onPrimary),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProductViewSwitcher(
                      isGridView: _isGridView,
                      onToggle: () =>
                          setState(() => _isGridView = !_isGridView),
                    ),
                    IconButton(
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      onPressed: () async {
                        final res =
                            await showModalBottomSheet<Map<String, dynamic>>(
                          context: context,
                          isScrollControlled: true,
                          builder: (ctx) {
                            var tempInStock = _filterInStockOnly;
                            var tempSort = _productSort;
                            return StatefulBuilder(builder: (c, s) {
                              return Padding(
                                padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(c).viewInsets.bottom),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Filter products',
                                          style: AppTextStyles.heading5),
                                      const SizedBox(height: 12),
                                      SwitchListTile(
                                        title: const Text('In stock only'),
                                        value: tempInStock,
                                        onChanged: (v) =>
                                            s(() => tempInStock = v),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text('Sort by',
                                          style: AppTextStyles.body2),
                                      RadioListTile<String>(
                                        title: const Text('None'),
                                        value: 'none',
                                        groupValue: tempSort,
                                        onChanged: (v) =>
                                            s(() => tempSort = v ?? 'none'),
                                      ),
                                      RadioListTile<String>(
                                        title:
                                            const Text('Price - Low to High'),
                                        value: 'priceAsc',
                                        groupValue: tempSort,
                                        onChanged: (v) =>
                                            s(() => tempSort = v ?? 'priceAsc'),
                                      ),
                                      RadioListTile<String>(
                                        title:
                                            const Text('Price - High to Low'),
                                        value: 'priceDesc',
                                        groupValue: tempSort,
                                        onChanged: (v) => s(
                                            () => tempSort = v ?? 'priceDesc'),
                                      ),
                                      RadioListTile<String>(
                                        title: const Text('Name (A - Z)'),
                                        value: 'name',
                                        groupValue: tempSort,
                                        onChanged: (v) =>
                                            s(() => tempSort = v ?? 'name'),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.of(c).pop(),
                                              child: const Text('Cancel')),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.of(c).pop({
                                                'inStock': tempInStock,
                                                'sort': tempSort
                                              });
                                            },
                                            child: const Text('Apply'),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            });
                          },
                        );

                        if (res != null) {
                          setState(() {
                            _filterInStockOnly =
                                res['inStock'] as bool? ?? false;
                            _productSort = res['sort'] as String? ?? 'none';
                          });
                        }
                      },
                    ),
                  ],
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.onPrimary.withOpacity(0.12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // Category Tabs
          Container(
            color: Theme.of(context).cardColor,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle:
                  AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Products'),
                Tab(text: 'Cart'),
                Tab(text: 'History'),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Products Tab
                _ProductsGrid(
                    searchQuery: _mainSearchController.text,
                    inStockOnly: _filterInStockOnly,
                    sortBy: _productSort,
                    isGridView: _isGridView,
                    onAddToCart: (product) => retail.addToCart(
                          product.id,
                          pricingMode: _globalPricingMode,
                        ),
                    globalPricingMode: _globalPricingMode),

                // Cart Tab
                _buildCartTab(retail),

                // History Tab
                _buildHistoryTab(),
              ],
            ),
          ),

          // Cart Preview (shown on Products tab)
          if (_tabController.index == 0 && retail.cartCount > 0)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Cart Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${retail.activeCartLabel} • ${retail.cartCount} items',
                            style: AppTextStyles.body2Secondary,
                          ),
                          Text(
                            formatCurrency(retail.cartTotal),
                            style: AppTextStyles.price,
                          ),
                        ],
                      ),
                    ),
                    // View Cart Button
                    Expanded(
                      child: CustomButton(
                        text: 'View Cart',
                        onPressed: () => _showCheckout(context, retail),
                        icon: Icons.shopping_cart_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoreSwitcher(RetailProvider retail) {
    final theme = Theme.of(context);
    final stores = retail.stores;

    if (stores.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedValue = stores.any((store) => store.id == _selectedStoreFilterId)
            ? _selectedStoreFilterId
            : _allStoresValue;

    return Container(
      width: double.infinity,
      color: theme.cardColor,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Icon(
            Icons.storefront_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Text(
            'Store',
            style: AppTextStyles.subtitle1,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedValue,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: _allStoresValue,
                  child: Text('All Stores'),
                ),
                ...stores.map(
                  (store) => DropdownMenuItem<String>(
                    value: store.id,
                    child: Text(store.name),
                  ),
                ),
              ],
              onChanged: (value) async {
                if (value == null || value == _selectedStoreFilterId) return;
                setState(() => _selectedStoreFilterId = value);
                await retail.loadProducts(
                  storeId: value == _allStoresValue ? null : value,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartTab(RetailProvider retail) {
    if (retail.cartCount == 0) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 80, color: AppColors.textTertiary),
            SizedBox(height: 16),
            Text('Your cart is empty', style: AppTextStyles.heading3),
            SizedBox(height: 8),
            Text('Add items from the Products tab', style: AppTextStyles.body1),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cart Items • ${retail.activeCartLabel}',
            style: AppTextStyles.heading3,
          ),
          const SizedBox(height: 16),
          ...retail.cartItems.entries.map((e) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key.name,
                                style: AppTextStyles.body1
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              formatCurrency(
                                  retail.getEffectivePriceForCartItem(
                                      e.key.id)),
                              style: AppTextStyles.body2,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              if (e.value > 1) {
                                retail.updateQty(e.key.id, e.value - 1);
                              } else {
                                retail.removeFromCart(e.key.id);
                              }
                            },
                          ),
                          Text(e.value.toString()),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () =>
                                retail.updateQty(e.key.id, e.value + 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => retail.removeFromCart(e.key.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:'),
                    Text(formatCurrency(retail.cartTotal)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:', style: AppTextStyles.heading4),
                    Text(formatCurrency(retail.cartTotal),
                        style: AppTextStyles.heading4
                            .copyWith(color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async => await _generateInvoice(retail),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Generate Invoice'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Proceed to Checkout',
              onPressed: () => _showCheckout(context, retail),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    // Apply local search filtering to sales history
    final filtered = _historyQuery.trim().isEmpty
        ? _salesHistory
        : _salesHistory.where((sale) {
            final q = _historyQuery.toLowerCase();
            final id = (sale['id'] ?? '').toString().toLowerCase();
            final ref = (sale['referenceId'] ?? '').toString().toLowerCase();
            final customer = (sale['customerName'] ?? sale['customer'] ?? '')
                .toString()
                .toLowerCase();
            final worker = (sale['workerName'] ?? '').toString().toLowerCase();
            final payment =
                (sale['paymentMethod'] ?? '').toString().toLowerCase();
            return id.contains(q) ||
                ref.contains(q) ||
                customer.contains(q) ||
                worker.contains(q) ||
                payment.contains(q);
          }).toList();

    return Column(
      children: [
        // History search input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _historySearchController,
            decoration: InputDecoration(
              hintText:
                  'Search history by order ID, customer, worker or payment...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _historyQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _historySearchController.clear();
                          _historyQuery = '';
                        });
                      },
                      child: const Icon(Icons.close),
                    )
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (v) => setState(() => _historyQuery = v.trim()),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _loadSalesHistory(),
            child: filtered.isEmpty
                ? (_loadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history,
                                size: 80, color: AppColors.textTertiary),
                            const SizedBox(height: 16),
                            const Text('No sales found',
                                style: AppTextStyles.heading3),
                            const SizedBox(height: 8),
                            const Text(
                                'Try a different query or pull to refresh',
                                style: AppTextStyles.body1),
                            const SizedBox(height: 24),
                            CustomButton(
                                text: 'Load History',
                                onPressed: _loadSalesHistory),
                          ],
                        ),
                      ))
                : ListView.builder(
                    itemCount: filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        return _loadingHistory
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              )
                            : _hasMoreHistory
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: CustomButton(
                                        text: 'Load More',
                                        onPressed: () {
                                          setState(() {
                                            _historyLimit += _historyPageSize;
                                          });
                                          _loadSalesHistory();
                                          // refresh realtime subscription with new limit
                                          context
                                              .read<RetailProvider>()
                                              .subscribeToSalesHistory((sales) {
                                            if (!mounted) return;
                                            setState(() {
                                              _salesHistory = sales;
                                              _hasMoreHistory =
                                                  sales.length >= _historyLimit;
                                            });
                                          }, limit: _historyLimit);
                                        },
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                      }

                      final sale = filtered[index];
                      final createdAt = sale['createdAt'] as Timestamp?;
                      final formattedTime = createdAt != null
                          ? DateFormat('dd/MM/yyyy HH:mm')
                              .format(createdAt.toDate())
                          : 'Unknown time';
                      final amount = sale['totalAmount'] as num? ?? 0;
                      final worker = sale['workerName'] ?? 'Unknown';
                      final itemCount = (sale['items'] as List?)?.length ?? 0;

                      return InkWell(
                        onTap: () => _showSaleDetails(context, sale),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        'Sale #${sale['referenceId'] ?? sale['id']}',
                                        style: AppTextStyles.body1.copyWith(
                                            fontWeight: FontWeight.w600)),
                                    Text('\u20a6${amount.toStringAsFixed(2)}',
                                        style: AppTextStyles.heading4.copyWith(
                                            color: AppColors.primary)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(worker,
                                        style: AppTextStyles.body2.copyWith(
                                            fontWeight: FontWeight.w500)),
                                    Text(formattedTime,
                                        style: AppTextStyles.body2.copyWith(
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('$itemCount item(s)',
                                    style: AppTextStyles.body2),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      ReceiptDetailScreen(
                                                          saleData: sale)));
                                        },
                                        icon: const Icon(Icons.receipt_long),
                                        label: const Text('View Receipt'),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () =>
                                            _showSaleDetails(context, sale),
                                        child: const Text('Details'),
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
                  ),
          ),
        ),
      ],
    );
  }

  void _showSaleDetails(BuildContext context, Map<String, dynamic> sale) {
    final items = (sale['items'] as List<dynamic>?) ?? [];
    final retail = context.read<RetailProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (c) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sale #${sale['referenceId'] ?? sale['id']}',
                  style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              ...items.map((i) {
                final item = i as Map<String, dynamic>;
                final productId = item['productId'] as String?;
                final productName = (item['productName'] as String?) ??
                    (item['name'] as String?) ??
                    (productId != null
                        ? retail.products
                            .firstWhere(
                              (p) => p.id == productId,
                              orElse: () => Product(
                                  id: productId,
                                  name: 'Unknown',
                                  price: 0,
                                  stock: 0,
                                  category: 'Unknown'),
                            )
                            .name
                        : 'Unknown');
                final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                final unitPrice = (item['unitPrice'] as num?)?.toDouble() ??
                    (item['price'] as num?)?.toDouble() ??
                    0.0;
                final total =
                    (item['total'] as num?)?.toDouble() ?? unitPrice * qty;

                return ListTile(
                  title: Text(productName, style: AppTextStyles.body1),
                  subtitle: Text('$qty x ₦${unitPrice.toStringAsFixed(2)}'),
                  trailing: Text('₦${total.toStringAsFixed(2)}',
                      style: AppTextStyles.body2),
                );
              }),
              const SizedBox(height: 12),
              Text(
                  'Total: ₦${(sale['totalAmount'] as num? ?? 0).toStringAsFixed(2)}',
                  style: AppTextStyles.heading4),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        // Close sheet then navigate to receipt screen
                        Navigator.pop(c);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ReceiptDetailScreen(saleData: sale),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('View Receipt'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductsGrid extends StatelessWidget {
  final String searchQuery;
  final bool inStockOnly;
  final String sortBy;
  final bool isGridView;
  final Function(Product) onAddToCart;
  final String globalPricingMode;

  const _ProductsGrid(
      {required this.searchQuery,
      this.inStockOnly = false,
      this.sortBy = 'none',
      this.isGridView = true,
      required this.onAddToCart,
      required this.globalPricingMode});

  @override
  Widget build(BuildContext context) {
    final allProducts = context.watch<RetailProvider>().products;
    final pharmacyProvider = context.watch<PharmacyProvider>();

    // Convert pharmacy drugs to Product-like model and merge
    final pharmacyProducts = pharmacyProvider.drugs.map((d) => Product(
          id: 'pharmacy:${d.id}',
          name: d.name,
          price: d.price,
          cost: 0.0,
          stock: d.stock.toDouble(),
          category: 'Pharmacy',
          imageUrl: null,
          barcode: null,
          emoji: '💊',
        ));

    // Merge by name (case-insensitive), prefer inventory (allProducts)
    final merged = <String, Product>{};
    for (final p in pharmacyProducts) {
      merged['name:${p.name.toLowerCase()}'] = p;
    }
    for (final p in allProducts) {
      merged['name:${p.name.toLowerCase()}'] = p; // override if exists
    }

    final combined = merged.values.toList();

    // Filter products based on search query using enhanced search
    var products = searchQuery.isEmpty
        ? combined
        : combined
            .where((p) =>
                SearchUtils.matchesSearchQuery(p.name, p.barcode, searchQuery))
            .toList();

    // Sort by relevance if there's a search query
    if (searchQuery.isNotEmpty) {
      products.sort((a, b) {
        final scoreA =
            SearchUtils.calculateRelevanceScore(a.name, a.barcode, searchQuery);
        final scoreB =
            SearchUtils.calculateRelevanceScore(b.name, b.barcode, searchQuery);
        return scoreB.compareTo(scoreA); // Higher score first
      });
    }

    // Apply in-stock filter
    if (inStockOnly) {
      products = products.where((p) => p.stock > 0).toList();
    }

    // Apply sorting
    if (sortBy == 'priceAsc') {
      products.sort((a, b) => a.price.compareTo(b.price));
    } else if (sortBy == 'priceDesc') {
      products.sort((a, b) => b.price.compareTo(a.price));
    } else if (sortBy == 'name') {
      products
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off,
                size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text('No products found', style: AppTextStyles.heading3),
            if (searchQuery.isNotEmpty)
              const Text('Try searching for something else',
                  style: AppTextStyles.body1),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Grid view configuration
        int crossAxisCount = 2;
        if (width >= 1200) {
          crossAxisCount = 6;
        } else if (width >= 800) {
          crossAxisCount = 4;
        }

        if (isGridView) {
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _ProductCard(
                product: product,
                onAdd: () => onAddToCart(product),
                globalPricingMode: globalPricingMode,
              );
            },
          );
        } else {
          // List view
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProductListTile(
                  product: product,
                  onAdd: () => onAddToCart(product),
                  globalPricingMode: globalPricingMode,
                ),
              );
            },
          );
        }
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;
  final String globalPricingMode;

  const _ProductCard({required this.product, required this.onAdd, required this.globalPricingMode});

  double getEffectivePrice() {
    if (globalPricingMode == 'wholesale' && product.hasWholesalePricing && product.wholesalePrice != null) {
      return product.wholesalePrice!;
    }
    return product.price;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: product.imageUrl != null
                  ? ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Center(
                            child: Text(product.emoji,
                                style: const TextStyle(fontSize: 48))),
                        errorWidget: (c, u, e) => Center(
                            child: Text(product.emoji,
                                style: const TextStyle(fontSize: 48))),
                      ),
                    )
                  : Center(
                      child: Text(
                        product.emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTextStyles.subtitle1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (product.category.toLowerCase() == 'pharmacy' ||
                    product.id.startsWith('pharmacy:'))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.pharmacy.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💊', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text('Pharmacy',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.pharmacy)),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '₦${globalPricingMode == 'wholesale' && product.hasWholesalePricing && product.wholesalePrice != null ? product.wholesalePrice!.toStringAsFixed(2) : product.price.toStringAsFixed(2)}',
                  style: AppTextStyles.heading5.copyWith(
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stock: ${product.stock}',
                  style: AppTextStyles.body2Secondary,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;
  final String globalPricingMode;

  const _ProductListTile({
    required this.product,
    required this.onAdd,
    required this.globalPricingMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadow,
      ),
      child: ListTile(
        leading: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: product.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Center(
                      child: Text(product.emoji,
                          style: const TextStyle(fontSize: 32)),
                    ),
                    errorWidget: (c, u, e) => Center(
                      child: Text(product.emoji,
                          style: const TextStyle(fontSize: 32)),
                    ),
                  ),
                )
              : Center(
                  child:
                      Text(product.emoji, style: const TextStyle(fontSize: 32)),
                ),
        ),
        title: Text(
          product.name,
          style: AppTextStyles.subtitle1,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (product.category.toLowerCase() == 'pharmacy' ||
                product.id.startsWith('pharmacy:'))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.pharmacy.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Pharmacy',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.pharmacy, fontSize: 11)),
                ),
              ),
            Text(
              '₦${(globalPricingMode == 'wholesale' && product.hasWholesalePricing && product.wholesalePrice != null ? product.wholesalePrice! : product.price).toStringAsFixed(2)} • Stock: ${product.stock.toInt()}',
              style: AppTextStyles.body2Secondary,
            ),
          ],
        ),
        trailing: SizedBox(
          width: 100,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_shopping_cart, size: 16),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  final Map<Product, int> items;
  final double total;
  final ScrollController? scrollController;
  final String? initialStoreId;
  final Function(
      String? customerId,
      String? customerEmail,
      String? customerName,
      String? customerPhone,
      String paymentMethod,
      String? storeId,
      double taxRate,
      double discount,
      Map<String, double> priceOverrides) onComplete;

  const _CheckoutSheet({
    required this.items,
    required this.total,
    required this.onComplete,
    this.scrollController,
    this.initialStoreId,
  });

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  String _paymentMethod = 'cash';
  String? _selectedStoreId;
  CustomerModel? _selectedCustomer;
  ScrollController? _internalScrollController;
  late TextEditingController _customerEmailController;
  late TextEditingController _customerNameController;
  late TextEditingController _taxRateController;
  late TextEditingController _discountController;

  // Per-item price overrides (keyed by product id)
  final Map<String, double> _priceOverrides = {};

  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _internalScrollController!;

  String _resolveBusinessId() {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id ??
        context.read<AuthProvider>().currentUser?.primaryBusinessId ??
        context.read<AuthProvider>().currentUser?.businessId ??
        '';
    return businessId.trim();
  }

  void _applySelectedCustomer(
    CustomerModel? customer, {
    bool syncProvider = true,
  }) {
    if (syncProvider) {
      final customerProvider = context.read<CustomerProvider>();
      if (customer == null) {
        customerProvider.clearSelectedCustomer();
      } else {
        customerProvider.selectCustomer(customer);
      }
    }

    setState(() {
      _selectedCustomer = customer;
      _customerNameController.text = customer?.name ?? '';
      _customerEmailController.text = customer?.email ?? '';
    });
  }

  Future<void> _loadCustomers() async {
    try {
      final businessId = _resolveBusinessId();
      if (businessId.isEmpty) return;

      final customerProvider = context.read<CustomerProvider>();
      customerProvider.setBusinessId(businessId);
      if (customerProvider.customers.isEmpty && !customerProvider.isLoading) {
        await customerProvider.loadCustomers();
      }

      if (!mounted) return;
      _applySelectedCustomer(
        customerProvider.selectedCustomer,
        syncProvider: false,
      );
    } catch (e) {
      debugPrint('[SalesCheckoutSheet] Failed to load customers: $e');
    }
  }

  Future<CustomerModel?> _showCreateCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    bool isSaving = false;

    return showDialog<CustomerModel?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add customer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSaving ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Customer name is required'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      final customerProvider = context.read<CustomerProvider>();
                      final created = await customerProvider.createCustomer(
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop(created);
                    },
              child: isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomerSelectionSheet() async {
    final customerProvider = context.read<CustomerProvider>();
    final businessId = _resolveBusinessId();
    if (businessId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load customers. Please select a business.'),
        ),
      );
      return;
    }

    customerProvider.setBusinessId(businessId);
    if (customerProvider.customers.isEmpty && !customerProvider.isLoading) {
      await customerProvider.loadCustomers();
    }

    if (!mounted) return;

    final selected = await showModalBottomSheet<CustomerModel?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String query = '';
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.42,
            maxChildSize: 0.92,
            builder: (sheetContext, scrollController) {
              final customers = customerProvider.customers.where((customer) {
                final q = query.trim().toLowerCase();
                if (q.isEmpty) return true;
                return customer.name.toLowerCase().contains(q) ||
                    (customer.phone?.toLowerCase().contains(q) ?? false) ||
                    (customer.email?.toLowerCase().contains(q) ?? false);
              }).toList();

              return SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(sheetContext)
                              .dividerColor
                              .withOpacity(0.9),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Select customer',
                                style: AppTextStyles.heading5,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search by name, phone, or email',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) =>
                              setSheetState(() => query = value),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.person_outline),
                              label: const Text('Walk-in customer'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: customerProvider.isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : customers.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('No customers found'),
                                    ),
                                  )
                                : ListView.separated(
                                    controller: scrollController,
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      16 +
                                          MediaQuery.of(sheetContext)
                                              .viewInsets
                                              .bottom,
                                    ),
                                    itemCount: customers.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final customer = customers[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          child: Text(
                                            customer.name.isNotEmpty
                                                ? customer.name[0].toUpperCase()
                                                : '?',
                                          ),
                                        ),
                                        title: Text(customer.name),
                                        subtitle: Text(
                                          customer.phone?.isNotEmpty == true
                                              ? customer.phone!
                                              : (customer.email?.isNotEmpty ==
                                                      true
                                                  ? customer.email!
                                                  : 'No contact details'),
                                        ),
                                        onTap: () => Navigator.of(sheetContext)
                                            .pop(customer),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (!mounted) return;
    _applySelectedCustomer(selected);
  }

  @override
  void initState() {
    super.initState();
    if (widget.scrollController == null) {
      _internalScrollController = ScrollController();
    }
    _customerEmailController = TextEditingController();
    _customerNameController = TextEditingController();
    _taxRateController = TextEditingController(text: '0'); // Default 0%
    _discountController = TextEditingController(text: '0'); // Default 0

    // Initialize price overrides with current product prices
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final retail = Provider.of<RetailProvider>(context, listen: false);
        final auth = Provider.of<AuthProvider>(context, listen: false);
        for (final entry in retail.cartItems.entries) {
          _priceOverrides[entry.key.id] =
              retail.getEffectivePriceForCartItem(entry.key.id);
        }
        if (retail.stores.isEmpty) retail.loadStores();
        _selectedStoreId = widget.initialStoreId ?? auth.currentUser?.storeId;
        _loadCustomers();
      } catch (_) {}
    });
  }

  double _lineTotal(RetailProvider retail, Product product, int qty) {
    final unit = _priceOverrides[product.id] ??
        retail.getEffectivePriceForCartItem(product.id);
    return unit * qty;
  }

  double _computedSubtotal(
    RetailProvider retail,
    Iterable<MapEntry<Product, int>> entries,
  ) {
    return entries.fold(0.0, (s, e) => s + _lineTotal(retail, e.key, e.value));
  }

  String _pricingModeFor(Product product) {
    final currentPrice = _priceOverrides[product.id] ?? product.price;
    if (product.wholesalePrice != null &&
        (currentPrice - product.wholesalePrice!).abs() < 0.0001) {
      return 'wholesale';
    }
    return 'retail';
  }

  String _saleUnitSummary(Product product) {
    final retail = context.read<RetailProvider>();
    final saleUnit = retail.getEffectiveSaleUnitForCartItem(product.id);
    final multiplier =
        retail.getEffectiveSaleUnitMultiplierForCartItem(product.id);
    if (saleUnit == product.unit && multiplier == 1) {
      return 'Sold in ${inventoryUnitLabel(saleUnit)}';
    }
    final multiplierLabel = multiplier == multiplier.roundToDouble()
        ? multiplier.toInt().toString()
        : multiplier.toStringAsFixed(2);
    return 'Sold in ${inventoryUnitLabel(saleUnit)} • 1 ${saleUnit.isEmpty ? product.unit : saleUnit} = $multiplierLabel ${product.unit}';
  }

  @override
  void dispose() {
    _internalScrollController?.dispose();
    _customerEmailController.dispose();
    _customerNameController.dispose();
    _taxRateController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final retail = context.watch<RetailProvider>();
    final entries = retail.cartItems.entries.toList();
    final currentProductIds = entries.map((entry) => entry.key.id).toSet();
    _priceOverrides.removeWhere(
      (productId, _) => !currentProductIds.contains(productId),
    );
    for (final entry in entries) {
      _priceOverrides.putIfAbsent(
        entry.key.id,
        () => retail.getEffectivePriceForCartItem(entry.key.id),
      );
    }
    final customerProvider = context.watch<CustomerProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = scheme.surface;
    final mutedSurface =
        isDark ? scheme.surface.withOpacity(0.92) : AppColors.background;
    final borderColor = scheme.outline.withOpacity(isDark ? 0.45 : 0.18);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Scrollbar(
        controller: _effectiveScrollController,
        thumbVisibility: entries.length > 2,
        child: SingleChildScrollView(
          controller: _effectiveScrollController,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Text('Cart', style: AppTextStyles.heading3),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Cart Items (shrinkWrapped so the outer SingleChildScrollView handles scrolling)
                ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final item = entry.key;
                    final qty = entry.value;
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: AppTextStyles.subtitle1.copyWith(
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _saleUnitSummary(item),
                                style: AppTextStyles.caption.copyWith(
                                  color: scheme.onSurface.withOpacity(0.66),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: TextFormField(
                                      key: ValueKey(
                                        '${item.id}-${(_priceOverrides[item.id] ?? item.price).toStringAsFixed(2)}',
                                      ),
                                      initialValue: (_priceOverrides[item.id] ??
                                              item.price)
                                          .toStringAsFixed(2),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: InputDecoration(
                                        prefixText: '₦',
                                        isDense: true,
                                        filled: true,
                                        fillColor: theme.inputDecorationTheme
                                                .fillColor ??
                                            theme.cardColor,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 8),
                                      ),
                                      onChanged: (v) {
                                        final parsed = double.tryParse(
                                                v.replaceAll(',', '')) ??
                                            0.0;
                                        if (parsed < 0) {
                                          // Show error for negative prices
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Price cannot be negative'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                        if ((parsed - item.price).abs() <
                                            0.0001) {
                                          retail.setPricingModeForCartItem(
                                            item.id,
                                            'retail',
                                          );
                                        } else if (item.hasWholesalePricing &&
                                            item.wholesalePrice != null &&
                                            (parsed - item.wholesalePrice!)
                                                    .abs() <
                                                0.0001) {
                                          retail.setPricingModeForCartItem(
                                            item.id,
                                            'wholesale',
                                          );
                                        }
                                        setState(() {
                                          _priceOverrides[item.id] = parsed;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (item.hasWholesalePricing) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: Text(
                                          'Retail ₦${item.price.toStringAsFixed(2)}'),
                                      selected:
                                          _pricingModeFor(item) == 'retail',
                                      onSelected: (_) {
                                        retail.setPricingModeForCartItem(
                                          item.id,
                                          'retail',
                                        );
                                        setState(() {
                                          _priceOverrides[item.id] = item.price;
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: Text(
                                        'Wholesale ₦${item.wholesalePrice!.toStringAsFixed(2)}',
                                      ),
                                      selected:
                                          _pricingModeFor(item) == 'wholesale',
                                      onSelected: (_) {
                                        retail.setPricingModeForCartItem(
                                          item.id,
                                          'wholesale',
                                        );
                                        setState(() {
                                          _priceOverrides[item.id] =
                                              item.wholesalePrice!;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Quantity Adjustment Buttons
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: qty > 1
                                  ? () {
                                      final retail =
                                          context.read<RetailProvider>();
                                      retail.updateQty(item.id, qty - 1);
                                      setState(() {});
                                    }
                                  : null,
                              tooltip: 'Decrease quantity',
                            ),
                            SizedBox(
                              width: 40,
                              child: Center(
                                child: Text(
                                  qty.toString(),
                                  style: AppTextStyles.heading5,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                retail.addToCart(item.id);
                                setState(() {});
                              },
                              tooltip: 'Increase quantity',
                            ),
                          ],
                        ),

                        SizedBox(
                          width: 100,
                          child: Text(
                            '₦${(_lineTotal(retail, item, qty)).toStringAsFixed(2)}',
                            style: AppTextStyles.heading5.copyWith(
                              color: scheme.onSurface,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Payment Method & Store Selection
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: mutedSurface,
                    border: Border(
                      top: BorderSide(color: borderColor),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store Selector
                      Consumer<RetailProvider>(builder: (context, retail, _) {
                        final stores = retail.stores;
                        if (stores.isEmpty) return const SizedBox.shrink();
                        final auth =
                            Provider.of<AuthProvider>(context, listen: false);
                        final defaultId = _selectedStoreId ??
                            auth.currentUser?.storeId ??
                            stores.first.id;
                        _selectedStoreId ??= defaultId;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Select Store',
                                style: AppTextStyles.subtitle1),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedStoreId,
                                  isExpanded: true,
                                  items: stores
                                      .map((s) => DropdownMenuItem(
                                          value: s.id, child: Text(s.name)))
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedStoreId = val),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }),
                      Text(
                        'Customer Information',
                        style: AppTextStyles.subtitle1.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.primary
                                      .withOpacity(isDark ? 0.24 : 0.12),
                                  child: Icon(
                                    _selectedCustomer == null
                                        ? Icons.person_outline
                                        : Icons.person,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedCustomer?.name ??
                                            'Walk-in customer',
                                        style: AppTextStyles.subtitle1.copyWith(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedCustomer == null
                                            ? 'Select an existing customer or create a new one for this sale.'
                                            : (_selectedCustomer!
                                                        .phone?.isNotEmpty ==
                                                    true
                                                ? _selectedCustomer!.phone!
                                                : (_selectedCustomer!.email
                                                            ?.isNotEmpty ==
                                                        true
                                                    ? _selectedCustomer!.email!
                                                    : 'No saved contact details')),
                                        style: AppTextStyles.caption.copyWith(
                                          color:
                                              scheme.onSurface.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (customerProvider.isLoading) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(minHeight: 3),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: customerProvider.isLoading
                                      ? null
                                      : _showCustomerSelectionSheet,
                                  icon: const Icon(Icons.people_outline),
                                  label: Text(
                                    _selectedCustomer == null
                                        ? 'Select Customer'
                                        : 'Change Customer',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final created =
                                        await _showCreateCustomerDialog();
                                    if (!mounted || created == null) return;
                                    _applySelectedCustomer(created);
                                  },
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Add New'),
                                ),
                                if (_selectedCustomer != null)
                                  TextButton.icon(
                                    onPressed: () =>
                                        _applySelectedCustomer(null),
                                    icon: const Icon(Icons.clear),
                                    label: const Text('Clear'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customerNameController,
                        decoration: InputDecoration(
                          labelText: 'Customer name',
                          hintText: 'Optional display name on receipt',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customerEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Customer email',
                          hintText: 'Optional email for receipt delivery',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Payment Method',
                          style: AppTextStyles.subtitle1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _PaymentMethodButton(
                            label: 'Cash',
                            icon: Icons.payments_rounded,
                            isSelected: _paymentMethod == 'cash',
                            onTap: () =>
                                setState(() => _paymentMethod = 'cash'),
                          ),
                          const SizedBox(width: 12),
                          _PaymentMethodButton(
                            label: 'Card',
                            icon: Icons.credit_card_rounded,
                            isSelected: _paymentMethod == 'card',
                            onTap: () =>
                                setState(() => _paymentMethod = 'card'),
                          ),
                          const SizedBox(width: 12),
                          _PaymentMethodButton(
                            label: 'Transfer',
                            icon: Icons.account_balance_rounded,
                            isSelected: _paymentMethod == 'transfer',
                            onTap: () =>
                                setState(() => _paymentMethod = 'transfer'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('Tax & Discount',
                          style: AppTextStyles.subtitle1),
                      const SizedBox(height: 12),
                      // Tax Field
                      Row(
                        children: [
                          Expanded(
                            child: Text('Tax (%)', style: AppTextStyles.body2),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              controller: _taxRateController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                hintText: '0',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                              '₦${(_computedSubtotal(retail, entries) * ((double.tryParse(_taxRateController.text) ?? 0) / 100)).toStringAsFixed(2)}',
                              style: AppTextStyles.caption),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Discount Field
                      Row(
                        children: [
                          Expanded(
                            child: Text('Discount (₦)',
                                style: AppTextStyles.body2),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              controller: _discountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                hintText: '0',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                              '-₦${(double.tryParse(_discountController.text) ?? 0).toStringAsFixed(2)}',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.success)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Total & Checkout
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.24 : 0.10),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: AppTextStyles.heading4.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              '₦${(_computedSubtotal(retail, entries) + (_computedSubtotal(retail, entries) * ((double.tryParse(_taxRateController.text) ?? 0) / 100)) - (double.tryParse(_discountController.text) ?? 0)).toStringAsFixed(2)}',
                              style: AppTextStyles.price.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AsyncCustomButton(
                          text: 'Complete Sale',
                          onPressed: () async => await widget.onComplete(
                            _selectedCustomer?.id,
                            _customerEmailController.text.trim().isEmpty
                                ? null
                                : _customerEmailController.text.trim(),
                            _customerNameController.text.trim().isEmpty
                                ? null
                                : _customerNameController.text.trim(),
                            (_selectedCustomer?.phone ?? '').trim().isEmpty
                                ? null
                                : _selectedCustomer!.phone!.trim(),
                            _paymentMethod,
                            _selectedStoreId,
                            double.tryParse(_taxRateController.text) ?? 0.0,
                            double.tryParse(_discountController.text) ?? 0,
                            Map<String, double>.from(_priceOverrides),
                          ),
                          icon: Icons.check_circle_outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
