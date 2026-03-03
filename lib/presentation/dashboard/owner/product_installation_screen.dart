import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/routes.dart';
import '../../../services/snackbar_service.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';

class ProductInstallationScreen extends StatefulWidget {
  const ProductInstallationScreen({super.key});

  @override
  State<ProductInstallationScreen> createState() => _ProductInstallationScreenState();
}

class _ProductInstallationScreenState extends State<ProductInstallationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storesController = TextEditingController(text: '1');
  final _productsController = TextEditingController(text: '100');
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  String? _requestId;

  @override
  void dispose() {
    _storesController.dispose();
    _productsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int _parseInt(TextEditingController c) {
    return int.tryParse(c.text.trim()) ?? 0;
  }

  int _basePricePerLocation(int productCount) {
    if (productCount <= 500) return 20000;
    if (productCount <= 1000) return 27800;
    if (productCount < 2000) return 40000;
    // For very large installs use custom quote, default to 40000
    return 40000;
  }

  void _calculateAndShow() {
    final products = _parseInt(_productsController);
    final stores = _parseInt(_storesController);

    final base = _basePricePerLocation(products);
    final subtotal = base * (stores <= 0 ? 1 : stores);
    final discount = subtotal * 0.10; // 10%
    final total = (subtotal - discount).round();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Installation Cost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Products: $products'),
            Text('Locations: $stores'),
            const SizedBox(height: 8),
            Text('Base price per location: ₦${base.toString()}'),
            Text('Subtotal: ₦${subtotal.toString()}'),
            Text('Discount (10%): ₦${discount.round().toString()}'),
            const Divider(),
            Text('Total: ₦${total.toString()}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    final bp = Provider.of<BusinessProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final products = _parseInt(_productsController);
    final stores = _parseInt(_storesController);

    if (bp.currentBusiness == null || auth.currentUser == null) {
      SnackBarService.showError(context, 'No business or user selected');
      return;
    }

    setState(() => _isSubmitting = true);

    final base = _basePricePerLocation(products);
    final subtotal = base * (stores <= 0 ? 1 : stores);
    final discount = subtotal * 0.10;
    final total = (subtotal - discount).round();

    try {
      final docRef = await FirebaseFirestore.instance.collection('product_installation_requests').add({
        'businessId': bp.currentBusiness!.id,
        'businessName': bp.currentBusiness!.name,
        'userId': auth.currentUser!.id,
        'userName': auth.currentUser!.fullName,
        'numberOfProducts': products,
        'numberOfLocations': stores,
        'basePricePerLocation': base,
        'subtotal': subtotal,
        'discountPercent': 10,
        'discountAmount': discount.round(),
        'total': total,
        'notes': _notesController.text.trim(),
        'status': 'pending', // pending | scheduled | evaluated | approved | rejected
        'paymentStatus': 'unpaid',
        'receiptConfirmed': false,
        'assignedOfficerName': null,
        'evaluationDate': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _requestId = docRef.id;
      });

      SnackBarService.showSnackBar(context: context, message: 'Request submitted. We will send an installation officer to evaluate stock before payment.');
    } catch (e) {
      SnackBarService.showError(context, 'Failed to submit request: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget _buildLiveRequestView() {
    if (_requestId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('product_installation_requests').doc(_requestId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>?; 
        if (data == null) return const SizedBox.shrink();

        final status = data['status'] as String? ?? 'pending';
        final assigned = data['assignedOfficerName'] as String?;
        final evalTs = data['evaluationDate'] as Timestamp?;
        final evalDate = evalTs?.toDate();
        final adminNotes = data['adminNotes'] as String? ?? '';
        final paymentStatus = data['paymentStatus'] as String? ?? 'unpaid';
        final lastPaymentId = data['lastPaymentId'] as String?;

        return Card(
          margin: const EdgeInsets.only(top: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Request status: ${status.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (assigned != null) Text('Assigned officer: $assigned'),
                if (evalDate != null) Text('Evaluation scheduled: ${evalDate.toLocal()}'),
                if (adminNotes.isNotEmpty) Text('Admin notes: $adminNotes'),
                const SizedBox(height: 8),
                Text('Payment status: ${paymentStatus.toUpperCase()}'),
                if (lastPaymentId != null) Text('Payment reference: $lastPaymentId'),
                const SizedBox(height: 8),
                if (status == 'evaluated')
                  const Text('Your request has been evaluated. Next steps will be provided by admin.'),
                if (status == 'approved')
                  const Text('Request approved. You will be notified of next steps.'),
                if (status == 'rejected')
                  const Text('Request rejected. Contact support for clarifications.'),
                if (status == 'pending' && evalDate == null)
                  const Text('Waiting for admin to schedule an evaluation visit.'),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Installation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Request a product installation visit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('A Manage Care installation officer will be sent to the shop location to evaluate stock before payment is made.'),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _storesController,
                    decoration: const InputDecoration(labelText: 'Number of locations', hintText: '1'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '0') ?? 0;
                      if (n <= 0) return 'Enter number of locations';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _productsController,
                    decoration: const InputDecoration(labelText: 'Number of products in range', hintText: 'e.g., 350'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '0') ?? 0;
                      if (n <= 0) return 'Enter number of products';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'e.g., special locations or SKUs'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _calculateAndShow,
                    child: const Text('Calculate Price'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: _isSubmitting ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Apply for Installation'),
                  ),
                  const SizedBox(height: 16),
                  if (_requestId != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Request created: $_requestId', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('You can upload a payment receipt independently via the "Upload Installation Receipt" option.'),
                        const SizedBox(height: 8),
                        ElevatedButton(onPressed: () => Navigator.pushNamed(context, Routes.installationReceiptUpload), child: const Text('Upload Installation Receipt')),
                      ],
                    ),                // Live admin-updated view for the created request
                _buildLiveRequestView(),                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
