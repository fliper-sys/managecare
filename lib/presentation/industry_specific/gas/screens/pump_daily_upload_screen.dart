import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../core/utils/amount_formatter.dart';
import '../../../../core/utils/connectivity_helper.dart';
import '../../../../services/email_service.dart';
import '../../../../services/managecare_api_client.dart';
import '../utils/pump_config_cache.dart';
import '../utils/pump_daily_upload_validation.dart';
import '../utils/pump_row_mapper.dart';
import '../utils/pump_upload_offline_queue.dart';

class PumpDailyUploadScreen extends StatefulWidget {
  const PumpDailyUploadScreen({super.key});

  @override
  State<PumpDailyUploadScreen> createState() => _PumpDailyUploadScreenState();
}

class _PumpDailyUploadScreenState extends State<PumpDailyUploadScreen> {
  static const List<int> _cashDenominations = [
    1000,
    500,
    200,
    100,
    50,
    20,
    10,
    5,
  ];

  final _analogClosingController = TextEditingController();
  final _analogOpeningController = TextEditingController();
  bool _cacheLoaded = false;
  List<Map<String, dynamic>> _cachedPumps = [];
  final _cashController = TextEditingController();
  final Map<int, TextEditingController> _cashDenominationControllers = {
    for (final denomination in _cashDenominations)
      denomination: TextEditingController(),
  };
  final _closingController = TextEditingController();
  String? _closingPhotoPath;
  String? _closingPhotoUrl;
  bool _isLoadingPreviousClosing = false;
  bool _isSaving = false;
  String? _lastLoadedPumpId;
  String? _loadingPumpId;
  String? _uploadingPhotoKind;
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

  // The custom backend doesn't support Firestore-style realtime snapshots,
  // so pump configuration is polled - same pattern used across every other
  // migrated screen this session.
  static const _pollInterval = Duration(seconds: 15);

