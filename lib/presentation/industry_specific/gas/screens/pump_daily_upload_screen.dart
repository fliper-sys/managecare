import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../core/utils/amount_formatter.dart';
import '../../../../services/email_service.dart';
import '../utils/pump_config_cache.dart';
import '../utils/pump_daily_upload_validation.dart';

class PumpDailyUploadScreen extends StatefulWidget {
  const PumpDailyUploadScreen({super.key});

  @override
  State<PumpDailyUploadScreen> createState() => _PumpDailyUploadScreenState();
}

class _PumpDailyUploadScreenState extends State<PumpDailyUploadScreen> {
  final _analogClosingController = TextEditingController();
  final _analogOpeningController = TextEditingController();
  bool _cacheLoaded = false;
  List<Map<String, dynamic>> _cachedPumps = [];
  final _cashController = TextEditingController();
  final _closingController = TextEditingController();
  String? _closingPhotoPath;
  String? _closingPhotoUrl;
  bool _isLoadingPreviousClosing = false;
  bool _isSaving = false;
  String? _lastLoadedPumpId;
  String? _loadingPumpId;
  final _openingController = TextEditingController();
  String? _openingPhotoPath;
  String? _openingPhotoUrl;
  final _posController = TextEditingController();
  double? _previousAnalogClosingVolume;
  double? _previousClosingVolume;
  double? _previousShiftClosingCash;
  String? _selectedPumpId;
  final _shiftCloseCashController = TextEditingController();
  String? _shiftCloseCashPhotoPath;
  String? _shiftCloseCashPhotoUrl;
  final _shiftOpeningCashController = TextEditingController();
  String? _shiftOpeningCashPhotoPath;
  String? _shiftOpeningCashPhotoUrl;

