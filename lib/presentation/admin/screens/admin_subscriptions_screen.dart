import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../../../services/subscription_service.dart';
import '../../../services/subscription_storage_service.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/marketer_provider.dart';
import '../../../models/marketer_model.dart';

class AdminSubscriptionsScreen extends StatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  State<AdminSubscriptionsScreen> createState() => _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen> {
  bool _isLoading = false;
  File? _selectedReceipt;
  List<Map<String, dynamic>> _businesses = [];
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('businesses')
          .limit(50)
          .get();
      _businesses = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('[AdminSubscriptions] Error loading businesses: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to load businesses: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickReceiptAndActivate(Map<String, dynamic> business, SubscriptionPlan plan) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      _selectedReceipt = File(image.path);
      _isLoading = true;
    });

    try {
      final storageService = SubscriptionStorageService();
      final ownerId = business['ownerId']?.toString() ?? '';
      final uploadResult = await storageService.uploadSubscriptionProofWithProgress(
        _selectedReceipt!,
        ownerId,
        plan.id,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _uploadProgress = progress);
          }
        },
      );

      if (!uploadResult.success || uploadResult.downloadUrl == null) {
        throw Exception('Upload failed: ${uploadResult.error ?? 'Unknown error'}');
      }

      final receiptUrl = uploadResult.downloadUrl!;

      final businessId = business['id'] as String;

      final subscriptionService = SubscriptionService(firestore: FirebaseFirestore.instance);
      final success = await subscriptionService.activateSubscriptionImmediately(
        userId: ownerId,
        planId: plan.id,
        receiptUrl: receiptUrl,
        amount: plan.price,
        businessId: businessId,
      );

      setState(() {
        _isLoading = false;
        _uploadProgress = 0.0;
      });

      if (success) {
        // Log approval to subscription_approvals for audit
        try {
          await FirebaseFirestore.instance.collection('subscription_approvals').add({
            'userId': ownerId,
            'userName': business['ownerName'] ?? business['ownerId'] ?? 'Unknown',
            'userEmail': business['ownerEmail'] ?? '',
            'planId': plan.id,
            'planName': plan.name,
            'amount': plan.price,
            'receiptUrl': receiptUrl,
            'approvedAt': DateTime.now().toIso8601String(),
            'approvedBy': 'admin',
            'status': 'approved',
          });
        } catch (_) {}

        // handle marketer referral if provided
        try {
          final marketerEmail = business['referralEmail']?.toString();
          if (marketerEmail != null && marketerEmail.isNotEmpty) {
            // create referral record and update marketer balance
            final commission = plan.price * 0.1; // 10% commission example
            await FirebaseFirestore.instance.collection('referrals').add({
              'marketerEmail': marketerEmail,
              'userId': ownerId,
              'userEmail': business['ownerEmail'] ?? '',
              'businessId': businessId,
              'commissionAmount': commission,
              'status': 'approved',
              'createdAt': FieldValue.serverTimestamp(),
              'approvedAt': FieldValue.serverTimestamp(),
              'approvingAdminId': 'admin',
            });

            // increment balance via provider (ensure list loaded)
            final marketerProv = context.read<MarketerProvider>();
            await marketerProv.fetchMarketers();
            final m = marketerProv.marketers.firstWhere(
                (x) => x.email.toLowerCase() == marketerEmail.toLowerCase(),
                orElse: () => MarketerModel(
                    id: '',
                    email: '',
                    fullName: '',
                    password: '',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now()));
            if (m.id.isNotEmpty) {
              await marketerProv.updateMarketerBalance(m.id, commission);
              try {
                await FirebaseFirestore.instance
                    .collection('app_marketers')
                    .doc(m.id)
                    .update({
                  'referredUserIds': FieldValue.arrayUnion([ownerId])
                });
              } catch (_) {}
            }
          }
        } catch (e) {
          // ignore failures
          debugPrint('Referral processing failed: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Subscription activated successfully'),
          backgroundColor: Colors.green,
        ));
        await _loadBusinesses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to activate subscription'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _uploadProgress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _confirmActivateWithoutReceipt(Map<String, dynamic> business, SubscriptionPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activate without receipt'),
        content: Text('Activate ${business['name'] ?? 'this business'} for ${plan.name} without a receipt?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Activate')),
        ],
      ),
    );

    if (confirmed == true) {
      await _activateWithoutReceipt(business, plan);
    }
  }

  Future<void> _activateWithoutReceipt(Map<String, dynamic> business, SubscriptionPlan plan) async {
    setState(() => _isLoading = true);
    try {
      final ownerId = business['ownerId']?.toString() ?? '';
      final businessId = business['id'] as String;
      if (ownerId.isEmpty) throw Exception('Business owner not set');

      final subscriptionService = SubscriptionService(firestore: FirebaseFirestore.instance);
      final success = await subscriptionService.activateSubscriptionImmediately(
        userId: ownerId,
        planId: plan.id,
        receiptUrl: '', // no receipt
        amount: plan.price,
        businessId: businessId,
      );

      if (success) {
        // Log approval to subscription_approvals for audit
        try {
          await FirebaseFirestore.instance.collection('subscription_approvals').add({
            'userId': ownerId,
            'userName': business['ownerName'] ?? business['ownerId'] ?? 'Unknown',
            'userEmail': business['ownerEmail'] ?? '',
            'planId': plan.id,
            'planName': plan.name,
            'amount': plan.price,
            'receiptUrl': '',
            'approvedAt': DateTime.now().toIso8601String(),
            'approvedBy': 'admin',
            'status': 'approved',
            'note': 'Activated by admin without receipt',
          });
        } catch (_) {}

        // referral logic similar to above
        try {
          final marketerEmail = business['referralEmail']?.toString();
          if (marketerEmail != null && marketerEmail.isNotEmpty) {
            final commission = plan.price * 0.1;
            await FirebaseFirestore.instance.collection('referrals').add({
              'marketerEmail': marketerEmail,
              'userId': ownerId,
              'userEmail': business['ownerEmail'] ?? '',
              'businessId': businessId,
              'commissionAmount': commission,
              'status': 'approved',
              'createdAt': FieldValue.serverTimestamp(),
              'approvedAt': FieldValue.serverTimestamp(),
              'approvingAdminId': 'admin',
            });
            final marketerProv = context.read<MarketerProvider>();
            await marketerProv.fetchMarketers();
            final m = marketerProv.marketers.firstWhere(
                (x) => x.email.toLowerCase() == marketerEmail.toLowerCase(),
                orElse: () => MarketerModel(
                    id: '',
                    email: '',
                    fullName: '',
                    password: '',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now()));
            if (m.id.isNotEmpty) {
              await marketerProv.updateMarketerBalance(m.id, commission);
              try {
                await FirebaseFirestore.instance
                    .collection('app_marketers')
                    .doc(m.id)
                    .update({
                  'referredUserIds': FieldValue.arrayUnion([ownerId])
                });
              } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('Referral processing failed: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Subscription activated without receipt'),
          backgroundColor: Colors.green,
        ));
        await _loadBusinesses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to activate subscription'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPlanSelector(Map<String, dynamic> business) {
    final businessType = (business['businessType'] ?? business['type'] ?? 'retail')
        .toString();
    final available = SubscriptionService.getPlansForBusinessType(businessType);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        builder: (context, controller) => SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Select plan for ${business['name'] ?? 'Business'}', style: AppTextStyles.heading5),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: available
                        .map((plan) => Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(plan.name, style: AppTextStyles.heading5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '₦${plan.price.toStringAsFixed(0)}',
                                            style: AppTextStyles.body2.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Duration: ${plan.durationInDays} days',
                                      style: AppTextStyles.body2.copyWith(color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => _pickReceiptAndActivate(business, plan),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: const Text('Pay & Activate'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _confirmActivateWithoutReceipt(business, plan),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: const Text('No Receipt'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin – Subscriptions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
            child: const Text('Skip', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBusinesses,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _businesses.length,
                itemBuilder: (context, idx) {
                  final b = _businesses[idx];
                  final businessClass = (b['businessClass'] ?? 'tier1').toString();
                  final planId = (b['subscriptionPlan'] ?? 'none').toString();
                  final owner = (b['ownerId'] ?? 'unknown').toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      title: Text(b['name'] ?? 'Unknown Business', style: AppTextStyles.body1),
                      subtitle: Text('Owner: $owner • Class: $businessClass • Plan: $planId'),
                      trailing: ElevatedButton(
                        onPressed: () => _showPlanSelector(b),
                        child: const Text('Manage'),
                      ),
                    ),
                  );
                },

              ),
            ),
    );
  }
}
