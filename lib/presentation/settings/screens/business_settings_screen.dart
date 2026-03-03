import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/email_service.dart';
import '../../../widgets/loading_indicator.dart';
import '../../sales/screens/receipt_customization_screen.dart';
import 'printer_settings_screen.dart';

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  late TextEditingController _addressController;
  late TextEditingController _businessNameController;
  bool _enableAutoBackup = false;
  bool _enableNotifications = true;
  bool _enableOfflineMode = true;
  bool _isUploadingPhoto = false;
  // For web-compatibility store pending bytes & filename for retry
  Uint8List? _pendingPhotoBytes;

  String? _pendingPhotoFilename;
  late TextEditingController _phoneController;
  String? _photoUrl;
  late TextEditingController _registrationController;
  late TextEditingController _taxIdController;

  @override
  void dispose() {
    _businessNameController.dispose();
    _registrationController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final business = context.read<BusinessProvider>().currentBusiness;
    _businessNameController = TextEditingController(text: business?.name ?? '');
    _photoUrl = business?.photoUrl;
    // Safely resolve registration number from the model
    String registrationText = '';
    if (business != null) {
      try {
        registrationText = (business as dynamic).registrationNumber ?? '';
      } catch (_) {
        registrationText = '';
      }
    }
    _registrationController = TextEditingController(text: registrationText);
    _addressController = TextEditingController(text: business?.address ?? '');
    _phoneController = TextEditingController(text: business?.phone ?? '');
    _taxIdController = TextEditingController(text: business?.taxId ?? '');
  }

  Widget _buildPhotoSection() {
    return Center(
      child: GestureDetector(
        onTap: _isUploadingPhoto ? null : () {
          if (_photoUrl != null && _photoUrl!.isNotEmpty) {
            showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.change_circle_outlined, color: AppColors.primary),
                      title: Text('Change photo', style: AppTextStyles.body1),
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndUploadBusinessPhoto();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: AppColors.error),
                      title: Text('Remove photo', style: AppTextStyles.body1.copyWith(color: AppColors.error)),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _photoUrl = null);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business photo removed')));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cancel_outlined),
                      title: Text('Cancel', style: AppTextStyles.body1),
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            );
          } else {
            _pickAndUploadBusinessPhoto();
          }
        },
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.background,
            border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_pendingPhotoBytes != null)
                  Image.memory(_pendingPhotoBytes!, fit: BoxFit.cover)
                else if (_photoUrl != null && _photoUrl!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: _photoUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(child: CustomLoadingIndicator()),
                    errorWidget: (_, __, ___) => const Icon(Icons.storefront, size: 60, color: AppColors.textSecondary),
                  )
                else
                  const Icon(Icons.storefront, size: 60, color: AppColors.textSecondary),

                if (_isUploadingPhoto)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(child: CustomLoadingIndicator(color: Colors.white)),
                  )
                else
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.white, size: 32),
                        SizedBox(height: 4),
                        Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Danger Zone',
                style: AppTextStyles.heading5.copyWith(color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'These actions are permanent and cannot be undone. Please proceed with caution.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete This Business'),
              onPressed: () => _showDeleteConfirmation(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _evictAndRemoveCache(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await DefaultCacheManager().removeFile(url);
      await CachedNetworkImageProvider(url).evict();
    } catch (e) {
      debugPrint('Error clearing cache for $url: $e');
    }
  }

  Future<void> _pickAndUploadBusinessPhoto() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final filename = xfile.name;
      setState(() {
        _isUploadingPhoto = true;
        _pendingPhotoBytes = bytes;
        _pendingPhotoFilename = filename;
      });

      debugPrint('[Business] Uploading via EmailService.uploadBytes');
      final url = await EmailService().uploadBytes(bytes, filename);
      setState(() => _isUploadingPhoto = false);

      if (url != null) {
        final cachebustedUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
        await _evictAndRemoveCache(_photoUrl);
        setState(() {
          _photoUrl = cachebustedUrl;
          _pendingPhotoBytes = null;
          _pendingPhotoFilename = null;
        });

        // Persist to backend without waiting
        context.read<BusinessProvider>().updateBusiness(
          context.read<BusinessProvider>().currentBusiness!.copyWith(photoUrl: cachebustedUrl)
        );

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business photo updated!')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Upload failed'), action: SnackBarAction(label: 'Retry', onPressed: _retryUploadPhoto)));
      }
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e'), action: SnackBarAction(label: 'Retry', onPressed: _retryUploadPhoto)));
    }
  }

  Future<void> _retryUploadPhoto() async {
    if (_pendingPhotoBytes != null && _pendingPhotoFilename != null) {
      _pickAndUploadBusinessPhoto();
    }
  }

  Future<void> _saveBusinessSettings(BuildContext context) async {
    final businessProvider = context.read<BusinessProvider>();
    final business = businessProvider.currentBusiness;
    if (business == null) return;

    final updatedBusiness = business.copyWith(
      name: _businessNameController.text,
      address: _addressController.text,
      phone: _phoneController.text,
      photoUrl: _photoUrl,
      taxId: _taxIdController.text,
      // Add other fields as needed
    );

    final success = await businessProvider.updateBusiness(updatedBusiness);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Settings saved successfully!' : 'Failed to save settings.'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this business? This action cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final businessProvider = context.read<BusinessProvider>();
              final businessId = businessProvider.currentBusiness?.id;
              if (businessId != null) {
                final success = await businessProvider.deleteBusiness(businessId);
                if (success && mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Business deleted successfully'), backgroundColor: AppColors.success),
                  );
                } else if(mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete business'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditPinDialog() async {
    final auth = context.read<AuthProvider>();
    final currentPin = auth.currentUser?.pin ?? '';
    final pinCtrl = TextEditingController(text: currentPin);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Owner PIN'),
        content: Form(
          key: formKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: pinCtrl,
                  decoration: InputDecoration(labelText: '4-digit PIN', prefixIcon: const Icon(Icons.key)),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter a 4-digit PIN';
                    final t = v.trim();
                    if (t.length != 4 || int.tryParse(t) == null) return 'Enter a 4-digit PIN';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => pinCtrl.text = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString(),
                child: const Text('Generate'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              try {
                final uid = auth.currentUser?.id ?? '';
                if (uid.isEmpty) throw Exception('No authenticated user');
                await FirebaseFirestore.instance.collection('users').doc(uid).set({'pin': pinCtrl.text.trim(), 'updatedAt': DateTime.now()}, SetOptions(merge: true));
                await context.read<AuthProvider>().refresh();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN updated')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update PIN: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessProvider = context.watch<BusinessProvider>();
    final business = businessProvider.currentBusiness;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Business Settings', style: AppTextStyles.heading4.copyWith(color: AppColors.textPrimary)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business Photo Upload Section
            _buildPhotoSection(),
            const SizedBox(height: 24),

            // Business Information Section
            _SettingCard(
              title: 'Business Information',
              children: [
                CustomTextField(
                  label: 'Business Name',
                  controller: _businessNameController,
                  prefixIcon: Icons.business_outlined,
                  hint: 'Enter business name',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Business Address',
                  controller: _addressController,
                  prefixIcon: Icons.location_on_outlined,
                  hint: 'Enter full address',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  hint: 'Enter contact number',
                ),
              ],
            ),

            // Tax & Registration Section
            _SettingCard(
              title: 'Tax & Registration',
              children: [
                CustomTextField(
                  label: 'Registration Number',
                  controller: _registrationController,
                  prefixIcon: Icons.assignment_outlined,
                  hint: 'Business registration number',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Tax ID',
                  controller: _taxIdController,
                  prefixIcon: Icons.receipt_outlined,
                  hint: 'Enter tax identification number',
                ),
              ],
            ),

            // Preferences Section
            _SettingCard(
              title: 'Preferences',
              children: [
                _PreferenceSwitch(
                  icon: Icons.notifications_active_outlined,
                  title: 'Enable Notifications',
                  subtitle: 'Receive order and system alerts',
                  value: _enableNotifications,
                  onChanged: (value) => setState(() => _enableNotifications = value),
                ),
                const Divider(color: AppColors.border, height: 1),
                _PreferenceSwitch(
                  icon: Icons.cloud_off_outlined,
                  title: 'Offline Mode',
                  subtitle: 'Work without internet connection',
                  value: _enableOfflineMode,
                  onChanged: (value) => setState(() => _enableOfflineMode = value),
                ),
                const Divider(color: AppColors.border, height: 1),
                _PreferenceSwitch(
                  icon: Icons.backup_outlined,
                  title: 'Automatic Backup',
                  subtitle: 'Daily backup to cloud storage',
                  value: _enableAutoBackup,
                  onChanged: (value) => setState(() => _enableAutoBackup = value),
                ),
              ],
            ),

            // Business Details Section
            if (business != null)
              _SettingCard(
                title: 'Business Details',
                children: [
                  _InfoCard(
                    icon: Icons.storefront_outlined,
                    label: 'Business Type',
                    value: business.businessType,
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.star_border_outlined,
                    label: 'Subscription Tier',
                    value: business.subscriptionTier.toUpperCase(),
                    valueColor: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.calendar_today_outlined,
                    label: 'Registered Since',
                    value: _formatDate(business.createdAt),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.key, color: AppColors.primary),
                    title: Text('Owner PIN', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('Tap to set or change the owner PIN', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    trailing: ElevatedButton(
                      onPressed: _showEditPinDialog,
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            
            // Other Settings
            _SettingCard(
              title: 'Other Settings',
              children: [
                 ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const Icon(Icons.print_outlined, color: AppColors.primary),
                  title: Text('Configure Thermal Printer', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen())),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                  title: Text('Receipt Customization', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Customize printed and emailed receipts (Pro)', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReceiptCustomizationScreen())),
                ),
              ],
            ),

            // Save Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: CustomButton(
                  text: 'Save Settings',
                  onPressed: () => _saveBusinessSettings(context),
                  isLoading: businessProvider.isLoading,
                ),
              ),
            ),

            // Danger Zone
            _buildDangerZone(),
            const SizedBox(height: 32),

          ].animate(interval: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.title, required this.children});

  final List<Widget> children;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final ValueChanged<bool> onChanged;
  final String subtitle;
  final String title;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

