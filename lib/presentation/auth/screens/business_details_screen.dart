import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/constants/routes.dart';
import '../../../core/constants/business_types.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../data/models/business_model.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../services/email_service.dart';
import '../../../services/subscription_service.dart';

class BusinessDetailsScreen extends StatefulWidget {
  final String businessType;

  const BusinessDetailsScreen({super.key, required this.businessType});

  @override
  State<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralEmailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  String? _logoUrl;
  bool _isUploadingLogo = false;
  File? _pendingLogoFile;

  bool _isLoading = false;
  String _selectedCurrency = 'NGN';
  double _taxRate = 0.0;

  // Size metrics for tier detection
  String _selectedPlanLevel = 'tier1';
  final _productCountController = TextEditingController(text: '0');
  final _staffCountController = TextEditingController(text: '0');
  final _monthlyIncomeController = TextEditingController(text: '0');
  String _computedTier = 'tier1';
  String _selectedBusinessClass = 'tier1';

  @override
  void initState() {
    super.initState();
    final products = int.tryParse(_productCountController.text) ?? 0;
    final staff = int.tryParse(_staffCountController.text) ?? 0;
    final income = double.tryParse(_monthlyIncomeController.text) ?? 0.0;
    _computedTier = SubscriptionService.detectTier(
      products: products,
      staff: staff,
      monthlyIncome: income,
      businessType: widget.businessType,
    );
    _selectedBusinessClass = SubscriptionService.detectBusinessClass(
      products: products,
      staff: staff,
      monthlyIncome: income,
      businessType: widget.businessType,
    );
    _selectedPlanLevel = _computedTier;
  }

  // Hospitality-specific config defaults
  bool _enableFrontDesk = true;
  bool _enableRestaurant = false;
  bool _enableBar = false;
  bool _enableKitchen = false;
  bool _enableLounge = false;
  bool _enableRoomService = false;
  bool _enableHallBooking = false;
  bool _enablePool = false;
  final _halfDayRateController = TextEditingController(text: '0.0');
  final _checkoutReminderHoursController = TextEditingController(text: '24');
  final _roomServiceFeeController = TextEditingController(text: '0.0');

  // Apartment-specific config defaults
  bool _allowBookings = true;
  final _defaultNightlyRateController = TextEditingController(text: '0.0');
  bool _requireDeposit = false;
  final _defaultDepositController = TextEditingController(text: '0.0');
  final _defaultUnitTypeController = TextEditingController();
  final _unitCountController = TextEditingController(text: '0');
  final _checkInController = TextEditingController(text: '14:00');
  final _checkOutController = TextEditingController(text: '11:00');

  final List<String> _currencies = ['NGN', 'USD', 'GBP', 'EUR'];

