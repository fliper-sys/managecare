import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/inventory_model.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/repositories/inventory_repository_impl.dart';
import '../../../core/utils/inventory_utils.dart';

/// Input formatter to allow only decimal numbers (digits and single decimal point)
class _DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // Allow empty
    if (text.isEmpty) {
      return newValue;
    }
    
    // Check if it's a valid decimal number
    if (double.tryParse(text) == null) {
      // Allow single decimal point and digits
      final pattern = RegExp(r'^(\d+)?\.?\d*$');
      if (pattern.hasMatch(text)) {
        return newValue;
      }
      // Invalid input, reject
      return oldValue;
    }
    
    return newValue;
  }
}


class EditInventoryScreen extends StatefulWidget {
  final String inventoryId;

  const EditInventoryScreen({super.key, required this.inventoryId});

  @override
  State<EditInventoryScreen> createState() => _EditInventoryScreenState();
}

class _EditInventoryScreenState extends State<EditInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _categoryController;
  late TextEditingController _quantityController;
  late TextEditingController _reorderLevelController;
  late TextEditingController _unitPriceController;
  late TextEditingController _unitController;

  // Additional product info
  late TextEditingController _costController;
  late TextEditingController _minStockController;
  late TextEditingController _wholesalePriceController;
  late TextEditingController _saleUnitMultiplierController;
  late TextEditingController _barcodeController;
  late TextEditingController _imageUrlController;
  late TextEditingController _emojiController;
  late TextEditingController _batchLabelController;
  bool _trackExpiry = false;
  String? _selectedSaleUnit;

  DateTime? _expiryDate;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _originalData;

  /// Parse and safely extract numeric value from controller text
  double _parsePrice(String text) {
    if (text.isEmpty) return 0.0;
    final trimmed = text.trim();
    return double.tryParse(trimmed) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _skuController = TextEditingController();
    _categoryController = TextEditingController();
    _quantityController = TextEditingController();
    _reorderLevelController = TextEditingController();
    _unitPriceController = TextEditingController();
    _unitController = TextEditingController();
    _minStockController = TextEditingController();
    _costController = TextEditingController();
    _wholesalePriceController = TextEditingController();
    _saleUnitMultiplierController = TextEditingController();
    _barcodeController = TextEditingController();
    _imageUrlController = TextEditingController();
    _emojiController = TextEditingController();
    _batchLabelController = TextEditingController();
    _selectedSaleUnit = null;

    _loadInventory();
  }

  Future<void> _loadInventory() async {
    try {
      // Use selected business (supports owners with multiple businesses)
      final businessProvider = context.read<BusinessProvider>();
      final businessId = businessProvider.currentBusiness?.id;

      if (businessId == null || businessId.isEmpty) {
        setState(() {
          _error = 'Business not selected';
          _isLoading = false;
        });
        return;
      }

      final repository = InventoryRepositoryImpl(
        firestore: FirebaseFirestore.instance,
      );
      final inventory = await repository.getInventoryByIdForBusiness(
        businessId,
        widget.inventoryId,
      );

      if (inventory != null) {
        Map<String, dynamic> raw;
        if (inventory is InventoryModel) {
          raw = inventory.toJson();
        } else if (inventory is Map<String, dynamic>) {
          raw = Map<String, dynamic>.from(inventory);
        } else if (inventory is Map) {
          // try to coerce a generic Map
          raw = Map<String, dynamic>.from(Map<String, dynamic>.from(inventory.map((k, v) => MapEntry(k.toString(), v))));
          debugPrint('[EditInventoryScreen] Coerced inventory Map from ${inventory.runtimeType}');
        } else {
          debugPrint('[EditInventoryScreen] Unexpected inventory type: ${inventory.runtimeType}');
          raw = <String, dynamic>{};
        }

        final model = InventoryModel.fromJson(raw);

        // Save original raw data for change diffing
        _originalData = Map<String, dynamic>.from(raw);

        setState(() {
          _nameController.text = model.name;
          _skuController.text = model.sku;
          _categoryController.text = model.category;
          _quantityController.text = model.quantity.toString();
          // Prefer minStock if present, otherwise use reorderLevel
          final minStockVal = raw['minStock'] ?? raw['reorderLevel'] ?? 0;
          _reorderLevelController.text = (raw['reorderLevel'] ?? minStockVal).toString();
          _minStockController.text = (minStockVal).toString();

          final priceValue = raw['price'] ?? raw['sellingPrice'] ?? model.unitPrice;
          _unitPriceController.text = (priceValue is num ? priceValue.toDouble() : double.tryParse(priceValue.toString()) ?? 0).toStringAsFixed(2);

          _unitController.text = model.unit;
          _selectedSaleUnit = (raw['saleUnit'] as String?)?.isNotEmpty == true
              ? canonicalizeInventoryUnit(raw['saleUnit'] as String)
              : null;
          _saleUnitMultiplierController.text = (raw['saleUnitMultiplier'] ?? 1.0).toString();
          _expiryDate = model.expiryDate;

          // Additional optional fields
          final costValue = raw['cost'] ?? raw['costPrice'] ?? 0;
          _costController.text = (costValue is num ? costValue.toDouble() : double.tryParse(costValue.toString()) ?? 0).toStringAsFixed(2);
          final wholesaleValue = raw['wholesalePrice'] ?? 0;
          _wholesalePriceController.text = (wholesaleValue is num ? wholesaleValue.toDouble() : double.tryParse(wholesaleValue.toString()) ?? 0).toStringAsFixed(2);
          _barcodeController.text = (raw['barcode'] ?? '') as String;
          _imageUrlController.text = (raw['imageUrl'] ?? '') as String;
          _emojiController.text = (raw['emoji'] ?? '') as String;
          _batchLabelController.text = (raw['batchLabel'] ?? '') as String;
          _trackExpiry = (raw['trackExpiry'] == true);

          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Inventory item not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load inventory: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final businessProvider = context.read<BusinessProvider>();
      final businessId = businessProvider.currentBusiness?.id;

      if (businessId == null || businessId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business not selected')),
        );
        return;
      }

      final repository = InventoryRepositoryImpl(
        firestore: FirebaseFirestore.instance,
      );

      final updatedData = {
        'name': _nameController.text.trim(),
        'sku': _skuController.text.trim(),
        'category': _categoryController.text.trim(),
        'quantity': double.tryParse(_quantityController.text.trim()) ?? 0,
        'reorderLevel': double.tryParse(_reorderLevelController.text.trim()) ?? 0,
        // keep backward-compatible key 'minStock' for other parts of app
        'minStock': double.tryParse(_minStockController.text.trim()) ?? double.tryParse(_reorderLevelController.text.trim()) ?? 0,
        'price': _parsePrice(_unitPriceController.text),
        'unitPrice': _parsePrice(_unitPriceController.text),
        'sellingPrice': _parsePrice(_unitPriceController.text), // Keep legacy inventory view fields in sync
        'wholesalePrice': _parsePrice(_wholesalePriceController.text),
        'saleUnit': _selectedSaleUnit ?? _unitController.text.trim(),
        'saleUnitMultiplier': double.tryParse(_saleUnitMultiplierController.text.trim()) ?? 1.0,
        'cost': _parsePrice(_costController.text),
        'costPrice': _parsePrice(_costController.text), // Keep backward compatibility
        'unit': _unitController.text.trim(),
        'barcode': _barcodeController.text.trim(),
        'imageUrl': _imageUrlController.text.trim(),
        'emoji': _emojiController.text.trim(),
        'batchLabel': _batchLabelController.text.trim(),
        'trackExpiry': _trackExpiry,
        'expiryDate': _expiryDate, // store as DateTime
        'updatedAt': DateTime.now().toIso8601String(),
        'businessId': businessId,
      };

      await repository.updateInventory(widget.inventoryId, updatedData);

      // Create history entry recording changed fields and the actor
      try {
        final authProv = context.read<AuthProvider>();
        final user = authProv.currentUser;

        final Map<String, dynamic> changes = {};
        if (_originalData != null) {
          for (final key in updatedData.keys) {
            final oldVal = _originalData![key];
            final newVal = updatedData[key];
            if (oldVal == null && newVal != null) {
              changes[key] = {'from': oldVal, 'to': newVal};
            } else if (oldVal != null && oldVal.toString() != (newVal ?? '').toString()) {
              changes[key] = {'from': oldVal, 'to': newVal};
            }
          }
        }

        final entry = {
          'action': 'updated',
          'performedBy': user?.id ?? '',
          'performedByName': user?.fullName ?? user?.email ?? '',
          'changes': changes,
          'details': 'Updated fields: ${changes.keys.join(', ')}',
        };

        await repository.addHistoryEntry(businessId, widget.inventoryId, entry);

        // update cached original data to reflect the saved state
        _originalData = {...?_originalData, ...updatedData};
      } catch (e) {
        // non-fatal: log and continue
        print('Failed to write update history: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Pop back after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectExpiryDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (pickedDate != null) {
      setState(() {
        _expiryDate = pickedDate;
      });
    }
  }

  Future<void> _scanBarcode() async {
    try {
      final navigator = Navigator.of(context);
      
      final result = await navigator.push<String>(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Scan Barcode'),
              backgroundColor: AppColors.primary,
            ),
            body: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final barcode = barcodes.first.rawValue;
                  if (barcode != null) {
                    navigator.pop(barcode);
                  }
                }
              },
            ),
          ),
        ),
      );

      if (result != null && result.isNotEmpty) {
        setState(() {
          _barcodeController.text = result;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Barcode scanned: $result'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode scan failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _reorderLevelController.dispose();
    _unitPriceController.dispose();
    _unitController.dispose();

    _costController.dispose();
    _wholesalePriceController.dispose();
    _saleUnitMultiplierController.dispose();
    _minStockController.dispose();
    _barcodeController.dispose();
    _imageUrlController.dispose();
    _emojiController.dispose();
    _batchLabelController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Inventory'),
          elevation: 0,
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Inventory'),
          elevation: 0,
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 24),
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
      appBar: AppBar(
        title: const Text('Edit Inventory'),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Name
              const Text('Product Information', style: AppTextStyles.heading3),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Product Name *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Product name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // SKU
              TextFormField(
                controller: _skuController,
                decoration: InputDecoration(
                  labelText: 'SKU',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'e.g., SKU-001',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'SKU is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'e.g., Electronics, Food',
                ),
              ),
              const SizedBox(height: 16),

              // Unit
              DropdownButtonFormField<String>(
                value: _unitController.text.isEmpty ? null : _unitController.text,
                decoration: InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Select unit',
                ),
                items: getInventoryUnitOptions(selectedUnit: _unitController.text)
                    .map(
                      (unit) => DropdownMenuItem<String>(
                        value: unit,
                        child: Text(inventoryUnitLabel(unit)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _unitController.text = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // Inventory Details
              const Text('Inventory Details', style: AppTextStyles.heading3),
              const SizedBox(height: 16),

              // Quantity
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Quantity is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Reorder Level
              TextFormField(
                controller: _reorderLevelController,
                decoration: InputDecoration(
                  labelText: 'Reorder Level',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Minimum quantity before reorder',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Unit Price / Selling Price
              TextFormField(
                controller: _unitPriceController,
                decoration: InputDecoration(
                  labelText: 'Selling Price (₦) *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Enter selling price',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                inputFormatters: [
                  // Allow digits and decimal point only
                  _DecimalInputFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selling price is required';
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed < 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Wholesale Price
              TextFormField(
                controller: _wholesalePriceController,
                decoration: InputDecoration(
                  labelText: 'Wholesale Price (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Enter wholesale price if applicable',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                inputFormatters: [
                  _DecimalInputFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed < 0) {
                    return 'Please enter a valid positive number or leave empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Sale Unit and Multiplier
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSaleUnit,
                      decoration: InputDecoration(
                        labelText: 'Sale Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: getInventoryUnitOptions(selectedUnit: _selectedSaleUnit)
                          .map(
                            (unit) => DropdownMenuItem<String>(
                              value: unit,
                              child: Text(inventoryUnitLabel(unit)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedSaleUnit = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _saleUnitMultiplierController,
                      decoration: InputDecoration(
                        labelText: 'Sale Unit Multiplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'e.g. 12',
                        helperText: 'How many inventory units make one sale unit',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      inputFormatters: [_DecimalInputFormatter()],
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid multiplier';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Additional Product Info
              const Text('Pricing & Metadata', style: AppTextStyles.heading3),
              const SizedBox(height: 16),

              // Cost
              TextFormField(
                controller: _costController,
                decoration: InputDecoration(
                  labelText: 'Cost Price (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Enter cost amount',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                inputFormatters: [
                  // Allow digits and decimal point only
                  _DecimalInputFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return null; // optional field
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed < 0) {
                    return 'Please enter a valid positive number or leave empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Min Stock
              TextFormField(
                controller: _minStockController,
                decoration: InputDecoration(
                  labelText: 'Minimum Stock (minStock)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Threshold used to detect low stock',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Barcode
              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Barcode',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _scanBarcode,
                    tooltip: 'Scan barcode',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Image URL
              TextFormField(
                controller: _imageUrlController,
                decoration: InputDecoration(
                  labelText: 'Image URL',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Batch Label
              TextFormField(
                controller: _batchLabelController,
                decoration: InputDecoration(
                  labelText: 'Batch Label / Code (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'e.g., Batch-001, Lot-A',
                ),
              ),
              const SizedBox(height: 16),

              // Emoji
              TextFormField(
                controller: _emojiController,
                decoration: InputDecoration(
                  labelText: 'Emoji (icon)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                value: _trackExpiry,
                onChanged: (val) => setState(() => _trackExpiry = val),
                title: const Text('Track Expiry Date'),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 24),

              // Expiry Date Section
              const Text('Expiry Information', style: AppTextStyles.heading3),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _selectExpiryDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _expiryDate == null
                            ? 'Select Expiry Date (Optional)'
                            : 'Expiry: ${DateFormat('MMM dd, yyyy').format(_expiryDate!)}',
                        style: TextStyle(
                          color:
                              _expiryDate == null ? Colors.grey : Colors.black,
                        ),
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              if (_expiryDate != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _expiryDate = null;
                    });
                  },
                  child: const Text('Clear Expiry Date'),
                ),
              ],
              const SizedBox(height: 32),

              // Save and Cancel Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Activity / History Log
              const Text('Activity Log', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Builder(builder: (context) {
                  final businessProvider = context.read<BusinessProvider>();
                  final businessId = businessProvider.currentBusiness?.id ?? '';
                  final repo = InventoryRepositoryImpl(firestore: FirebaseFirestore.instance);

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: repo.streamInventoryHistory(businessId, widget.inventoryId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return const Center(child: Text('No activity recorded yet'));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 8),
                        itemBuilder: (context, index) {
                          final e = items[index];
                          final createdAt = e['createdAt'] != null ? DateTime.tryParse(e['createdAt']) : null;
                          final action = (e['action'] ?? 'action').toString();
                          final actor = (e['performedByName'] ?? e['performedBy'] ?? 'Unknown').toString();

                          return ListTile(
                            dense: true,
                            title: Text('$action by $actor'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (createdAt != null) Text(DateFormat('MMM dd, yyyy HH:mm').format(createdAt)),
                                const SizedBox(height: 4),
                                if (e['details'] != null) Text(e['details'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                                if (e['changes'] != null) Text('Changes: ${e['changes'].toString()}', maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                            leading: const Icon(Icons.history, size: 20),
                          );
                        },
                      );
                    },
                  );
                }),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

