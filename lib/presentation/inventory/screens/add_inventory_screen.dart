import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../services/email_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/lottie_dialog.dart';
import '../../../data/repositories/inventory_repository_impl.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/retail_provider.dart';
import '../../../providers/auth_provider.dart';

class AddInventoryScreen extends StatefulWidget {
  const AddInventoryScreen({super.key});

  @override
  State<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends State<AddInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minStockController = TextEditingController();
  final _emojiController = TextEditingController(text: '📦');

  String _selectedCategory = 'Electronics';
  String _selectedUnit = 'pcs';
  DateTime? _expiryDate;
  bool _isLoading = false;
  bool _trackExpiry = false;

  String? _selectedStoreId;
  
  // Product name suggestions
  List<String> _productNameSuggestions = [];
  List<String> _filteredSuggestions = [];
  bool _showSuggestions = false;

  final List<String> _categories = [
    'Bread',
    'Pastry',
    'Cake',
    'Snacks',
    'Ingredient',
    'Packaging',
    'Electronics',
    'Clothing',
    'Food',
    'Beverages',
    'Accessories',
    'Fuel',
    'Cosmetics',
    'Device',
    'Other'
  ];

  final List<String> _units = [
    'pcs',
    'kg',
    'g',
    'bag',
    'tray',
    'box',
    'pack',
    'crate',
    'dozen',
    'set',
    'ltr',
    'ton'
  ];

