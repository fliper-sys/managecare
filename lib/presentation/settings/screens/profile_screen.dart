import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/constants/routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/lottie_dialog.dart';
import '../../../services/email_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../widgets/loading_indicator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isEditing = false;
  bool _isUploading = false;
  // Upload progress (0.0 - 1.0)
  // Any error message from the last upload attempt
  String? _uploadErrorMessage;
  // Keep pending bytes/filename to allow reliable retry without re-picking
  Uint8List? _pendingUploadBytes;
  String? _pendingUploadFilename;
  // In-memory preview bytes for immediate local preview before upload completes
  Uint8List? _previewPhotoBytes;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mutedText =
        theme.textTheme.bodyMedium?.color?.withOpacity(0.68) ??
            AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: theme.iconTheme.color),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit_outlined),
            onPressed: () {
              if (_isEditing) {
                _saveProfile(authProvider);
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Main Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.alphaBlend(
                      scheme.primary.withOpacity(0.10),
                      theme.cardColor,
                    ),
                    theme.cardColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outline.withOpacity(0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _isEditing
                              ? 'Editing account details'
                              : 'Account overview',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Profile Photo Section (mirrors Business Settings behavior)
                  _buildPhotoSection(),
                  const SizedBox(height: 20),

                  if (!_isEditing) ...[
                    Text(
                      user?.fullName ?? 'User Name',
                      style: (theme.textTheme.headlineSmall ??
                              AppTextStyles.heading3)
                          .copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user?.email ?? 'user@email.com',
                      style: AppTextStyles.body2.copyWith(
                        color: mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ProfilePill(
                          icon: Icons.badge_outlined,
                          label: (user?.role ?? 'Owner').toUpperCase(),
                          tint: scheme.primary,
                        ),
                        const _ProfilePill(
                          icon: Icons.check_circle_outline,
                          label: 'ACTIVE',
                          tint: AppColors.success,
                        ),
                        if (user?.phoneNumber?.isNotEmpty == true)
                          _ProfilePill(
                            icon: Icons.phone_rounded,
                            label: user!.phoneNumber!,
                            tint: scheme.secondary,
                          ),
                      ],
                    ),
                    if (user?.phoneNumber?.isNotEmpty == true) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Keep these details current so receipts, reminders, and notifications reach you quickly.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: mutedText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ] else ...[
                    // Edit Form inside card
                    const SizedBox(height: 8),
                    CustomTextField(
                      label: 'Full Name',
                      controller: _nameController,
                      prefixIcon: Icons.person_outline_rounded,
                      hint: 'Enter your full name',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Email Address',
                      controller: _emailController,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      hint: 'Enter your sign-in email',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Phone Number',
                      controller: _phoneController,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      hint: 'Enter your phone number',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.primary.withOpacity(0.12),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Changing your email triggers a secure verification flow. We will ask for your current password before the update is applied.',
                              style: AppTextStyles.caption.copyWith(
                                color: mutedText,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: CustomButton(
                        text: 'Save Profile Changes',
                        onPressed: () {
                          _saveProfile(authProvider);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          _nameController.text = user?.fullName ?? '';
                          _emailController.text = user?.email ?? '';
                          _phoneController.text = user?.phoneNumber ?? '';
                          setState(() => _isEditing = false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: scheme.outline.withOpacity(0.55),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: mutedText),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Account Information Section
            if (!_isEditing) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Account Information',
                          style: AppTextStyles.heading5.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _InfoTile(
                      label: 'Email',
                      value: user?.email ?? 'N/A',
                      icon: Icons.email_outlined,
                    ),
                    _InfoTile(
                      label: 'User ID',
                      value: user?.id ?? 'N/A',
                      icon: Icons.fingerprint,
                    ),
                    _InfoTile(
                      label: 'Account Type',
                      value: user?.role ?? 'Owner',
                      icon: Icons.badge_outlined,
                    ),
                    const _InfoTile(
                      label: 'Status',
                      value: 'Active',
                      statusColor: AppColors.success,
                      icon: Icons.check_circle_outline,
                    ),
                    _InfoTile(
                      label: 'Joined',
                      value: user?.createdAt != null
                          ? _formatDate(user!.createdAt)
                          : 'N/A',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Security Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security_rounded,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Security & Privacy',
                          style: AppTextStyles.heading5.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SecurityOption(
                      icon: Icons.lock_outline_rounded,
                      title: 'Change Password',
                      subtitle: 'Update your password regularly',
                      onTap: () => _showChangePasswordDialog(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                          height: 1, color: AppColors.border.withOpacity(0.5)),
                    ),
                    _SecurityOption(
                      icon: Icons.verified_user_outlined,
                      title: 'Two-Factor Authentication',
                      subtitle: 'Add an extra layer of security',
                      trailing: Switch(
                        value: false,
                        activeColor: AppColors.primary,
                        onChanged: (value) {
                          _show2FADialog(context, value);
                        },
                      ),
                      onTap: null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                          height: 1, color: AppColors.border.withOpacity(0.5)),
                    ),
                    _SecurityOption(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'Review our privacy policy',
                      onTap: () => _showPrivacyPolicyDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Settings Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, Routes.settings);
                  },
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('App Settings'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.border.withOpacity(0.8)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    _showLogoutDialog(context, authProvider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors.error.withAlpha((0.08 * 255).toInt()),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Logout',
                    style: AppTextStyles.heading5.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Map<String, String>? _getSettingsContextOrNotify() {
    final userId = context.read<AuthProvider>().currentUser?.id;
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;

    if (userId == null || businessId == null) {
      _safeShowSnackBar(
        const SnackBar(
          content: Text('Unable to access your account settings right now.'),
          backgroundColor: AppColors.error,
        ),
      );
      return null;
    }

    return {
      'userId': userId,
      'businessId': businessId,
    };
  }

  Future<String?> _promptForCurrentPassword(String newEmail) async {
    final controller = TextEditingController();
    bool obscureText = true;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Verify Email Change'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To change your sign-in email to $newEmail, enter your current password.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: obscureText,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => obscureText = !obscureText);
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    return result;
  }

  void _saveProfile(AuthProvider authProvider) async {
    try {
      final ids = _getSettingsContextOrNotify();
      if (ids == null) return;

      final fullName = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final phoneNumber = _phoneController.text.trim();

      if (fullName.isEmpty) {
        _safeShowSnackBar(
          const SnackBar(
            content: Text('Full name is required'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (email.isEmpty || !email.contains('@')) {
        _safeShowSnackBar(
          const SnackBar(
            content: Text('Enter a valid email address'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final currentEmail =
          (authProvider.currentUser?.email ?? '').trim().toLowerCase();
      final emailChanged = email != currentEmail;

      if (emailChanged) {
        final currentPassword = await _promptForCurrentPassword(email);
        if (currentPassword == null) return;
        if (currentPassword.isEmpty) {
          _safeShowSnackBar(
            const SnackBar(
              content: Text('Current password is required to change email'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }

        final emailUpdateOk = await runWithLottieErrorHandling<bool>(
              context,
              () => authProvider.changeEmail(currentPassword, email),
              errorTitle: 'Email Update Failed',
            ) ??
            false;

        if (!mounted) return;
        if (!emailUpdateOk) {
          _safeShowSnackBar(
            SnackBar(
              content: Text(
                authProvider.errorMessage ??
                    'Unable to update your sign-in email.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      }

      final settingsProvider = context.read<SettingsProvider>();

      // Save profile changes using SettingsProvider
      final res = await runWithLottieErrorHandling<bool>(
        context,
        () async {
          return await settingsProvider.updateProfile(
            ids['businessId']!,
            ids['userId']!,
            fullName: fullName,
            email: email,
            phoneNumber: phoneNumber,
          );
        },
        errorTitle: 'Profile Save Failed',
      );

      if (!mounted) return;

      if (res == true) {
        // Update auth provider cache so UI reflects changes immediately
        await authProvider.updateProfile(
          email: email,
          fullName: fullName,
          phoneNumber: phoneNumber,
        );

        await showSuccessLottieDialog(
          context,
          title: 'Profile Updated',
          message: emailChanged
              ? 'Your profile was saved. Check your inbox to verify the new email address if prompted.'
              : 'Your profile was saved',
        );
        setState(() => _isEditing = false);
      } else {
        _safeShowSnackBar(
          const SnackBar(
            content: Text('Failed to save profile'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      _safeShowSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showImagePickerOptions(BuildContext context) {
    final authProviderRead = context.read<AuthProvider>();
    final user = authProviderRead.currentUser;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.change_circle_outlined, color: AppColors.primary),
              title: Text('Change photo', style: AppTextStyles.body1),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndUploadProfilePhoto();
              },
            ),
            if (user?.photoUrl?.isNotEmpty == true)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Future.microtask(() async {
                      // Use the outer context to read providers (safe after sheet closed)
                      final authProvider = context.read<AuthProvider>();
                      final settingsProvider = context.read<SettingsProvider>();

                      try {
                        // Keep reference to existing photo so we can clear caches
                        final prevPhotoUrl = authProvider.currentUser?.photoUrl;
                        final ids = _getSettingsContextOrNotify();
                        if (ids == null) return;

                        // Update profile with null photo URL
                        await settingsProvider.updateProfile(
                          ids['businessId']!,
                          ids['userId']!,
                          fullName: _nameController.text,
                          email: _emailController.text,
                          phoneNumber: _phoneController.text,
                          profilePhotoUrl: '',
                        );

                        // Update auth provider
                        await authProvider.updateProfile(photoUrl: '');

                        // Clear previous image cache
                        try {
                          await _evictAndRemoveCache(prevPhotoUrl);
                        } catch (e) {
                          debugPrint('Error clearing previous photo cache: $e');
                        }

                        if (!mounted) return;
                        _safeShowSnackBar(
                          const SnackBar(
                            content: Text('Profile photo removed'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        setState(() {});
                      } catch (e) {
                        if (!mounted) return;
                        _safeShowSnackBar(
                          SnackBar(
                            content: Text('Error removing photo: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    });
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final filename = xfile.name;

      setState(() {
        _isUploading = true;
        _pendingUploadBytes = bytes;
        _pendingUploadFilename = filename;
        _previewPhotoBytes = bytes;
      });

      debugPrint('[Profile] Uploading via EmailService.uploadBytes');
      final url = await EmailService().uploadBytes(bytes, filename);

      setState(() => _isUploading = false);

      if (url != null) {
        final cachebustedUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

        // Clear any existing caches for previous photo
        final prev = context.read<AuthProvider>().currentUser?.photoUrl;
        await _evictAndRemoveCache(prev);

        // Persist profile photo
        final authProvider = context.read<AuthProvider>();
        final settingsProvider = context.read<SettingsProvider>();
        final ids = _getSettingsContextOrNotify();
        if (ids == null) {
          setState(() => _isUploading = false);
          return;
        }

        await settingsProvider.updateProfile(
          ids['businessId']!,
          ids['userId']!,
          fullName: _nameController.text,
          email: _emailController.text,
          phoneNumber: _phoneController.text,
          profilePhotoUrl: cachebustedUrl,
        );

        await authProvider.updateProfile(photoUrl: cachebustedUrl);

        // Persist to users collection (best-effort)
        try {
          await FirebaseFirestore.instance.collection('users').doc(ids['userId']).set({'photoUrl': cachebustedUrl}, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[ProfileScreen] Failed to write photoUrl to users doc: $e');
        }

        // Clear pending and preview
        setState(() {
          _previewPhotoBytes = null;
          _pendingUploadBytes = null;
          _pendingUploadFilename = null;
          _uploadErrorMessage = null;
        });

        if (mounted) _safeShowSnackBar(const SnackBar(content: Text('Profile photo updated successfully'), backgroundColor: Colors.green));
        setState(() {});
      } else {
        setState(() => _uploadErrorMessage = 'Upload failed');
        if (mounted) _safeShowSnackBar(SnackBar(content: const Text('Upload failed'), backgroundColor: AppColors.error, action: SnackBarAction(label: 'Retry', onPressed: _retryProfileUpload)));
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e'), action: SnackBarAction(label: 'Retry', onPressed: _retryProfileUpload)));
    }
  }

  /// Retry the previously-chosen profile image upload using cached bytes
  Future<void> _retryProfileUpload() async {
    if (_pendingUploadBytes == null || _pendingUploadBytes!.isEmpty) {
      if (mounted) _safeShowSnackBar(const SnackBar(content: Text('No cached image to retry')));
      return;
    }

    if (_isUploading) return;
    setState(() {
      _isUploading = true;
      _uploadErrorMessage = null;
    });

    // Capture providers and ids early to avoid races
    final authProvider = context.read<AuthProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final ids = _getSettingsContextOrNotify();
    if (ids == null) {
      setState(() => _isUploading = false);
      return;
    }

    final bytes = _pendingUploadBytes!;
    final filename = _pendingUploadFilename ?? 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      final email = EmailService();
      String? photoUrl;
      try {
        photoUrl = await email.uploadBytes(bytes, filename);
      } catch (e) {
        if (!mounted) return;
        final msg = e.toString();
        setState(() {
          _uploadErrorMessage = msg;
          _isUploading = false;
        });
        _safeShowSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error, action: SnackBarAction(label: 'Retry', onPressed: _retryProfileUpload, textColor: Colors.white)));
        return;
      }

      if (!mounted) return;

      if (photoUrl == null) {
        setState(() => _uploadErrorMessage = 'Upload failed');
        _safeShowSnackBar(SnackBar(content: const Text('Upload failed'), backgroundColor: AppColors.error, action: SnackBarAction(label: 'Retry', onPressed: _retryProfileUpload, textColor: Colors.white)));
        return;
      }

      final cachebustedUrl = '$photoUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      // Persist as profile photo
      // Ensure widget is still mounted before proceeding
      if (!mounted) {
        debugPrint('[Profile] Widget unmounted after retry upload; aborting post-upload updates.');
        return;
      }

      final success = await settingsProvider.updateProfile(
        ids['businessId']!,
        ids['userId']!,
        fullName: _nameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
        profilePhotoUrl: cachebustedUrl,
      );

      if (!mounted) return;

      if (success) {
        await authProvider.updateProfile(photoUrl: cachebustedUrl);
        try {
          await FirebaseFirestore.instance.collection('users').doc(ids['userId']).set({'photoUrl': cachebustedUrl}, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[ProfileScreen] Failed to write photoUrl to users doc: $e');
        }

        // Clear caches
        await _evictAndRemoveCache(photoUrl);
        await _evictAndRemoveCache(cachebustedUrl);

        setState(() {
          _previewPhotoBytes = null;
          _pendingUploadBytes = null;
          _pendingUploadFilename = null;
          _uploadErrorMessage = null;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            _safeShowSnackBar(const SnackBar(content: Text('Profile photo updated successfully'), backgroundColor: Colors.green));
          } catch (e) {
            debugPrint('ShowSnackBar failed: $e');
          }
        });
      } else {
        setState(() => _uploadErrorMessage = 'Failed to update profile with uploaded photo');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            _safeShowSnackBar(const SnackBar(content: Text('Failed to update profile photo'), backgroundColor: AppColors.error));
          } catch (e) {
            debugPrint('ShowSnackBar failed: $e');
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadErrorMessage = e.toString());
      final msg = _uploadErrorMessage ?? 'Upload error';
      _safeShowSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error, action: SnackBarAction(label: 'Retry', onPressed: _retryProfileUpload, textColor: Colors.white)));
    } finally {
      if (mounted) setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _evictAndRemoveCache(String? url) async {
    if (url == null || url.isEmpty) return;

    final baseUrl = url.split('?').first;
    try {
      await CachedNetworkImageProvider(url).evict();
    } catch (e) {
      debugPrint('Evict image (url) error: $e');
    }

    if (baseUrl != url) {
      try {
        await CachedNetworkImageProvider(baseUrl).evict();
      } catch (e) {
        debugPrint('Evict image (baseUrl) error: $e');
      }
    }

    try {
      await DefaultCacheManager().removeFile(url);
    } catch (e) {
      debugPrint('RemoveFile (url) error: $e');
    }

    if (baseUrl != url) {
      try {
        await DefaultCacheManager().removeFile(baseUrl);
      } catch (e) {
        debugPrint('RemoveFile (baseUrl) error: $e');
      }
    }
  }

  Widget _buildPhotoSection() {
    final user = context.watch<AuthProvider>().currentUser;
    final photoUrl = user?.photoUrl;

    return Center(
      child: GestureDetector(
        onTap: _isUploading
            ? null
            : () {
                if (photoUrl != null && photoUrl.isNotEmpty) {
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
                              _pickAndUploadProfilePhoto();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete_outline, color: AppColors.error),
                            title: Text('Remove photo', style: AppTextStyles.body1.copyWith(color: AppColors.error)),
                            onTap: () async {
                              Navigator.pop(context);
                              final authProvider = context.read<AuthProvider>();
                              final settingsProvider = context.read<SettingsProvider>();
                              try {
                                final prevPhotoUrl = authProvider.currentUser?.photoUrl;
                                final ids = _getSettingsContextOrNotify();
                                if (ids == null) return;
                                await settingsProvider.updateProfile(
                                  ids['businessId']!,
                                  ids['userId']!,
                                  fullName: _nameController.text,
                                  email: _emailController.text,
                                  phoneNumber: _phoneController.text,
                                  profilePhotoUrl: '',
                                );
                                await authProvider.updateProfile(photoUrl: '');
                                try {
                                  await _evictAndRemoveCache(prevPhotoUrl);
                                } catch (e) {
                                  debugPrint('Error clearing previous photo cache: $e');
                                }

                                if (mounted) _safeShowSnackBar(const SnackBar(content: Text('Profile photo removed'), backgroundColor: Colors.green));
                                setState(() {});
                              } catch (e) {
                                if (mounted) _safeShowSnackBar(SnackBar(content: Text('Error removing photo: $e'), backgroundColor: AppColors.error));
                              }
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
                  _pickAndUploadProfilePhoto();
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
                if (_pendingUploadBytes != null)
                  Image.memory(_pendingUploadBytes!, fit: BoxFit.cover)
                else if (photoUrl != null && photoUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(child: CustomLoadingIndicator()),
                    errorWidget: (_, __, ___) => const Icon(Icons.person, size: 60, color: AppColors.textSecondary),
                  )
                else
                  const Icon(Icons.person, size: 60, color: AppColors.textSecondary),

                if (_isUploading)
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

  // Safe snackbar helper to avoid ancestor lookups on deactivated widgets
  void _safeShowSnackBar(SnackBar snack) {
    if (!mounted) return;
    // Defer to the next frame to ensure the element tree is stable. Use maybeOf
    // to avoid throwing when no ScaffoldMessenger is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
        scaffoldMessenger?.showSnackBar(snack);
      } catch (e) {
        debugPrint('Safe SnackBar failed: $e');
      }
    });
  }


  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              authProvider.logout();
              Navigator.pushReplacementNamed(context, Routes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscureCurrentPassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                      () => obscureCurrentPassword = !obscureCurrentPassword,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: obscureNewPassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNewPassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                      () => obscureNewPassword = !obscureNewPassword,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                      () => obscureConfirmPassword = !obscureConfirmPassword,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPassword = currentPasswordController.text;
                final newPassword = newPasswordController.text;
                final confirmPassword = confirmPasswordController.text;

                // Validation
                if (currentPassword.isEmpty ||
                    newPassword.isEmpty ||
                    confirmPassword.isEmpty) {
                  _safeShowSnackBar(
                    const SnackBar(
                      content: Text('Please fill all fields'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                if (newPassword != confirmPassword) {
                  _safeShowSnackBar(
                    const SnackBar(
                      content: Text('New passwords do not match'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                if (newPassword.length < 8) {
                  _safeShowSnackBar(
                    const SnackBar(
                      content:
                          Text('Password must be at least 8 characters long'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                try {
                  // Call auth provider to change password
                  final authProvider = context.read<AuthProvider>();
                  final success = await authProvider.changePassword(
                    currentPassword,
                    newPassword,
                  );

                  if (!mounted) return;

                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Failed to change password. Check current password.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _show2FADialog(BuildContext context, bool enabled) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Two-Factor Authentication'),
        content: Text(
          enabled
              ? 'Two-Factor Authentication will be enabled. You will need to verify your identity with an additional code when logging in.'
              : 'Two-Factor Authentication will be disabled. Your account will be less secure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '2FA ${enabled ? 'enabled' : 'disabled'} successfully',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: enabled ? Colors.green : AppColors.error,
            ),
            child: Text(enabled ? 'Enable 2FA' : 'Disable 2FA'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Privacy Policy',
                style: AppTextStyles.heading4,
              ),
              const SizedBox(height: 16),
              const Text(
                'Last Updated: December 2024',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 16),
              _buildPolicySection(
                'Data Collection',
                'We collect information you provide directly, such as when you create an account, make a purchase, or contact us.',
              ),
              _buildPolicySection(
                'Data Usage',
                'Your data is used to provide and improve our services, process transactions, and communicate with you.',
              ),
              _buildPolicySection(
                'Data Protection',
                'We implement industry-standard security measures to protect your personal information.',
              ),
              _buildPolicySection(
                'Sharing Information',
                'We do not share your personal information with third parties without your consent.',
              ),
              _buildPolicySection(
                'Your Rights',
                'You have the right to access, update, or delete your personal information at any time.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy Policy accepted'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('I Agree'),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.heading5.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;

  const _ProfilePill({
    required this.icon,
    required this.label,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}


class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? statusColor;
  final IconData? icon;

  const _InfoTile({
    required this.label,
    required this.value,
    this.statusColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final mutedText =
        Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.68) ??
            AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: mutedText),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AppTextStyles.body2.copyWith(
                  color: mutedText,
                ),
              ),
            ],
          ),
          if (statusColor != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor!.withAlpha((0.05 * 255).toInt()),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: AppTextStyles.caption.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Text(
              value,
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _SecurityOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SecurityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final mutedText =
        Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.68) ??
            AppColors.textSecondary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(
          color: mutedText,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: mutedText,
          ),
      onTap: onTap,
    );
  }
}