  @override
  void dispose() {
    _openingController.dispose();
    _closingController.dispose();
    _analogOpeningController.dispose();
    _analogClosingController.dispose();
    _shiftOpeningCashController.dispose();
    _shiftCloseCashController.dispose();
    _cashController.dispose();
    for (final controller in _cashDenominationControllers.values) {
      controller.dispose();
    }
    _posController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedPumps();
      _syncPendingUploads();
    });
  }

  Future<void> _syncPendingUploads() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;
    try {
      final synced = await PumpUploadOfflineQueue.sync(businessId);
      if (synced > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              synced == 1
                  ? '1 offline pump upload synced'
                  : '$synced offline pump uploads synced',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Pending pump upload sync failed: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> _pumpsStream(String businessId) async* {
    while (true) {
      try {
        final response = await ManagecareApiClient.instance
            .get('/api/pumps/$businessId/pumps', query: {'isActive': 'true'});
        final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        yield rows.map(pumpRowToJson).toList();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
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

  void _syncCacheFromRows(String businessId, List<Map<String, dynamic>> rows) {
    final remotePumps = PumpConfigCache.sort(rows);
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

  Future<Map<String, dynamic>?> _fetchLatestUpload(
    String businessId,
    String pumpId,
  ) async {
    try {
      final response = await ManagecareApiClient.instance.get(
        '/api/pumps/$businessId/uploads/latest',
        query: {'pumpId': pumpId},
      );
      if (response == null) return null;
      return pumpUploadRowToJson(Map<String, dynamic>.from(response as Map));
    } catch (error) {
      debugPrint('Pump upload query failed: $error');
      return null;
    }
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

  int _parseDenominationCount(TextEditingController controller) {
    final value = _parseControllerValue(controller);
    return value <= 0 ? 0 : value.round();
  }

  List<Map<String, dynamic>> _cashBreakdownEntries() {
    return _cashDenominations.map((denomination) {
      final pieces = _parseDenominationCount(
        _cashDenominationControllers[denomination]!,
      );
      return {
        'denomination': denomination,
        'pieces': pieces,
        'amount': denomination * pieces,
      };
    }).toList();
  }

  double _cashBreakdownTotal() {
    return _cashBreakdownEntries().fold<double>(
      0,
      (total, entry) => total + ((entry['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  void _syncCashTotalFromBreakdown({bool saveDraft = true}) {
    final total = _cashBreakdownTotal();
    final nextText = total <= 0 ? '' : formatAmount(total, decimalDigits: 2);
    if (_cashController.text != nextText) {
      _cashController.text = nextText;
    }
    if (mounted) setState(() {});
    if (saveDraft) {
      _saveDraft();
    }
  }

  void _clearCashBreakdown() {
    for (final controller in _cashDenominationControllers.values) {
      controller.clear();
    }
    _cashController.clear();
  }

  void _restoreCashBreakdown(dynamic raw) {
    if (raw == null) return;

    final byDenomination = <int, int>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final denomination = int.tryParse(entry.key.toString());
        final pieces = _parseNumber(entry.value)?.round();
        if (denomination != null && pieces != null) {
          byDenomination[denomination] = pieces;
        }
      }
    } else if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final denomination = _parseNumber(item['denomination'])?.round();
        final pieces = _parseNumber(
          item['pieces'] ?? item['count'] ?? item['quantity'],
        )?.round();
        if (denomination != null && pieces != null) {
          byDenomination[denomination] = pieces;
        }
      }
    }

    for (final denomination in _cashDenominations) {
      final pieces = byDenomination[denomination] ?? 0;
      _cashDenominationControllers[denomination]!.text =
          pieces <= 0 ? '' : pieces.toString();
    }
    _syncCashTotalFromBreakdown(saveDraft: false);
  }

  Future<void> _loadPreviousClosing(
    String pumpId, {
    String? pumpNumber,
  }) async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;
    if (_isLoadingPreviousClosing && _loadingPumpId == pumpId) return;

    setState(() {
      _isLoadingPreviousClosing = true;
      _loadingPumpId = pumpId;
      _previousClosingVolume = null;
    });

    Map<String, dynamic>? latest;
    try {
      latest = await _fetchLatestUpload(businessId, pumpId);
      final value =
          latest == null ? null : _parseNumber(latest['closingVolume']);
      final previousShiftCash =
          latest == null ? null : _parseNumber(latest['shiftCloseCash']);
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

    await _loadPreviousAnalogClosing(pumpId, latestUpload: latest);
  }

  Future<void> _loadPreviousAnalogClosing(
    String pumpId, {
    Map<String, dynamic>? latestUpload,
  }) async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;

    final cachedValue = await PumpAnalogClosingCache.load(businessId, pumpId);
    double? value = cachedValue;

    final latest = latestUpload ?? await _fetchLatestUpload(businessId, pumpId);
    if (latest != null) {
      final remoteValue = _parseNumber(latest['analogClosingVolume']);
      if (remoteValue != null) {
        value = remoteValue;
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
    _restoreCashBreakdown(draft['cashBreakdown'] ?? draft['cash_breakdown']);
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
      'cashBreakdown': _cashBreakdownEntries(),
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
    if (_uploadingPhotoKind != null || _isSaving) return;

    setState(() => _uploadingPhotoKind = kind);

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;
      if (!kIsWeb) {
        _setPhotoDraft(kind: kind, path: picked.path);
      }

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
      if (mounted) setState(() => _uploadingPhotoKind = null);
    }
  }

  bool _isPhotoUploading(String kind) => _uploadingPhotoKind == kind;

  Widget _photoUploadIcon({
    required String kind,
    required bool hasPhoto,
  }) {
    if (_isPhotoUploading(kind)) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Icon(
      hasPhoto ? Icons.check_circle_outline : Icons.camera_alt_outlined,
      color: hasPhoto ? Colors.green : null,
    );
  }

  String _photoUploadLabel({
    required String kind,
    required bool hasPhoto,
    required String uploadText,
    required String savedText,
  }) {
    if (_isPhotoUploading(kind)) return 'Uploading...';
    return hasPhoto ? savedText : uploadText;
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

    Map<String, dynamic>? productData;
    try {
      final response = await ManagecareApiClient.instance
          .get('/api/inventory/$businessId/$productId');
      productData = response == null
          ? null
          : Map<String, dynamic>.from(response as Map);
    } catch (_) {
      productData = null;
    }

    final currentPrice =
        (productData?['price'] as num?)?.toDouble() ?? fallbackPrice;

    if (currentPrice > 0 && (currentPrice - fallbackPrice).abs() > 0.0001) {
      final pumpId = pump['id']?.toString();
      if (pumpId != null && pumpId.isNotEmpty) {
        try {
          await ManagecareApiClient.instance.put(
            '/api/pumps/$businessId/pumps/$pumpId',
            body: {'product_price': currentPrice},
          );
        } catch (_) {
          // Non-fatal - the sale still proceeds at the resolved price even
          // if persisting the refreshed price back onto the pump fails.
        }
        await PumpConfigCache.upsert(businessId, pumpId, {
          ...pump,
          'productPrice': currentPrice,
        });
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

  double _computeCashBasedSalesVolume(
    double shiftOpeningCash,
    double shiftCloseCash,
    double price,
  ) {
    if (price <= 0) return 0.0;
    final cashDifference = (shiftCloseCash - shiftOpeningCash).clamp(0.0, 999999999.0);
    if (cashDifference <= 0) return 0.0;
    final volumeFromCash = cashDifference / price;
    final roundedVolume = double.parse(volumeFromCash.toStringAsFixed(6));
    if (roundedVolume <= 0) return 0.001;
    return roundedVolume < 0.000001 ? 0.000001 : roundedVolume;
  }

  double _computeExpectedCash(
    double shiftOpeningCash,
    double shiftCloseCash,
  ) {
    final cashDifference =
        (shiftCloseCash - shiftOpeningCash).clamp(0.0, 999999999.0);
    return double.parse(cashDifference.toStringAsFixed(2));
  }

  String _uploadFingerprint({
    required String pumpId,
    required String productId,
    required double opening,
    required double closing,
    required double analogOpening,
    required double analogClosing,
    required double shiftOpeningCash,
    required double shiftCloseCash,
    required double cash,
    required double pos,
  }) {
    String fixed(double value, int decimals) => value.toStringAsFixed(decimals);
    return [
      pumpId,
      productId,
      fixed(opening, 3),
      fixed(closing, 3),
      fixed(analogOpening, 3),
      fixed(analogClosing, 3),
      fixed(shiftOpeningCash, 2),
      fixed(shiftCloseCash, 2),
      fixed(cash, 2),
      fixed(pos, 2),
    ].join('|');
  }

  Future<bool> _hasDuplicateUpload({
    required String businessId,
    required String fingerprint,
    required String pumpId,
  }) async {
    try {
      final response = await ManagecareApiClient.instance.get(
        '/api/pumps/$businessId/uploads',
        query: {'pumpId': pumpId, 'limit': '50'},
      );
      final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      return rows.any((row) => row['upload_fingerprint']?.toString() == fingerprint);
    } catch (error) {
      debugPrint('Duplicate upload check failed: $error');
      // The server-side unique constraint on (business_id, pump_id,
      // upload_fingerprint) is the authoritative backstop if this
      // pre-check can't run.
      return false;
    }
  }

  bool _allImagesSelected() {
    // On web, _pickAndUploadPhoto never sets the *PhotoPath fields (there's
    // no local file path on web - the picker's path isn't a usable file),
    // only the *PhotoUrl fields once the upload finishes. Checking path
    // alone left this permanently false on web even after every photo had
    // genuinely uploaded, which kept the submit button disabled forever.
    return (_openingPhotoPath != null || _openingPhotoUrl != null) &&
        (_closingPhotoPath != null || _closingPhotoUrl != null) &&
        (_shiftOpeningCashPhotoPath != null || _shiftOpeningCashPhotoUrl != null) &&
        (_shiftCloseCashPhotoPath != null || _shiftCloseCashPhotoUrl != null);
  }

  Future<void> _saveUpload(Map<String, dynamic> pump) async {
    if (_isSaving) return;
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty || _selectedPumpId == null) return;

    // Set before any of the checks/network calls below run, not just before
    // the final POST - those checks each await (duplicate-fingerprint
    // lookup, price resolution, photo uploads), and the submit button only
    // reads _isSaving to decide whether it's tappable. Setting this any
    // later left a window where a fast double-tap fired _saveUpload twice
    // before the button ever disabled, which is exactly how attendants
    // ended up submitting the same reading more than once.
    setState(() => _isSaving = true);

    if (!_allImagesSelected()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All images (opening, closing, opening cash, closing cash) are required'),
          duration: Duration(seconds: 3),
        ),
      );
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    final opening = _parseControllerValue(_openingController);
    final closing = _parseControllerValue(_closingController);
    final analogOpening = _parseControllerValue(_analogOpeningController);
    final analogClosing = _parseControllerValue(_analogClosingController);
    final shiftOpeningCash =
        _parseControllerValue(_shiftOpeningCashController);
    final shiftCloseCash =
        _parseControllerValue(_shiftCloseCashController);
    final cashBreakdown = _cashBreakdownEntries();
    final cash = cashBreakdown.fold<double>(
      0,
      (total, entry) => total + ((entry['amount'] as num?)?.toDouble() ?? 0),
    );
    final pos = _parseControllerValue(_posController);

    if (closing <= opening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Closing volume must be greater than opening volume'),
          duration: Duration(seconds: 3),
        ),
      );
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    final productId = pump['productId']?.toString() ?? '';
    final uploadFingerprint = _uploadFingerprint(
      pumpId: _selectedPumpId!,
      productId: productId,
      opening: opening,
      closing: closing,
      analogOpening: analogOpening,
      analogClosing: analogClosing,
      shiftOpeningCash: shiftOpeningCash,
      shiftCloseCash: shiftCloseCash,
      cash: cash,
      pos: pos,
    );

    if (await _hasDuplicateUpload(
      businessId: businessId,
      fingerprint: uploadFingerprint,
      pumpId: _selectedPumpId!,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This exact pump upload has already been submitted.'),
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    final retail = context.read<RetailProvider>();
    await retail.loadProducts(forceRefresh: true);
    final productInfo =
        await _resolveCurrentProductInfo(businessId, productId, pump);
    final price = productInfo['price'] ?? 0.0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to resolve current product price')),
      );
      if (mounted) setState(() => _isSaving = false);
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

    // retail.fuelSale() below already queues the sale locally and reports
    // success while offline; the upload POST used to have no such path and
    // just threw, leaving a sale with no matching pump upload record (and a
    // worker who retried after the "failed to save" error only piled up
    // more queued sales). Checking connectivity once up front lets both
    // halves take the same offline-queued path together instead.
    final isOnline = await ConnectivityHelper.hasInternetConnection();

    String? shiftOpeningCashPhotoUrl;
    String? shiftCloseCashPhotoUrl;
    String? openingPhotoUrl;
    String? closingPhotoUrl;

    if (isOnline) {
      shiftOpeningCashPhotoUrl = await _ensurePhotoUrl(
        label: 'shift opening cash',
        url: _shiftOpeningCashPhotoUrl,
        path: _shiftOpeningCashPhotoPath,
      );
      shiftCloseCashPhotoUrl = await _ensurePhotoUrl(
        label: 'shift close cash',
        url: _shiftCloseCashPhotoUrl,
        path: _shiftCloseCashPhotoPath,
      );
      openingPhotoUrl = await _ensurePhotoUrl(
        label: 'closing pump volume',
        url: _openingPhotoUrl,
        path: _openingPhotoPath,
      );
      closingPhotoUrl = await _ensurePhotoUrl(
        label: 'Opening pump volume',
        url: _closingPhotoUrl,
        path: _closingPhotoPath,
      );

      // Verify all images were successfully uploaded
      if (shiftOpeningCashPhotoUrl == null ||
          shiftCloseCashPhotoUrl == null ||
          openingPhotoUrl == null ||
          closingPhotoUrl == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload one or more images. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      _shiftOpeningCashPhotoUrl = shiftOpeningCashPhotoUrl;
      _shiftCloseCashPhotoUrl = shiftCloseCashPhotoUrl;
      _openingPhotoUrl = openingPhotoUrl;
      _closingPhotoUrl = closingPhotoUrl;
      await _saveDraft();
    } else {
      // Offline: skip the network upload attempts entirely (they'd just
      // throw) and carry whatever local paths/URLs are already on hand.
      // PumpUploadOfflineQueue resolves the actual photo URLs at sync time.
      shiftOpeningCashPhotoUrl = _shiftOpeningCashPhotoUrl;
      shiftCloseCashPhotoUrl = _shiftCloseCashPhotoUrl;
      openingPhotoUrl = _openingPhotoUrl;
      closingPhotoUrl = _closingPhotoUrl;
    }

    try {
      final auth = context.read<AuthProvider>().currentUser;
      final expectedAmount = _computeExpectedCash(
        shiftOpeningCash,
        shiftCloseCash,
      );

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
        idempotencyKey: uploadFingerprint,
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

      final uploadBody = {
        'pump_id': _selectedPumpId,
        'pump_number': pump['pumpNumber'],
        'product_id': productId,
        'product_name': pump['productName'],
        'product_unit': pump['productUnit'],
        'product_price': price,
        'opening_volume': opening,
        'closing_volume': closing,
        'digital_volume': digitalVolume,
        'volume_difference': digitalVolume,
        'analog_opening_volume': analogOpening,
        'sold_volume': calculatedSalesVolume,
        'cash_derived_volume': calculatedSalesVolume,
        'analog_closing_volume': analogClosing,
        'previous_analog_closing_volume': _previousAnalogClosingVolume,
        'previous_shift_closing_cash': _previousShiftClosingCash,
        'previous_closing_volume': _previousClosingVolume,
        'expected_amount': expectedAmount,
        'discrepancy_notes': discrepancyNotes,
        'discrepancy_summary': discrepancySummary,
        'shift_opening_cash': shiftOpeningCash,
        'shift_close_cash': shiftCloseCash,
        'shift_cash_difference': shiftCashDifference,
        'today_pump_cash': cash,
        'cash_amount': cash,
        'cash_breakdown': cashBreakdown,
        'pos_amount': pos,
        'total_paid': totalPaid,
        'upload_fingerprint': uploadFingerprint,
        'sale_id': saleData['id'] ?? saleData['orderId'],
        'shift_opening_cash_photo_url': shiftOpeningCashPhotoUrl,
        'shift_close_cash_photo_url': shiftCloseCashPhotoUrl,
        'opening_photo_url': openingPhotoUrl,
        'closing_photo_url': closingPhotoUrl,
        'worker_id': auth?.id,
        'worker_name': auth?.fullName ?? auth?.email,
      };
      final photoPaths = {
        'shift_opening_cash_photo_url': _shiftOpeningCashPhotoPath,
        'shift_close_cash_photo_url': _shiftCloseCashPhotoPath,
        'opening_photo_url': _openingPhotoPath,
        'closing_photo_url': _closingPhotoPath,
      };

      var queuedOffline = false;
      if (!isOnline) {
        await PumpUploadOfflineQueue.enqueue(
          businessId,
          uploadBody,
          photoPaths: photoPaths,
        );
        queuedOffline = true;
      } else {
        try {
          await ManagecareApiClient.instance.post(
            '/api/pumps/$businessId/uploads',
            body: uploadBody,
          );
        } on ManagecareApiException catch (error) {
          if (error.statusCode == 409) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This exact pump upload has already been submitted.'),
              ),
            );
            return;
          }
          if (error.statusCode >= 400 && error.statusCode < 500) {
            // The server explicitly rejected this data (e.g. the
            // closing-must-exceed-opening rule) - retrying later won't
            // help, so surface it now instead of silently queuing
            // something that will just keep failing.
            rethrow;
          }
          // 5xx or similar - likely transient, queue for later.
          await PumpUploadOfflineQueue.enqueue(
            businessId,
            uploadBody,
            photoPaths: photoPaths,
          );
          queuedOffline = true;
        } catch (_) {
          // Network-level failure mid-flight (e.g. connection dropped
          // between the connectivity check above and this call) - queue
          // rather than lose the submission.
          await PumpUploadOfflineQueue.enqueue(
            businessId,
            uploadBody,
            photoPaths: photoPaths,
          );
          queuedOffline = true;
        }
      }

      await PumpAnalogClosingCache.save(businessId, _selectedPumpId!, analogClosing);
      await PumpUploadDraftCache.clear(businessId, _selectedPumpId!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queuedOffline
                ? 'No connection - upload saved offline and will sync automatically once you\'re back online.'
                : 'Pump upload saved',
          ),
          duration: Duration(seconds: queuedOffline ? 4 : 3),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      // Without this, an exception here (e.g. fuelSale() failing because the
      // pump isn't linked to a real inventory product) propagated uncaught
      // past the finally below - _isSaving still got reset, but no message
      // ever reached the user, so the submit button just silently did
      // nothing from their point of view.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save pump upload: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    final currentOpeningCash = parseAmountInput(_shiftOpeningCashController.text) ?? 0.0;
    final openingCashDiff = _previousShiftClosingCash != null
        ? currentOpeningCash - _previousShiftClosingCash!
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Pump Volume Upload')),
      body: businessId == null || businessId.isEmpty
          ? const Center(child: Text('No business selected'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _pumpsStream(businessId),
              builder: (context, snapshot) {
                final pumpRows = snapshot.data ?? [];
                if (pumpRows.isNotEmpty) {
                  _syncCacheFromRows(businessId, pumpRows);
                }
                final remotePumps = PumpConfigCache.sort(pumpRows);
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
                final expectedAmount = _computeExpectedCash(
                  shiftOpeningCash,
                  shiftCloseCash,
                );
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
                          _clearCashBreakdown();
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
                                  'Opening cash diff: ${openingCashDiff != null && openingCashDiff >= 0 ? '+' : ''}${openingCashDiff?.toStringAsFixed(2) ?? '0.00'} from previous shift close',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _isSaving || _uploadingPhotoKind != null
                                  ? null
                                  : () => _pickAndUploadPhoto(
                                        'shiftOpeningCash',
                                      ),
                              icon: _photoUploadIcon(
                                kind: 'shiftOpeningCash',
                                hasPhoto: _shiftOpeningCashPhotoUrl != null ||
                                    _shiftOpeningCashPhotoPath != null,
                              ),
                              label: Text(
                                _photoUploadLabel(
                                  kind: 'shiftOpeningCash',
                                  hasPhoto: _shiftOpeningCashPhotoUrl != null ||
                                      _shiftOpeningCashPhotoPath != null,
                                  uploadText: 'Upload shift opening cash image',
                                  savedText: 'Shift opening cash image saved',
                                ),
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
                              onPressed: _isSaving || _uploadingPhotoKind != null
                                  ? null
                                  : () => _pickAndUploadPhoto(
                                        'shiftCloseCash',
                                      ),
                              icon: _photoUploadIcon(
                                kind: 'shiftCloseCash',
                                hasPhoto: _shiftCloseCashPhotoUrl != null ||
                                    _shiftCloseCashPhotoPath != null,
                              ),
                              label: Text(
                                _photoUploadLabel(
                                  kind: 'shiftCloseCash',
                                  hasPhoto: _shiftCloseCashPhotoUrl != null ||
                                      _shiftCloseCashPhotoPath != null,
                                  uploadText: 'Upload shift close cash image',
                                  savedText: 'Shift close cash image saved',
                                ),
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
                            onPressed: _isSaving || _uploadingPhotoKind != null
                                ? null
                                : () => _pickAndUploadPhoto('opening'),
                            icon: _photoUploadIcon(
                              kind: 'opening',
                              hasPhoto: _openingPhotoUrl != null ||
                                  _openingPhotoPath != null,
                            ),
                            label: Text(
                              _photoUploadLabel(
                                kind: 'opening',
                                hasPhoto: _openingPhotoUrl != null ||
                                    _openingPhotoPath != null,
                                uploadText: 'Closing pump volume upload',
                                savedText: 'Closing pump volume saved',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving || _uploadingPhotoKind != null
                                ? null
                                : () => _pickAndUploadPhoto('closing'),
                            icon: _photoUploadIcon(
                              kind: 'closing',
                              hasPhoto: _closingPhotoUrl != null ||
                                  _closingPhotoPath != null,
                            ),
                            label: Text(
                              _photoUploadLabel(
                                kind: 'closing',
                                hasPhoto: _closingPhotoUrl != null ||
                                    _closingPhotoPath != null,
                                uploadText: 'Opening pump volume upload',
                                savedText: 'Opening pump volume saved',
                              ),
                            ),
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
                      inputFormatters: const [AmountInputFormatter(decimalDigits: 3)],
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
                          'Opening diff: ${(_parseControllerValue(_openingController) - _previousClosingVolume!) >= 0 ? '+' : ''}${(_parseControllerValue(_openingController) - _previousClosingVolume!).toStringAsFixed(3)} liters from previous close',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _closingController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [AmountInputFormatter(decimalDigits: 3)],
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
                      inputFormatters: const [AmountInputFormatter(decimalDigits: 3)],
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
                      inputFormatters: const [AmountInputFormatter(decimalDigits: 3)],
                      decoration: const InputDecoration(
                        labelText: 'Today analog entry',
                        border: OutlineInputBorder(),
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
                          formatAmount(expectedAmount, decimalDigits: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cash breakdown',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 640;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _cashDenominations.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isWide ? 4 : 2,
                            childAspectRatio: isWide ? 2.6 : 2.35,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemBuilder: (context, index) {
                            final denomination = _cashDenominations[index];
                            return TextField(
                              controller:
                                  _cashDenominationControllers[denomination],
                              keyboardType: TextInputType.number,
                              inputFormatters: const [
                                AmountInputFormatter(decimalDigits: 0),
                              ],
                              decoration: InputDecoration(
                                labelText: '₦$denomination pcs',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) =>
                                  _syncCashTotalFromBreakdown(),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cashController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [AmountInputFormatter()],
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Today total pump cash',
                        helperText: 'Automatically calculated from cash breakdown',
                        border: OutlineInputBorder(),
                      ),
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
                      onPressed: _isSaving ||
                              _uploadingPhotoKind != null ||
                              selectedPump == null ||
                              !_allImagesSelected()
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