  @override
  void initState() {
    super.initState();
    _loadProductNameSuggestions();
    _nameController.addListener(_onNameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isBakeryBusiness()) return;
      setState(() {
        _selectedCategory = 'Bread';
        _selectedUnit = 'pcs';
        _trackExpiry = true;
        _expiryDate = DateTime.now().add(const Duration(days: 2));
        _minStockController.text = '10';
      });
    });
  }

  bool _isBakeryBusiness() {
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

  int? _bakeryShelfLifeDays(String category) {
    switch (category) {
      case 'Bread':
        return 2;
      case 'Pastry':
      case 'Snacks':
        return 1;
      case 'Cake':
        return 3;
      case 'Ingredient':
        return 90;
      case 'Packaging':
        return 365;
    }
    return null;
  }

  void _applyBakeryCategoryDefaults(String category) {
    final shelfLifeDays = _bakeryShelfLifeDays(category) ?? 7;
    setState(() {
      _selectedCategory = category;
      _selectedUnit = category == 'Ingredient' ? 'kg' : 'pcs';
      _trackExpiry = category != 'Packaging';
      _expiryDate = DateTime.now().add(Duration(days: shelfLifeDays));
      if (_emojiController.text.trim().isEmpty ||
          _emojiController.text == '📦') {
        _emojiController.text = category == 'Ingredient'
            ? 'flour'
            : category == 'Cake'
                ? 'cake'
                : category == 'Pastry'
                    ? 'pie'
                    : 'bread';
      }
    });
  }

  Future<void> _loadProductNameSuggestions() async {
    try {
      final businessProvider = context.read<BusinessProvider>();
      final businessId = businessProvider.currentBusiness?.id;
      
      if (businessId == null) return;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .get();
      
      final names = snapshot.docs
          .map((doc) => (doc['name'] as String?)?.trim())
          .where((name) => name != null && name.isNotEmpty)
          .cast<String>()
          .toList();
      
      // Remove duplicates and sort
      final uniqueNames = names.toSet().toList();
      uniqueNames.sort();
      
      setState(() => _productNameSuggestions = uniqueNames);
    } catch (e) {
      print('[AddInventory] Error loading product suggestions: $e');
    }
  }

  void _onNameChanged() {
    final query = _nameController.text.trim().toLowerCase();
    
    if (query.isEmpty) {
      setState(() => _showSuggestions = false);
      return;
    }
    
    // Filter suggestions based on user input
    final filtered = _productNameSuggestions
        .where((name) => name.toLowerCase().contains(query))
        .toList();
    
    setState(() {
      _filteredSuggestions = filtered;
      _showSuggestions = filtered.isNotEmpty;
    });
  }

  void _selectSuggestion(String name) {
    setState(() {
      _nameController.text = name;
      _showSuggestions = false;
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _unitPriceController.dispose();
    _costPriceController.dispose();
    _quantityController.dispose();
    _minStockController.dispose();
    _emojiController.dispose();
    super.dispose();
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final businessProvider = context.read<BusinessProvider>();
      if (businessProvider.currentBusiness == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a business first')),
          );
        }
        return;
      }

      final repository =
          InventoryRepositoryImpl(firestore: FirebaseFirestore.instance);
      final isBakery = _isBakeryBusiness();
      final shelfLifeDays = isBakery ? _bakeryShelfLifeDays(_selectedCategory) : null;

      final inventoryData = {
        'businessId': businessProvider.currentBusiness!.id,
        if (_selectedStoreId != null && _selectedStoreId!.isNotEmpty) 'storeId': _selectedStoreId,
        'name': _nameController.text.trim(),
        'sku': _skuController.text.trim(),
        'barcode': _barcodeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'price': double.tryParse(_unitPriceController.text) ?? 0.0,
        'cost': double.tryParse(_costPriceController.text) ?? 0.0,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'unit': _selectedUnit,
        'minStock': int.tryParse(_minStockController.text) ?? 10,
        'trackExpiry': _trackExpiry,
        'expiryDate': _expiryDate, // store as DateTime (Firestore will save as Timestamp)
        if (isBakery) 'businessSection': 'bakery',
        if (shelfLifeDays != null) 'shelfLifeDays': shelfLifeDays,
        if (isBakery)
          'batchLabel':
              '${_selectedCategory}_${DateTime.now().millisecondsSinceEpoch}',
        'emoji': _emojiController.text.isEmpty ? '📦' : _emojiController.text,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final result = await repository.addInventory(inventoryData);

      // Add history log entry for creation
      try {
        final user = context.read<AuthProvider>().currentUser;
        final invId = (result is Map<String, dynamic>) ? (result['id'] as String?) : null;
        if (invId != null) {
          await repository.addHistoryEntry(
            businessProvider.currentBusiness!.id,
            invId,
            {
              'action': 'created',
              'performedBy': user?.id ?? 'system',
              'performedByName': user?.fullName ?? user?.email ?? 'system',
              'details': {
                'name': inventoryData['name'],
                'sku': inventoryData['sku'],
                'quantity': inventoryData['quantity'],
                'price': inventoryData['price'],
              },
            },
          );
        }
      } catch (e) {
        // Non-blocking: log but don't block UI
        print('[Inventory History] Failed to add creation log: $e');
      }

      setState(() => _isLoading = false);

      if (!mounted) return;

      final generatedSku = (result is Map<String, dynamic>) ? result['sku'] as String? : null;

      await showSuccessLottieDialog(
        context,
        title: 'Saved',
        message: generatedSku != null
            ? 'Product added successfully! SKU: $generatedSku'
            : 'Product added successfully!',
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final xfile =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (xfile == null) return;
      setState(() => _isLoading = true);
      final bytes = await xfile.readAsBytes();
      final filename = xfile.name;
      final url = await EmailService().uploadBytes(bytes, filename);
      setState(() => _isLoading = false);
      if (url != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Image uploaded')));
        // Store or use the uploaded URL as needed when saving product
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Upload failed')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Upload error')));
    }
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date != null) {
      setState(() => _expiryDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Product'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Image Upload
              GestureDetector(
                onTap: _pickAndUploadImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.cardShadow,
                    border: Border.all(
                      color: AppColors.border,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: AppColors.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add Product Image',
                        style: AppTextStyles.body1Secondary,
                      ),
                      const Text(
                        'Tap to upload',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Basic Information
              const Text('Basic Information', style: AppTextStyles.heading5),
              const SizedBox(height: 16),

              // Product Name with Suggestions
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomTextField(
                    controller: _nameController,
                    label: 'Product Name *',
                    hint: 'Enter product name',
                    prefixIcon: Icons.inventory_2_outlined,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter product name';
                      }
                      return null;
                    },
                  ),
                  // Suggestions Dropdown
                  if (_showSuggestions && _filteredSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _filteredSuggestions[index];
                            return ListTile(
                              dense: true,
                              title: Text(suggestion),
                              onTap: () => _selectSuggestion(suggestion),
                              hoverColor: AppColors.primary.withOpacity(0.1),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _skuController,
                      label: 'SKU (auto-generated if blank)',
                      hint: 'e.g. SKU-00001 (optional)',
                      prefixIcon: Icons.qr_code,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _barcodeController,
                      label: 'Barcode',
                      hint: 'Barcode',
                      prefixIcon: Icons.barcode_reader,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scanBarcode,
                        tooltip: 'Scan barcode',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category *', style: AppTextStyles.label),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            if (_isBakeryBusiness() &&
                                _bakeryShelfLifeDays(value) != null) {
                              _applyBakeryCategoryDefaults(value);
                            } else {
                              setState(() => _selectedCategory = value);
                            }
                          }
                        },
                      ),
                    ),
                  ),

                  if (_isBakeryBusiness()) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Text(
                        'Bakery mode: bread, pastry, cake, snacks, ingredients, and packaging automatically apply sensible units, shelf-life, expiry tracking, and batch metadata.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Optional store selector (for multi-store setups)
                  Consumer<RetailProvider>(builder: (context, retail, _) {
                    final stores = retail.stores;
                    if (stores.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text('Store', style: AppTextStyles.label),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedStoreId ?? stores.first.id,
                              isExpanded: true,
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

                ],
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Product description',
                prefixIcon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _emojiController,
                label: 'Product Emoji',
                hint: '📦',
                maxLength: 2,
                prefixIcon: Icons.emoji_emotions_outlined,
              ),

              const SizedBox(height: 24),

              // Pricing
              const Text('Pricing', style: AppTextStyles.heading5),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _unitPriceController,
                      label: 'Selling Price (₦) *',
                      hint: '0.00',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.attach_money,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _costPriceController,
                      label: 'Cost Price (₦)',
                      hint: '0.00',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.money_off,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Stock Information
              const Text('Stock Information', style: AppTextStyles.heading5),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: CustomTextField(
                      controller: _quantityController,
                      label: 'Quantity *',
                      hint: '0',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.inventory_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Unit *', style: AppTextStyles.label),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedUnit,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down),
                              items: _units.map((unit) {
                                return DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedUnit = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _minStockController,
                label: 'Minimum Stock Level',
                hint: '0',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.warning_amber_outlined,
              ),

              const SizedBox(height: 16),

              // Track Expiry
              SwitchListTile(
                value: _trackExpiry,
                onChanged: (value) {
                  setState(() => _trackExpiry = value);
                },
                title: const Text(
                  'Track Expiry Date',
                  style: AppTextStyles.body1,
                ),
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),

              if (_trackExpiry) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _selectExpiryDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Expiry Date',
                                  style: AppTextStyles.label),
                              Text(
                                _expiryDate != null
                                    ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                                    : 'Select expiry date',
                                style: AppTextStyles.body1,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Save Button
              _isLoading
                  ? const Center(child: CustomLoadingIndicator())
                  : CustomButton(
                      text: 'Add Product',
                      onPressed: _handleSave,
                      icon: Icons.check,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

