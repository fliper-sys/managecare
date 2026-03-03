import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/snackbar_service.dart';
import '../../../services/file_upload_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';

class InstallationReceiptUploadScreen extends StatefulWidget {
  const InstallationReceiptUploadScreen({super.key});

  @override
  State<InstallationReceiptUploadScreen> createState() => _InstallationReceiptUploadScreenState();
}

class _InstallationReceiptUploadScreenState extends State<InstallationReceiptUploadScreen> {
  String? _selectedRequestId;
  PlatformFile? _pickedFile;
  bool _isUploading = false;

  Future<List<QueryDocumentSnapshot>> _fetchRequests() async {
    final bp = Provider.of<BusinessProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (bp.currentBusiness == null || auth.currentUser == null) return [];

    final snap = await FirebaseFirestore.instance.collection('product_installation_requests')
      .where('businessId', isEqualTo: bp.currentBusiness!.id)
      .where('userId', isEqualTo: auth.currentUser!.id)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .get();

    return snap.docs;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false, type: FileType.any, withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _pickedFile = result.files.single;
    });
  }

  Future<void> _uploadReceipt() async {
    if (_selectedRequestId == null) {
      SnackBarService.showError(context, 'Select a request to attach the receipt to');
      return;
    }
    if (_pickedFile == null) {
      SnackBarService.showError(context, 'Select a receipt file to upload');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uploader = FileUploadService();
      String? url;

      // Prefer a File upload when a native path is available, otherwise upload bytes (web)
      if (_pickedFile!.path != null && _pickedFile!.path!.isNotEmpty) {
        final file = File(_pickedFile!.path!);
        url = await uploader.uploadFile(file);
      } else if (_pickedFile!.bytes != null) {
        url = await uploader.uploadBytes(_pickedFile!.bytes!, _pickedFile!.name);
      } else {
        throw Exception('Unable to read selected file for upload.');
      }

      if (url == null) throw Exception(uploader.lastError ?? 'Upload failed');

      final uploadId = 'INST_PAY_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('installation_payments').doc(uploadId).set({
        'uploadId': uploadId,
        'requestId': _selectedRequestId,
        'receiptUrl': url,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Link payment to installation request for easier admin workflow and user feedback
      final reqRef = FirebaseFirestore.instance.collection('product_installation_requests').doc(_selectedRequestId);
      await reqRef.set({
        'lastPaymentId': uploadId,
        'paymentStatus': 'uploaded', // uploaded | pending_confirmation | confirmed
        'paymentUploadedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      SnackBarService.showSnackBar(context: context, message: 'Receipt uploaded and submitted for admin approval');
      setState(() {
        _pickedFile = null;
        _selectedRequestId = null;
      });
    } catch (e) {
      SnackBarService.showError(context, 'Failed to upload receipt: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Installation Receipt')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Attach a payment receipt to an installation request'),
            const SizedBox(height: 12),
            const Text(
              'How installation works:\n• Submit a request — an officer will be scheduled to evaluate stock before payment.\n• Wait until an evaluation is scheduled or completed before uploading a receipt.\n• Upload a receipt here and the admin will confirm it. You will be notified once payment is approved.',
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<QueryDocumentSnapshot>>(
              future: _fetchRequests(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final docs = (snap.data ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] as String?) ?? 'pending';
                  final paymentStatus = (data['paymentStatus'] as String?) ?? 'unpaid';
                  // Show requests that are not rejected and are relevant for uploading receipts
                  return status != 'rejected' && paymentStatus != 'confirmed' && (status == 'pending' || status == 'scheduled' || status == 'evaluated');
                }).toList();

                // Ensure a selected request is set so the upload button works without manual selection
                if (_selectedRequestId == null && docs.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _selectedRequestId == null) setState(() => _selectedRequestId = docs.first.id);
                  });
                }

                if (docs.isEmpty) return const Text('No installation requests found. Apply for installation first.');

                // Allow selection and show contextual info about the chosen request
                QueryDocumentSnapshot? selectedDoc;
                for (final d in docs) {
                  if (d.id == _selectedRequestId) {
                    selectedDoc = d;
                    break;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedRequestId,
                      items: docs.map((d) {
                        final data = d.data() as Map<String, dynamic>?;
                        final status = data?['status'] ?? 'unknown';
                        final total = data?['total'] ?? '0';
                        return DropdownMenuItem(value: d.id, child: Text('${d.id} • $status • ₦$total'));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedRequestId = v),
                      decoration: const InputDecoration(labelText: 'Select request'),
                    ),
                    const SizedBox(height: 8),
                    if (selectedDoc != null)
                      Builder(builder: (ctx) {
                        final sdata = selectedDoc!.data() as Map<String, dynamic>;
                        final status = (sdata['status'] as String?) ?? 'pending';
                        final evalTs = sdata['evaluationDate'] as Timestamp?;
                        final evalDate = evalTs?.toDate();
                        final paymentStatus = (sdata['paymentStatus'] as String?) ?? 'unpaid';

                        final List<Widget> msgs = [];
                        if (status == 'pending' && evalDate == null) msgs.add(const Text('This request is pending; we recommend waiting until an evaluation is scheduled before uploading payment.'));
                        if (status == 'scheduled' && evalDate != null) msgs.add(Text('Evaluation scheduled: ${evalDate.toLocal()}'));
                        if (paymentStatus == 'uploaded') msgs.add(const Text('A receipt has been uploaded for this request and awaits admin confirmation.'));

                        if (msgs.isEmpty) return const SizedBox.shrink();
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: msgs);
                      })
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.upload_file), label: const Text('Choose Receipt File')),
            const SizedBox(height: 8),
            if (_pickedFile != null) Text('Selected: ${_pickedFile!.name}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadReceipt,
              child: _isUploading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Upload Receipt'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[200]!)),
              child: const Text('Note: Receipts are submitted to admin for approval. Installation officers will evaluate physical stock before payment is processed.'),
            ),
          ],
        ),
      ),
    );
  }
}
