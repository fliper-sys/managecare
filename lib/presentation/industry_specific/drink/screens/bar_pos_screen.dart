import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';

import '../../../../providers/retail_provider.dart' show RetailProvider;
import '../../../../services/receipt_manager.dart';
import '../../../../services/notification_and_email_service.dart';
import '../../../../services/business_notification_manager.dart';
import '../../../../providers/drink_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/customer_provider.dart';
import '../../../../data/models/customer_model.dart';
import '../../../../core/constants/routes.dart';
import '../../../../widgets/custom_button.dart';

class BarPosScreenDrink extends StatefulWidget {
  const BarPosScreenDrink({super.key});

  @override
  State<BarPosScreenDrink> createState() => _BarPosScreenDrinkState();
}

class _BarPosScreenDrinkState extends State<BarPosScreenDrink> {
  final Map<String, int> _cart = {};
  String _search = '';
  bool _showCart = false;

  String? _selectedStoreId;
  CustomerModel? _selectedCustomer;
  final TextEditingController _tableLabelController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final retail = Provider.of<RetailProvider>(context, listen: false);
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final customers = Provider.of<CustomerProvider>(context, listen: false);
        if (retail.stores.isEmpty) retail.loadStores();
        if (customers.customers.isEmpty && !customers.isLoading) {
          customers.loadCustomers();
        }
        _selectedStoreId = auth.currentUser?.storeId;
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _tableLabelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addToCart(String drinkId, {int qty = 1}) {
    _cart.update(drinkId, (v) => v + qty, ifAbsent: () => qty);
    setState(() {});
  }

  void _removeFromCart(String drinkId) {
    _cart.remove(drinkId);
    setState(() {});
  }

  void _clearCart() {
    _cart.clear();
    setState(() {});
  }

  int get cartCount => _cart.values.fold(0, (a, b) => a + b);

  double cartTotal(DrinkProvider provider) {
    return _cart.entries.fold<double>(0.0, (sum, e) {
      final d = provider.getDrinkById(e.key);
      if (d == null) return sum;
      return sum + (d.pricePerBottle * e.value);
    });
  }

  List<OrderLine> _buildOrderLines(DrinkProvider provider) {
    return _cart.entries
        .map((entry) {
          final drink = provider.getDrinkById(entry.key);
          if (drink == null) return null;
          return OrderLine(
            drinkId: drink.id,
            quantityBottles: entry.value,
            unitPrice: drink.pricePerBottle,
          );
        })
        .whereType<OrderLine>()
        .toList();
  }

  String _resolvedCustomerName() =>
      _selectedCustomer?.name ?? 'Walk-in Customer';

