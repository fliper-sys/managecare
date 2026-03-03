import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/search_utils.dart';
import '../../../widgets/product_view_switcher.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/barcode_service.dart';
import '../../../../services/analytics_service.dart'; 

import '../widgets/checkout_sheet.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  // Currently selected store for filtering products in POS
  String? _selectedStoreId; 

  // Handheld scanner mode
  bool _handheldMode = false;
  final _handheldController = TextEditingController();
  final _handheldFocusNode = FocusNode();

  // View toggle
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _handheldController.dispose();
    _handheldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Point of Sale'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () async {
              final barcodeService = BarcodeService();
              try {
                final barcode = await barcodeService.scanBarcode(context);
                if (barcode != null && barcode.isNotEmpty) {
                  final retail = Provider.of<RetailProvider>(context, listen: false);
                  final added = retail.addByBarcode(barcode);
                  final analytics = AnalyticsService();
                  try {
                    await analytics.logEvent('barcode_scanned', {'barcode': barcode, 'source': 'pos', 'added': added});
                  } catch (_) {}
                  if (added) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Product added to cart'), duration: const Duration(seconds: 2)),
                    );
                  } else {
                    if (!mounted) return;
                    _searchController.text = barcode;
                    setState(() => _searchQuery = barcode);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No product found for barcode: $barcode'), backgroundColor: AppColors.error),
                    );
                  }
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Scan error: $e'), backgroundColor: AppColors.error),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(_handheldMode ? Icons.keyboard : Icons.keyboard_hide),
            tooltip: 'Toggle handheld scanner',
            onPressed: () {
              setState(() => _handheldMode = !_handheldMode);
              if (_handheldMode) {
                Future.delayed(const Duration(milliseconds: 200), () {
                  _handheldFocusNode.requestFocus();
                });
              }
            },
          ),
        ],
      ),
      body: Consumer<RetailProvider>(
        builder: (context, retailProvider, _) {
          // Ensure stores are loaded and the POS uses the selected store to filter products
          final auth = Provider.of<AuthProvider>(context, listen: false);
          if (retailProvider.stores.isEmpty) {
            retailProvider.loadStores();
          }

          final stores = retailProvider.stores;
          // When stores first become available, pick a default selected store and load products for it
          if (_selectedStoreId == null && stores.isNotEmpty) {
            _selectedStoreId = auth.currentUser?.storeId ?? stores.first.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              retailProvider.loadProducts(storeId: _selectedStoreId);
            });
          }

          // Get unique categories
          final categories = {
            'All',
            ...retailProvider.products.map((p) => p.category)
          };

          // Filter products based on search and category
          var filteredProducts = retailProvider.products; 

          if (_selectedCategory != 'All') {
            filteredProducts = filteredProducts
                .where((p) => p.category == _selectedCategory)
                .toList();
          }

          if (_searchQuery.isNotEmpty) {
            filteredProducts = filteredProducts
                .where((p) =>
                    SearchUtils.matchesSearchQuery(p.name, p.barcode, _searchQuery))
                .toList();
            
            // Sort by relevance
            filteredProducts.sort((a, b) {
              final scoreA = SearchUtils.calculateRelevanceScore(a.name, a.barcode, _searchQuery);
              final scoreB = SearchUtils.calculateRelevanceScore(b.name, b.barcode, _searchQuery);
              return scoreB.compareTo(scoreA); // Higher score first
            });
          }

          // Filter out out-of-stock items
          filteredProducts =
              filteredProducts.where((p) => p.stock > 0).toList();

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products or scan barcode...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ProductViewSwitcher(
                          isGridView: _isGridView,
                          onToggle: () => setState(() => _isGridView = !_isGridView),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // Store selector (filters products by store)
              if (retailProvider.stores.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Text('Store:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStoreId ?? retailProvider.stores.first.id,
                            isExpanded: true,
                            items: retailProvider.stores
                                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => _selectedStoreId = val);
                              // Load products for the newly selected store
                              retailProvider.loadProducts(storeId: val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Handheld scanner input (keyboard wedge)
              if (_handheldMode)
                Container(
                  color: AppColors.surface,
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
                          onSubmitted: (value) {
                            if (value.trim().isEmpty) return;
                            final added = retailProvider.addByBarcode(value.trim());
                            final analytics = AnalyticsService();
                            analytics.logEvent('barcode_scanned', {'barcode': value.trim(), 'source': 'handheld', 'added': added}).catchError((_) {});
                            if (added) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Product added to cart'), duration: const Duration(seconds: 2)),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('No product found for barcode: ${value.trim()}'), backgroundColor: AppColors.error),
                              );
                            }
                            _handheldController.clear();
                            Future.delayed(const Duration(milliseconds: 50), () => _handheldFocusNode.requestFocus());
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

              // Category Filter
              if (categories.isNotEmpty)
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories.elementAt(index);
                      final isSelected = category == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (_) => setState(
                            () => _selectedCategory = category,
                          ),
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 8),

              // Products Grid
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No products found',
                              style: AppTextStyles.heading5.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          int crossAxisCount = 2;
                          if (width >= 1200) {
                            crossAxisCount = 6;
                          } else if (width >= 800) {
                            crossAxisCount = 4;
                          }

                          if (_isGridView) {
                            return GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                final cartQty =
                                    retailProvider.cartItems.containsKey(product)
                                        ? retailProvider.cartItems[product]!
                                        : 0;

                                return _ProductCard(
                                  product: product,
                                  cartQuantity: cartQty,
                                  onAdd: () =>
                                      retailProvider.addToCart(product.id, qty: 1),
                                  onRemove: () {
                                    if (cartQty > 1) {
                                      retailProvider.updateQty(
                                          product.id, cartQty - 1);
                                    } else {
                                      retailProvider.removeFromCart(product.id);
                                    }
                                  },
                                );
                              },
                            );
                          } else {
                            // List view
                            return ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                final cartQty =
                                    retailProvider.cartItems.containsKey(product)
                                        ? retailProvider.cartItems[product]!
                                        : 0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ProductListTile(
                                    product: product,
                                    cartQuantity: cartQty,
                                    onAdd: () =>
                                        retailProvider.addToCart(product.id, qty: 1),
                                    onRemove: () {
                                      if (cartQty > 1) {
                                        retailProvider.updateQty(
                                            product.id, cartQty - 1);
                                      } else {
                                        retailProvider.removeFromCart(product.id);
                                      }
                                    },
                                  ),
                                );
                              },
                            );
                          }
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          builder: (_) => const CheckoutSheet(),
          isScrollControlled: true,
        ),
        icon: Stack(
          alignment: Alignment.topRight,
          children: [
            const Icon(Icons.shopping_cart),
            Consumer<RetailProvider>(
              builder: (context, provider, _) {
                if (provider.cartCount > 0) {
                  return Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        provider.cartCount.toString(),
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        label: Consumer<RetailProvider>(
          builder: (context, provider, _) {
            return Text(
              'Cart (₦${provider.cartTotal.toStringAsFixed(2)})',
            );
          },
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

// Enhanced product card with easy quantity controls
class _ProductCard extends StatelessWidget {
  final Product product;
  final int cartQuantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductCard({
    required this.product,
    required this.cartQuantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isInCart = cartQuantity > 0;

    return Card(
      elevation: isInCart ? 4 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border:
              isInCart ? Border.all(color: AppColors.primary, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₦${product.price.toStringAsFixed(2)}',
                      style: AppTextStyles.heading5.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: product.stock < 10
                            ? AppColors.warning.withAlpha(51)
                            : AppColors.success.withAlpha(51),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${product.stock} left',
                        style: AppTextStyles.caption.copyWith(
                          color: product.stock < 10
                              ? AppColors.warning
                              : AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(8),
              child: isInCart
                  ? Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onRemove,
                            icon: const Icon(Icons.remove, size: 16),
                            label: Text(
                              cartQuantity > 99
                                  ? '99+'
                                  : cartQuantity.toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onAdd,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onAdd,
                        icon:
                            const Icon(Icons.shopping_cart_outlined, size: 16),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  final Product product;
  final int cartQuantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductListTile({
    required this.product,
    required this.cartQuantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isInCart = cartQuantity > 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: isInCart ? Border.all(color: AppColors.primary, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          product.name,
          style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Row(
          children: [
            Text(
              '₦${product.price.toStringAsFixed(2)}',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: product.stock < 10
                    ? AppColors.warning.withAlpha(51)
                    : AppColors.success.withAlpha(51),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${product.stock} left',
                style: AppTextStyles.caption.copyWith(
                  color: product.stock < 10
                      ? AppColors.warning
                      : AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        trailing: isInCart
            ? SizedBox(
                width: 150,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onRemove,
                        icon: const Icon(Icons.remove, size: 14),
                        label: Text(
                          cartQuantity > 99 ? '99+' : cartQuantity.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                width: 100,
                child: ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

