import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/pharmacy_provider.dart';
import '../../../providers/retail_provider.dart' show Product;
import '../../../services/managecare_api_client.dart';
import '../../../services/web_download.dart' as web_download;
import '../../../widgets/loading_indicator.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    // Set default date range to last 30 days
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[ProductDetailsScreen] Building with productId: ${widget.productId}');
    
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final business = businessProvider.currentBusiness;
    
    if (business == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: const Center(child: Text('No business selected')),
      );
    }

    // Check if this is a pharmacy product
    final isPharmacyProduct = widget.productId.startsWith('pharmacy_');
    
    if (isPharmacyProduct) {
      return _buildPharmacyProductDetails(context);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      // Product details no longer live in Firestore, and the custom backend
      // doesn't implement realtime push, so this is a one-shot fetch rather
      // than a live subscription.
      body: FutureBuilder<Map<String, dynamic>?>(
        future: ManagecareApiClient.instance
            .get('/inventory/${business.id}/${widget.productId}')
            .then((data) => data as Map<String, dynamic>?)
            .catchError((_) => null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Product not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final productData = snapshot.data!;
          final product = Product.fromJson(productData);

          return DefaultTabController(
            length: 3,
            child: CustomScrollView(
              slivers: [
                // Image Carousel App Bar
                SliverAppBar(
                  expandedHeight: 400,
                  pinned: true,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: const Icon(Icons.favorite_border, color: AppColors.textPrimary),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Added to favorites')),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      children: [
                        // Product Image or Placeholder
                        PageView.builder(
                          itemCount: (product.imageUrl != null) ? 1 : 1,
                          itemBuilder: (context, index) {
                            return Container(
                              color: AppColors.background,
                              child: product.imageUrl != null
                                  ? Image.network(
                                      product.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 120,
                                            color: AppColors.primary.withOpacity(0.3),
                                          ),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Text(
                                        product.emoji,
                                        style: const TextStyle(fontSize: 120),
                                      ),
                                    ),
                            );
                          },
                        ),
                        // Image Indicators
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 24,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // TabBar for Overview, Sales History, Procurement
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: AppTextStyles.body2,
                      unselectedLabelStyle: AppTextStyles.body2Secondary,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Sales'),
                        Tab(text: 'Procurement'),
                      ],
                    ),
                  ),
                ),

                // Product Details & Tabs Content
                SliverFillRemaining(
                  child: TabBarView(
                    children: [
                      _buildOverviewTab(product, productData),
                      _buildSalesHistoryTab(business.id, product),
                      _buildProcurementHistoryTab(business.id, product),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Build Overview Tab
  Widget _buildOverviewTab(Product product, Map<String, dynamic> productData) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '₦');
    
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name & Category
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.category,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Product Name
                  Text(
                    product.name,
                    style: AppTextStyles.heading3,
                  ),
                  const SizedBox(height: 12),

                  // Price and Stock Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selling Price', style: AppTextStyles.body2Secondary),
                          Text(
                            currencyFormat.format(product.price),
                            style: AppTextStyles.heading4.copyWith(color: AppColors.success),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Cost Price', style: AppTextStyles.body2Secondary),
                          Text(
                            currencyFormat.format(product.cost),
                            style: AppTextStyles.body1,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Stock Status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: product.stock > 10
                          ? Colors.green.withOpacity(0.1)
                          : product.stock > 0
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: product.stock > 10
                            ? Colors.green
                            : product.stock > 0
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Stock', style: AppTextStyles.body2Secondary),
                            Text(
                              '${product.stock.toInt()} ${product.unit}',
                              style: AppTextStyles.heading5,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: product.stock > 10
                                ? Colors.green
                                : product.stock > 0
                                    ? Colors.orange
                                    : Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.stock > 10
                                ? 'In Stock'
                                : product.stock > 0
                                    ? 'Low Stock'
                                    : 'Out of Stock',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Product Details
                  const Text('Product Details', style: AppTextStyles.heading5),
                  const SizedBox(height: 12),
                  
                  _buildDetailRow('Barcode', product.barcode ?? 'N/A'),
                  _buildDetailRow('Unit', product.unit),
                  if ((productData['bagWeightKg'] ?? 0) != null && (productData['bagWeightKg'] as num) > 0)
                    _buildDetailRow('Bag weight', '${(productData['bagWeightKg'] as num).toString()} kg'),
                  _buildDetailRow('Emoji', product.emoji),
                  _buildDetailRow('Profit Margin', '${(((product.price - product.cost) / product.price) * 100).toStringAsFixed(1)}%'),
                  
                  const SizedBox(height: 24),
                  
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${product.name} added to cart')),
                            );
                          },
                          icon: const Icon(Icons.shopping_cart),
                          label: const Text('Add to Cart'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body2Secondary),
          Text(value, style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Helper: Parse timestamp from various formats
  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed ?? DateTime.now();
    }
    return DateTime.now();
  }

  // Helper: Extract product quantity from sale
  int _extractProductQuantityFromSale(
    Map<String, dynamic> saleData,
    Product product,
  ) {
    final items = (saleData['items'] as List?) ?? [];
    int totalQty = 0;
    
    for (var item in items) {
      if (item is Map) {
        final normalized = Map<String, dynamic>.from(item);
        if (_saleItemMatchesProduct(normalized, product)) {
          final qty = normalized['quantity'] ?? normalized['qty'] ?? normalized['quantitySold'] ?? 0;
          totalQty += (qty is num) ? qty.toInt() : int.tryParse(qty.toString()) ?? 0;
        }
      }
    }
    
    return totalQty;
  }

  // Helper: Extract product cost from procurement item
  double _extractProductCostFromProcurement(Map<String, dynamic> procItem) {
    final total = procItem['total'] ?? 
                  procItem['cost'] ?? 
                  ((procItem['quantity'] ?? 0) * (procItem['unitCost'] ?? 0)) ?? 
                  0;
    
    if (total is num) return total.toDouble();
    return double.tryParse(total.toString()) ?? 0.0;
  }

  bool _saleItemMatchesProduct(Map<String, dynamic> item, Product product) {
    final productId = widget.productId.trim().toLowerCase();
    final productName = product.name.trim().toLowerCase();
    final productBarcode = (product.barcode ?? '').trim().toLowerCase();

    final itemProductId = (item['productId'] ??
            item['product_id'] ??
            item['id'] ??
            item['productIdStr'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    final itemName = (item['productName'] ?? item['name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final itemBarcode = (item['barcode'] ?? '').toString().trim().toLowerCase();
    final itemSku = (item['sku'] ?? '').toString().trim().toLowerCase();

    final directMatches = <String>{
      productId,
      productName,
      productBarcode,
    }.where((value) => value.isNotEmpty).toSet();

    final itemValues = <String>{
      itemProductId,
      itemName,
      itemBarcode,
      itemSku,
    };

    if (directMatches.any(itemValues.contains)) return true;

    if (productId.isNotEmpty && itemProductId.isNotEmpty) {
      if (itemProductId.contains(productId) || productId.contains(itemProductId)) {
        return true;
      }
    }

    if (productName.isNotEmpty && itemName.isNotEmpty) {
      if (itemName.contains(productName) || productName.contains(itemName)) {
        return true;
      }
    }

    if (productBarcode.isNotEmpty && itemBarcode.isNotEmpty) {
      if (itemBarcode.contains(productBarcode) || productBarcode.contains(itemBarcode)) {
        return true;
      }
    }

    return false;
  }

  bool _saleContainsProduct(Map<String, dynamic> saleData, Product product) {
    final items = (saleData['items'] as List?) ?? [];
    for (final item in items) {
      if (item is Map<String, dynamic> && _saleItemMatchesProduct(item, product)) {
        return true;
      }
      if (item is Map) {
        final normalized = Map<String, dynamic>.from(item);
        if (_saleItemMatchesProduct(normalized, product)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> _loadProductSalesHistory(
    String businessId,
    Product product,
  ) async {
    final combined = <String, Map<String, dynamic>>{};

    Future<void> addDocs(QuerySnapshot snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (!_saleContainsProduct(data, product)) continue;
        combined[doc.id] = {'id': doc.id, ...data};
      }
    }

    try {
      await addDocs(await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .get());
    } catch (e) {
      debugPrint('[ProductDetailsScreen] Nested sales load failed: $e');
    }

    try {
      await addDocs(await FirebaseFirestore.instance
          .collection('sales')
          .where('businessId', isEqualTo: businessId)
          .get());
    } catch (e) {
      debugPrint('[ProductDetailsScreen] Root sales load failed: $e');
    }

    final records = combined.values.toList();
    records.sort((left, right) {
      final leftTime = _parseTimestamp(left['createdAt'] ?? left['timestamp']).millisecondsSinceEpoch;
      final rightTime = _parseTimestamp(right['createdAt'] ?? right['timestamp']).millisecondsSinceEpoch;
      return rightTime.compareTo(leftTime);
    });
    return records;
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _buildProductSalesCsv(List<Map<String, dynamic>> sales, Product product) {
    final buffer = StringBuffer();
    buffer.writeln([
      'Sale ID',
      'Date',
      'Product',
      'Quantity',
      'Unit Price',
      'Line Total',
      'Payment Method',
      'Receipt Number',
    ].join(','));

    for (final sale in sales) {
      final timestamp = _parseTimestamp(sale['createdAt'] ?? sale['timestamp']);
      final items = (sale['items'] as List?) ?? [];
      for (final item in items) {
        if (item is! Map) continue;
        final normalized = Map<String, dynamic>.from(item);
        if (!_saleItemMatchesProduct(normalized, product)) continue;

        final qty = (normalized['quantity'] ?? normalized['qty'] ?? normalized['quantitySold'] ?? 0);
        final unitPrice = (normalized['unitPrice'] ?? normalized['price'] ?? normalized['sellingPrice'] ?? 0);
        final lineTotal = (normalized['total'] ?? normalized['amount'] ?? 0);

        buffer.writeln([
          _escapeCsv(sale['id']?.toString() ?? ''),
          _escapeCsv(DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)),
          _escapeCsv(product.name),
          _escapeCsv(qty.toString()),
          _escapeCsv(unitPrice.toString()),
          _escapeCsv(lineTotal.toString()),
          _escapeCsv(sale['paymentMethod']?.toString() ?? ''),
          _escapeCsv(sale['receiptNumber']?.toString() ?? ''),
        ].join(','));
      }
    }

    return buffer.toString();
  }

  Future<void> _exportProductSalesHistory(
    String businessId,
    Product product,
  ) async {
    try {
      final sales = await _loadProductSalesHistory(businessId, product);
      if (sales.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sales history found for this product')),
        );
        return;
      }

      final csv = _buildProductSalesCsv(sales, product);
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final fileName =
          '${product.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}_sales_history.csv';

      if (kIsWeb) {
        web_download.downloadBytes(bytes, fileName, 'text/csv');
      } else {
        await Share.shareXFiles([
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: 'text/csv',
          ),
        ],
            text: 'Product sales history for ${product.name}');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sales history exported for ${product.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export product sales history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

    // Build Sales History Tab
  Widget _buildSalesHistoryTab(String businessId, Product product) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: AppColors.background,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.date_range, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDateRange(),
                      child: Text(
                        _dateRange != null
                            ? '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}'
                            : 'Select Date Range',
                        style: AppTextStyles.body2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() => _dateRange = null);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSalesQuickStats(businessId, product),
          const SizedBox(height: 20),
          _buildSalesHistoryList(businessId, product),
        ],
      ),
    );
  }

  Widget _buildSalesQuickStats(String businessId, Product product) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _calculateSalesStats(businessId, product),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data ?? {'totalUnits': 0, 'revenue': 0.0, 'margin': 0.0, 'historyCount': 0};
        final totalUnits = stats["totalUnits"] as int;
        final revenue = stats["revenue"] as double;
        final margin = stats["margin"] as double;
        final historyCount = stats["historyCount"] as int;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Summary', style: AppTextStyles.heading5),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.trending_up,
                    label: 'Total Sold',
                    value: '$totalUnits units',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.attach_money,
                    label: 'Revenue',
                    value: '₦${revenue.toStringAsFixed(0)}',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.percent,
                    label: 'Margin',
                    value: '${margin.toStringAsFixed(1)}%',
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Loaded from $historyCount sale record(s)',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesHistoryList(String businessId, Product product) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: "en_US", symbol: "₦");
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadProductSalesHistory(businessId, product),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text(
            "Failed to load sales history: ${snapshot.error}",
            style: AppTextStyles.body2.copyWith(color: AppColors.error),
          );
        }

        final sales = snapshot.data ?? const [];
        final filtered = sales.where((sale) {
          if (_dateRange == null) return true;
          final timestamp = _parseTimestamp(sale["createdAt"] ?? sale["timestamp"]);
          return !timestamp.isBefore(_dateRange!.start) && !timestamp.isAfter(_dateRange!.end);
        }).toList();

        if (sales.isEmpty) {
          return const Center(child: Text("No sales records found for this product"));
        }

        if (filtered.isEmpty) {
          return const Center(child: Text("No sales records found in the selected range"));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text("Sales Records", style: AppTextStyles.heading5),
                ),
                IconButton(
                  tooltip: "Download product sales history",
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => _exportProductSalesHistory(businessId, product),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final saleData = filtered[index];
                final timestamp = _parseTimestamp(saleData["createdAt"] ?? saleData["timestamp"]);
                final formattedDate = DateFormat("MMM dd, yyyy").format(timestamp);
                final totalAmount = (saleData["finalAmount"] ?? saleData["totalAmount"] ?? saleData["total"] ?? 0) as num;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_bag, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Sale #${(saleData["id"] ?? "").toString().substring(0, 8).toUpperCase()}",
                                style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Total: ${currencyFormat.format(totalAmount)}",
                                style: AppTextStyles.caption,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Qty: ${_extractProductQuantityFromSale(saleData, product)} units",
                                style: AppTextStyles.caption.copyWith(color: AppColors.success),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Build Procurement History Tab
  Widget _buildProcurementHistoryTab(String businessId, Product product) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Procurement Stats
          _buildProcurementStats(),
          const SizedBox(height: 20),

          // Procurement History List
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Procurement History', style: AppTextStyles.heading5),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('businesses')
                    .doc(businessId)
                    .collection('procurements')
                    .orderBy('createdAt', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No procurement records found'),
                    );
                  }
                  
                  // Filter for procurements containing this product only
                  final procurementsForProduct = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final items = (data['items'] as List?) ?? [];
                    
                    return items.any((item) {
                      if (item is! Map) return false;
                      
                      final itemProductId = item['productId'] ?? 
                                           item['product_id'] ?? 
                                           item['id'];
                      
                      final isMatch = itemProductId == widget.productId || 
                                     (itemProductId is String && widget.productId.isNotEmpty && 
                                      (itemProductId.contains(widget.productId) || 
                                       widget.productId.contains(itemProductId)));
                      
                      return isMatch;
                    });
                  }).toList();
                  
                  if (procurementsForProduct.isEmpty) {
                    return const Center(
                      child: Text('No procurements found for this product'),
                    );
                  }
                  
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: procurementsForProduct.length,
                    itemBuilder: (context, index) {
                      final procDoc = procurementsForProduct[index];
                      final procData = procDoc.data() as Map<String, dynamic>;
                      
                      final timestamp = _parseTimestamp(procData['createdAt'] ?? procData['timestamp']);
                      final formattedDate = DateFormat('MMM dd, yyyy').format(timestamp);
                      final status = procData['status'] ?? 'pending';
                      
                      final items = (procData['items'] as List?) ?? [];
                      final productItem = items.firstWhere(
                        (item) => item is Map && 
                                 (item['productId'] == widget.productId || 
                                  item['product_id'] == widget.productId),
                        orElse: () => null,
                      );
                      
                      if (productItem == null) return const SizedBox.shrink();
                      
                      final productCost = _extractProductCostFromProcurement(productItem as Map<String, dynamic>);
                      final productQty = (productItem['quantity'] ?? 0) as num;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.inventory_2,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      procData['supplierName'] ?? 'Unknown Supplier',
                                      style: AppTextStyles.body2.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Invoice: ${procData['invoiceRef'] ?? procDoc.id.substring(0, 8)}',
                                      style: AppTextStyles.caption,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Qty: ${productQty.toInt()} units',
                                          style: AppTextStyles.caption,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Cost: ₦${productCost.toStringAsFixed(0)}',
                                          style: AppTextStyles.caption,
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'received'
                                                ? AppColors.success.withOpacity(0.2)
                                                : Colors.orange.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: AppTextStyles.caption.copyWith(
                                              color: status == 'received'
                                                  ? AppColors.success
                                                  : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formattedDate,
                                      style: AppTextStyles.caption
                                          .copyWith(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 16, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build Procurement Stats
  Widget _buildProcurementStats() {
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final businessId = businessProvider.currentBusiness?.id ?? '';
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _calculateProcurementStats(businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final stats = snapshot.data ?? {'totalUnits': 0, 'totalCost': 0.0, 'pending': 0};
        final totalUnits = stats['totalUnits'] as int;
        final totalCost = stats['totalCost'] as double;
        final pending = stats['pending'] as int;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Procurement Overview', style: AppTextStyles.heading5),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.inventory,
                    label: 'Total Procured',
                    value: '$totalUnits units',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.shopping_cart,
                    label: 'Total Cost',
                    value: '₦${totalCost.toStringAsFixed(0)}',
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.local_shipping,
                    label: 'Pending',
                    value: '$pending orders',
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Date Range Picker
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null && picked != _dateRange) {
      setState(() => _dateRange = picked);
    }
  }

  // Calculate sales statistics
  Future<Map<String, dynamic>> _calculateSalesStats(
    String businessId,
    Product product,
  ) async {
    try {
      final sales = await _loadProductSalesHistory(businessId, product);
      final relevantSales = sales.where((sale) {
        if (_dateRange == null) return true;
        final timestamp = _parseTimestamp(sale['createdAt'] ?? sale['timestamp']);
        return !timestamp.isBefore(_dateRange!.start) &&
            !timestamp.isAfter(_dateRange!.end);
      }).toList();
      int totalUnits = 0;
      double productRevenue = 0.0;
      double productCost = 0.0;

      for (final sale in relevantSales) {
        final items = (sale['items'] as List?) ?? [];
        for (final item in items) {
          if (item is! Map) continue;
          final normalized = Map<String, dynamic>.from(item);
          if (!_saleItemMatchesProduct(normalized, product)) continue;

          final qty = normalized['quantity'] ?? normalized['qty'] ?? normalized['quantitySold'] ?? 0;
          totalUnits += (qty is num) ? qty.toInt() : int.tryParse(qty.toString()) ?? 0;

          final itemTotal = normalized['total'] ??
              normalized['price'] ??
              (normalized['quantity'] != null && normalized['unitPrice'] != null
                  ? normalized['quantity'] * normalized['unitPrice']
                  : 0);
          productRevenue += (itemTotal is num) ? itemTotal.toDouble() : double.tryParse(itemTotal.toString()) ?? 0.0;

          final itemCost = normalized['cost'] ??
              normalized['unitCost'] ??
              (normalized['quantity'] != null && normalized['unitCost'] != null
                  ? normalized['quantity'] * normalized['unitCost']
                  : 0);
          productCost += (itemCost is num) ? itemCost.toDouble() : double.tryParse(itemCost.toString()) ?? 0.0;
        }
      }

      final margin = productRevenue > 0
          ? (((productRevenue - productCost) / productRevenue) * 100)
          : 0.0;

      return {
        'totalUnits': totalUnits,
        'revenue': productRevenue,
        'margin': margin,
        'historyCount': relevantSales.length,
      };
    } catch (e) {
      debugPrint('[_calculateSalesStats] ERROR: $e');
      return {
        'totalUnits': 0,
        'revenue': 0.0,
        'margin': 0.0,
        'historyCount': 0,
      };
    }
  }

  // Calculate procurement statistics
  Future<Map<String, dynamic>> _calculateProcurementStats(String businessId) async {
    try {
      debugPrint('[_calculateProcurementStats] Starting for product: ${widget.productId}');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('procurements')
          .get();
      
      debugPrint('[_calculateProcurementStats] Found ${snapshot.docs.length} procurement documents');
      
      int totalUnits = 0;
      double productOnlyCost = 0.0;
      int pending = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        final items = (data['items'] as List?) ?? [];
        debugPrint('[_calculateProcurementStats] Procurement ${doc.id} has ${items.length} items');
        
        for (var item in items) {
          if (item is! Map) continue;
          
          final itemProductId = item['productId'] ?? 
                               item['product_id'] ?? 
                               item['id'];
          
          debugPrint('[_calculateProcurementStats] Checking item: itemProductId="$itemProductId" (${itemProductId.runtimeType}), widget.productId="${widget.productId}" (${widget.productId.runtimeType})');
          
          final isExactMatch = itemProductId == widget.productId;
          final isContainMatch = itemProductId is String && widget.productId.isNotEmpty && 
                                (itemProductId.contains(widget.productId) || 
                                 widget.productId.contains(itemProductId));
          final isMatch = isExactMatch || isContainMatch;
          
          debugPrint('[_calculateProcurementStats] exactMatch=$isExactMatch, containMatch=$isContainMatch, finalMatch=$isMatch');
          
          if (isMatch) {
            debugPrint('[_calculateProcurementStats] MATCH FOUND!');
            
            final qty = item['quantity'] ?? item['qty'] ?? 0;
            totalUnits += (qty is num) ? qty.toInt() : int.tryParse(qty.toString()) ?? 0;
            
            final itemCost = item['total'] ?? 
                            item['cost'] ??
                            (item['quantity'] != null && item['unitCost'] != null 
                              ? item['quantity'] * item['unitCost'] 
                              : 0);
            productOnlyCost += (itemCost is num) ? itemCost.toDouble() : 
                              double.tryParse(itemCost.toString()) ?? 0.0;
            
            if (data['status'] == 'pending') pending++;
          }
        }
      }
      
      debugPrint('[_calculateProcurementStats] FINAL - Units: $totalUnits, Cost: $productOnlyCost, Pending: $pending');
      
      return {
        'totalUnits': totalUnits,
        'totalCost': productOnlyCost,
        'pending': pending,
      };
    } catch (e) {
      debugPrint('[_calculateProcurementStats] Error: $e');
      return {'totalUnits': 0, 'totalCost': 0.0, 'pending': 0};
    }
  }

  // Build pharmacy product details
  Widget _buildPharmacyProductDetails(BuildContext context) {
    final pharmacyProvider = Provider.of<PharmacyProvider>(context, listen: false);
    final productIdWithoutPrefix = widget.productId.replaceFirst('pharmacy_', '');
    
    // Find the drug from pharmacy provider
    Drug? drug;
    try {
      drug = pharmacyProvider.drugs.firstWhere(
        (d) => d.id == productIdWithoutPrefix,
      );
    } catch (_) {
      drug = null;
    }

    if (drug == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.medication_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Pharmacy product not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(drug.name),
        elevation: 0,
      ),
      body: DefaultTabController(
        length: 2,
        child: CustomScrollView(
          slivers: [
            // Image/Icon
            SliverToBoxAdapter(
              child: Container(
                height: 250,
                color: AppColors.background,
                child: Center(
                  child: Text(
                    '💊',
                    style: TextStyle(fontSize: 100),
                  ),
                ),
              ),
            ),
            // Basic Info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drug.name,
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₦${drug.price.toStringAsFixed(2)}',
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Quick Stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.inventory_2,
                            label: 'In Stock',
                            value: drug.stock.toString(),
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.calendar_today,
                            label: 'Expiry',
                            value: DateFormat('MMM dd, yyyy').format(drug.expiry),
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // TabBar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'History'),
                  ],
                ),
              ),
            ),
            // TabBarView Content
            SliverFillRemaining(
              child: TabBarView(
                children: [
                  // Overview Tab
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Details',
                          style: AppTextStyles.heading3,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Name', drug.name),
                        _buildDetailRow('Batch', drug.batch),
                        _buildDetailRow('Price', '₦${drug.price}'),
                        _buildDetailRow('Stock', drug.stock.toString()),
                        _buildDetailRow('Expiry', DateFormat('MMM dd, yyyy').format(drug.expiry)),
                      ],
                    ),
                  ),
                  // History Tab
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchase History',
                          style: AppTextStyles.heading3,
                        ),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text('No purchase history available'),
                        ),
                      ],
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

// Custom TabBar Delegate for Sliver
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }

}
