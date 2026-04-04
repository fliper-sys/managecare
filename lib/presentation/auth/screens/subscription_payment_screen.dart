import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../services/payment_service.dart';
import '../../../services/receipt_upload_service.dart';
import '../../../services/subscription_service.dart';
import '../../../services/subscription_storage_service.dart';
import '../../../widgets/loading_indicator.dart';

class SubscriptionPaymentScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String userName;
  final String? businessId;
  final String? businessType;
  final String? businessTier;
  final String? businessClass;

  const SubscriptionPaymentScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.businessId,
    this.businessType,
    this.businessTier,
    this.businessClass,
  });

  @override
  State<SubscriptionPaymentScreen> createState() =>
      _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState extends State<SubscriptionPaymentScreen> {
  String _selectedPlanId = '';
  bool _isProcessing = false;
  File? _selectedReceipt;
  double _uploadProgress = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureSelectedPlan(context.read<BusinessProvider>());
  }

  String _resolveBusinessType(BusinessProvider businessProvider) {
    final explicitBusinessType = widget.businessType?.trim() ?? '';
    if (explicitBusinessType.isNotEmpty) return explicitBusinessType;

    final currentBusinessType =
        businessProvider.currentBusiness?.businessType.trim() ?? '';
    if (currentBusinessType.isNotEmpty) return currentBusinessType;

    final userBusinessType =
        context.read<AuthProvider>().currentUser?.businessType?.trim() ?? '';
    if (userBusinessType.isNotEmpty) return userBusinessType;

    return 'retail';
  }

  String _resolveBusinessId(BusinessProvider businessProvider) {
    final explicitBusinessId = widget.businessId?.trim() ?? '';
    if (explicitBusinessId.isNotEmpty) return explicitBusinessId;

    final currentBusinessId = businessProvider.currentBusiness?.id.trim() ?? '';
    if (currentBusinessId.isNotEmpty) return currentBusinessId;

    final user = context.read<AuthProvider>().currentUser;
    final primaryBusinessId = user?.primaryBusinessId.trim() ?? '';
    if (primaryBusinessId.isNotEmpty) return primaryBusinessId;

    return user?.businessId.trim() ?? '';
  }

  List<SubscriptionPlan> _availablePlans(BusinessProvider businessProvider) {
    return SubscriptionService.getPlansForBusinessType(
      _resolveBusinessType(businessProvider),
    );
  }

  void _ensureSelectedPlan(BusinessProvider businessProvider) {
    final plans = _availablePlans(businessProvider);
    if (plans.isEmpty) return;
    if (plans.any((plan) => plan.id == _selectedPlanId)) return;

    final preferredTier = SubscriptionService.normalizeStoredPlanLevel(
      subscriptionTier: widget.businessTier,
      businessClass: widget.businessClass,
    );
    final preferredPlan = plans.where((plan) => plan.tierId == preferredTier);
    _selectedPlanId = (preferredPlan.isNotEmpty ? preferredPlan.first : plans.first).id;
  }

  SubscriptionPlan? _selectedPlan(BusinessProvider businessProvider) {
    final plans = _availablePlans(businessProvider);
    if (plans.isEmpty) return null;
    return plans.firstWhere(
      (plan) => plan.id == _selectedPlanId,
      orElse: () => plans.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final role = auth.currentUser?.role.toLowerCase();
    if (role == 'worker') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Subscription'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Subscriptions are managed by business owners.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async => !_isProcessing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Choose Your Plan'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: _isProcessing
                  ? null
                  : () {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushReplacementNamed('/');
                      }
                    },
              child: const Text(
                'Skip',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: _isProcessing
            ? const Center(child: CustomLoadingIndicator())
            : Consumer<BusinessProvider>(
                builder: (context, businessProvider, _) {
                  _ensureSelectedPlan(businessProvider);
                  final selectedPlan = _selectedPlan(businessProvider);
                  final plans = _availablePlans(businessProvider);
                  final currency =
                      businessProvider.currentBusiness?.currency ?? 'NGN';
                  final currencySymbol = _getCurrencySymbol(currency);
                  final businessType = _resolveBusinessType(businessProvider);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Plans for ${businessType.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Subscriptions are now checked per business, so this purchase applies only to the current business.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (plans.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: const Text(
                              'No plans are configured for this business type yet.',
                            ),
                          )
                        else
                          ...plans.map(
                            (plan) => _buildPlanCard(
                              plan: plan,
                              isSelected: plan.id == _selectedPlanId,
                              currencySymbol: currencySymbol,
                              onTap: () => setState(() => _selectedPlanId = plan.id),
                            ),
                          ),
                        const SizedBox(height: 24),
                        if (selectedPlan != null)
                          _buildBankDetailsSection(
                            currency: currency,
                            currencySymbol: currencySymbol,
                            selectedPlan: selectedPlan,
                          ),
                        const SizedBox(height: 24),
                        _buildUploadSection(currency),
                        if (_selectedReceipt != null) ...[
                          const SizedBox(height: 16),
                          _buildReceiptPreview(),
                        ],
                        if (_uploadProgress > 0 && _isProcessing) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(value: _uploadProgress),
                          const SizedBox(height: 8),
                          Text(
                            'Uploading... ${(_uploadProgress * 100).toInt()}%',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _selectedReceipt == null || _isProcessing
                              ? null
                              : () => _submitReceipt(currency),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Submit Receipt for Approval'),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionPlan plan,
    required bool isSelected,
    required String currencySymbol,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.tierId.toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$currencySymbol${plan.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${plan.durationInDays} days access',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...plan.features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '- $feature',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetailsSection({
    required String currency,
    required String currencySymbol,
    required SubscriptionPlan selectedPlan,
  }) {
    const bankName = 'Moniepoint';
    const accountName = 'Manage Care Limited';
    const accountNumber = '5181766595';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transfer Payment Details',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send $currencySymbol${selectedPlan.price.toStringAsFixed(0)} ($currency) to the account below.',
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Bank Name', bankName),
          const SizedBox(height: 12),
          _buildDetailRow('Account Name', accountName),
          const SizedBox(height: 12),
          _buildDetailRowWithCopy('Account Number', accountNumber),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(value),
        ),
      ],
    );
  }

  Widget _buildDetailRowWithCopy(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Expanded(child: Text(value)),
              IconButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.content_copy, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadSection(String currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Upload Payment Proof',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Use Flutterwave for instant activation, or upload a receipt for manual approval.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _payWithFlutterwave(currency),
            icon: const Icon(Icons.payment),
            label: const Text('Pay with Flutterwave'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _secondaryAction(
                icon: Icons.camera_alt,
                label: 'Camera',
                onPressed: _pickReceiptFromCamera,
              ),
              _secondaryAction(
                icon: Icons.image,
                label: 'Gallery',
                onPressed: _pickReceiptFromGallery,
              ),
              _secondaryAction(
                icon: Icons.file_present,
                label: 'File',
                onPressed: _pickReceiptFile,
              ),
              _secondaryAction(
                icon: Icons.email,
                label: 'Upload Only',
                onPressed: _sendViaEmail,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _secondaryAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 160,
      child: OutlinedButton.icon(
        onPressed: _isProcessing ? null : onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  Widget _buildReceiptPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(height: 8),
          Text(
            _selectedReceipt!.path.split(Platform.pathSeparator).last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _selectedReceipt = null),
            child: const Text('Change Receipt'),
          ),
        ],
      ),
    );
  }

  Future<void> _payWithFlutterwave(String currency) async {
    final businessProvider = context.read<BusinessProvider>();
    final selectedPlan = _selectedPlan(businessProvider);
    if (selectedPlan == null) {
      _showError('No subscription plan is selected.');
      return;
    }

    final userId = widget.userId;
    if (userId.isEmpty) {
      _showError('User ID missing. Please log in again.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final publicKey = await PaymentService().getPublicKey();
      if (publicKey == null || publicKey.isEmpty) {
        _showError('Payment public key is not configured.');
        return;
      }

      final businessId = _resolveBusinessId(businessProvider);
      final businessType = _resolveBusinessType(businessProvider);
      final txRef = 'sub_${userId}_${DateTime.now().millisecondsSinceEpoch}';

      final paymentResult = await PaymentService().processPayment(
        context: context,
        amount: selectedPlan.price,
        currency: currency,
        email: widget.userEmail,
        fullName: widget.userName,
        txRef: txRef,
        publicKey: publicKey,
        businessId: businessId,
      );

      if (paymentResult['success'] != true) {
        _showError(
          'Payment failed: ${paymentResult['message'] ?? 'Unknown error'}',
        );
        return;
      }

      final transactionId = paymentResult['transactionId'] ?? txRef;
      final now = DateTime.now();
      final receiptUrl = 'flutterwave:$transactionId';

      await FirebaseFirestore.instance
          .collection('subscription_requests')
          .doc('FLW_${userId}_${now.millisecondsSinceEpoch}')
          .set({
        'userId': userId,
        'businessId': businessId,
        'businessType': businessType,
        'planId': selectedPlan.id,
        'planName': selectedPlan.name,
        'planTier': selectedPlan.tierId,
        'planFamily': selectedPlan.businessFamily,
        'amount': selectedPlan.price,
        'currency': currency,
        'userEmail': widget.userEmail,
        'userName': widget.userName,
        'receiptUrl': receiptUrl,
        'status': 'approved',
        'paymentMethod': 'flutterwave',
        'paymentProcessor': 'flutterwave',
        'processorTransactionId': transactionId,
        'subscriptionStatus': 'approved',
        'createdAt': now.toIso8601String(),
        'approvedAt': now.toIso8601String(),
        'approvedBy': 'system',
        'updatedAt': now.toIso8601String(),
      });

      await FirebaseFirestore.instance.collection('payment_transactions').add({
        'transactionId': transactionId,
        'businessId': businessId,
        'userId': userId,
        'userEmail': widget.userEmail,
        'userName': widget.userName,
        'amount': selectedPlan.price,
        'currency': currency,
        'method': 'flutterwave',
        'status': 'completed',
        'subscriptionPayment': true,
        'planId': selectedPlan.id,
        'processorResponse': paymentResult['processorResponse'],
        'createdAt': now.toIso8601String(),
      });

      final activated = await SubscriptionService(
        firestore: FirebaseFirestore.instance,
      ).activateSubscriptionImmediately(
        userId: userId,
        planId: selectedPlan.id,
        receiptUrl: receiptUrl,
        amount: selectedPlan.price,
        businessId: businessId.isNotEmpty ? businessId : null,
      );

      if (!activated) {
        _showError(
          'Payment succeeded, but subscription activation did not complete. Please contact support.',
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful and subscription activated'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushReplacementNamed(
        '/subscription-status',
        arguments: {
          'userId': userId,
          'userEmail': widget.userEmail,
          'userName': widget.userName,
          'businessId': businessId,
          'businessType': businessType,
          'subscriptionPlan': selectedPlan.id,
          'subscriptionAmount': selectedPlan.price,
        },
      );
    } catch (e) {
      _showError('Payment error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickReceiptFromCamera() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() => _selectedReceipt = File(image.path));
      }
    } catch (e) {
      _showError('Failed to open camera: $e');
    }
  }

  Future<void> _pickReceiptFromGallery() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() => _selectedReceipt = File(image.path));
      }
    } catch (e) {
      _showError('Failed to open gallery: $e');
    }
  }

  Future<void> _pickReceiptFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null && path.isNotEmpty) {
          setState(() => _selectedReceipt = File(path));
        }
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _sendViaEmail() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );
      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return;
      }

      final selectedPlan = _selectedPlan(context.read<BusinessProvider>());
      if (selectedPlan == null) {
        _showError('No subscription plan is selected.');
        return;
      }

      setState(() {
        _isProcessing = true;
        _uploadProgress = 0.0;
      });

      final uploadResult = await SubscriptionStorageService()
          .uploadSubscriptionProofWithProgress(
        File(result.files.first.path!),
        widget.userId,
        selectedPlan.id,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _uploadProgress = progress);
          }
        },
      );

      if (!mounted) return;
      if (uploadResult.success && uploadResult.downloadUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showError(
          'Upload failed: ${uploadResult.error ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _submitReceipt(String currency) async {
    final businessProvider = context.read<BusinessProvider>();
    final selectedPlan = _selectedPlan(businessProvider);
    if (_selectedReceipt == null) {
      _showError('Please select a receipt first.');
      return;
    }
    if (selectedPlan == null) {
      _showError('No subscription plan is selected.');
      return;
    }
    if (widget.userId.isEmpty) {
      _showError('User ID is missing. Please log in again.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _uploadProgress = 0.0;
    });

    try {
      final businessId = _resolveBusinessId(businessProvider);
      final businessType = _resolveBusinessType(businessProvider);

      final receiptResult = await ReceiptUploadService().uploadReceipt(
        userId: widget.userId,
        businessId: businessId,
        planId: selectedPlan.id,
        planName: selectedPlan.name,
        amount: selectedPlan.price,
        currency: currency,
        receiptFile: _selectedReceipt!,
        userEmail: widget.userEmail,
        userName: widget.userName,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _uploadProgress = progress);
          }
        },
      );

      final receiptUrl = receiptResult.receiptUrl;
      if (receiptUrl == null) {
        _showError('Receipt upload failed. Please try again.');
        return;
      }

      final submitted = await SubscriptionService(
        firestore: FirebaseFirestore.instance,
      ).submitManualSubscriptionForApproval(
        userId: widget.userId,
        planId: selectedPlan.id,
        receiptUrl: receiptUrl,
        amount: selectedPlan.price,
        currency: currency,
        userEmail: widget.userEmail,
        userName: widget.userName,
        businessId: businessId.isNotEmpty ? businessId : null,
        existingRequestId: receiptResult.uploadId,
      );

      if (!submitted) {
        _showError(
          'Receipt uploaded, but we could not queue your approval request.',
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/subscription-status',
        arguments: {
          'userId': widget.userId,
          'userEmail': widget.userEmail,
          'userName': widget.userName,
          'businessId': businessId,
          'businessType': businessType,
          'subscriptionPlan': selectedPlan.id,
          'subscriptionAmount': selectedPlan.price,
        },
      );
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getCurrencySymbol(String currency) {
    const symbols = {
      'NGN': 'N',
      'USD': '\$',
      'EUR': 'EUR',
      'GBP': 'GBP',
      'KES': 'Ksh',
      'ZAR': 'R',
    };
    return symbols[currency] ?? currency;
  }
}