  String _resolvedInvoiceType() {
    if (_tableLabelController.text.trim().isNotEmpty) return 'table';
    if (_selectedCustomer != null) return 'tab';
    return 'invoice';
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
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
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
                      final customerProvider =
                          Provider.of<CustomerProvider>(context, listen: false);
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
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveInvoice(DrinkProvider provider) async {
    if (_cart.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final businessId =
        Provider.of<BusinessProvider>(context, listen: false)
                .currentBusiness
                ?.id ??
            authProvider.currentUser?.businessId ??
            '';
    if (businessId.isNotEmpty) {
      provider.setBusinessId(businessId);
    }
    final lines = _buildOrderLines(provider);
    if (lines.isEmpty) return;

    try {
      final invoice = await provider.createInvoice(
        lines: lines,
        invoiceType: _resolvedInvoiceType(),
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name,
        customerPhone: _selectedCustomer?.phone,
        customerEmail: _selectedCustomer?.email,
        tableLabel: _tableLabelController.text.trim().isEmpty
            ? null
            : _tableLabelController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        workerId: authProvider.currentUser?.id,
        workerName: authProvider.currentUser?.fullName,
        storeId: _selectedStoreId ?? authProvider.currentUser?.storeId,
      );

      _clearCart();
      _tableLabelController.clear();
      _notesController.clear();

      if (!mounted) return;
      setState(() {
        _selectedCustomer = null;
        _showCart = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Invoice ${invoice.invoiceNumber} saved to Tabs & Invoices'),
          backgroundColor: Colors.brown.shade700,
        ),
      );
      Navigator.pushNamed(context, Routes.drinkTabs);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save invoice: $e')),
      );
    }
  }

  Future<void> _checkout(DrinkProvider provider) async {
    if (_cart.isEmpty) return;

    try {
      // Get business ID from BusinessProvider, fallback to auth
      final businessProvider =
          Provider.of<BusinessProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final businessId = businessProvider.currentBusiness?.id ??
          authProvider.currentUser?.businessId;

      if (businessId == null || businessId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business ID not found')),
        );
        return;
      }
      provider.setBusinessId(businessId);

      // Build order lines
      final lines = _buildOrderLines(provider);

      if (lines.isEmpty) return;

      // Create sale record in Firestore
      final itemsList = lines.map((line) {
        final drink = provider.getDrinkById(line.drinkId);
        return {
          'productId': line.drinkId,
          'productName': drink?.name ?? 'Unknown',
          'quantity': line.quantityBottles,
          'unitPrice': line.unitPrice,
          'total': line.lineTotal(),
        };
      }).toList();

      final totalAmount =
          lines.fold<double>(0.0, (sum, line) => sum + line.lineTotal());

      // Ask user for payment method
      final paymentMethod = await _selectPaymentMethod();
      if (paymentMethod == null) return;

      final order = Order(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        lines: lines,
      );

      // Deduct from provider inventory only after payment is confirmed
      provider.createOrder(order);

      final saleData = {
        'businessId': businessId,
        'items': itemsList,
        'subtotal': totalAmount,
        'total': totalAmount,
        'totalAmount': totalAmount,
        'finalAmount': totalAmount,
        'status': 'completed',
        'paymentMethod': paymentMethod,
        'category': 'Drinks/Bar',
        'createdAt': FieldValue.serverTimestamp(),
        'customerId': _selectedCustomer?.id,
        'customerName': _resolvedCustomerName(),
        'customerPhone': _selectedCustomer?.phone,
        'customerEmail': _selectedCustomer?.email,
        if (_tableLabelController.text.trim().isNotEmpty)
          'tableLabel': _tableLabelController.text.trim(),
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
        if (authProvider.currentUser?.id != null)
          'workerId': authProvider.currentUser!.id,
        if (authProvider.currentUser?.fullName != null)
          'workerName': authProvider.currentUser!.fullName,
        if ((_selectedStoreId ?? authProvider.currentUser?.storeId) != null)
          'storeId': (_selectedStoreId ?? authProvider.currentUser?.storeId),
      };

      // Save sale to Firestore and persist orderId
      final firestore = FirebaseFirestore.instance;
      final saleRef = await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .add(saleData);
      // Update the document with the generated orderId for easier tracking
      await saleRef.update({
        'orderId': saleRef.id,
        'totalAmount': totalAmount,
        'finalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        if ((_selectedStoreId ?? authProvider.currentUser?.storeId) != null) 'storeId': (_selectedStoreId ?? authProvider.currentUser?.storeId),
      });

      if (_selectedCustomer != null) {
        try {
          await Provider.of<CustomerProvider>(context, listen: false)
              .updateCustomerAfterPurchase(_selectedCustomer!.id, totalAmount);
        } catch (e) {
          debugPrint('[BarPOS] Failed to update customer stats: $e');
        }
      }

      // Update inventory in Firestore for each drink
      for (final line in lines) {
        final stock = provider.getStock(line.drinkId);
        if (stock != null) {
          final drink = provider.getDrinkById(line.drinkId);
          await firestore
              .collection('businesses')
              .doc(businessId)
              .collection('inventory')
              .doc(line.drinkId)
              .update({
            'quantity': stock.totalBottles(drink?.bottlesPerCarton ?? 1),
            'cartons': stock.cartons,
            'bottles': stock.bottles,
          });
        }
      }

      // Clear cart locally
      _clearCart();

      if (!mounted) return;

      // Build unified sale map using the saved saleRef id
      final saleMap = {
        'id': saleRef.id,
        'items': itemsList,
        'subtotal': totalAmount,
        'discount': 0.0,
        'total': totalAmount,
        'totalAmount': totalAmount,
        'finalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'timestamp': DateTime.now().toIso8601String(),
        'customerName': _resolvedCustomerName(),
        if (_tableLabelController.text.trim().isNotEmpty)
          'tableLabel': _tableLabelController.text.trim(),
        if (authProvider.currentUser?.id != null)
          'workerId': authProvider.currentUser!.id,
        if (authProvider.currentUser?.fullName != null)
          'workerName': authProvider.currentUser!.fullName,
      };

      // Send notification/email to owner if available (align with RetailProvider behavior)
      try {
        final business = Provider.of<BusinessProvider>(context, listen: false)
            .currentBusiness;
        final ownerEmail = business?.email ?? '';
        if (ownerEmail.isNotEmpty) {
          final notif = NotificationAndEmailService();
          final success = await notif.sendSalesNotification(
            ownerEmail: ownerEmail,
            businessName: business?.name ?? '',
            customerName: _resolvedCustomerName(),
            customerEmail: _selectedCustomer?.email ?? '',
            totalAmount: totalAmount,
            items: itemsList
                .map((it) => {
                      'name': it['productName'] ?? it['name'],
                      'quantity': it['quantity'],
                      'price': it['unitPrice'] ?? it['price']
                    })
                .toList(),
            paymentMethod: paymentMethod,
            receiptNumber: saleRef.id,
            businessId: business?.id,
          );

          // Log notification attempt
          try {
            await notif.logNotificationEvent(
              businessId: business?.id ?? businessId,
              type: 'sale',
              channel: 'email',
              recipient: ownerEmail,
              success: success,
              orderId: saleRef.id,
            );
          } catch (e) {
            debugPrint('[BarPOS] Notification log failed: $e');
          }
        }
      } catch (e) {
        debugPrint('[BarPOS] Owner email notify failed: $e');
      }

      // Send push notification to business owners
      try {
        await BusinessNotificationManager.instance.notifySaleCompleted(
          businessId: businessId,
          customerName: _resolvedCustomerName(),
          amount: totalAmount,
          paymentMethod: paymentMethod,
        );

        if (totalAmount > 100) {
          await BusinessNotificationManager.instance.notifyLargeSale(
            businessId: businessId,
            customerName: _resolvedCustomerName(),
            amount: totalAmount,
          );
        }
      } catch (e) {
        debugPrint('[BarPOS] Push notification failed: $e');
      }

      try {
        await ReceiptManager.handlePostSale(context, saleMap);
      } catch (e) {
        debugPrint('[BarPOS] Receipt error: $e');
      }

      setState(() {
        _selectedCustomer = null;
      });
      _tableLabelController.clear();
      _notesController.clear();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ Sale completed and inventory updated'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      debugPrint('[BarPOS] Checkout error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<String?> _selectPaymentMethod() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Cash'),
              onTap: () => Navigator.pop(ctx, 'Cash'),
            ),
            ListTile(
              title: const Text('Debit/Credit Card'),
              onTap: () => Navigator.pop(ctx, 'Debit/Credit Card'),
            ),
            ListTile(
              title: const Text('Digital Wallet'),
              onTap: () => Navigator.pop(ctx, 'Digital Wallet'),
            ),
            ListTile(
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
    return selection;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DrinkProvider>(context);
    final drinks = provider.drinks
        .where((d) => d.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bar POS System'),
        backgroundColor: Colors.brown.shade700,
        elevation: 2,
        actions: [
          IconButton(
            tooltip: 'Tabs & Invoices',
            onPressed: () => Navigator.pushNamed(context, Routes.drinkTabs),
            icon: const Icon(Icons.receipt_long),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'Items: $cartCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: !_showCart
          ? _buildMenuView(provider, drinks)
          : _buildCartView(provider),
      bottomNavigationBar: cartCount > 0
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  top: BorderSide(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Store selector
                  Consumer<RetailProvider>(builder: (context, retail, _) {
                    final stores = retail.stores;
                    if (stores.isEmpty) return const SizedBox.shrink();
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    _selectedStoreId ??= auth.currentUser?.storeId ?? stores.first.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Store', style: AppTextStyles.caption),
                          ),
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
                                  value: _selectedStoreId,
                                  isExpanded: true,
                                  items: stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                                  onChanged: (val) => setState(() => _selectedStoreId = val),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Amount',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '₦${cartTotal(provider).toStringAsFixed(2)}',
                              style: AppTextStyles.heading4.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.brown.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: _showCart ? 'Back to Menu' : 'Review Order',
                          onPressed: () => setState(() => _showCart = !_showCart),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildMenuView(DrinkProvider provider, List<dynamic> drinks) {
    return Column(
      children: [
        // Order Flow Progress Indicator
        _buildOrderFlowIndicator(),

        // Search Bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search drinks by name...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _search = ''),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),

        // Menu Grid
        Expanded(
          child: drinks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.local_bar_outlined,
                        size: 64,
                        color: AppColors.border,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _search.isEmpty
                            ? 'No drinks available'
                            : 'No results found',
                        style: AppTextStyles.body1.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
                  : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      int crossAxisCount = 2;
                      if (width >= 1200) {
                        crossAxisCount = 6;
                      } else if (width >= 800) {
                        crossAxisCount = 4;
                      }

                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: drinks.length,
                        itemBuilder: (context, index) {
                      final d = drinks[index];
                      final inStock = provider.getTotalBottles(d.id) > 0;
                      final cartQty = _cart[d.id] ?? 0;

                      return _DrinkCard(
                        drink: d,
                        inStock: inStock,
                        cartQuantity: cartQty,
                        onAdd: () => _addToCart(d.id),
                        onRemove: () {
                          if (cartQty > 0) {
                            if (cartQty <= 1) {
                              _removeFromCart(d.id);
                            } else {
                              _cart[d.id] = cartQty - 1;
                            }
                            setState(() {});
                          }
                        },
                      );
                    },
                  );},),
                ),
        ),
      ],
    );
  }

  Widget _buildCartView(DrinkProvider provider) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Review Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Review',
                  style: AppTextStyles.heading4.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text('$cartCount items'),
                  backgroundColor: Colors.brown.shade100,
                  labelStyle: AppTextStyles.caption.copyWith(
                    color: Colors.brown.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Order Items
            ..._cart.entries.map((e) {
              final d = provider.getDrinkById(e.key)!;
              final lineTotal = d.pricePerBottle * e.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Drink Image
                    if (d.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: d.imageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.border),
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.border),
                        ),
                      )
                    else
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child:
                            Text(d.emoji, style: const TextStyle(fontSize: 32)),
                      ),
                    const SizedBox(width: 12),

                    // Drink Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.name,
                            style: AppTextStyles.subtitle1.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₦${d.pricePerBottle.toStringAsFixed(2)}/bottle',
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Quantity Controls
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                if (e.value <= 1) {
                                  _removeFromCart(e.key);
                                } else {
                                  _cart[e.key] = e.value - 1;
                                }
                                setState(() {});
                              },
                              iconSize: 20,
                            ),
                            Container(
                              width: 32,
                              alignment: Alignment.center,
                              child: Text(
                                e.value.toString(),
                                style: AppTextStyles.subtitle2.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                _addToCart(e.key);
                              },
                              iconSize: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₦${lineTotal.toStringAsFixed(2)}',
                          style: AppTextStyles.subtitle2.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.brown.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),