  @override
  void dispose() {
    _openingController.dispose();
    _closingController.dispose();
    _analogOpeningController.dispose();
    _analogClosingController.dispose();
    _shiftOpeningCashController.dispose();
    _shiftCloseCashController.dispose();
    _cashController.dispose();
    _posController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCachedPumps());
  }

  CollectionReference<Map<String, dynamic>>? _collection(String name) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection(name);
  }

  Map<String, dynamic>? _getPumpById(
    List<Map<String, dynamic>> pumps,
    String? pumpId,
  ) {
    if (pumpId == null || pumpId.isEmpty) return null;
    for (final pump in pumps) {
      if (pump['id']?.toString() == pumpId) {
        return pump;
      }
    }
    return null;
  }

  Future<void> _loadCachedPumps() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;
    final cachedPumps = await PumpConfigCache.load(businessId);
    if (!mounted) return;
    setState(() {
      _cachedPumps = cachedPumps;
      _cacheLoaded = true;
    });
  }

  void _syncCacheFromSnapshot(
    String businessId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final remotePumps = PumpConfigCache.sort(
      docs.map(PumpConfigCache.fromDoc).toList(),
    );
    if (remotePumps.isEmpty || PumpConfigCache.same(remotePumps, _cachedPumps)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PumpConfigCache.save(businessId, remotePumps);
      if (!mounted) return;
      setState(() {
        _cachedPumps = remotePumps;
        _cacheLoaded = true;
      });
    });
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findLatestUpload(
    CollectionReference<Map<String, dynamic>> uploads,
    String pumpId, {
    String? pumpNumber,
  }) async {
    QuerySnapshot<Map<String, dynamic>>? snapshot;

    Future<QuerySnapshot<Map<String, dynamic>>?> runQuery(
      Query<Map<String, dynamic>> query,
    ) async {
      try {
        return await query.limit(1).get();
      } catch (error) {
        debugPrint('Pump upload query failed: $error');
        return null;
      }
    }

    snapshot = await runQuery(
      uploads
          .where('pumpId', isEqualTo: pumpId)
          .orderBy('uploadedAt', descending: true),
    );
    if (snapshot != null && snapshot.docs.isNotEmpty) {
      return snapshot.docs.first;
    }

    if (pumpNumber != null && pumpNumber.isNotEmpty) {
      snapshot = await runQuery(
        uploads
            .where('pumpNumber', isEqualTo: pumpNumber)
            .orderBy('uploadedAt', descending: true),
      );
      if (snapshot != null && snapshot.docs.isNotEmpty) {
        return snapshot.docs.first;
      }

      final numericPumpNumber = num.tryParse(pumpNumber);
      if (numericPumpNumber != null) {
        snapshot = await runQuery(
          uploads
              .where('pumpNumber', isEqualTo: numericPumpNumber)
              .orderBy('uploadedAt', descending: true),
        );
        if (snapshot != null && snapshot.docs.isNotEmpty) {
          return snapshot.docs.first;
        }
      }
    }

    // Last-resort fallback: inspect recent uploads for a matching pump ID or number.
    try {
      snapshot = await uploads.orderBy('uploadedAt', descending: true).limit(100).get();
    } catch (error) {
      debugPrint('Pump upload fallback scan failed: $error');
      return null;
    }

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['pumpId']?.toString() == pumpId) return doc;
      if (pumpNumber != null && pumpNumber.isNotEmpty) {
        if (data['pumpNumber']?.toString() == pumpNumber) return doc;
        final numericPumpNumber = num.tryParse(pumpNumber);
        if (numericPumpNumber != null && data['pumpNumber'] == numericPumpNumber) {
          return doc;
        }
      }
    }

    return null;
  }

  double? _parseNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().replaceAll(',', '').trim();
    return double.tryParse(text);
  }

  double _parseControllerValue(TextEditingController controller) {
    final text = controller.text.replaceAll(',', '').trim();
    return double.tryParse(text) ?? 0.0;
  }

  Future<void> _loadPreviousClosing(
    String pumpId, {
    String? pumpNumber,
  }) async {
    final uploads = _collection('pump_daily_uploads');
    if (uploads == null) return;
    if (_isLoadingPreviousClosing && _loadingPumpId == pumpId) return;

    setState(() {
      _isLoadingPreviousClosing = true;
      _loadingPumpId = pumpId;
      _previousClosingVolume = null;
    });

    try {
      final latest = await _findLatestUpload(
        uploads,
        pumpId,
        pumpNumber: pumpNumber,
      );
      final value = latest == null
          ? null
          : _parseNumber(latest.data()['closingVolume']);
      final previousShiftCash = latest == null
          ? null
          : _parseNumber(latest.data()['shiftCloseCash']);
      if (!mounted) return;
      setState(() {
        _previousClosingVolume = value;
        _previousShiftClosingCash = previousShiftCash;
        _lastLoadedPumpId = pumpId;
        if (value != null && _openingController.text.trim().isEmpty) {
          _openingController.text = value.toStringAsFixed(3);
        }
        if (previousShiftCash != null && _shiftOpeningCashController.text.trim().isEmpty) {
          _shiftOpeningCashController.text = previousShiftCash.toStringAsFixed(2);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPreviousClosing = false;
          _loadingPumpId = null;
          _lastLoadedPumpId = pumpId;
        });
      }
    }

    await _loadPreviousAnalogClosing(pumpId, pumpNumber: pumpNumber);
  }

  Future<void> _loadPreviousAnalogClosing(
    String pumpId, {
    String? pumpNumber,
  }) async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;

    final cachedValue = await PumpAnalogClosingCache.load(businessId, pumpId);
    double? value = cachedValue;

    final uploads = _collection('pump_daily_uploads');
    if (uploads != null) {
      final latest = await _findLatestUpload(
        uploads,
        pumpId,
        pumpNumber: pumpNumber,
      );
      if (latest != null) {
        final remoteValue = _parseNumber(latest.data()['analogClosingVolume']);
        if (remoteValue != null) {
          value = remoteValue;
        }
      }
    }

    if (value != null) {
      await PumpAnalogClosingCache.save(businessId, pumpId, value);
    }

    if (!mounted) return;
    setState(() {
      _previousAnalogClosingVolume = value;
      if (value != null && _analogOpeningController.text.trim().isEmpty) {
        _analogOpeningController.text = value.toStringAsFixed(3);
      }
    });
  }

  Future<void> _loadDraft(String pumpId) async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;
    final draft = await PumpUploadDraftCache.load(businessId, pumpId);
    if (!mounted || _selectedPumpId != pumpId) return;
    setState(() {
      _openingController.text = draft['openingVolume']?.toString() ??
          _openingController.text;
      _closingController.text = draft['closingVolume']?.toString() ?? '';
      _analogOpeningController.text =
          draft['analogOpeningVolume']?.toString() ?? '';
      _analogClosingController.text =
          draft['analogClosingVolume']?.toString() ?? '';
      _shiftOpeningCashController.text =
          draft['shiftOpeningCash']?.toString() ?? '';
      _shiftCloseCashController.text =
          draft['shiftCloseCash']?.toString() ?? '';
      _cashController.text = draft['todayPumpCash']?.toString() ?? '';
      _posController.text = draft['posAmount']?.toString() ?? '';
      _shiftOpeningCashPhotoUrl =
          draft['shiftOpeningCashPhotoUrl']?.toString();
      _shiftOpeningCashPhotoPath =
          draft['shiftOpeningCashPhotoPath']?.toString();
      _shiftCloseCashPhotoUrl =
          draft['shiftCloseCashPhotoUrl']?.toString();
      _shiftCloseCashPhotoPath =
          draft['shiftCloseCashPhotoPath']?.toString();
      _openingPhotoUrl = draft['openingPhotoUrl']?.toString();
      _openingPhotoPath = draft['openingPhotoPath']?.toString();
      _closingPhotoUrl = draft['closingPhotoUrl']?.toString();
      _closingPhotoPath = draft['closingPhotoPath']?.toString();
    });
  }

  Future<void> _saveDraft() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    final pumpId = _selectedPumpId;
    if (businessId == null ||
        businessId.isEmpty ||
        pumpId == null ||
        pumpId.isEmpty) {
      return;
    }
    await PumpUploadDraftCache.save(businessId, pumpId, {
      'openingVolume': _openingController.text.trim(),
      'closingVolume': _closingController.text.trim(),
      'analogOpeningVolume': _analogOpeningController.text.trim(),
      'analogClosingVolume': _analogClosingController.text.trim(),
      'shiftOpeningCash': _shiftOpeningCashController.text.trim(),
      'shiftCloseCash': _shiftCloseCashController.text.trim(),
      'todayPumpCash': _cashController.text.trim(),
      'posAmount': _posController.text.trim(),
      'shiftOpeningCashPhotoUrl': _shiftOpeningCashPhotoUrl,
      'shiftOpeningCashPhotoPath': _shiftOpeningCashPhotoPath,
      'shiftCloseCashPhotoUrl': _shiftCloseCashPhotoUrl,
      'shiftCloseCashPhotoPath': _shiftCloseCashPhotoPath,
      'openingPhotoUrl': _openingPhotoUrl,
      'openingPhotoPath': _openingPhotoPath,
      'closingPhotoUrl': _closingPhotoUrl,
      'closingPhotoPath': _closingPhotoPath,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  void _setPhotoDraft({
    required String kind,
    String? url,
    String? path,
  }) {
    setState(() {
      if (kind == 'shiftOpeningCash') {
        if (url != null) _shiftOpeningCashPhotoUrl = url;
        if (path != null) _shiftOpeningCashPhotoPath = path;
      } else if (kind == 'shiftCloseCash') {
        if (url != null) _shiftCloseCashPhotoUrl = url;
        if (path != null) _shiftCloseCashPhotoPath = path;
      } else if (kind == 'opening') {
        if (url != null) _openingPhotoUrl = url;
        if (path != null) _openingPhotoPath = path;
      } else {
        if (url != null) _closingPhotoUrl = url;
        if (path != null) _closingPhotoPath = path;
      }
    });
    _saveDraft();
  }

  Future<void> _pickAndUploadPhoto(String kind) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;
    if (!kIsWeb) {
      _setPhotoDraft(kind: kind, path: picked.path);
    }
    setState(() => _isSaving = true);
    try {
      String? url;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final filename = picked.name.isNotEmpty ? picked.name : 'photo.jpg';
        url = await EmailService().uploadBytes(bytes, filename);
      } else {
        url = await EmailService().uploadFile(File(picked.path));
      }
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo saved locally. It will upload on submit.'),
          ),
        );
        return;
      }
      _setPhotoDraft(kind: kind, url: url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo saved locally. It will upload on submit.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _ensurePhotoUrl({
    required String label,
    String? url,
    String? path,
  }) async {
    if (url != null && url.isNotEmpty) return url;
    if (path == null || path.isEmpty || kIsWeb) return null;
    try {
      return await EmailService().uploadFile(File(path));
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to upload $label image')),
      );
      return null;
    }
  }

  Future<Map<String, double>> _resolveCurrentProductInfo(
    String businessId,
    String productId,
    Map<String, dynamic> pump,
  ) async {
    final fallbackPrice = (pump['productPrice'] as num?)?.toDouble() ?? 0.0;
    if (productId.isEmpty) {
      return {'price': fallbackPrice};
    }

    final productDoc = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('inventory')
        .doc(productId)
        .get();

    final productData = productDoc.data();
    final currentPrice =
        (productData?['price'] as num?)?.toDouble() ?? fallbackPrice;

    if (currentPrice > 0) {
      if ((currentPrice - fallbackPrice).abs() > 0.0001) {
        final pumpId = pump['id']?.toString();
        if (pumpId != null && pumpId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('businesses')
              .doc(businessId)
              .collection('pump_configurations')
              .doc(pumpId)
              .set({'productPrice': currentPrice}, SetOptions(merge: true));
          await PumpConfigCache.upsert(businessId, pumpId, {
            ...pump,
            'productPrice': currentPrice,
          });
        }
      }
    }

    return {'price': currentPrice};
  }

  double _currentProductPrice(
    RetailProvider retail,
    Map<String, dynamic> pump,
  ) {
    final productId = pump['productId']?.toString() ?? '';
    if (productId.isEmpty) {
      return (pump['productPrice'] as num?)?.toDouble() ?? 0.0;
    }

    final product = retail.products.firstWhere(
      (prod) => prod.id == productId,
      orElse: () => Product(
        id: productId,
        name: pump['productName']?.toString() ?? 'Unknown',
        price: 0.0,
        stock: 0.0,
        category: 'Unknown',
      ),
    );

    return product.price > 0
        ? product.price
        : (pump['productPrice'] as num?)?.toDouble() ?? 0.0;
  }

  double _computeCalculatedSalesVolume(double opening, double closing, double price) {
    if (price <= 0) return 0.0;
    final rawVolume = (closing - opening).clamp(0.0, 999999999.0);
    if (rawVolume <= 0) return 0.0;
    final roundedVolume = double.parse(rawVolume.toStringAsFixed(3));
    if (roundedVolume <= 0) return 0.001;
    return roundedVolume < 0.001 ? 0.001 : roundedVolume;
  }

  double _computeCashBasedSalesVolume(
    double shiftOpeningCash,
    double shiftCloseCash,
    double price,
  ) {
    if (price <= 0) return 0.0;
    final cashDifference = (shiftCloseCash - shiftOpeningCash).clamp(0.0, 999999999.0);
    if (cashDifference <= 0) return 0.0;
    final volumeFromCash = cashDifference / price;
    final roundedVolume = double.parse(volumeFromCash.toStringAsFixed(3));
    if (roundedVolume <= 0) return 0.001;
    return roundedVolume < 0.001 ? 0.001 : roundedVolume;
  }

  Future<void> _saveUpload(Map<String, dynamic> pump) async {
    final uploads = _collection('pump_daily_uploads');
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (uploads == null || businessId == null || _selectedPumpId == null) return;

    final opening = double.tryParse(_openingController.text.trim()) ?? 0.0;
    final closing = double.tryParse(_closingController.text.trim()) ?? 0.0;
    final analogOpening =
        double.tryParse(_analogOpeningController.text.trim()) ?? 0.0;
    final analogClosing =
        double.tryParse(_analogClosingController.text.trim()) ?? 0.0;
    final shiftOpeningCash =
        _parseControllerValue(_shiftOpeningCashController);
    final shiftCloseCash =
        _parseControllerValue(_shiftCloseCashController);
    final cash = _parseControllerValue(_cashController);
    final pos = _parseControllerValue(_posController);
    final productId = pump['productId']?.toString() ?? '';

    final retail = context.read<RetailProvider>();
    await retail.loadProducts(forceRefresh: true);
    final productInfo =
        await _resolveCurrentProductInfo(businessId, productId, pump);
    final price = productInfo['price'] ?? 0.0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to resolve current product price')),
      );
      return;
    }

    // Pump volume from digital meter
    final digitalVolume = closing - opening;

    // Shift cash difference
    final shiftCashDifference = shiftCloseCash - shiftOpeningCash;
    final cashBasedSalesVolume = _computeCashBasedSalesVolume(
      shiftOpeningCash,
      shiftCloseCash,
      price,
    );

    final hasShiftCashEntry =
        _shiftOpeningCashController.text.trim().isNotEmpty ||
        _shiftCloseCashController.text.trim().isNotEmpty;

    // Volume sold is derived from the shift cash difference divided by price
    final calculatedSalesVolume = cashBasedSalesVolume;

    // Reconciliation checks are now recorded as notes rather than blocking the upload
    final hasAnalogEntry =
        _analogClosingController.text.trim().isNotEmpty &&
        _previousAnalogClosingVolume != null;

    final totalPaid = cash + pos;

    final shiftOpeningCashPhotoUrl = await _ensurePhotoUrl(
      label: 'shift opening cash',
      url: _shiftOpeningCashPhotoUrl,
      path: _shiftOpeningCashPhotoPath,
    );
    final shiftCloseCashPhotoUrl = await _ensurePhotoUrl(
      label: 'shift close cash',
      url: _shiftCloseCashPhotoUrl,
      path: _shiftCloseCashPhotoPath,
    );
    final openingPhotoUrl = await _ensurePhotoUrl(
      label: 'closing pump volume',
      url: _openingPhotoUrl,
      path: _openingPhotoPath,
    );
    final closingPhotoUrl = await _ensurePhotoUrl(
      label: 'Opening pump volume',
      url: _closingPhotoUrl,
      path: _closingPhotoPath,
    );
    _shiftOpeningCashPhotoUrl = shiftOpeningCashPhotoUrl;
    _shiftCloseCashPhotoUrl = shiftCloseCashPhotoUrl;
    _openingPhotoUrl = openingPhotoUrl;
    _closingPhotoUrl = closingPhotoUrl;
    await _saveDraft();

    setState(() => _isSaving = true);
    try {
      final auth = context.read<AuthProvider>().currentUser;
      final expectedAmount = calculatedSalesVolume * price;

      final paymentMethod = cash > 0 && pos > 0
          ? 'mixed'
          : pos > 0
              ? 'pos'
              : 'cash';

      // Use the cash-derived sales volume for the sale
      final saleData = await retail.fuelSale(
      productId: productId,
      quantity: calculatedSalesVolume,
      amountPaid: totalPaid > 0 ? totalPaid : null,
      paymentMethod: paymentMethod,
      workerId: auth?.id,
      workerName: auth?.fullName ?? auth?.email,
      pumpId: _selectedPumpId,
      pumpNumber: pump['pumpNumber']?.toString(),
      pumpName: pump['productName']?.toString(),
    );

    final discrepancyNotes = buildDiscrepancyNotes(
      opening: opening,
      closing: closing,
      analogClosing: analogClosing,
      shiftOpeningCash: shiftOpeningCash,
      shiftCloseCash: shiftCloseCash,
      cash: cash,
      pos: pos,
      digitalVolume: digitalVolume,
      shiftCashDifference: shiftCashDifference,
      price: price,
      expectedAmount: expectedAmount,
      totalPaid: totalPaid,
      hasShiftCashEntry: hasShiftCashEntry,
      hasAnalogEntry: hasAnalogEntry,
      previousClosingVolume: _previousClosingVolume,
      previousAnalogClosingVolume: _previousAnalogClosingVolume,
      productId: productId,
      shiftOpeningCashPhotoUrl: shiftOpeningCashPhotoUrl,
      shiftCloseCashPhotoUrl: shiftCloseCashPhotoUrl,
      openingPhotoUrl: openingPhotoUrl,
      closingPhotoUrl: closingPhotoUrl,
    );
    final discrepancySummary = formatDiscrepancySummary(discrepancyNotes);

    final uploadRef = uploads.doc();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.set(uploadRef, {
        'pumpId': _selectedPumpId,
        'pumpNumber': pump['pumpNumber'],
        'productId': productId,
        'productName': pump['productName'],
        'productUnit': pump['productUnit'],
        'productPrice': price,
        'openingVolume': opening,
        'closingVolume': closing,
        'digitalVolume': digitalVolume,
        'volumeDifference': digitalVolume,
        'analogOpeningVolume': analogOpening,
        'soldVolume': calculatedSalesVolume,
        'cashDerivedVolume': calculatedSalesVolume,
        'analogClosingVolume': analogClosing,
        'previousAnalogClosingVolume': _previousAnalogClosingVolume,
        'previousShiftClosingCash': _previousShiftClosingCash,
        'expectedAmount': expectedAmount,
        'discrepancyNotes': discrepancyNotes,
        'discrepancySummary': discrepancySummary,
        'shiftOpeningCash': shiftOpeningCash,
        'shiftCloseCash': shiftCloseCash,
        'shiftCashDifference': shiftCashDifference,
        'previousClosingVolume': _previousClosingVolume,
        'todayPumpCash': cash,
        'cashAmount': cash,
        'posAmount': pos,
        'totalPaid': totalPaid,
        'saleId': saleData['id'] ?? saleData['orderId'],
        'shiftOpeningCashPhotoUrl': shiftOpeningCashPhotoUrl,
        'shiftCloseCashPhotoUrl': shiftCloseCashPhotoUrl,
        'openingPhotoUrl': openingPhotoUrl,
        'closingPhotoUrl': closingPhotoUrl,
        'workerId': auth?.id,
        'workerName': auth?.fullName ?? auth?.email,
        'uploadedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'category': 'pump_daily_upload',
      });
    });
      await PumpAnalogClosingCache.save(businessId, _selectedPumpId!, analogClosing);
      await PumpUploadDraftCache.clear(businessId, _selectedPumpId!);

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
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Pump Volume Upload')),
      body: pumps == null
          ? const Center(child: Text('No business selected'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: pumps
                  .where('isActive', isEqualTo: true)
                  .snapshots(includeMetadataChanges: true),
              builder: (context, snapshot) {
                final pumpDocs = snapshot.data?.docs ?? [];
                if (businessId != null && businessId.isNotEmpty) {
                  _syncCacheFromSnapshot(businessId, pumpDocs);
                }
                final remotePumps = PumpConfigCache.sort(
                  pumpDocs.map(PumpConfigCache.fromDoc).toList(),
                );
                final availablePumps =
                    remotePumps.isNotEmpty ? remotePumps : _cachedPumps;
                final selectedPump = _getPumpById(availablePumps, _selectedPumpId);
                final selectedPumpId = selectedPump?['id']?.toString();
                if (selectedPumpId != null &&
                    _lastLoadedPumpId != selectedPumpId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final pumpNumber = selectedPump?['pumpNumber']?.toString();
                    _loadPreviousClosing(selectedPumpId, pumpNumber: pumpNumber);
                  });
                }
                final retail = context.watch<RetailProvider>();
                final price = selectedPump == null
                    ? 0.0
                    : _currentProductPrice(retail, selectedPump);
                // Calculate the sales volume from the meter difference for display
                final shiftOpeningCash =
                    _parseControllerValue(_shiftOpeningCashController);
                final shiftCloseCash =
                    _parseControllerValue(_shiftCloseCashController);
                final calculatedSalesVolume = _computeCashBasedSalesVolume(
                  shiftOpeningCash,
                  shiftCloseCash,
                  price,
                );
                final expectedAmount = calculatedSalesVolume * price;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedPumpId,
                      decoration: const InputDecoration(
                        labelText: 'Select pump',
                        border: OutlineInputBorder(),
                      ),
                      items: availablePumps
                          .map(
                            (pump) => DropdownMenuItem(
                              value: pump['id']?.toString(),
                              child: Text(
                                'Pump ${pump['pumpNumber']} - ${pump['productName']}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        final selectedPump = _getPumpById(availablePumps, value);
                        final pumpNumber = selectedPump?['pumpNumber']?.toString();
                        setState(() {
                          _selectedPumpId = value;
                          _previousClosingVolume = null;
                          _previousAnalogClosingVolume = null;
                          _previousShiftClosingCash = null;
                          _lastLoadedPumpId = null;
                          _shiftOpeningCashPhotoUrl = null;
                          _shiftOpeningCashPhotoPath = null;
                          _shiftCloseCashPhotoUrl = null;
                          _shiftCloseCashPhotoPath = null;
                          _openingPhotoUrl = null;
                          _openingPhotoPath = null;
                          _closingPhotoUrl = null;
                          _closingPhotoPath = null;
                          _openingController.clear();
                          _closingController.clear();
                          _analogOpeningController.clear();
                          _analogClosingController.clear();
                          _shiftOpeningCashController.clear();
                          _shiftCloseCashController.clear();
                          _cashController.clear();
                          _posController.clear();
                        });
                        if (value != null) {
                          _loadPreviousClosing(value, pumpNumber: pumpNumber);
                          _loadDraft(value);
                        }
                      },
                    ),
                    if (availablePumps.isEmpty && _cacheLoaded)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'No configured pumps found. Add a pump in Pump Configuration first.',
                        ),
                      ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Shift Cash Uploads',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _shiftOpeningCashController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: const [AmountInputFormatter()],
                              decoration: InputDecoration(
                                labelText: 'Shift opening cash value',
                                helperText: _previousShiftClosingCash == null
                                    ? 'No previous shift close cash found'
                                    : 'Default from previous shift close cash: ${_previousShiftClosingCash!.toStringAsFixed(2)}',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setState(() {});
                                _saveDraft();
                              },
                            ),
                            if (_previousShiftClosingCash != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Opening cash diff: ${(double.tryParse(_shiftOpeningCashController.text.trim()) ?? 0.0) - _previousShiftClosingCash! >= 0 ? '+' : ''}${(double.tryParse(_shiftOpeningCashController.text.trim()) ?? 0.0) - _previousShiftClosingCash!.toDouble()} from previous shift close',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () => _pickAndUploadPhoto(
                                        'shiftOpeningCash',
                                      ),
                              icon: Icon(
                                _shiftOpeningCashPhotoUrl == null &&
                                        _shiftOpeningCashPhotoPath == null
                                    ? Icons.camera_alt_outlined
                                    : Icons.check_circle_outline,
                                color: _shiftOpeningCashPhotoUrl == null &&
                                        _shiftOpeningCashPhotoPath == null
                                    ? null
                                    : Colors.green,
                              ),
                              label: Text(
                                _shiftOpeningCashPhotoUrl == null &&
                                        _shiftOpeningCashPhotoPath == null
                                    ? 'Upload shift opening cash image'
                                    : 'Shift opening cash image saved',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _shiftCloseCashController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: const [AmountInputFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Shift close cash value',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setState(() {});
                                _saveDraft();
                              },
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () => _pickAndUploadPhoto(
                                        'shiftCloseCash',
                                      ),
                              icon: Icon(
                                _shiftCloseCashPhotoUrl == null &&
                                        _shiftCloseCashPhotoPath == null
                                    ? Icons.camera_alt_outlined
                                    : Icons.check_circle_outline,
                                color: _shiftCloseCashPhotoUrl == null &&
                                        _shiftCloseCashPhotoPath == null
                                    ? null
                                    : Colors.green,
                              ),
                              label: Text(
                                _shiftCloseCashPhotoUrl == null &&
                                        _shiftCloseCashPhotoPath == null
                                    ? 'Upload shift close cash image'
                                    : 'Shift close cash image saved',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _pickAndUploadPhoto('opening'),
                            icon: Icon(
                              _openingPhotoUrl == null &&
                                      _openingPhotoPath == null
                                  ? Icons.camera_alt_outlined
                                  : Icons.check_circle_outline,
                              color: _openingPhotoUrl == null &&
                                      _openingPhotoPath == null
                                  ? null
                                  : Colors.green,
                            ),
                            label: Text(_openingPhotoUrl == null &&
                                    _openingPhotoPath == null
                                ? 'Closing pump volume upload'
                                : 'Closing pump volume saved'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _pickAndUploadPhoto('closing'),
                            icon: Icon(
                              _closingPhotoUrl == null &&
                                      _closingPhotoPath == null
                                  ? Icons.camera_alt_outlined
                                  : Icons.check_circle_outline,
                              color: _closingPhotoUrl == null &&
                                      _closingPhotoPath == null
                                  ? null
                                  : Colors.green,
                            ),
                            label: Text(_closingPhotoUrl == null &&
                                    _closingPhotoPath == null
                                ? 'Opening pump volume upload'
                                : 'Opening pump volume saved'),
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
                      inputFormatters: const [AmountInputFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Opening volume',
                        helperText: _isLoadingPreviousClosing
                            ? 'Loading previous Closing...'
                            : _previousClosingVolume == null
                                ? 'No previous Closing recorded for this pump'
                                : 'Default from previous Closing: ${_previousClosingVolume!.toStringAsFixed(3)}',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _saveDraft();
                      },
                    ),
                    if (_previousClosingVolume != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Opening diff: ${(double.tryParse(_openingController.text.trim()) ?? 0.0) - _previousClosingVolume! >= 0 ? '+' : ''}${(double.tryParse(_openingController.text.trim()) ?? 0.0) - _previousClosingVolume!.toDouble()} liters from previous close',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _closingController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [AmountInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Closing volume',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _saveDraft();
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _analogOpeningController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [AmountInputFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Analog opening volume',
                        helperText: _previousAnalogClosingVolume == null
                            ? 'No previous analog closing value found'
                            : 'Default from previous analog close: ${_previousAnalogClosingVolume!.toStringAsFixed(3)}',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _saveDraft();
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _analogClosingController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [AmountInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Today analog entry',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _saveDraft();
                      },
                    ),
                    if (_previousAnalogClosingVolume != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Previous day analog entry: ${formatAmount(_previousAnalogClosingVolume!, decimalDigits: 3)}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        title: const Text('Calculated sales (cash-based)'),
                        subtitle: Text(
                          '${formatAmount(calculatedSalesVolume.clamp(0.0, 999999999.0), decimalDigits: 3)} liters'
                          ' = (shift close cash - shift opening cash) ÷ ${formatAmount(price, decimalDigits: 2)}',
                        ),
                        trailing: Text(
                          '${formatAmount(expectedAmount, decimalDigits: 2)}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cashController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [AmountInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Today total pump cash',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _saveDraft(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _posController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [AmountInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'POS / transfer / card amount',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _saveDraft(),
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
