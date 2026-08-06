import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/email_service.dart';
import '../../../../core/utils/inventory_utils.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../providers/retail_provider.dart';

/// AddProductScreen - Product creation/editing for Retail business type ONLY
/// 
/// NOTE: Store requirement is unique to Retail operations. Other business types
/// (Restaurant, Salon, Hotel, Pharmacy, Gym, etc.) do NOT require store selection
/// as they operate under a single business location model.
/// 
/// Store requirement ensures retail products are properly inventory-tracked
/// across multiple physical store locations.
class AddProductScreen extends StatefulWidget {
  final Product? product; // null for add, non-null for edit

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  late TextEditingController _wholesalePriceController;
  late TextEditingController _distributorPriceController;
  late TextEditingController _stockController;
  late TextEditingController _categoryController;
  late TextEditingController _barcodeController;
  late TextEditingController _emojiController;
  late TextEditingController _saleUnitMultiplierController;
  late TextEditingController _batchLabelController;
  bool _isLoading = false;
  String? _imageUrl;
  Uint8List? _pendingImageBytes;
  String? _pendingImageFilename;
  String? _selectedStoreId;
  late String _selectedUnit;
  late String _selectedSaleUnit;
  DateTime? _selectedExpiryDate;

  static const Map<String, int> _bakeryShelfLifeDays = {
    'Bread': 2,
    'Pastry': 1,
    'Cake': 3,
    'Snacks': 1,
    'Ingredient': 90,
    'Packaging': 365,
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController =
        TextEditingController(text: widget.product?.price.toString() ?? '');
    _costController =
        TextEditingController(text: widget.product?.cost.toString() ?? '');
    _wholesalePriceController = TextEditingController(
      text: widget.product?.wholesalePrice?.toString() ?? '',
    );
    _distributorPriceController = TextEditingController(
      text: widget.product?.distributorPrice?.toString() ?? '',
    );
    _stockController =
        TextEditingController(text: widget.product?.stock.toString() ?? '');
    _categoryController =
        TextEditingController(text: widget.product?.category ?? '');
    _barcodeController =
        TextEditingController(text: widget.product?.barcode ?? '');
    _emojiController =
        TextEditingController(text: widget.product?.emoji ?? '📦');
    _imageUrl = widget.product?.imageUrl;
    _selectedUnit = canonicalizeInventoryUnit(widget.product?.unit);
    _selectedSaleUnit = canonicalizeInventoryUnit(
      widget.product?.resolvedSaleUnit,
    );
    _saleUnitMultiplierController = TextEditingController(
      text: widget.product?.resolvedSaleUnitMultiplier.toString() ?? '1',
    );
    _batchLabelController = TextEditingController(
      text: widget.product?.batchLabel ?? '',
    );
    _selectedExpiryDate = widget.product?.expiryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _wholesalePriceController.dispose();
    _distributorPriceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _barcodeController.dispose();
    _emojiController.dispose();
    _saleUnitMultiplierController.dispose();
    _batchLabelController.dispose();
    super.dispose();
  }

  bool _isBakeryBusiness(BuildContext context) {
    final type = context
            .read<BusinessProvider>()
            .currentBusiness
            ?.businessType
            .toLowerCase() ??
        '';
    final normalized = type.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized == 'bakery' ||
        normalized == 'bakeryshop' ||
        normalized == 'bakeshop';
  }

  bool _requiresStoreSelection(BuildContext context) {
    final type = context
            .read<BusinessProvider>()
            .currentBusiness
            ?.businessType
            .toLowerCase() ??
        '';
    final normalized = type.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized == 'retail' ||
        normalized == 'supermarket' ||
        normalized == 'grocery' ||
        normalized == 'minimart';
  }

  bool _supportsStoreSelection(BuildContext context) =>
      _requiresStoreSelection(context) || _isBakeryBusiness(context);

