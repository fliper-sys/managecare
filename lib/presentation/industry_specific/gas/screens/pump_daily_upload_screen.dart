import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/email_service.dart';

class PumpDailyUploadScreen extends StatefulWidget {
  const PumpDailyUploadScreen({super.key});

  @override
  State<PumpDailyUploadScreen> createState() => _PumpDailyUploadScreenState();
}

class _PumpDailyUploadScreenState extends State<PumpDailyUploadScreen> {
  final _openingController = TextEditingController();
  final _closingController = TextEditingController();
  final _cashController = TextEditingController();
  final _posController = TextEditingController();
  String? _selectedPumpId;
  String? _openingPhotoUrl;
  String? _closingPhotoUrl;
  bool _isSaving = false;
  double? _previousClosingVolume;

  @override
  void dispose() {
    _openingController.dispose();
    _closingController.dispose();
    _cashController.dispose();
    _posController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>>? _collection(String name) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection(name);
  }

  Future<void> _loadPreviousClosing(String pumpId) async {
    final uploads = _collection('pump_daily_uploads');
    if (uploads == null) return;
    final snapshot = await uploads
        .where('pumpId', isEqualTo: pumpId)
        .orderBy('uploadedAt', descending: true)
        .limit(1)
        .get();
    final value = snapshot.docs.isEmpty
        ? null
        : (snapshot.docs.first.data()['closingVolume'] as num?)?.toDouble();
    if (!mounted) return;
    setState(() {
      _previousClosingVolume = value;
      if (value != null && _openingController.text.trim().isEmpty) {
        _openingController.text = value.toStringAsFixed(3);
      }
    });
  }

  Future<void> _pickAndUploadPhoto(bool opening) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _isSaving = true);
    try {
      final url = await EmailService().uploadFile(File(picked.path));
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo upload failed')),
        );
        return;
      }
      setState(() {
        if (opening) {
          _openingPhotoUrl = url;
        } else {
          _closingPhotoUrl = url;
        }
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveUpload(Map<String, dynamic> pump) async {
    final uploads = _collection('pump_daily_uploads');
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (uploads == null || businessId == null || _selectedPumpId == null) return;

    final opening = double.tryParse(_openingController.text.trim()) ?? 0.0;
    final closing = double.tryParse(_closingController.text.trim()) ?? 0.0;
    final cash = double.tryParse(_cashController.text.trim()) ?? 0.0;
    final pos = double.tryParse(_posController.text.trim()) ?? 0.0;
    if (closing <= opening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Closing volume must exceed opening volume')),
      );
      return;
    }
    if (_previousClosingVolume != null &&
        (opening - _previousClosingVolume!).abs() > 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opening volume must match previous closing (${_previousClosingVolume!.toStringAsFixed(3)})',
          ),
        ),
      );
      return;
    }
    if (_openingPhotoUrl == null || _closingPhotoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload opening and closing photos')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final auth = context.read<AuthProvider>().currentUser;
      final productId = pump['productId']?.toString() ?? '';
      final price = (pump['productPrice'] as num?)?.toDouble() ?? 0.0;
      final soldVolume = closing - opening;
      final expectedAmount = soldVolume * price;
      final inventoryRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .doc(productId);
      final uploadRef = uploads.doc();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final inventorySnapshot = await transaction.get(inventoryRef);
        final inventoryData = inventorySnapshot.data() ?? <String, dynamic>{};
        final currentStock =
            (inventoryData['quantity'] as num?)?.toDouble() ??
                (inventoryData['stock'] as num?)?.toDouble() ??
                0.0;
        final newStock = (currentStock - soldVolume).clamp(0.0, 999999999.0);
        transaction.set(uploadRef, {
          'pumpId': _selectedPumpId,
          'pumpNumber': pump['pumpNumber'],
          'productId': productId,
          'productName': pump['productName'],
          'productUnit': pump['productUnit'],
          'productPrice': price,
          'openingVolume': opening,
          'closingVolume': closing,
          'soldVolume': soldVolume,
          'expectedAmount': expectedAmount,
          'cashAmount': cash,
          'posAmount': pos,
          'openingPhotoUrl': _openingPhotoUrl,
          'closingPhotoUrl': _closingPhotoUrl,
          'workerId': auth?.id,
          'workerName': auth?.fullName ?? auth?.email,
          'uploadedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'category': 'pump_daily_upload',
        });
        transaction.set(
          inventoryRef,
          {
            'quantity': newStock,
            'stock': newStock,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pump upload saved')),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pumps = _collection('pump_configurations');
    final soldVolume = (double.tryParse(_closingController.text.trim()) ?? 0) -
        (double.tryParse(_openingController.text.trim()) ?? 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Total Sales Upload')),
      body: pumps == null
          ? const Center(child: Text('No business selected'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: pumps
                  .where('isActive', isEqualTo: true)
                  .orderBy('pumpNumber')
                  .snapshots(includeMetadataChanges: true),
              builder: (context, snapshot) {
                final pumpDocs = snapshot.data?.docs ?? [];
                final selectedPump = pumpDocs
                    .where((doc) => doc.id == _selectedPumpId)
                    .map((doc) => doc.data())
                    .cast<Map<String, dynamic>?>()
                    .firstWhere((pump) => pump != null, orElse: () => null);
                final price =
                    (selectedPump?['productPrice'] as num?)?.toDouble() ?? 0.0;
                final expectedAmount = soldVolume > 0 ? soldVolume * price : 0.0;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedPumpId,
                      decoration: const InputDecoration(
                        labelText: 'Select pump',
                        border: OutlineInputBorder(),
                      ),
                      items: pumpDocs
                          .map(
                            (doc) => DropdownMenuItem(
                              value: doc.id,
                              child: Text(
                                'Pump ${doc.data()['pumpNumber']} - ${doc.data()['productName']}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedPumpId = value);
                        if (value != null) _loadPreviousClosing(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _isSaving ? null : () => _pickAndUploadPhoto(true),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(_openingPhotoUrl == null
                                ? 'Opening Photo'
                                : 'Opening Uploaded'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _pickAndUploadPhoto(false),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(_closingPhotoUrl == null
                                ? 'Closing Photo'
                                : 'Closing Uploaded'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _openingController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Opening volume',
                        helperText: _previousClosingVolume == null
                            ? 'No previous closing recorded for this pump'
                            : 'Must match previous closing: ${_previousClosingVolume!.toStringAsFixed(3)}',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _closingController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Closing volume',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        title: const Text('Calculated sales'),
                        subtitle: Text(
                          '${soldVolume.clamp(0.0, 999999999.0).toStringAsFixed(3)} volume'
                          ' x ${price.toStringAsFixed(2)}',
                        ),
                        trailing: Text(expectedAmount.toStringAsFixed(2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cashController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cash amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _posController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'POS / transfer / card amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isSaving || selectedPump == null
                          ? null
                          : () => _saveUpload(selectedPump),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Submit Upload'),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
