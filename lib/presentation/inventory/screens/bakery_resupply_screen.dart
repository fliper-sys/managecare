import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/constants/routes.dart';
import '../../../data/repositories/inventory_repository_impl.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/workers_provider.dart';

class BakeryResupplyScreen extends StatefulWidget {
  const BakeryResupplyScreen({
    super.key,
    this.initialIngredientId,
  });

  final String? initialIngredientId;

  @override
  State<BakeryResupplyScreen> createState() => _BakeryResupplyScreenState();
}

class _BakeryResupplyScreenState extends State<BakeryResupplyScreen> {
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  final _expectedProductionController = TextEditingController(text: '0');
  final _actualProductionController = TextEditingController(text: '0');
  final Map<String, Map<String, dynamic>> _cartItems = {};
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _filteredIngredients = [];
  List<Map<String, dynamic>> _selectedBakerAssignments = [];
  bool _loadingSelectedBakerAssignments = false;
  String? _selectedBakerId;
  String? _selectedBakerName;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
    _searchController.addListener(_filterIngredients);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    _expectedProductionController.dispose();
    _actualProductionController.dispose();
    super.dispose();
  }

  bool _isIngredientItem(Map<String, dynamic> item) {
    final explicitFlag = item['isIngredient'] == true || item['isIngredient'] == 'true';
    final category = (item['category'] ?? '').toString().toLowerCase();
    return explicitFlag || category.contains('ingredient');
  }

  Future<void> _loadIngredients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final businessProvider = context.read<BusinessProvider>();
      final businessId = businessProvider.currentBusiness?.id ?? '';
      if (businessId.isEmpty) {
        setState(() {
          _error = 'No business selected';
          _isLoading = false;
        });
        return;
      }

      final authProvider = context.read<AuthProvider>();
      final userStoreId = authProvider.currentUser?.storeId;
      final repository = InventoryRepositoryImpl(firestore: FirebaseFirestore.instance);
      final inventoryData = await repository.getInventory(businessId, storeId: userStoreId);

      final ingredients = inventoryData
          .whereType<Map<String, dynamic>>()
          .where(_isIngredientItem)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      setState(() {
        _ingredients = ingredients;
        _filteredIngredients = ingredients;
        _isLoading = false;
      });

      if (widget.initialIngredientId != null && widget.initialIngredientId!.isNotEmpty) {
        final selectedItem = ingredients.firstWhere(
          (item) => (item['id'] ?? '').toString() == widget.initialIngredientId,
          orElse: () => {},
        );
        if (selectedItem.isNotEmpty) {
          _addToCart(selectedItem, 1.0);
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load ingredients: $e';
        _isLoading = false;
      });
    }
  }

  void _filterIngredients() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredIngredients = _ingredients.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        final sku = (item['sku'] ?? '').toString().toLowerCase();
        return query.isEmpty || name.contains(query) || sku.contains(query);
      }).toList();
    });
  }

  void _addToCart(Map<String, dynamic> item, double quantity) {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;
    final existing = _cartItems[id];
    final totalQty = (existing?['quantity'] as double? ?? 0.0) + quantity;
    _cartItems[id] = {
      'item': item,
      'quantity': totalQty,
    };
    setState(() {});
  }

  Future<void> _promptAddQuantity(Map<String, dynamic> item) async {
    final quantityController = TextEditingController(text: '1');
    final currentQuantity = ((item['quantity'] as num?) ?? (item['stock'] as num?) ?? 0).toDouble();
    final unit = (item['unit'] ?? '').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to Resupply Cart'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter quantity for ${item['name'] ?? 'item'} (${unit.isNotEmpty ? unit : 'pcs'})'),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Quantity',
                helperText: 'Available: ${currentQuantity.toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );

    if (confirmed != true) return;

    final quantity = double.tryParse(quantityController.text.trim()) ?? 0.0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid quantity')));
      return;
    }

    if (quantity > currentQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity exceeds available stock')));
      return;
    }

    _addToCart(item, quantity);
  }

  Future<void> _loadSelectedBakerAssignments(String? bakerId) async {
    if (bakerId == null || bakerId.isEmpty) {
      if (mounted) {
        setState(() {
          _selectedBakerAssignments = [];
          _loadingSelectedBakerAssignments = false;
        });
      }
      return;
    }

    final businessProvider = context.read<BusinessProvider>();
    final businessId = businessProvider.currentBusiness?.id ?? '';
    if (businessId.isEmpty) return;

    setState(() {
      _loadingSelectedBakerAssignments = true;
      _selectedBakerAssignments = [];
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('bakery_resupplies')
          .where('bakerId', isEqualTo: bakerId)
          .orderBy('createdAt', descending: true)
          .limit(6)
          .get();

      final history = snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();

      if (!mounted) return;
      setState(() {
        _selectedBakerAssignments = history.cast<Map<String, dynamic>>();
        _loadingSelectedBakerAssignments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSelectedBakerAssignments = false;
      });
    }
  }

  Future<void> _submitResupply() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add items to the resupply cart first')));
      return;
    }

    if (_selectedBakerId == null || _selectedBakerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a baker to assign the resupply')));
      return;
    }

    final businessProvider = context.read<BusinessProvider>();
    final businessId = businessProvider.currentBusiness?.id ?? '';
    if (businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No business selected')));
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final performedById = authProvider.currentUser?.id;
    final performedByName = authProvider.currentUser?.fullName ?? authProvider.currentUser?.email;
    final repository = InventoryRepositoryImpl(firestore: FirebaseFirestore.instance);
    final expectedProductionAmount = double.tryParse(_expectedProductionController.text.trim()) ?? 0.0;
    final actualProductionAmount = double.tryParse(_actualProductionController.text.trim()) ?? 0.0;
    setState(() => _isLoading = true);

    try {
      for (final entry in _cartItems.values) {
        final item = Map<String, dynamic>.from(entry['item'] as Map<String, dynamic>);
        final quantity = entry['quantity'] as double;
        await repository.recordBakeryResupply(
          businessId: businessId,
          inventoryId: (item['id'] ?? '').toString(),
          quantity: quantity,
          bakerId: _selectedBakerId,
          bakerName: _selectedBakerName,
          notes: _notesController.text.trim(),
          performedById: performedById,
          performedByName: performedByName,
          expectedProductionAmount: expectedProductionAmount,
          actualProductionAmount: actualProductionAmount,
          productionUnit: 'pcs',
          productionItemName: item['name']?.toString() ?? '',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bakery resupply recorded successfully')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to record resupply: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final workersProvider = context.watch<WorkersProvider>();
    final bakeryWorkers = workersProvider.workers.where((worker) {
      final role = (worker['role'] ?? worker['roles'] ?? '').toString().toLowerCase();
      return role.contains('baker') || role.contains('pastry');
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bakery Resupply'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search ingredients',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _filteredIngredients.isEmpty
                            ? const Center(child: Text('No ingredients found'))
                            : ListView.separated(
                                itemCount: _filteredIngredients.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _filteredIngredients[index];
                                  final available = ((item['quantity'] as num?) ?? (item['stock'] as num?) ?? 0).toDouble();
                                  final unit = (item['unit'] ?? 'pcs').toString();
                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item['name'] ?? 'Unnamed', style: AppTextStyles.subtitle1),
                                                const SizedBox(height: 6),
                                                Text('SKU: ${item['sku'] ?? 'N/A'}', style: AppTextStyles.body2Secondary),
                                                const SizedBox(height: 8),
                                                Text('Available: ${available.toStringAsFixed(2)} $unit', style: AppTextStyles.body2),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: available <= 0 ? null : () => _promptAddQuantity(item),
                                            child: const Text('Add'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Resupply Cart', style: AppTextStyles.heading4),
                              const SizedBox(height: 12),
                              if (_cartItems.isEmpty)
                                const Text('No items added yet')
                              else ...[
                                ..._cartItems.entries.map((entry) {
                                  final item = entry.value['item'] as Map<String, dynamic>;
                                  final quantity = entry.value['quantity'] as double;
                                  final unit = (item['unit'] ?? 'pcs').toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${item['name'] ?? 'Item'} • ${quantity.toStringAsFixed(2)} $unit',
                                            style: AppTextStyles.body1,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          onPressed: () {
                                            setState(() {
                                              _cartItems.remove(entry.key);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedBakerId,
                                decoration: const InputDecoration(labelText: 'Select baker'),
                                items: bakeryWorkers.map((worker) {
                                  final name = (worker['name'] ?? worker['fullName'] ?? 'Unnamed').toString();
                                  return DropdownMenuItem<String>(
                                    value: (worker['id'] ?? '').toString(),
                                    child: Text(name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBakerId = value;
                                    final selected = bakeryWorkers.firstWhere(
                                      (worker) => (worker['id'] ?? '').toString() == value,
                                      orElse: () => <String, dynamic>{},
                                    );
                                    _selectedBakerName = (selected['name'] ?? selected['fullName'] ?? '').toString();
                                  });
                                  _loadSelectedBakerAssignments(value);
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _expectedProductionController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Expected production amount',
                                        helperText: 'Planned output for this assignment',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _actualProductionController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Actual produced amount',
                                        helperText: 'Recorded output after production',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _notesController,
                                maxLines: 3,
                                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                              ),
                              const SizedBox(height: 12),
                              if (_selectedBakerId != null && _selectedBakerId!.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Previous assignments for ${_selectedBakerName ?? 'selected baker'}',
                                        style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 8),
                                      if (_loadingSelectedBakerAssignments)
                                        const Text('Loading previous assignments...')
                                      else if (_selectedBakerAssignments.isEmpty)
                                        const Text('No previous assignments found yet.')
                                      else ...[
                                        ..._selectedBakerAssignments.map((assignment) {
                                          final expected = ((assignment['expectedProductionAmount'] as num?) ?? 0).toDouble();
                                          final actual = ((assignment['actualProductionAmount'] as num?) ?? 0).toDouble();
                                          final createdAt = assignment['createdAt'];
                                          String dateLabel = 'Unknown';
                                          if (createdAt is Timestamp) {
                                            final date = createdAt.toDate();
                                            dateLabel = '${date.day}/${date.month}/${date.year}';
                                          } else if (createdAt is DateTime) {
                                            dateLabel = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
                                          }

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${assignment['productionItemName'] ?? assignment['inventoryName'] ?? 'Assignment'} • expected ${expected.toStringAsFixed(0)} / actual ${actual.toStringAsFixed(0)}',
                                                    style: AppTextStyles.caption,
                                                  ),
                                                ),
                                                Text(dateLabel, style: AppTextStyles.caption),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Complete Resupply'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                onPressed: _cartItems.isEmpty || bakeryWorkers.isEmpty ? null : _submitResupply,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (bakeryWorkers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Add bakery workers in the workers section before creating a resupply.',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
