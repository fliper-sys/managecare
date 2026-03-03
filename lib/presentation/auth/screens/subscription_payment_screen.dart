import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../../core/constants/routes.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../providers/business_provider.dart';
import '../../../services/subscription_service.dart';
import '../../../services/email_service.dart';
import '../../../services/receipt_upload_service.dart';
import '../../../services/payment_service.dart';
import '../../../providers/auth_provider.dart';

class SubscriptionPaymentScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String userName;
  final String? businessId;
  final String? businessTier;
  final String? businessClass; // 'tier1' | 'tier2' | 'tier3'

  const SubscriptionPaymentScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.businessId,
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

  @override
  void initState() {
    super.initState();
    // Choose a sensible default plan for the detected tier if possible
    final defaultPlans = _availablePlansForTier(widget.businessTier);
    if (defaultPlans.isNotEmpty) {
      _selectedPlanId = defaultPlans.first.id;
    }
  }

  List<SubscriptionPlan> _availablePlansForTier(String? tier) {
    // Use businessClass primarily to decide which class plans to show (tier1/tier2/tier3)
    final cls = (widget.businessClass ?? 'tier1').toString().toLowerCase();
    if (cls == 'tier1' || cls == 't1') {
      // Tier 1: Only Basic plans
      return SubscriptionService.plans.where((p) => p.id.startsWith('t1_basic_')).toList();
    }

    if (cls == 'tier2' || cls == 't2') {
      // Tier 2: Show both Basic and Pro for tier2
      return SubscriptionService.plans.where((p) => p.id.startsWith('t2_')).toList();
    }

    if (cls == 'tier3' || cls == 't3') {
      // Tier 3: Show both Basic and Pro for tier3
      return SubscriptionService.plans.where((p) => p.id.startsWith('t3_')).toList();
    }

    // Fallback: return all plans
    return SubscriptionService.plans;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = auth.currentUser?.role;
    if (role != null && role.toLowerCase() == 'worker') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Subscription'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                const SizedBox(height: 12),
                const Text('Subscriptions are managed by business owners.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
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
          elevation: 0,
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
              child: const Text('Skip', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: _isProcessing
            ? const Center(child: CustomLoadingIndicator())
            : Consumer<BusinessProvider>(
                builder: (context, businessProvider, _) {
                  final currency =
                      businessProvider.currentBusiness?.currency ?? 'NGN';
                  final currencySymbol = _getCurrencySymbol(currency);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Select a subscription plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width:8),
                        Container(
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                                child: IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () async {
                                  try {
                                    await context.read<AuthProvider>().logout();
                                    if (context.mounted) Navigator.of(context).pushReplacementNamed(Routes.login);
                                  } catch (e) {
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
                                  }
                                }),
                              ),
                        const SizedBox(height: 16),
                        // Filter plans based on detected business tier (passed from signup when available)
                        ..._availablePlansForTier(widget.businessTier).map((plan) {
                          final isSelected = _selectedPlanId == plan.id;
                          return _buildPlanCard(
                            plan: plan,
                            isSelected: isSelected,
                            currencySymbol: currencySymbol,
                            onTap: () {
                              setState(() {
                                _selectedPlanId = plan.id;
                              });
                            },
                          );
                        }),
                        const SizedBox(height: 32),
                        _buildBankDetailsSection(currency),
                        const SizedBox(height: 24),
                        _buildUploadReceiptSection(currency),
                        const SizedBox(height: 24),
                        if (_selectedReceipt != null) _buildReceiptPreview(),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _selectedReceipt == null || _isProcessing
                              ? null
                              : () => _submitReceipt(context, currency),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: const Text(
                            'Submit Receipt for Approval',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'How it works',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '1. Select a subscription plan\n'
                                '2. Upload a receipt of your payment\n'
                                '3. Submit for admin review\n'
                                '4. Receive approval notification\n'
                                '5. Subscription activated automatically',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
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
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(plan.durationInDays / 30).round()} month(s) access',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currencySymbol${plan.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '/${plan.durationInDays} days',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Features:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              ...plan.features.map((feature) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• $feature',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetailsSection(String currency) {
    const bankName = 'Moniepoint';
    const accountName = 'Manage Care Limited';
    const accountNumber = '5181766595';
    final currencySymbol = _getCurrencySymbol(currency);

    final selectedPlan = SubscriptionService.plans
        .firstWhere((plan) => plan.id == _selectedPlanId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        border: Border.all(color: AppColors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance,
                  color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transfer Payment Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Send $currencySymbol${selectedPlan.price.toStringAsFixed(0)} to the account below',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBankDetailRow('Bank Name', bankName),
          const SizedBox(height: 12),
          _buildBankDetailRow('Account Name', accountName),
          const SizedBox(height: 12),
          _buildBankDetailRowWithCopy('Account Number', accountNumber),
        ],
      ),
    );
  }

  Widget _buildBankDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBankDetailRowWithCopy(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _copyToClipboard(value);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.content_copy,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildUploadReceiptSection(String currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[50],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Upload Payment Receipt',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a screenshot or image of your payment receipt/proof',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _payWithFlutterwave(context, currency),
                  icon: const Icon(Icons.payment),
                  label: const Text('Pay with Flutterwave'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _pickReceiptFromCamera(),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _pickReceiptFromGallery(),
                  icon: const Icon(Icons.image),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _pickReceiptFile(),
                  icon: const Icon(Icons.file_present),
                  label: const Text('File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _sendViaEmail(),
                  icon: const Icon(Icons.email),
                  label: const Text('Send to Web Server via Email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _payWithFlutterwave(
      BuildContext context, String currency) async {
    final selectedPlan = SubscriptionService.plans
        .firstWhere((plan) => plan.id == _selectedPlanId);
    final userId = widget.userId;
    if (userId.isEmpty) {
      _showError('User ID missing. Please login again.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Fetch public key from Firestore secure/secure
      final publicKey = await PaymentService().getPublicKey();
      if (publicKey == null || publicKey.isEmpty) {
        _showError(
            'Payment public key not configured. Please contact support.');
        return;
      }

      final txRef = 'sub_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;

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

      if (paymentResult['success'] == true) {
        final transactionId = paymentResult['transactionId'] ?? txRef;
        final now = DateTime.now();
        
        // Create subscription_requests entry for admin tracking (Flutterwave auto-approval)
        try {
          final uploadId = 'FLW_${userId}_${DateTime.now().millisecondsSinceEpoch}';
          await FirebaseFirestore.instance
              .collection('subscription_requests')
              .doc(uploadId)
              .set({
            'uploadId': uploadId,
            'userId': userId,
            'businessId': businessId ?? '',
            'planId': _selectedPlanId,
            'planName': selectedPlan.name,
            'amount': selectedPlan.price,
            'currency': currency,
            'userEmail': widget.userEmail,
            'userName': widget.userName,
            'receiptUrl': 'flutterwave:$transactionId',
            'status': 'approved', // Flutterwave auto-approves after success
            'paymentMethod': 'flutterwave',
            'paymentProcessor': 'flutterwave',
            'processorTransactionId': transactionId,
            'createdAt': now.toIso8601String(),
            'approvedAt': now.toIso8601String(),
            'approvedBy': 'system',
            'updatedAt': now.toIso8601String(),
            'subscriptionStatus': 'approved',
            'subscriptionAmount': selectedPlan.price,
            'subscriptionReceiptUrl': 'flutterwave:$transactionId',
            'subscriptionPlan': _selectedPlanId,
            'notes': 'Flutterwave payment - auto-approved on success',
            'receiptPath': null,
          });
          print('[SubscriptionPaymentScreen] ✓ Subscription request created for Flutterwave payment');
        } catch (e) {
          print('[SubscriptionPaymentScreen] ⚠ Warning: Could not create subscription_requests entry: $e');
        }
        
        // Log Flutterwave transaction for admin tracking
        try {
          await FirebaseFirestore.instance
              .collection('payment_transactions')
              .add({
            'transactionId': transactionId,
            'businessId': businessId ?? '',
            'email': widget.userEmail,
            'amount': selectedPlan.price,
            'currency': currency,
            'method': 'flutterwave',
            'status': 'completed',
            'paymentProcessor': 'flutterwave',
            'processorTransactionId': transactionId,
            'createdAt': now.toIso8601String(),
            'processorResponse': paymentResult['processorResponse'],
            'subscriptionPayment': true,
            'planId': _selectedPlanId,
            'userId': userId,
            'userName': widget.userName,
            'userEmail': widget.userEmail,
          });
          print('[SubscriptionPaymentScreen] ✓ Flutterwave transaction logged');
        } catch (e) {
          print('[SubscriptionPaymentScreen] ⚠ Warning: Could not log transaction: $e');
        }
        
        // Activate subscription immediately
        final subscriptionService =
            SubscriptionService(firestore: FirebaseFirestore.instance);
        final currentBusinessId = businessId ?? '';
        final activated =
            await subscriptionService.activateSubscriptionImmediately(
          userId: userId,
          planId: _selectedPlanId,
          receiptUrl: 'flutterwave:$transactionId',
          amount: selectedPlan.price,
          businessId: currentBusinessId.isNotEmpty ? currentBusinessId : null,
        );

        if (!activated) {
          // fallback to set user doc
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'hasActiveSubscription': true,
            'subscriptionPlan': _selectedPlanId,
            'subscriptionStatus': 'active',
            'subscriptionReceiptUrl': 'flutterwave:$transactionId',
            'subscriptionAmount': selectedPlan.price,
            'subscriptionRequestDate': now.toIso8601String(),
            'paymentMethod': 'flutterwave',
            'flutterwaveTransactionId': transactionId,
            'updatedAt': now.toIso8601String(),
          }, SetOptions(merge: true));
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✓ Payment successful and subscription activated'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));

          Navigator.of(context)
              .pushReplacementNamed('/subscription-status', arguments: {
            'userId': userId,
            'userEmail': widget.userEmail,
            'userName': widget.userName,
            'subscriptionPlan': _selectedPlanId,
            'subscriptionAmount': selectedPlan.price,
          });
        }
      } else {
        _showError(
            'Payment failed: ${paymentResult['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showError('Payment error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildReceiptPreview() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green, width: 2),
            borderRadius: BorderRadius.circular(12),
            color: Colors.green[50],
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(height: 8),
              Text(
                'Receipt Selected',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedReceipt!.path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _selectedReceipt = null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Change Receipt'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickReceiptFromCamera() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (image != null) {
        setState(() {
          _selectedReceipt = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image from camera: $e');
    }
  }

  Future<void> _pickReceiptFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        setState(() {
          _selectedReceipt = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image from gallery: $e');
    }
  }

  Future<void> _pickReceiptFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedReceipt = File(result.files.first.path!);
        });
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
      if (result != null && result.files.isNotEmpty) {
        final selectedFile = File(result.files.first.path!);
        final selectedPlan = SubscriptionService.plans
            .firstWhere((plan) => plan.id == _selectedPlanId);

        print(
            '[SubscriptionPaymentScreen] ▶ Uploading receipt via email service');
        print('[SubscriptionPaymentScreen] File: ${selectedFile.path}');
        print('[SubscriptionPaymentScreen] Plan: ${selectedPlan.name}');
        print(
            '[SubscriptionPaymentScreen] User: ${widget.userName} (${widget.userEmail})');

        setState(() => _isProcessing = true);

        final emailService = EmailService();
        final uploadUrl = await emailService.uploadFile(selectedFile);

        print('[SubscriptionPaymentScreen] Upload result: $uploadUrl');

        if (uploadUrl != null) {
          print('[SubscriptionPaymentScreen] ✓ Upload successful');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Receipt uploaded to server successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
          // Clear receipt preview after successful upload
          setState(() => _selectedReceipt = null);
        } else {
          print('[SubscriptionPaymentScreen] ✗ Upload failed - null returned');
          if (mounted) {
            _showError('Failed to upload receipt. Please try again.');
          }
        }
      }
    } catch (e) {
      print('[SubscriptionPaymentScreen] ✗ Exception: $e');
      _showError('Error uploading receipt: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _submitReceipt(BuildContext context, String currency) async {
    if (_selectedReceipt == null) {
      _showError('Please select a receipt first');
      return;
    }

    print('[SubscriptionPaymentScreen] ▶ Receipt submission initiated');

    final selectedPlan = SubscriptionService.plans
        .firstWhere((plan) => plan.id == _selectedPlanId);

    setState(() {
      _isProcessing = true;
    });

    // Capture context values BEFORE any async operations
    final userId = widget.userId;
    // Defensive: Check if userId is valid
    if (userId.isEmpty) {
      _showError('User ID is missing. Please log in again.');
      setState(() => _isProcessing = false);
      return;
    }
    // Capture navigator state early, before widget might be disposed
    final navigator = Navigator.of(context);
    final navigationArguments = {
      'userId': userId,
      'userEmail': widget.userEmail,
      'userName': widget.userName,
      'subscriptionPlan': _selectedPlanId,
      'subscriptionAmount': selectedPlan.price,
    };

    try {
      print('[SubscriptionPaymentScreen] Selected plan: $_selectedPlanId');
      print(
          '[SubscriptionPaymentScreen] Plan: ${selectedPlan.name} | Amount: ${selectedPlan.price}');

      print(
          '[SubscriptionPaymentScreen] ▶ Creating subscription request via ReceiptUploadService...');
      final receiptService = ReceiptUploadService();
      final currentBusinessId =
          context.read<BusinessProvider>().currentBusiness?.id ?? '';
      final result = await receiptService.uploadReceipt(
        userId: userId,
        businessId: currentBusinessId,
        planId: _selectedPlanId,
        planName: selectedPlan.name,
        amount: selectedPlan.price,
        currency: currency,
        receiptFile: _selectedReceipt!,
        userEmail: widget.userEmail,
        userName: widget.userName,
      );

      print('[SubscriptionPaymentScreen] Upload result: ${result.uploadId}');
      final uploadUrl = result.receiptUrl;

      // Check if widget is still mounted after async operation
      if (!mounted) {
        print(
            '[SubscriptionPaymentScreen] ⚠ Widget disposed, skipping status update');
        return;
      }

      if (uploadUrl != null) {
        print(
            '[SubscriptionPaymentScreen] ✓ Receipt uploaded successfully to: $uploadUrl');

        // Activate subscription immediately so user isn't disturbed until next reminder
        print(
            '[SubscriptionPaymentScreen] ▶ Activating subscription immediately...');
        try {
          final subscriptionService = SubscriptionService(
            firestore: FirebaseFirestore.instance,
          );

          final currentBusinessId =
              context.read<BusinessProvider>().currentBusiness?.id ?? '';
          final activated =
              await subscriptionService.activateSubscriptionImmediately(
            userId: userId,
            planId: _selectedPlanId,
            receiptUrl: uploadUrl,
            amount: selectedPlan.price,
            businessId: currentBusinessId.isNotEmpty ? currentBusinessId : null,
          );

          if (activated) {
            print(
                '[SubscriptionPaymentScreen] ✓ Subscription activated successfully!');
          } else {
            print(
                '[SubscriptionPaymentScreen] ⚠ Warning: Could not activate subscription');
            // Continue anyway - receipt was uploaded successfully
          }
        } catch (activationError) {
          print(
              '[SubscriptionPaymentScreen] ⚠ Warning: Activation error: $activationError');
          // Fallback: manually update status using set with merge to handle missing documents
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
            if (!userDoc.exists) {
              print(
                  '[SubscriptionPaymentScreen] ⚠ User document not found for userId: $userId');
              _showError('User not found. Please contact support.');
            } else {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .set({
                'hasActiveSubscription': true,
                'subscriptionPlan': _selectedPlanId,
                'subscriptionStatus': 'active',
                'subscriptionReceiptUrl': uploadUrl,
                'subscriptionAmount': selectedPlan.price,
                'subscriptionRequestDate': DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
              }, SetOptions(merge: true));
              print(
                  '[SubscriptionPaymentScreen] ✓ Subscription marked as pending approval');
            }
          } catch (updateError) {
            print(
                '[SubscriptionPaymentScreen] ⚠ Warning: Could not update subscription status: $updateError');
            _showError(
                'Could not update subscription status. Please try again or contact support.');
          }
        }

        // Delay before navigation to ensure Firestore writes complete
        await Future.delayed(const Duration(milliseconds: 500));

        // Use the captured navigator to safely navigate
        try {
          navigator.pushReplacementNamed(
            '/subscription-status',
            arguments: navigationArguments,
          );
        } catch (navError) {
          print('[SubscriptionPaymentScreen] ⚠ Navigation error: $navError');
          // If navigation fails, just log it - subscription was already activated
        }
      } else {
        print(
            '[SubscriptionPaymentScreen] ✗ Upload failed - null returned from EmailService');
        if (mounted) {
          _showError('Failed to upload receipt. Please try again.');
        }
      }
    } catch (e, stackTrace) {
      print('[SubscriptionPaymentScreen] ✗ ERROR: $e');
      print('[SubscriptionPaymentScreen] Stack trace: $stackTrace');

      if (mounted) {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
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
      'NGN': '₦',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'KES': 'Ksh',
      'ZAR': 'R',
    };
    return symbols[currency] ?? currency;
  }
}