            Consumer<CustomerProvider>(
              builder: (context, customerProvider, _) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assign Invoice',
                        style: AppTextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedCustomer?.id,
                        decoration: const InputDecoration(
                          labelText: 'Customer / Tab owner',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Walk-in customer'),
                          ),
                          ...customerProvider.customers.map(
                            (customer) => DropdownMenuItem<String>(
                              value: customer.id,
                              child: Text(customer.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            if (value == null || value.isEmpty) {
                              _selectedCustomer = null;
                            } else {
                              try {
                                _selectedCustomer =
                                    customerProvider.customers.firstWhere(
                                  (customer) => customer.id == value,
                                );
                              } catch (_) {
                                _selectedCustomer = null;
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: customerProvider.isLoading
                                ? null
                                : () => customerProvider.loadCustomers(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh customers'),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () async {
                              final created = await _showCreateCustomerDialog();
                              if (!mounted || created == null) return;
                              setState(() => _selectedCustomer = created);
                            },
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Add new'),
                          ),
                        ],
                      ),
                      if (_selectedCustomer != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _selectedCustomer!.phone?.isNotEmpty == true
                              ? _selectedCustomer!.phone!
                              : (_selectedCustomer!.email?.isNotEmpty == true
                                  ? _selectedCustomer!.email!
                                  : 'No saved contact info'),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _tableLabelController,
                        decoration: const InputDecoration(
                          labelText: 'Table number or tab label',
                          hintText: 'e.g. Table 4, Lounge Left',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Optional note for staff or invoice record',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Order Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.brown.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.brown.shade200),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Subtotal',
                    value: '₦${cartTotal(provider).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  const _SummaryRow(
                    label: 'Tax (0%)',
                    value: '₦0.00',
                  ),
                  const SizedBox(height: 8),
                  const _SummaryRow(
                    label: 'Discount',
                    value: '₦0.00',
                  ),
                  const Divider(height: 20),
                  _SummaryRow(
                    label: 'Total Amount',
                    value: '₦${cartTotal(provider).toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            CustomButton(
              text: 'Save Invoice / Open Tab',
              backgroundColor: Colors.brown.shade700,
              onPressed: () => _saveInvoice(
                Provider.of<DrinkProvider>(context, listen: false),
              ),
            ),
            const SizedBox(height: 8),
            CustomButton(
              text: 'Proceed to Payment',
              backgroundColor: Colors.green.shade600,
              onPressed: () async {
                await _checkout(
                    Provider.of<DrinkProvider>(context, listen: false));
                if (mounted) {
                  setState(() => _showCart = false);
                }
              },
            ),
            const SizedBox(height: 8),
            CustomButton(
              text: 'Clear Order',
              backgroundColor: Colors.red.shade400,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear Order?'),
                    content:
                        const Text('This will remove all items from the cart.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearCart();
                          _tableLabelController.clear();
                          _notesController.clear();
                          setState(() => _selectedCustomer = null);
                          Navigator.pop(context);
                          setState(() => _showCart = false);
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderFlowIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.brown.shade50,
      child: Row(
        children: [
          _StepIndicator(number: 1, label: 'Select', active: !_showCart),
          SizedBox(
            width: 40,
            child: Center(
              child: Container(
                height: 2,
                color: _showCart ? Colors.brown : AppColors.border,
              ),
            ),
          ),
          _StepIndicator(number: 2, label: 'Review', active: _showCart),
          SizedBox(
            width: 40,
            child: Center(
              child: Container(
                height: 2,
                color: AppColors.border,
              ),
            ),
          ),
          const _StepIndicator(number: 3, label: 'Pay', active: false),
        ],
      ),
    );
  }
}

class _DrinkCard extends StatelessWidget {
  final dynamic drink;
  final bool inStock;
  final int cartQuantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _DrinkCard({
    required this.drink,
    required this.inStock,
    required this.cartQuantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: inStock ? onAdd : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cartQuantity > 0 ? Colors.brown : AppColors.border,
            width: cartQuantity > 0 ? 2 : 1,
          ),
          boxShadow: cartQuantity > 0
              ? [
                  BoxShadow(
                    color: Colors.brown.withOpacity(0.2),
                    blurRadius: 8,
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drink Image
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: drink.imageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: drink.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.border,
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          drink.emoji,
                          style: const TextStyle(fontSize: 48),
                        ),
                      ),
              ),
            ),

            // Drink Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drink.name,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₦${drink.pricePerBottle.toStringAsFixed(2)}',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              inStock ? 'Available' : 'Out',
                              style: AppTextStyles.caption.copyWith(
                                color: inStock ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (cartQuantity > 0)
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.brown,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              cartQuantity.toString(),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Quick Action Buttons
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: inStock ? onRemove : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Icon(
                          Icons.remove,
                          size: 18,
                          color: inStock ? Colors.red : AppColors.border,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: inStock ? onAdd : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Icon(
                          Icons.add,
                          size: 18,
                          color: inStock ? Colors.green : AppColors.border,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int number;
  final String label;
  final bool active;

  const _StepIndicator({
    required this.number,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.brown : AppColors.border,
          ),
          alignment: Alignment.center,
          child: Text(
            number.toString(),
            style: AppTextStyles.caption.copyWith(
              color: active ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: active ? Colors.brown : AppColors.textSecondary,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold)
              : AppTextStyles.body2,
        ),
        Text(
          value,
          style: isTotal
              ? AppTextStyles.heading5.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.brown.shade700,
                )
              : AppTextStyles.body2,
        ),
      ],
    );
  }
}

