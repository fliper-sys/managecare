import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../services/email_service.dart';
import '../../../data/repositories/customer_repository_impl.dart';
import '../../../providers/business_provider.dart';
import '../../../data/local/database_helper.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isVip = false;
  String _customerType = 'Individual';
  String? _profilePhotoUrl;

  final List<String> _customerTypes = ['Individual', 'Business'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final businessProvider = context.read<BusinessProvider>();
    if (businessProvider.currentBusiness == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a business first')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    final repository =
        CustomerRepositoryImpl(firestore: FirebaseFirestore.instance);

    final now = DateTime.now();

    // canonical customer data used for both remote and local stores
    final customerData = {
      'businessId': businessProvider.currentBusiness!.id,
      'name': _nameController.text.trim(),
      'fullName': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'notes': _notesController.text.trim(),
      'customerType': _customerType,
      'isVip': _isVip,
      'isActive': true,
      'profilePhotoUrl': _profilePhotoUrl,
      'createdAt': now,
      'updatedAt': now,
      'totalOrders': 0,
      'totalPurchases': 0,
    };

    try {
      // attempt Firestore save
      final result = await repository.addCustomer(Map.from(customerData));
      final String? remoteId = (result is Map) ? (result['id'] as String?) : null;

      // persist local copy (synced if remote succeeded)
      DatabaseHelper? db;
      try {
        db = DatabaseHelper.instance;
      } catch (_) {
        db = null;
      }

      final localId = remoteId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final localCustomer = {
        'id': localId,
        'businessId': businessProvider.currentBusiness!.id,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'loyaltyPoints': 0,
        'totalPurchases': 0,
        'isActive': 1,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'syncStatus': remoteId != null ? 'synced' : 'pending',
      };

      if (db != null) {
        try {
          await db.insert('customers', localCustomer);
        } catch (e) {
          print('[AddCustomer] Warning: failed to insert local customer: $e');
        }
      }

      // If remote save failed silently (no id), enqueue for sync when DB available
      if (remoteId == null && db != null) {
        try {
          await db.addToSyncQueue(
            entityType: 'customer',
            entityId: localId,
            action: 'create',
            data: {...customerData, 'id': localId},
          );
        } catch (e) {
          print('[AddCustomer] Warning: failed to add to sync queue: $e');
        }
      }

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer added successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      // On Firestore error (likely offline), save locally and enqueue for sync
      DatabaseHelper? db;
      try {
        db = DatabaseHelper.instance;
      } catch (_) {
        db = null;
      }

      final localId = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();
      final localCustomer = {
        'id': localId,
        'businessId': businessProvider.currentBusiness!.id,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'loyaltyPoints': 0,
        'totalPurchases': 0,
        'isActive': 1,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'syncStatus': 'pending',
      };

      if (db != null) {
        try {
          await db.insert('customers', localCustomer);
        } catch (e) {
          print('[AddCustomer] Warning: failed to insert local customer (error path): $e');
        }

        try {
          await db.addToSyncQueue(
            entityType: 'customer',
            entityId: localId,
            action: 'create',
            data: {...customerData, 'id': localId},
          );
        } catch (e) {
          print('[AddCustomer] Warning: failed to add to sync queue (error path): $e');
        }
      } else {
        print('[AddCustomer] Warning: local DB not available; customer saved only in memory');
      }

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer saved locally (offline). Will sync when online.'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Customer'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Photo Upload
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(_profilePhotoUrl!, fit: BoxFit.cover, width: 100, height: 100, errorBuilder: (_, __, ___) => Icon(Icons.person_outline, size: 50, color: AppColors.primary.withOpacity(0.5)),),
                            )
                          : Icon(
                              Icons.person_outline,
                              size: 50,
                              color: AppColors.primary.withOpacity(0.5),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () async {
                          try {
                            final picker = ImagePicker();
                            final xfile = await picker.pickImage(
                                source: ImageSource.gallery, imageQuality: 80);
                            if (xfile == null) return;
                            setState(() => _isLoading = true);
                            final bytes = await xfile.readAsBytes();
                            final filename = xfile.name;
                            final url = await EmailService().uploadBytes(bytes, filename);
                            setState(() => _isLoading = false);
                            if (url != null) {
                              setState(() => _profilePhotoUrl = url);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Profile photo uploaded')));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Upload failed')));
                            }
                          } catch (e) {
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Upload error')));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Customer Type
              Row(
                children: [
                  const Text('Customer Type', style: AppTextStyles.label),
                  const Spacer(),
                  ..._customerTypes.map((type) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(type),
                        selected: _customerType == type,
                        onSelected: (selected) {
                          setState(() => _customerType = type);
                        },
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        checkmarkColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _customerType == type
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 24),

              // Basic Information
              const Text('Basic Information', style: AppTextStyles.heading5),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _nameController,
                label: 'Full Name *',
                hint: 'Enter customer name',
                prefixIcon: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter customer name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'customer@example.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _phoneController,
                label: 'Phone Number *',
                hint: '+234 800 000 0000',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Address Information
              const Text('Address Information', style: AppTextStyles.heading5),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _addressController,
                label: 'Address',
                hint: 'Street address',
                prefixIcon: Icons.home_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _cityController,
                      label: 'City',
                      hint: 'City',
                      prefixIcon: Icons.location_city_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _stateController,
                      label: 'State',
                      hint: 'State',
                      prefixIcon: Icons.map_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Additional Information
              const Text('Additional Information',
                  style: AppTextStyles.heading5),
              const SizedBox(height: 16),

              // VIP Status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: AppColors.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('VIP Customer', style: AppTextStyles.subtitle1),
                          Text(
                            'Mark as VIP for special benefits',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isVip,
                      onChanged: (value) {
                        setState(() => _isVip = value);
                      },
                      activeThumbColor: AppColors.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _notesController,
                label: 'Notes',
                hint: 'Additional notes about customer',
                prefixIcon: Icons.note_outlined,
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Save Button
              _isLoading
                  ? const Center(child: CustomLoadingIndicator())
                  : Column(
                      children: [
                        CustomButton(
                          text: 'Add Customer',
                          onPressed: _handleSave,
                          icon: Icons.person_add,
                        ),
                        const SizedBox(height: 12),
                        CustomButton(
                          text: 'Add & Create Sale',
                          onPressed: () {
                            _handleSave();
                          },
                          type: ButtonType.outlined,
                          icon: Icons.shopping_cart,
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

