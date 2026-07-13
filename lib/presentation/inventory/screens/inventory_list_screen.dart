import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/constants/routes.dart';
import '../../../core/utils/search_utils.dart';
import '../../../providers/pharmacy_provider.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/animated_lottie.dart';
import '../../../services/barcode_service.dart';
import '../../../services/inventory_export_service.dart';
import '../../../data/repositories/inventory_repository_impl.dart';
import '../../../data/repositories/distributor_repository.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/retail_provider.dart';
import '../../../providers/workers_provider.dart';
import 'inventory_alerts_screen.dart';
import 'low_stock_products_screen.dart';
import 'distributor_sales_report_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({
    super.key,
    this.showIngredientsOnly = false,
    this.initialCategory,
  });

  final bool showIngredientsOnly;
  final String? initialCategory;

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _sortBy = 'name';
  bool _showLowStock = false;
  late InventoryRepositoryImpl _repository;
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _filteredInventory = [];
  bool _isLoading = true;
  String? _error;
  int _totalItems = 0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;

  final List<String> _categories = [
    'All',
    'Electronics',
    'Clothing',
    'Food',
    'Beverages',
    'Accessories',
    'Ingredient',
  ];

  @override
  void initState() {
    super.initState();
    _repository =
        InventoryRepositoryImpl(firestore: FirebaseFirestore.instance);
    _selectedCategory = widget.initialCategory ??
        (widget.showIngredientsOnly ? 'Ingredient' : 'All');
    _loadInventory();
    _searchController.addListener(_filterInventory);
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final businessProvider = context.read<BusinessProvider>();
      if (businessProvider.currentBusiness == null) {
        setState(() {
          _error = 'No business selected';
          _isLoading = false;
        });
        return;
      }

      final businessId = businessProvider.currentBusiness!.id;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userStoreId = authProvider.currentUser?.storeId;

      var inventoryData =
          await _repository.getInventory(businessId, storeId: userStoreId);

      // Fallback: if primary query returned no results, try broader fetches
      if ((inventoryData.isEmpty) && businessId.isNotEmpty) {
        try {
          final allItems =
              await _repository.fetchInventory(storeId: userStoreId);
          final userBizId = authProvider.currentUser?.businessId ?? '';
          final businessName = businessProvider.currentBusiness?.name ?? '';

          final fallback = <dynamic>[];
          for (final it in allItems) {
            final bid = (it['businessId'] ?? '').toString();
            final bname = (it['businessName'] ?? '').toString();
            final createdBy = (it['createdBy'] ?? '').toString();

            if (bid == businessId || bid == userBizId) {
              fallback.add(it);
              continue;
            }

            // Accept items with empty businessId if they reference the same business name
            if ((bid.isEmpty) && (bname == businessName)) {
              fallback.add(it);
              continue;
            }

            // Accept items with empty businessId created by current user
            if (bid.isEmpty && createdBy == authProvider.currentUser?.id) {
              fallback.add(it);
              continue;
            }
          }

          if (fallback.isNotEmpty) {
            inventoryData = fallback;
          }
        } catch (e) {
          // ignore fallback errors
        }
      }

      List<Map<String, dynamic>> items = [];
      int lowStock = 0;
      int outOfStock = 0;

      for (var item in inventoryData) {
        if (item is Map<String, dynamic>) {
          items.add(item);
          final quantity = item['quantity'] ?? 0;
          final minStock = item['minStock'] ?? 10;

          if (quantity == 0) {
            outOfStock++;
          } else if (quantity <= minStock) lowStock++;
        }
      }

      // If there are pharmacy drugs cached locally (offline-first), merge them in so they are visible here
      try {
        final pharmacyProvider =
            Provider.of<PharmacyProvider>(context, listen: false);
        for (final d in pharmacyProvider.drugs) {
          final nameKey = d.name.toLowerCase();
          final exists = items.any(
              (it) => (it['name'] ?? '').toString().toLowerCase() == nameKey);
          if (!exists) {
            items.add({
              'id': 'pharmacy_${d.id}',
              'name': d.name,
              'price': d.price,
              'quantity': d.stock,
              'category': 'Pharmacy',
              'emoji': '💊',
            });
            if (d.stock == 0) {
              outOfStock++;
            } else if (d.stock <= (10)) {
              lowStock++;
            }
          }
        }
      } catch (_) {
        // ignore if provider not available
      }

      // Sort by selected sort option
      _sortInventory(items);

      setState(() {
        _inventory = items;
        _totalItems = items.length;
        _lowStockCount = lowStock;
        _outOfStockCount = outOfStock;
        _isLoading = false;
      });

      // Apply filters after loading
      _filterInventory();
    } catch (e) {
      setState(() {
        _error = 'Error loading inventory: $e';
        _isLoading = false;
      });
    }
  }

  void _sortInventory(List<Map<String, dynamic>> items) {
    switch (_sortBy) {
      case 'price':
        items.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
        break;
      case 'stock':
        items
            .sort((a, b) => (b['quantity'] ?? 0).compareTo(a['quantity'] ?? 0));
        break;
      default: // 'name'
        items.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    }
  }

  bool _isIngredientItem(Map<String, dynamic> item) {
    final category = (item['category'] ?? '').toString();
    final normalizedCategory = category.toLowerCase();
    final explicitFlag = item['isIngredient'] == true || item['isIngredient'] == 'true';
    return explicitFlag || normalizedCategory.contains('ingredient');
  }

  void _filterInventory() {
    List<Map<String, dynamic>> filtered = _inventory.where((item) {
      final name = (item['name'] ?? '').toString();
      final barcode = (item['barcode'] ?? '').toString();
      final sku = (item['sku'] ?? '').toString();
      final category = (item['category'] ?? 'All').toString();
      final quantity = item['quantity'] ?? 0;
      final minStock = item['minStock'] ?? 10;
      final isIngredient = _isIngredientItem(item);

      final searchQuery = _searchController.text;

      // Use enhanced search that checks name, barcode, and SKU with fuzzy matching
      final matchesSearch = searchQuery.isEmpty ||
          SearchUtils.matchesSearchQuery(
              name, barcode.isNotEmpty ? barcode : null, searchQuery) ||
          SearchUtils.matchesSearchQuery(sku, null, searchQuery);

      final matchesCategory = _selectedCategory == 'All'
          ? true
          : _selectedCategory == 'Ingredient'
              ? isIngredient
              : category == _selectedCategory;

      final matchesIngredientFilter = !widget.showIngredientsOnly || isIngredient;
      final matchesStockFilter = !_showLowStock || quantity <= minStock;

      return matchesSearch &&
          matchesCategory &&
          matchesIngredientFilter &&
          matchesStockFilter;
    }).toList();

    setState(() => _filteredInventory = filtered);
  }

  List<Map<String, dynamic>> get _inventoryForExport {
    final hasActiveFilters = _searchController.text.trim().isNotEmpty ||
        _selectedCategory != 'All' ||
        _showLowStock;
    return hasActiveFilters ? _filteredInventory : _inventory;
  }

  Future<void> _showExportOptions() async {
    final items = _inventoryForExport;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No inventory items available to export')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Export Inventory',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                  'Exports the inventory currently visible on this screen'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('CSV'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _exportInventory(asPdf: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _exportInventory(asPdf: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportInventory({required bool asPdf}) async {
    final items = _inventoryForExport;
    if (items.isEmpty) return;

    final businessName =
        context.read<BusinessProvider>().currentBusiness?.name ?? 'Manage Care';

    try {
      final result = asPdf
          ? await InventoryExportService.exportPdf(
              items: items,
              businessName: businessName,
              fileBaseName: 'Inventory',
            )
          : await InventoryExportService.exportCsv(
              items: items,
              businessName: businessName,
              fileBaseName: 'Inventory',
            );

      if (!mounted) return;
      final exportedCount = items.length;
      final format = asPdf ? 'PDF' : 'CSV';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported $exportedCount inventory item(s) as $format: ${result.fileName}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export inventory: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FilterSheet(
        selectedCategory: _selectedCategory,
        sortBy: _sortBy,
        showLowStock: _showLowStock,
        categories: _categories,
        onApply: (category, sort, lowStock) {
          setState(() {
            _selectedCategory = category;
            _sortBy = sort;
            _showLowStock = lowStock;
          });
          _sortInventory(_inventory);
          _filterInventory();
          Navigator.pop(context);
        },
      ),
    );
  }

  bool _isBakeryBusiness() {
    final businessType = context.read<BusinessProvider>().currentBusiness?.businessType?.toString().toLowerCase() ?? '';
    return businessType == 'bakery' || businessType == 'bakeryshop' || businessType == 'bakeshop';
  }

  Future<void> _showBakeryResupplyDialog(Map<String, dynamic> item) async {
    if (!_isBakeryBusiness()) return;

    final quantityController = TextEditingController(text: '1');
    final notesController = TextEditingController();
    String? selectedBakerId;
    String? selectedBakerName;

    final workersProvider = context.read<WorkersProvider>();
    final bakeryWorkers = workersProvider.workers.where((worker) {
      final role = (worker['role'] ?? worker['roles'] ?? '').toString().toLowerCase();
      return role.contains('baker') || role.contains('pastry');
    }).toList();

    final selected = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Issue to Baker'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Send stock from ${item['name'] ?? 'this item'} to production.'),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 12),
              if (bakeryWorkers.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedBakerId,
                  decoration: const InputDecoration(labelText: 'Baker'),
                  items: bakeryWorkers.map((worker) {
                    final name = (worker['name'] ?? worker['fullName'] ?? 'Unnamed').toString();
                    return DropdownMenuItem<String>(
                      value: (worker['id'] ?? '').toString(),
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedBakerId = value;
                    final worker = bakeryWorkers.firstWhere(
                      (entry) => (entry['id'] ?? '').toString() == value,
                      orElse: () => <String, dynamic>{},
                    );
                    selectedBakerName = (worker['name'] ?? worker['fullName'] ?? '').toString();
                  },
                )
              else
                const Text('Add bakery workers first to assign this resupply to a baker.'),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Record Resupply'),
          ),
        ],
      ),
    );

    if (selected != true) return;

    final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity must be greater than zero')));
      return;
    }

    final businessProvider = context.read<BusinessProvider>();
    final businessId = businessProvider.currentBusiness?.id ?? '';
    if (businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No business selected')));
      return;
    }

    try {
      final repo = InventoryRepositoryImpl(firestore: FirebaseFirestore.instance);
      await repo.recordBakeryResupply(
        businessId: businessId,
        inventoryId: (item['id'] ?? '').toString(),
        quantity: quantity,
        bakerId: selectedBakerId,
        bakerName: selectedBakerName,
        notes: notesController.text.trim(),
        performedById: context.read<AuthProvider>().currentUser?.id,
        performedByName: context.read<AuthProvider>().currentUser?.fullName ?? context.read<AuthProvider>().currentUser?.email,
      );
      await _loadInventory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resupply recorded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to record resupply: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showDistributorSaleDialog(Map<String, dynamic> item) async {
    final authProvider = context.read<AuthProvider>();
    final isOwner = authProvider.currentUser?.isOwner == true;
    if (!isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only owners can save distributor discounts')));
      return;
    }

    final discountController = TextEditingController(
      text: ((item['distributorDiscountPercent'] as num?)?.toString() ?? '0'),
    );
    final businessProvider = context.read<BusinessProvider>();
    final businessId = businessProvider.currentBusiness?.id ?? '';
    if (businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No business selected')));
      return;
    }

    final productId = (item['id'] ?? '').toString();
    if (productId.startsWith('pharmacy_')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preset discounts are only available for inventory products')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save Distributor Discount'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Set the default distributor discount for ${item['name'] ?? 'this item'}.'),
              const SizedBox(height: 12),
              TextField(
                controller: discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Discount %'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')), 
        ],
      ),
    );

    if (confirmed != true) return;

    final discount = double.tryParse(discountController.text.trim()) ?? 0;
    if (discount < 0 || discount > 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Discount must be between 0 and 100')));
      return;
    }

    try {
      final repository = InventoryRepositoryImpl(firestore: FirebaseFirestore.instance);
      await repository.updateInventory(productId, {
        'businessId': businessId,
        'distributorDiscountPercent': discount,
        'discountPercent': discount,
      });
      await _loadInventory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved ${discount.toStringAsFixed(0)}% distributor discount')));
      context.read<RetailProvider>().loadProducts(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save distributor discount: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '') as String;
    final name = (item['name'] ?? 'Unnamed') as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product'),
        content: Text(
            'Are you sure you want to delete "${name}"? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final businessProvider = context.read<BusinessProvider>();
    final businessId = businessProvider.currentBusiness?.id ?? '';

    if (businessId.isEmpty && !id.startsWith('pharmacy_')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to delete: no business context')));
      return;
    }

    // Show progress dialog while deleting
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: const [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
            SizedBox(width: 16),
            Expanded(child: Text('Deleting...')),
          ],
        ),
      ),
    );

    try {
      if (id.startsWith('pharmacy_')) {
        final drugId = id.replaceFirst('pharmacy_', '');
        final pharmProv = Provider.of<PharmacyProvider>(context, listen: false);

        // Keep a backup for undo
        Drug? backup;
        try {
          backup = pharmProv.drugs.firstWhere((d) => d.id == drugId);
        } catch (_) {
          backup = null;
        }

        await pharmProv.removeDrug(drugId,
            persist: true, businessId: businessId);

        // Close progress dialog
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $name'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                // show small progress while undoing
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    content: Row(
                      children: const [
                        SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator()),
                        SizedBox(width: 16),
                        Expanded(child: Text('Restoring...')),
                      ],
                    ),
                  ),
                );

                try {
                  if (backup != null) {
                    pharmProv.addDrug(backup,
                        persist: true, businessId: businessId);
                    await _loadInventory();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Restore failed: $e'),
                      backgroundColor: Colors.red));
                } finally {
                  Navigator.pop(context);
                }
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        // Firestore backed item
        final repo = _repository;
        final original = Map<String, dynamic>.from(item);
        // ensure businessId and id are present for restore
        original['businessId'] = businessId;
        original['id'] = id;

        // Log deletion entry before removing the document
        try {
          final authProv = context.read<AuthProvider>();
          final user = authProv.currentUser;
          await repo.addHistoryEntry(businessId, id, {
            'action': 'deleted',
            'performedBy': user?.id ?? '',
            'performedByName': user?.fullName ?? user?.email ?? '',
            'details': {'name': name, 'sku': (item['sku'] ?? '')},
          });
        } catch (e) {
          // non-fatal
          print('Failed to write deletion history: $e');
        }

        await repo.deleteInventoryForBusiness(businessId, id);

        // Close progress dialog
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $name'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                // show small progress while restoring
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    content: Row(
                      children: const [
                        SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator()),
                        SizedBox(width: 16),
                        Expanded(child: Text('Restoring...')),
                      ],
                    ),
                  ),
                );

                try {
                  await repo.syncInventoryToFirestore(original);
                  await _loadInventory();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Restore failed: $e'),
                      backgroundColor: Colors.red));
                } finally {
                  Navigator.pop(context);
                }
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      await _loadInventory();
    } catch (e) {
      // Close progress dialog if still open
      try {
        Navigator.pop(context);
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.showIngredientsOnly ? 'Ingredients' : 'Inventory'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () async {
              final barcodeService = BarcodeService();
              try {
                final barcode = await barcodeService.scanBarcode(context);
                if (barcode != null && barcode.isNotEmpty) {
                  // Filter inventory by scanned barcode
                  _searchController.text = barcode;
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Scanned: $barcode'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Scan error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
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
          IconButton(
            icon: const Icon(Icons.warning_rounded),
            tooltip: 'Inventory Alerts',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const InventoryAlertsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Inventory',
            onPressed: _showExportOptions,
          ),
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'Distributor Sales',
            onPressed: () {
              Navigator.pushNamed(context, Routes.distributorSalesReport);
            },
          ),
          IconButton(
            icon: const Icon(Icons.move_to_inbox_outlined),
            tooltip: 'Assign all inventory to a store',
            onPressed: () async {
              // Migration helper: assign storeId to existing items
              final businessProvider = context.read<BusinessProvider>();
              if (businessProvider.currentBusiness == null) return;

              final retail =
                  Provider.of<RetailProvider>(context, listen: false);
              final stores = retail.stores;
              if (stores.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No stores configured')),
                );
                return;
              }

              final selected = await showDialog<String?>(
                  context: context,
                  builder: (context) {
                    String tmp = stores.first.id;
                    return AlertDialog(
                      title: const Text('Assign all inventory to store'),
                      content: DropdownButton<String>(
                        value: tmp,
                        items: stores
                            .map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) tmp = v;
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, null),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, tmp),
                          child: const Text('Assign'),
                        ),
                      ],
                    );
                  });

              if (selected == null || selected.isEmpty) return;

              final repo = InventoryRepositoryImpl(
                  firestore: FirebaseFirestore.instance);
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assigning...')));
                final count = await repo.assignAllInventoryToStore(
                    businessProvider.currentBusiness!.id, selected);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Assigned $count items to store')));
                await _loadInventory();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Migration failed: $e')));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: scheme.onPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle:
                        TextStyle(color: scheme.onPrimary.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.search, color: scheme.onPrimary),
                    suffixIcon: IconButton(
                      icon: Stack(
                        children: [
                          Icon(Icons.tune, color: scheme.onPrimary),
                          if (_selectedCategory != 'All' || _showLowStock)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: _showFilterSheet,
                    ),
                    filled: true,
                    fillColor: scheme.onPrimary.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Total Items',
                        value: '$_totalItems',
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _lowStockCount > 0
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const LowStockProductsScreen(),
                                  ),
                                );
                              }
                            : null,
                        child: _StatCard(
                          label: 'Low Stock',
                          value: '$_lowStockCount',
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          isClickable: _lowStockCount > 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Out of Stock',
                        value: '$_outOfStockCount',
                        icon: Icons.error_outline,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Category Chips
          Container(
            height: 50,
            color: theme.cardColor,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                      _filterInventory();
                    },
                    backgroundColor: theme.cardColor,
                    selectedColor: AppColors.primary.withOpacity(0.1),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : theme.textTheme.bodyMedium?.color ??
                              scheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                );
              },
            ),
          ),

          // Product List
          Expanded(
            child: Builder(builder: (context) {
              if (_isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: AppTextStyles.body1),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadInventory,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (_filteredInventory.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedLottie(
                        asset: 'assets/lottie/loop.json',
                        width: 180,
                        height: 180,
                        repeat: true,
                      ),
                      SizedBox(height: 12),
                      Text('No products found', style: AppTextStyles.subtitle1),
                      SizedBox(height: 6),
                      Text('Tap "Add Product" to create your first product',
                          style: AppTextStyles.body2Secondary),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _filteredInventory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _filteredInventory[index];
                  return _ProductCard(
                    id: item['id'] ?? '',
                    name: item['name'] ?? 'Unnamed',
                    sku: item['sku'] ?? 'N/A',
                    quantity: (item['quantity'] as num?)?.toInt() ?? 0,
                    minStock: (item['minStock'] as num?)?.toInt() ?? 10,
                    price: (item['price'] as num?)?.toDouble() ?? 0.0,
                    category: item['category'] ?? 'All',
                    emoji: item['emoji'] ?? '📦',
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        Routes.productDetails,
                        arguments: {'productId': item['id'] ?? ''},
                      );
                    },
                    onBakeryResupply: _isBakeryBusiness() ? () => _showBakeryResupplyDialog(item) : null,
                    onDistributorSale: () => _showDistributorSaleDialog(item),
                    onDelete: () => _confirmDelete(item),
                  );
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: Builder(builder: (context) {
        final isOwner = Provider.of<AuthProvider>(context).currentUser?.isOwner == true;
        if (isOwner) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: FloatingActionButton.extended(
                  onPressed: () => Navigator.pushNamed(context, Routes.procurement),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Procurement'),
                  backgroundColor: Colors.orange,
                ),
              ),
              FloatingActionButton.extended(
                onPressed: () {
                  Navigator.pushNamed(context, Routes.inventoryAdd);
                },
                icon: const Icon(Icons.add),
                label: Text(widget.showIngredientsOnly ? 'Add Ingredient' : 'Add Product'),
                backgroundColor: AppColors.primary,
              ),
            ],
          );
        }

        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, Routes.inventoryAdd);
          },
          icon: const Icon(Icons.add),
          label: Text(widget.showIngredientsOnly ? 'Add Ingredient' : 'Add Product'),
          backgroundColor: AppColors.primary,
        );
      }),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isClickable;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isClickable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.onPrimary.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: isClickable
            ? Border.all(color: scheme.onPrimary.withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Text(
                value,
                style: AppTextStyles.heading4.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: scheme.onPrimary.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String id;
  final String name;
  final String sku;
  final int quantity;
  final int minStock;
  final double price;
  final String category;
  final String emoji;
  final VoidCallback onTap;
  final VoidCallback? onBakeryResupply;
  final VoidCallback? onDistributorSale;
  final VoidCallback? onDelete;

  const _ProductCard({
    required this.id,
    required this.name,
    required this.sku,
    required this.quantity,
    required this.minStock,
    required this.price,
    required this.category,
    this.emoji = '📦',
    required this.onTap,
    this.onBakeryResupply,
    this.onDistributorSale,
    this.onDelete,
  });

  Color get _stockStatusColor {
    if (quantity == 0) return AppColors.error;
    if (quantity <= minStock) return AppColors.warning;
    return AppColors.success;
  }

  String get _stockStatus {
    if (quantity == 0) return 'Out of Stock';
    if (quantity <= minStock) return 'Low Stock';
    return 'In Stock';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Product Image/Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.subtitle1),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (category.toLowerCase() == 'pharmacy' ||
                            id.startsWith('pharmacy_'))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.pharmacy.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('💊',
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 6),
                                Text('Pharmacy',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.pharmacy)),
                              ],
                            ),
                          ),
                        if (category.toLowerCase() == 'pharmacy' ||
                            id.startsWith('pharmacy_'))
                          const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sku,
                            style: AppTextStyles.body2Secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _stockStatusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: _stockStatusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _stockStatus,
                                style: AppTextStyles.caption.copyWith(
                                  color: _stockStatusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Qty: $quantity',
                          style: AppTextStyles.body2,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Price and Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₦${price.toStringAsFixed(2)}',
                    style: AppTextStyles.heading5.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onBakeryResupply != null) ...[
                        IconButton(
                          icon: const Icon(Icons.bakery_dining_outlined, size: 20),
                          tooltip: 'Issue to baker',
                          onPressed: onBakeryResupply,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.orange.withOpacity(0.12),
                            foregroundColor: Colors.orange.shade800,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (onDistributorSale != null) ...[
                        IconButton(
                          icon: const Icon(Icons.local_shipping_outlined, size: 20),
                          tooltip: 'Record distributor sale',
                          onPressed: onDistributorSale,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.12),
                            foregroundColor: Colors.blue.shade800,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => Navigator.pushNamed(
                            context, Routes.inventoryEdit,
                            arguments: {'productId': id}),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: onDelete,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.error.withOpacity(0.1),
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final String selectedCategory;
  final String sortBy;
  final bool showLowStock;
  final List<String> categories;
  final Function(String, String, bool) onApply;

  const _FilterSheet({
    required this.selectedCategory,
    required this.sortBy,
    required this.showLowStock,
    required this.categories,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _category;
  late String _sort;
  late bool _lowStock;

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _sort = widget.sortBy;
    _lowStock = widget.showLowStock;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text('Filters', style: AppTextStyles.heading3),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _category = 'All';
                      _sort = 'name';
                      _lowStock = false;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category
                  const Text('Category', style: AppTextStyles.subtitle1),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.categories.map((category) {
                      final isSelected = category == _category;
                      return FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _category = category);
                        },
                        backgroundColor: theme.cardColor,
                        selectedColor: AppColors.primary.withOpacity(0.1),
                        checkmarkColor: AppColors.primary,
                        side: BorderSide(
                          color:
                              isSelected ? AppColors.primary : AppColors.border,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Sort By
                  const Text('Sort By', style: AppTextStyles.subtitle1),
                  const SizedBox(height: 12),
                  _RadioOption(
                    label: 'Name (A-Z)',
                    value: 'name',
                    groupValue: _sort,
                    onChanged: (val) => setState(() => _sort = val!),
                  ),
                  _RadioOption(
                    label: 'Price (Low to High)',
                    value: 'price_asc',
                    groupValue: _sort,
                    onChanged: (val) => setState(() => _sort = val!),
                  ),
                  _RadioOption(
                    label: 'Price (High to Low)',
                    value: 'price_desc',
                    groupValue: _sort,
                    onChanged: (val) => setState(() => _sort = val!),
                  ),
                  _RadioOption(
                    label: 'Stock Quantity',
                    value: 'quantity',
                    groupValue: _sort,
                    onChanged: (val) => setState(() => _sort = val!),
                  ),
                  const SizedBox(height: 24),

                  // Stock Status
                  const Text('Stock Status', style: AppTextStyles.subtitle1),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _lowStock,
                    onChanged: (val) => setState(() => _lowStock = val),
                    title: const Text('Show only low stock items'),
                    activeThumbColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),

          // Apply Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: CustomButton(
              text: 'Apply Filters',
              onPressed: () {
                widget.onApply(_category, _sort, _lowStock);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _RadioOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(label),
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }
}