  void _applyBakeryCategory(String category) {
    final shelfLife = _bakeryShelfLifeDays[category] ?? 1;
    setState(() {
      _categoryController.text = category;
      _selectedUnit = category == 'Ingredient' ? 'kg' : 'pcs';
      _selectedSaleUnit = category == 'Ingredient' ? 'kg' : 'pcs';
      _selectedExpiryDate = DateTime.now().add(Duration(days: shelfLife));
      if (_batchLabelController.text.trim().isEmpty) {
        _batchLabelController.text =
            '$category ${DateTime.now().day}/${DateTime.now().month}';
      }
    });
  }

  Future<void> _selectBakeryExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() => _selectedExpiryDate = picked);
    }
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Select best-before date';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final xfile =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final filename = xfile.name;
      setState(() {
        _isLoading = true;
        _pendingImageBytes = bytes;
        _pendingImageFilename = filename;
      });
      final url = await EmailService().uploadBytes(bytes, filename);
      setState(() => _isLoading = false);
      if (url != null) {
        setState(() {
          _imageUrl = url;
          _pendingImageBytes = null;
          _pendingImageFilename = null;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Image uploaded')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Upload failed'),
            action:
                SnackBarAction(label: 'Retry', onPressed: _retryUploadImage)));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload error: $e'),
          action:
              SnackBarAction(label: 'Retry', onPressed: _retryUploadImage)));
    }
  }

  Future<void> _retryUploadImage() async {
    if (_pendingImageBytes == null || _pendingImageFilename == null) return;
    try {
      setState(() => _isLoading = true);
      final url = await EmailService().uploadBytes(_pendingImageBytes!, _pendingImageFilename!);
      setState(() => _isLoading = false);
      if (url != null) {
        setState(() {
          _imageUrl = url;
          _pendingImageBytes = null;
          _pendingImageFilename = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Image uploaded')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Upload failed'),
              action: SnackBarAction(
                  label: 'Retry', onPressed: _retryUploadImage)));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload error: $e'),
            action:
                SnackBarAction(label: 'Retry', onPressed: _retryUploadImage)));
      }
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _barcodeController.text = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode scanned: $result'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _saveProduct() async {
    final retailProvider =
        Provider.of<RetailProvider>(context, listen: false);
    final requiresStoreSelection = _requiresStoreSelection(context);

    // RETAIL-SPECIFIC: Store selection is required for retail inventory management
    // Store requirement ensures products are tracked across multiple physical locations
    // Other business types (Restaurant, Salon, etc.) do not require this
    if (requiresStoreSelection && retailProvider.stores.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No Store Available'),
          content: const Text(
            'You must create a store before adding products. Would you like to create one now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Navigate to store creation
                Navigator.of(context).pushNamed('/retail/stores');
              },
              child: const Text('Create Store'),
            ),
          ],
        ),
      );
      return;
    }
    
    // Validation
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.tr(context, 'name_required')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.tr(context, 'price_required')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_stockController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.tr(context, 'stock_required')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    // Validate store selection
    if (requiresStoreSelection &&
        (_selectedStoreId == null || _selectedStoreId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a store'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (widget.product == null) {
      final businessProvider =
          Provider.of<BusinessProvider>(context, listen: false);
      final currentCount = retailProvider.products.length;

      if (!businessProvider.isWithinLimit('products', currentCount)) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Product limit reached'),
            content: Text(
              businessProvider.getLimitReachedMessage('products'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final product = Product(
        id: widget.product?.id ?? '',
        name: _nameController.text,
        price: double.parse(_priceController.text),
        cost: double.tryParse(_costController.text) ?? 0.0,
        wholesalePrice: _wholesalePriceController.text.trim().isEmpty
            ? null
            : double.tryParse(_wholesalePriceController.text.trim()),
        distributorPrice: _distributorPriceController.text.trim().isEmpty
            ? null
            : double.tryParse(_distributorPriceController.text.trim()),
        stock: double.parse(_stockController.text),
        category: _categoryController.text.isEmpty
            ? 'Uncategorized'
            : _categoryController.text,
        barcode:
            _barcodeController.text.isEmpty ? null : _barcodeController.text,
        emoji: _emojiController.text.isEmpty ? '📦' : _emojiController.text,
        imageUrl: _imageUrl,
        unit: _selectedUnit,
        saleUnit: _selectedSaleUnit,
        saleUnitMultiplier:
            double.tryParse(_saleUnitMultiplierController.text.trim()) ?? 1.0,
        trackExpiry: _isBakeryBusiness(context) || _selectedExpiryDate != null,
        expiryDate: _selectedExpiryDate,
        batchLabel: _batchLabelController.text.trim(),
        shelfLifeDays: _bakeryShelfLifeDays[_categoryController.text.trim()],
      );

      if (widget.product == null) {
        // Add new product
        debugPrint('[AddProductScreen] Adding product, runtimeType=${product.runtimeType}');
        await retailProvider.addProduct(product, storeId: _selectedStoreId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.tr(context, 'product_added')),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        // Update existing product
        debugPrint('[AddProductScreen] Updating product, incomingWidgetProductType=${widget.product.runtimeType}, newProductType=${product.runtimeType}');
        await retailProvider.updateProduct(widget.product!.id, product, storeId: _selectedStoreId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.tr(context, 'product_updated')),
            backgroundColor: AppColors.success,
          ),
        );
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.tr(context, 'error')}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final isBakery = _isBakeryBusiness(context);
    final requiresStoreSelection = _requiresStoreSelection(context);
    final supportsStoreSelection = _supportsStoreSelection(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: Text(
          isBakery
              ? (isEditing ? 'Edit Bakery Item' : 'Add Bakery Item')
              : (isEditing ? 'Edit Product' : 'Add Product'),
        ),
        backgroundColor:
            isBakery ? const Color(0xFFD97706) : AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Name
            Text('Product Name',
                style: AppTextStyles.heading5.copyWith(
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter product name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            Text('Category',
                style: AppTextStyles.heading5.copyWith(
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 8),
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                hintText: isBakery ? 'Bread, Pastry, Cake...' : 'Category',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            if (isBakery) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bakeryShelfLifeDays.keys.map((category) {
                  final selected = _categoryController.text == category;
                  return ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    selectedColor: const Color(0xFFD97706).withOpacity(0.18),
                    onSelected: (_) => _applyBakeryCategory(category),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.secondary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bakery freshness setup',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _batchLabelController,
                      decoration: const InputDecoration(
                        labelText: 'Batch label',
                        hintText: 'Example: Morning Bread Batch',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _selectBakeryExpiryDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Best-before / expiry date',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_busy_rounded),
                            const SizedBox(width: 10),
                            Text(_dateLabel(_selectedExpiryDate)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'These fields power freshness tracking, batch review, and daily bakery stock control.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            if (supportsStoreSelection)
              Consumer<RetailProvider>(builder: (context, retail, _) {
                final stores = retail.stores;
                if (!requiresStoreSelection && stores.isEmpty) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/retail/stores');
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add store for this product'),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          requiresStoreSelection ? 'Store *' : 'Store (optional)',
                          style: AppTextStyles.label,
                        ),
                        if (stores.isEmpty)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/retail/stores');
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Create Store'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (stores.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiaryContainer,
                          border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'No stores available. Please create a store to add products.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedStoreId == null ? Theme.of(context).colorScheme.error : Colors.transparent,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStoreId,
                            isExpanded: true,
                            hint: const Text('Select a store'),
                            icon: const Icon(Icons.store),
                            items: stores.map((s) {
                              return DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              );
                            }).toList(),
                            onChanged: (String? val) {
                              if (val != null) setState(() => _selectedStoreId = val);
                            },
                          ),
                        ),
                      ),
                  ],
                );
              }),
            const SizedBox(height: 16),

            // Emoji
            Text('Product Emoji',
                style: AppTextStyles.heading5.copyWith(
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 8),
            TextField(
              controller: _emojiController,
              decoration: InputDecoration(
                hintText: 'e.g., 📱, 👕, 🎮 (single emoji)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              maxLength: 2,
            ),
            const SizedBox(height: 16),

            // Product Image
            Text('Product Image',
                style: AppTextStyles.heading5
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isLoading
                  ? null
                  : () async {
                      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.change_circle),
                                  title: const Text('Change image'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickAndUploadImage();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.delete_outline),
                                  title: const Text('Remove image'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    setState(() => _imageUrl = null);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.cancel),
                                  title: const Text('Cancel'),
                                  onTap: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        await _pickAndUploadImage();
                      }
                    },
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: (_pendingImageBytes != null)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _pendingImageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          gaplessPlayback: true,
                        ),
                      )
                    : (_imageUrl != null && _imageUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: _imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (_, __) =>
                                  const Center(child: CircularProgressIndicator()),
                              errorWidget: (_, __, ___) => Center(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                    const Icon(Icons.broken_image, size: 36),
                                    TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _pendingImageBytes = null;
                                            _pendingImageFilename = null;
                                          });
                                          _pickAndUploadImage();
                                        },
                                        child: const Text('Retry'))
                                  ])),
                            ),
                          )
                        : (_isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : const Center(child: Icon(Icons.image, size: 48))),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),

            // Price
            Text('Price (₦)',
                style: AppTextStyles.heading5.copyWith(
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter price',
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
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _costController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Cost (₦)',
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
              ],
            ),
            const SizedBox(height: 16),
            Text('Wholesale / Sale Unit',
                style: AppTextStyles.heading5.copyWith(
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 8),
            TextField(
              controller: _wholesalePriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Wholesale price (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _distributorPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Distributor price (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedSaleUnit,
              decoration: InputDecoration(
                labelText: 'Primary sale unit',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
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
                if (value == null) return;
                setState(() => _selectedSaleUnit = canonicalizeInventoryUnit(value));
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _saleUnitMultiplierController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'How many inventory units make 1 sale unit?',
                helperText:
                    'Example: carton sold from piece stock = 12, litre sold from mL stock = 1000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stock
            Text('Stock Quantity',
                style: AppTextStyles.heading5.copyWith(
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedUnit,
              decoration: InputDecoration(
                labelText: 'Inventory Unit',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: getInventoryUnitOptions(selectedUnit: _selectedUnit)
                  .map(
                    (unit) => DropdownMenuItem<String>(
                      value: unit,
                      child: Text(inventoryUnitLabel(unit)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                final previousUnit = _selectedUnit;
                final nextUnit = canonicalizeInventoryUnit(value);
                setState(() {
                  _selectedUnit = nextUnit;
                  if (_selectedSaleUnit == previousUnit ||
                      _selectedSaleUnit.trim().isEmpty) {
                    _selectedSaleUnit = nextUnit;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            // If this is a Gas business and the category contains Fuel, show a short tip about units/pricing
            Consumer<BusinessProvider>(builder: (context, bp, _) {
              final businessType = bp.currentBusiness?.businessType ?? '';
              final category = _categoryController.text.toLowerCase();
              final showGasTip = businessType.toLowerCase() == 'gas' && category.contains('fuel');
              if (!showGasTip) {
                return TextField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter stock quantity',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter stock quantity (e.g., litres for petrol/diesel, cylinders for cooking gas)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.yellow[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tip for Gas products', style: AppTextStyles.subtitle2.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('For fuel products set the unit appropriately (L for litres, cyl for cylinders). Price should be the selling price per unit (e.g., per litre or per cylinder). Stock quantity should represent available units (litres for petrol/diesel, number of cylinders for cooking gas).', style: AppTextStyles.body2),
                        const SizedBox(height: 6),
                        Text('Example: Petrol priced at ₦200 per L with 1000 L in stock; Cooking Gas may be priced per cylinder (e.g., ₦12,000) with quantity equal to available cylinders.', style: AppTextStyles.caption),
                      ],
                    ),
                  )
                ],
              );
            }),
            const SizedBox(height: 16),

            // Barcode (optional)
            Text('Barcode (Optional)',
                style: AppTextStyles.heading5.copyWith(
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      hintText: 'Enter or scan barcode',
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
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(isEditing ? 'Update Product' : 'Add Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late MobileScannerController controller;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: AppColors.primary,
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            final String? rawValue = barcode.rawValue;
            if (rawValue != null && rawValue.isNotEmpty) {
              Navigator.pop(context, rawValue);
              return;
            }
          }
        },
      ),
    );
  }
}