  @override
  void dispose() {
    _businessNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();

    // Apartment controllers
    _halfDayRateController.dispose();
    _checkoutReminderHoursController.dispose();
    _roomServiceFeeController.dispose();
    _defaultNightlyRateController.dispose();
    _defaultDepositController.dispose();
    _defaultUnitTypeController.dispose();
    _unitCountController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();

    // Size metric controllers
    _productCountController.dispose();
    _staffCountController.dispose();
    _monthlyIncomeController.dispose();
    _referralEmailController.dispose();

    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (xfile == null) return;
      setState(() {
        _isUploadingLogo = true;
        _pendingLogoFile = File(xfile.path);
      });

      final url = await EmailService().uploadFile(_pendingLogoFile!);

      setState(() => _isUploadingLogo = false);

      if (url != null) {
        setState(
            () => _logoUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}');
        _pendingLogoFile = null;
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Logo uploaded')));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Logo upload failed'),
              action:
                  SnackBarAction(label: 'Retry', onPressed: _retryUploadLogo),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logo upload error: $e'),
            action: SnackBarAction(label: 'Retry', onPressed: _retryUploadLogo),
          ),
        );
      }
    }
  }

  Future<void> _retryUploadLogo() async {
    if (_pendingLogoFile == null) return;
    try {
      setState(() => _isUploadingLogo = true);
      final url = await EmailService().uploadFile(_pendingLogoFile!);
      setState(() => _isUploadingLogo = false);
      if (url != null) {
        setState(
            () => _logoUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}');
        _pendingLogoFile = null;
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Logo uploaded')));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Logo upload failed'),
              action:
                  SnackBarAction(label: 'Retry', onPressed: _retryUploadLogo),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logo upload error: $e'),
            action: SnackBarAction(label: 'Retry', onPressed: _retryUploadLogo),
          ),
        );
      }
    }
  }

  bool _isFuelStationType(String businessType) {
    final type = businessType
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '');
    return type == 'gas' ||
        type == 'petroleum' ||
        type == 'petrolstation' ||
        type == 'petroleumstation' ||
        type == 'fillingstation';
  }

  Map<String, dynamic> _sizeMetrics() {
    return {
      'products': int.tryParse(_productCountController.text) ?? 0,
      'staff': int.tryParse(_staffCountController.text) ?? 0,
      'monthlyIncome': double.tryParse(_monthlyIncomeController.text) ?? 0.0,
    };
  }

  Map<String, dynamic> _buildIndustrySpecificSettings() {
    if (_isFuelStationType(widget.businessType)) {
      return {
        'fuelUnit': 'L',
        'enablePump': true,
        'receiptPrinting': true,
        'defaultFuelProductsConfigured': false,
        'stationType': widget.businessType == 'petroleum'
            ? 'petroleum_station'
            : 'gas_station',
        'sizeMetrics': _sizeMetrics(),
      };
    }

    if (widget.businessType == 'bakery') {
      return {
        'defaultBakeryProductsConfigured': false,
        'dailyProductionTracking': true,
        'expiryTracking': true,
        'retailPosEnabled': true,
        'sizeMetrics': _sizeMetrics(),
      };
    }

    if (widget.businessType == 'hotel') {
      return {
        'hospitalityServices': {
          'frontDesk': _enableFrontDesk,
          'restaurant': _enableRestaurant,
          'bar': _enableBar,
          'kitchen': _enableKitchen,
          'lounge': _enableLounge,
          'roomService': _enableRoomService,
          'hallBooking': _enableHallBooking,
          'pool': _enablePool,
        },
        'roomPricing': {
          'nightlyRate':
              double.tryParse(_defaultNightlyRateController.text) ?? 0.0,
          'halfDayRate':
              double.tryParse(_halfDayRateController.text) ?? 0.0,
          'roomServiceFee':
              double.tryParse(_roomServiceFeeController.text) ?? 0.0,
          'checkoutReminderHours':
              int.tryParse(_checkoutReminderHoursController.text) ?? 24,
        },
        'sizeMetrics': _sizeMetrics(),
      };
    }

    if (widget.businessType == 'apartment') {
      return {
        'allowBookings': _allowBookings,
        'defaultNightlyRate':
            double.tryParse(_defaultNightlyRateController.text) ?? 0.0,
        'requireDeposit': _requireDeposit,
        'defaultDeposit':
            double.tryParse(_defaultDepositController.text) ?? 0.0,
        'defaultUnitType': _defaultUnitTypeController.text.trim(),
        'defaultUnitCount': int.tryParse(_unitCountController.text) ?? 0,
        'checkInTime': _checkInController.text,
        'checkOutTime': _checkOutController.text,
        'sizeMetrics': _sizeMetrics(),
      };
    }

    return {'sizeMetrics': _sizeMetrics()};
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final businessProvider = context.read<BusinessProvider>();

    if (authProvider.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Recompute tier and business class from the latest form inputs
    final products = int.tryParse(_productCountController.text) ?? 0;
    final staff = int.tryParse(_staffCountController.text) ?? 0;
    final income = double.tryParse(_monthlyIncomeController.text) ?? 0.0;
    _computedTier = SubscriptionService.detectTier(
      products: products,
      staff: staff,
      monthlyIncome: income,
      businessType: widget.businessType,
    );
    _selectedBusinessClass = SubscriptionService.detectBusinessClass(
      products: products,
      staff: staff,
      monthlyIncome: income,
      businessType: widget.businessType,
    );

    final trialStartDate = DateTime.now();
    final trialEndDate = trialStartDate.add(const Duration(days: 7));

    final business = BusinessModel(
      id: _uuid.v4(),
      name: _businessNameController.text.trim(),
      businessType: widget.businessType,
      ownerId: authProvider.currentUser!.id,
      logoUrl: _logoUrl?.split('?').first,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      currency: _selectedCurrency,
      taxRate: _taxRate,
      
      // Set subscription tier (user-selected level constrained by class) and size metrics
      subscriptionTier: _selectedPlanLevel,
      businessClass: _selectedBusinessClass,
      referralEmail: _referralEmailController.text.trim().isEmpty ? null : _referralEmailController.text.trim(),
      subscriptionStartDate: trialStartDate,
      subscriptionEndDate: trialEndDate,
      isSubscriptionActive: true,
      createdAt: trialStartDate,
      isActive: true,
      totalWorkers: int.tryParse(_staffCountController.text) ?? 0,
      totalProducts: int.tryParse(_productCountController.text) ?? 0,
      industrySpecificSettings: _buildIndustrySpecificSettings(),
    );

    print('[BusinessDetails] Creating business ${business.id}');
    final success = await businessProvider.createBusiness(business);
    print('[BusinessDetails] createBusiness returned: $success');

    if (success && mounted) {
      // Update the user's profile with the new businessId and mark as owner
      try {
        print('[BusinessDetails] Updating user profile with new business id');
        await authProvider.updateProfile(businessId: business.id, isOwner: true);
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(business.id)
            .set({
          'subscriptionStatus': 'trial',
          'subscriptionReviewStatus': 'trial',
          'subscriptionPaymentRequired': false,
          'subscriptionTrialStartedAt': trialStartDate.toIso8601String(),
          'subscriptionTrialEndsAt': trialEndDate.toIso8601String(),
          'subscriptionTrialReminderSentFor': FieldValue.delete(),
          'updatedAt': trialStartDate.toIso8601String(),
        }, SetOptions(merge: true));
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authProvider.currentUser!.id)
            .set({
          'hasActiveSubscription': true,
          'subscriptionPaymentRequired': false,
          'subscriptionStatus': 'trial',
          'subscriptionReviewStatus': 'trial',
          'subscriptionPlan': _selectedPlanLevel,
          'subscriptionTier': _selectedPlanLevel,
          'businessClass': _selectedBusinessClass,
          'subscriptionStartDate': trialStartDate.toIso8601String(),
          'subscriptionEndDate': trialEndDate.toIso8601String(),
          'subscriptionTrialStartedAt': trialStartDate.toIso8601String(),
          'subscriptionTrialEndsAt': trialEndDate.toIso8601String(),
          'subscriptionTrialReminderSentFor': FieldValue.delete(),
          'updatedAt': trialStartDate.toIso8601String(),
        }, SetOptions(merge: true));
        print('[BusinessDetails] updateProfile finished');
      } catch (e) {
        print('[BusinessDetails] updateProfile failed: $e');
      }

      // Persist preferred business and cache it for quick switching
      try {
        print('[BusinessDetails] Setting current business and saving preference');
        await businessProvider.setCurrentBusinessAndSave(
            authProvider.currentUser!.id, business);
        print('[BusinessDetails] setCurrentBusinessAndSave finished');
      } catch (e) {
        // Non-fatal: log and continue
        print('[BusinessDetails] Failed to set preferred business: $e');
      }
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your 7-day free trial is active until ${trialEndDate.day}/${trialEndDate.month}/${trialEndDate.year}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      final route =
          BusinessProvider.industryRouteForType(widget.businessType) ??
              Routes.ownerDashboard;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            businessProvider.errorMessage ?? 'Failed to create business',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessTypeInfo = BusinessTypes.getById(widget.businessType);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Business Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    businessTypeInfo?.color ?? AppColors.primary,
                    (businessTypeInfo?.color ?? AppColors.primary)
                        .withOpacity(0.7),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isUploadingLogo
                        ? null
                        : () async {
                            if (_logoUrl != null && _logoUrl!.isNotEmpty) {
                              // show options to change or remove
                              showModalBottomSheet(
                                context: context,
                                builder: (_) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading:
                                            const Icon(Icons.change_circle),
                                        title: const Text('Change logo'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          await _pickAndUploadLogo();
                                        },
                                      ),
                                      ListTile(
                                        leading:
                                            const Icon(Icons.delete_outline),
                                        title: const Text('Remove logo'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          setState(() => _logoUrl = null);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text('Logo removed')),
                                          );
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
                              await _pickAndUploadLogo();
                            }
                          },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (businessTypeInfo?.color ?? AppColors.primary)
                                    .withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _isUploadingLogo
                          ? const Center(child: CircularProgressIndicator())
                          : (_logoUrl != null && _logoUrl!.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: _logoUrl!,
                                    fit: BoxFit.cover,
                                    width: 80,
                                    height: 80,
                                    placeholder: (c, u) => const Center(
                                        child: CircularProgressIndicator()),
                                    errorWidget: (c, u, e) => Icon(
                                      businessTypeInfo?.icon ?? Icons.business,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Icon(
                                  businessTypeInfo?.icon ?? Icons.business,
                                  size: 40,
                                  color: Colors.white,
                                ),
                    ),
                  ).animate().fadeIn(duration: 400.ms).scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                        duration: 500.ms,
                        curve: Curves.easeOut,
                      ),
                  const SizedBox(height: 16),
                  Text(
                    businessTypeInfo?.name ?? 'Business',
                    style: AppTextStyles.heading3.copyWith(
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about your business',
                    style: AppTextStyles.body1.copyWith(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w400,
                    ),
                  ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
                ],
              ),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Business Information Card
                    _SectionCard(
                      title: 'Business Information',
                      icon: Icons.business_outlined,
                      children: [
                        CustomTextField(
                          controller: _businessNameController,
                          label: 'Business Name *',
                          hint: 'Enter your business name',
                          prefixIcon: Icons.store_outlined,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter business name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _emailController,
                          label: 'Business Email',
                          hint: 'business@example.com',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _phoneController,
                          label: 'WhatsApp Phone no.*',
                          hint: '+234 800 000 0000',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_outlined,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter phone number';
                            }
                            return null;
                          },
                        ),                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _referralEmailController,
                          label: 'Referral (marketer) Email',
                          hint: 'Optional',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                        ),                      ],
                    ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 500.ms,
                          curve: Curves.easeOut,
                        ),

                    const SizedBox(height: 20),

                    // Location Card
                    _SectionCard(
                      title: 'Location',
                      icon: Icons.location_on_outlined,
                      children: [
                        CustomTextField(
                          controller: _addressController,
                          label: 'Address *',
                          hint: 'Street address',
                          prefixIcon: Icons.home_outlined,
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _cityController,
                                label: 'City *',
                                hint: 'City',
                                prefixIcon: Icons.location_city_outlined,
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
                                controller: _stateController,
                                label: 'State *',
                                hint: 'State',
                                prefixIcon: Icons.map_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 500.ms,
                          curve: Curves.easeOut,
                        ),

                    const SizedBox(height: 20),

                    // Settings Card
                    _SectionCard(
                      title: 'Business Settings',
                      icon: Icons.settings_outlined,
                      children: [
                        // Currency Selector
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Currency', style: AppTextStyles.label),
                            const SizedBox(height: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCurrency,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down),
                                  items: _currencies.map((currency) {
                                    return DropdownMenuItem(
                                      value: currency,
                                      child: Text(currency),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedCurrency = value);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Tax Rate
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tax Rate (%)',
                                style: AppTextStyles.label),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _taxRate,
                                    min: 0,
                                    max: 30,
                                    divisions: 60,
                                    label: '${_taxRate.toStringAsFixed(1)}%',
                                    activeColor: businessTypeInfo?.color ??
                                        AppColors.primary,
                                    onChanged: (value) {
                                      setState(() => _taxRate = value);
                                    },
                                  ),
                                ),
                                Container(
                                  width: 60,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (businessTypeInfo?.color ??
                                            AppColors.primary)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_taxRate.toStringAsFixed(1)}%',
                                    style: AppTextStyles.body1.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 500.ms,
                          curve: Curves.easeOut,
                        ),

                    // Apartment settings
                    if (widget.businessType == 'apartment') const SizedBox(height: 20),
                    if (widget.businessType == 'apartment') _SectionCard(
                      title: 'Apartment Settings',
                      icon: Icons.apartment_outlined,
                      children: [
                        SwitchListTile(
                          value: _allowBookings,
                          title: const Text('Enable bookings'),
                          onChanged: (v) => setState(() => _allowBookings = v),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _defaultNightlyRateController,
                          label: 'Default nightly rate',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: Icons.price_change_outlined,
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            final parsed = double.tryParse(v);
                            if (parsed == null) return 'Enter a valid number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          value: _requireDeposit,
                          title: const Text('Require security deposit'),
                          onChanged: (v) => setState(() => _requireDeposit = v),
                        ),
                        if (_requireDeposit) const SizedBox(height: 8),
                        if (_requireDeposit)
                          CustomTextField(
                            controller: _defaultDepositController,
                            label: 'Default deposit amount',
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            prefixIcon: Icons.attach_money,
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              if (double.tryParse(v) == null) return 'Enter a valid number';
                              return null;
                            },
                          ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _defaultUnitTypeController,
                          label: 'Default unit type',
                          hint: 'e.g., 1BR, Studio, 2BR',
                          prefixIcon: Icons.category_outlined,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _unitCountController,
                          label: 'Default unit count (optional)',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.format_list_numbered,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _checkInController,
                                label: 'Check-in time',
                                hint: 'e.g., 14:00',
                                prefixIcon: Icons.login,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: _checkOutController,
                                label: 'Check-out time',
                                hint: 'e.g., 11:00',
                                prefixIcon: Icons.logout,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ).animate().fadeIn(delay: 450.ms, duration: 500.ms).slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 500.ms,
                          curve: Curves.easeOut,
                        ),

                    if (widget.businessType == 'hotel') const SizedBox(height: 20),
                    if (widget.businessType == 'hotel') _SectionCard(
                      title: 'Hospitality Services',
                      icon: Icons.room_service_outlined,
                      children: [
                        SwitchListTile(
                          value: _enableFrontDesk,
                          title: const Text('Front desk'),
                          subtitle: const Text('Enable room check-in and front desk workflows'),
                          onChanged: (v) => setState(() => _enableFrontDesk = v),
                        ),
                        SwitchListTile(
                          value: _enableRestaurant,
                          title: const Text('Restaurant'),
                          subtitle: const Text('Enable restaurant and table ordering'),
                          onChanged: (v) => setState(() => _enableRestaurant = v),
                        ),
                        SwitchListTile(
                          value: _enableBar,
                          title: const Text('Bar / Lounge'),
                          subtitle: const Text('Enable bar sales and tab management'),
                          onChanged: (v) => setState(() => _enableBar = v),
                        ),
                        SwitchListTile(
                          value: _enableKitchen,
                          title: const Text('Kitchen'),
                          subtitle: const Text('Enable kitchen order preparation and menu integration'),
                          onChanged: (v) => setState(() => _enableKitchen = v),
                        ),
                        SwitchListTile(
                          value: _enableLounge,
                          title: const Text('Lounge'),
                          subtitle: const Text('Enable lounge and hospitality service areas'),
                          onChanged: (v) => setState(() => _enableLounge = v),
                        ),
                        SwitchListTile(
                          value: _enableRoomService,
                          title: const Text('Room service'),
                          subtitle: const Text('Keep food and bar orders attached to room bills'),
                          onChanged: (v) => setState(() => _enableRoomService = v),
                        ),
                        SwitchListTile(
                          value: _enableHallBooking,
                          title: const Text('Hall booking'),
                          subtitle: const Text('Enable event hall reservations and billing'),
                          onChanged: (v) => setState(() => _enableHallBooking = v),
                        ),
                        SwitchListTile(
                          value: _enablePool,
                          title: const Text('Pool booking'),
                          subtitle: const Text('Enable pool bookings and service tracking'),
                          onChanged: (v) => setState(() => _enablePool = v),
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _defaultNightlyRateController,
                          label: 'Default nightly rate',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: Icons.price_change_outlined,
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            final parsed = double.tryParse(v);
                            if (parsed == null) return 'Enter a valid number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _halfDayRateController,
                          label: 'Half-day rate',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: Icons.av_timer,
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (double.tryParse(v) == null) return 'Enter a valid number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _roomServiceFeeController,
                          label: 'Room service fee',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: Icons.room_service,
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (double.tryParse(v) == null) return 'Enter a valid number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _checkoutReminderHoursController,
                          label: 'Checkout reminder (hours)',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.notifications_active,
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (int.tryParse(v) == null) return 'Enter a valid integer';
                            return null;
                          },
                        ),
                      ],
                    ).animate().fadeIn(delay: 450.ms, duration: 500.ms).slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 500.ms,
                          curve: Curves.easeOut,
                        ),

                    const SizedBox(height: 16),

                    // Business Size & Tier Detection
                    _SectionCard(
                      title: 'Business Size & Tier',
                      icon: Icons.assessment_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _productCountController,
                                label: 'Number of Products',
                                hint: 'Total products in inventory',
                                keyboardType: TextInputType.number,
                                prefixIcon: Icons.inventory_2_outlined,
                                onChanged: (v) {
                                  final products = int.tryParse(v) ?? 0;
                                  final staff = int.tryParse(_staffCountController.text) ?? 0;
                                  final income = double.tryParse(_monthlyIncomeController.text) ?? 0.0;
                                  final detectedClass = SubscriptionService.detectBusinessClass(
                                    products: products,
                                    staff: staff,
                                    monthlyIncome: income,
                                    businessType: widget.businessType,
                                  );
                                  setState(() {
                                    _computedTier = SubscriptionService.detectTier(
                                      products: products,
                                      staff: staff,
                                      monthlyIncome: income,
                                      businessType: widget.businessType,
                                    );
                                    _selectedBusinessClass = detectedClass;
                                    _selectedPlanLevel = detectedClass;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: _staffCountController,
                                label: 'Number of Staff',
                                hint: 'Total staff/workers',
                                keyboardType: TextInputType.number,
                                prefixIcon: Icons.people_outline,
                                onChanged: (v) {
                                  final products = int.tryParse(_productCountController.text) ?? 0;
                                  final staff = int.tryParse(v) ?? 0;
                                  final income = double.tryParse(_monthlyIncomeController.text) ?? 0.0;
                                  final detectedClass = SubscriptionService.detectBusinessClass(
                                    products: products,
                                    staff: staff,
                                    monthlyIncome: income,
                                    businessType: widget.businessType,
                                  );
                                  setState(() {
                                    _computedTier = SubscriptionService.detectTier(
                                      products: products,
                                      staff: staff,
                                      monthlyIncome: income,
                                      businessType: widget.businessType,
                                    );
                                    _selectedBusinessClass = detectedClass;
                                    _selectedPlanLevel = detectedClass;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _monthlyIncomeController,
                          label: 'Monthly Income (NGN)',
                          hint: 'Estimated monthly revenue',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: Icons.monetization_on_outlined,
                          onChanged: (v) {
                            final products = int.tryParse(_productCountController.text) ?? 0;
                            final staff = int.tryParse(_staffCountController.text) ?? 0;
                            final income = double.tryParse(v) ?? 0.0;
                            final detectedClass = SubscriptionService.detectBusinessClass(
                              products: products,
                              staff: staff,
                              monthlyIncome: income,
                              businessType: widget.businessType,
                            );
                            setState(() {
                              _computedTier = SubscriptionService.detectTier(
                                products: products,
                                staff: staff,
                                monthlyIncome: income,
                                businessType: widget.businessType,
                              );
                              _selectedBusinessClass = detectedClass;
                              _selectedPlanLevel = detectedClass;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: _computedTier == 'tier3'
                                    ? Colors.orange.withOpacity(0.1)
                                    : _computedTier == 'tier2'
                                        ? const Color(0xFF8B5CF6).withOpacity(0.08)
                                        : const Color(0xFF3B82F6).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Detected Tier: ${_computedTier.toUpperCase()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _computedTier == 'tier3'
                                      ? Colors.orange
                                      : _computedTier == 'tier2'
                                          ? const Color(0xFF8B5CF6)
                                          : const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text('This tier is detected from the number of products, staff and monthly income. You can change plan later.')),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Business class (auto-assigned, read-only)
                        Row(
                          children: [
                            Expanded(child: Text('Business Class', style: AppTextStyles.body2)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.withOpacity(0.12)),
                              ),
                              child: Text(_selectedBusinessClass.toUpperCase(), style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Plan level selector (users can choose the current or a higher tier)
                        DropdownButtonFormField<String>(
                          value: _selectedPlanLevel,
                          decoration: const InputDecoration(
                            labelText: 'Plan Level',
                            border: OutlineInputBorder(),
                          ),
                          items: SubscriptionService.getTierOptionsForBusinessType(widget.businessType)
                              .where((tier) =>
                                  SubscriptionService.getTierRank(tier) >=
                                  SubscriptionService.getTierRank(_selectedBusinessClass))
                              .map((tier) => DropdownMenuItem(
                                    value: tier,
                                    child: Text(tier.toUpperCase()),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedPlanLevel = v ?? _selectedBusinessClass),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    _isLoading
                        ? const Center(child: CustomLoadingIndicator())
                        : CustomButton(
                            text: 'Create Business',
                            onPressed: _handleSubmit,
                            icon: Icons.check_circle_outline,
                            backgroundColor:
                                businessTypeInfo?.color ?? AppColors.primary,
                          ),

                    const SizedBox(height: 16),

                    // Skip Button
                    TextButton(
                      onPressed: () async {
                        await context.read<AuthProvider>().logout();
                        if (!context.mounted) return;
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.login,
                          (_) => false,
                        );
                      },
                      child: Text(
                        'Logout',
                        style: AppTextStyles.body1.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
        boxShadow:
            theme.brightness == Brightness.dark ? null : AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: AppTextStyles.heading5),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
