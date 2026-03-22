import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../../../widgets/custom_button.dart';
import '../../../../widgets/async_button.dart';
import '../providers/wholesale_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/business_notification_manager.dart';

class WarehousePosScreen extends StatefulWidget {
  const WarehousePosScreen({super.key});

  @override
  State<WarehousePosScreen> createState() => _WarehousePosScreenState();
}

class _WarehousePosScreenState extends State<WarehousePosScreen> {
  final List<CartItem> _cart = [];
  late TextEditingController _searchCtrl;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<WholesaleProvider>();
      provider.loadProducts();
      provider.loadWarehouses();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Warehouse POS'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          // Cart button on small screens
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Stack(
              children: [
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_cart),
                    label: Text('${_cart.length}'),
                    onPressed: _cart.isEmpty ? null : () => _showCartModal(context),
                  ),
                ),
                if (_cart.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_cart.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Consumer<WholesaleProvider>(
        builder: (context, provider, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 900;
              var products = provider.products;

              // Filter by search
              if (_searchCtrl.text.isNotEmpty) {
                products = products
                    .where((p) => p.name
                        .toLowerCase()
                        .contains(_searchCtrl.text.toLowerCase()))
                    .toList();
              }

              // Filter by category
              if (_selectedCategory != 'all') {
                products =
                    products.where((p) => p.category == _selectedCategory).toList();
              }

              final categories = ['all'] +
                  provider.products.map((p) => p.category).toSet().toList();

              return isSmall
                  ? _buildMobileLayout(products, categories, context)
                  : _buildDesktopLayout(products, categories, context);
            },
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout(List<WholesaleProduct> products, List<String> categories, BuildContext context) {
    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchCtrl.clear()),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),

        // Category Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              ...categories.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category == 'all' ? 'All' : category),
                    selected: _selectedCategory == category,
                    onSelected: (_) => setState(() => _selectedCategory = category),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Products Grid (Responsive: 2 / 4 / 6 columns)
        Expanded(
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
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
              final product = products[index];
              final cartItem = _cart.firstWhere(
                (item) => item.product.id == product.id,
                orElse: () => CartItem(product, 0),
              );

              return _ProductCard(
                product: product,
                inCart: cartItem.quantity,
                onAddToCart: () {
                  setState(() {
                    final existing = _cart.indexWhere(
                        (item) => item.product.id == product.id);
                    if (existing >= 0) {
                      _cart[existing].quantity++;
                    } else {
                      _cart.add(CartItem(product, 1));
                    }
                  });
                },
                onRemoveFromCart: () {
                  if (cartItem.quantity > 0) {
                    setState(() {
                      final existing = _cart.indexWhere(
                          (item) => item.product.id == product.id);
                      if (existing >= 0) {
                        _cart[existing].quantity--;
                        if (_cart[existing].quantity == 0) {
                          _cart.removeAt(existing);
                        }
                      }
                    });
                  }
                },
              );
            },
          );},
              ))
            ]);}
  

  Widget _buildDesktopLayout(List<WholesaleProduct> products, List<String> categories, BuildContext context) {
    return Row(
      children: [
        // Product List
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => _searchCtrl.clear()),
                                )
                              : null,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),

                    // Category Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          ...categories.map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label:
                                    Text(category == 'all' ? 'All' : category),
                                selected: _selectedCategory == category,
                                onSelected: (_) => setState(
                                    () => _selectedCategory = category),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Products Grid
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final cartItem = _cart.firstWhere(
                            (item) => item.product.id == product.id,
                            orElse: () => CartItem(product, 0),
                          );

                          return _ProductCard(
                            product: product,
                            inCart: cartItem.quantity,
                            onAddToCart: () {
                              setState(() {
                                final existing = _cart.indexWhere(
                                    (item) => item.product.id == product.id);
                                if (existing >= 0) {
                                  _cart[existing].quantity++;
                                } else {
                                  _cart.add(CartItem(product, 1));
                                }
                              });
                            },
                            onRemoveFromCart: () {
                              if (cartItem.quantity > 0) {
                                setState(() {
                                  final existing = _cart.indexWhere(
                                      (item) => item.product.id == product.id);
                                  if (existing >= 0) {
                                    _cart[existing].quantity--;
                                    if (_cart[existing].quantity == 0) {
                                      _cart.removeAt(existing);
                                    }
                                  }
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Cart Sidebar
              Container(
                width: 320,
                color: Colors.white,
                child: Column(
                  children: [
                    // Cart Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius:
                            BorderRadius.only(bottomLeft: Radius.circular(12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sales Cart',
                            style: AppTextStyles.heading3
                                .copyWith(color: Colors.white),
                          ),
                          Text(
                            '${_cart.length} items',
                            style: AppTextStyles.body2
                                .copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    // Cart Items
                    Expanded(
                      child: _cart.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.shopping_cart_outlined,
                                      size: 48, color: AppColors.border),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Cart is empty',
                                    style: AppTextStyles.body2.copyWith(
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _cart.length,
                              itemBuilder: (context, index) {
                                final cartItem = _cart[index];
                                return _CartItemTile(
                                  item: cartItem,
                                  onQuantityChange: (newQty) {
                                    setState(() {
                                      if (newQty <= 0) {
                                        _cart.removeAt(index);
                                      } else {
                                        cartItem.quantity = newQty;
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),

                    // Checkout
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        border:
                            Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Column(
                        children: [
                          _PriceSummary(items: _cart),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: 'Checkout',
                            backgroundColor: AppColors.primary,
                            onPressed: _cart.isEmpty
                                ? null
                                : () => _showCheckoutDialog(context),
                          ),
                          const SizedBox(height: 8),
                          CustomButton(
                            text: 'Clear Cart',
                            backgroundColor: Colors.red,
                            onPressed: () => setState(() => _cart.clear()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }


  void _showCartModal(BuildContext context) {
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
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
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
                    Text('Cart', style: AppTextStyles.heading3.copyWith(color: AppColors.primary)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),

              Expanded(
                child: _cart.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.border), const SizedBox(height: 12), Text('Cart is empty', style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary))]))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _cart.length,
                        itemBuilder: (context, index) {
                          final cartItem = _cart[index];
                          return _CartItemTile(
                            item: cartItem,
                            onQuantityChange: (newQty) {
                              setState(() {
                                if (newQty <= 0) {
                                  _cart.removeAt(index);
                                } else {
                                  cartItem.quantity = newQty;
                                }
                              });
                            },
                          );
                        },
                      ),
              ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    _PriceSummary(items: _cart),
                    const SizedBox(height: 16),
                    CustomButton(text: 'Checkout', backgroundColor: AppColors.primary, onPressed: _cart.isEmpty ? null : () { Navigator.pop(context); _showCheckoutDialog(context); }),
                    const SizedBox(height: 8),
                    CustomButton(text: 'Clear Cart', backgroundColor: Colors.red, onPressed: () => setState(() => _cart.clear())),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context) {
    final warehouses = context.read<WholesaleProvider>().warehouses;
    final defaultWarehouseId = context.read<AuthProvider>().currentUser?.storeId;

    showDialog(
      context: context,
      builder: (context) => _CheckoutDialog(
        cartItems: _cart,
        warehouses: warehouses,
        defaultWarehouseId: defaultWarehouseId,
        onComplete: (payment, warehouseId) async {
          // Save to Firestore via provider
          await _saveToFirestore(context, payment, warehouseId);
          Navigator.pop(context);
          setState(() => _cart.clear());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sale completed successfully')),
          );
        },
      ),
    );
  }

  Future<void> _saveToFirestore(BuildContext context, String paymentMethod, String? warehouseId) async {
    final provider = context.read<WholesaleProvider>();
    final auth = context.read<AuthProvider>();

    // Build order items for provider
    final items = _cart
        .map((item) => OrderItem(
              productId: item.product.id,
              productName: item.product.name,
              quantity: item.quantity,
              unitPrice: item.product.wholesalePrice,
              total: item.product.wholesalePrice * item.quantity,
            ))
        .toList();

    try {
      await provider.createSale(
        items: items,
        paymentMethod: paymentMethod,
        workerId: auth.currentUser?.id,
        workerName: auth.currentUser?.fullName,
        warehouseId: warehouseId,
      );

      // Send push notification to business owners
      try {
        final totalAmount = items.fold<double>(0.0, (sum, item) => sum + item.total);
        await BusinessNotificationManager.instance.notifySaleCompleted(
          businessId: auth.currentUser?.businessId ?? '',
          customerName: 'Customer',
          amount: totalAmount,
          paymentMethod: paymentMethod,
        );

        if (totalAmount > 100) {
          await BusinessNotificationManager.instance.notifyLargeSale(
            businessId: auth.currentUser?.businessId ?? '',
            customerName: 'Customer',
            amount: totalAmount,
          );
        }
      } catch (e) {
        debugPrint('[WarehousePOS] Push notification failed: $e');
      }
    } catch (e) {
      debugPrint('[WarehousePOS] Failed to save sale: $e');
    }
  }
}

class CartItem {
  final WholesaleProduct product;
  int quantity;

  CartItem(this.product, this.quantity);
}

class _ProductCard extends StatelessWidget {
  final WholesaleProduct product;
  final int inCart;
  final VoidCallback onAddToCart;
  final VoidCallback onRemoveFromCart;

  const _ProductCard({
    required this.product,
    required this.inCart,
    required this.onAddToCart,
    required this.onRemoveFromCart,
  });

  @override
  Widget build(BuildContext context) {
    final lowStock = product.quantity < product.reorderLevel;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: lowStock ? Colors.red : AppColors.border,
          width: lowStock ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(7),
                      topRight: Radius.circular(7),
                    ),
                  ),
                  child: product.imageUrl != null &&
                          product.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.image_not_supported,
                              color: AppColors.border))
                      : const Icon(Icons.image_not_supported,
                          color: AppColors.border),
                ),
              ),

              // Product Info
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₦${product.wholesalePrice.toStringAsFixed(0)}',
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stock: ${product.quantity}',
                      style: AppTextStyles.caption.copyWith(
                        color: lowStock ? Colors.red : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Add to Cart Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    if (inCart > 0)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              GestureDetector(
                                onTap: onRemoveFromCart,
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.remove,
                                      size: 16, color: AppColors.primary),
                                ),
                              ),
                              Text('$inCart',
                                  style: AppTextStyles.caption
                                      .copyWith(fontWeight: FontWeight.bold)),
                              GestureDetector(
                                onTap:
                                    product.quantity > 0 ? onAddToCart : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.add,
                                      size: 16,
                                      color: product.quantity > 0
                                          ? AppColors.primary
                                          : Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: GestureDetector(
                          onTap: product.quantity > 0 ? onAddToCart : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: product.quantity > 0
                                  ? AppColors.primary
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.quantity > 0 ? 'Add' : 'Out',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (lowStock)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Low',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final Function(int) onQuantityChange;

  const _CartItemTile({required this.item, required this.onQuantityChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.product.name,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₦${(item.product.wholesalePrice * item.quantity).toStringAsFixed(0)}',
                style:
                    AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => onQuantityChange(item.quantity - 1),
                    child: const Icon(Icons.remove_circle,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text('${item.quantity}', style: AppTextStyles.body2),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => onQuantityChange(item.quantity + 1),
                    child: const Icon(Icons.add_circle,
                        size: 20, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceSummary extends StatelessWidget {
  final List<CartItem> items;

  const _PriceSummary({required this.items});

  @override
  Widget build(BuildContext context) {
    final subtotal = items.fold<double>(
        0, (sum, item) => sum + (item.product.wholesalePrice * item.quantity));
    final tax = subtotal * 0.08;
    final total = subtotal + tax;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal'),
              Text('₦${subtotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tax (8%)'),
              Text('₦${tax.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                '₦${total.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  final List<CartItem> cartItems;
  final List<WarehouseLocation> warehouses;
  final String? defaultWarehouseId;
  final Function(String paymentMethod, String? warehouseId) onComplete;

  const _CheckoutDialog({
    required this.cartItems,
    required this.warehouses,
    this.defaultWarehouseId,
    required this.onComplete,
  });

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  String _paymentMethod = 'cash';
  String? _selectedWarehouseId;

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.cartItems.fold<double>(
        0, (sum, item) => sum + (item.product.wholesalePrice * item.quantity));
    final tax = subtotal * 0.08;
    final total = subtotal + tax;

    return AlertDialog(
      title: const Text('Checkout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items: ${widget.cartItems.length}', style: AppTextStyles.body2),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal'),
                    Text('₦${subtotal.toStringAsFixed(0)}'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tax'),
                    Text('₦${tax.toStringAsFixed(0)}'),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('₦${total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Payment Method', style: AppTextStyles.body1),
          const SizedBox(height: 8),
          ...['cash', 'card', 'transfer', 'flutterwave'].map(
            (method) => RadioListTile<String>(
              title: Text(method.toUpperCase()),
              value: method,
              groupValue: _paymentMethod,
              onChanged: (value) => setState(() => _paymentMethod = value!),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.warehouses.isNotEmpty) ...[
            const Text('Select Warehouse', style: AppTextStyles.body1),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedWarehouseId ?? widget.defaultWarehouseId ?? widget.warehouses.first.id,
              items: widget.warehouses
                  .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedWarehouseId = value),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        AsyncButton(
          onPressed: () async => await widget.onComplete(_paymentMethod, _selectedWarehouseId ?? widget.defaultWarehouseId ?? (widget.warehouses.isNotEmpty ? widget.warehouses.first.id : null)),
          child: const Text('Complete Sale'),
        ),
      ],
    );
  }
}
