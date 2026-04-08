import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/receipt_settings_model.dart';

class ReceiptSettingsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ReceiptSettingsModel? _receiptSettings;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _receiptPreferences = {};

  ReceiptSettingsModel? get receiptSettings => _receiptSettings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get receiptPreferences => _receiptPreferences;

  /// Fetch receipt settings for a business
  Future<void> fetchReceiptSettings(String businessId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('receipt_settings')
          .doc(businessId)
          .get();

      if (doc.exists) {
        _receiptSettings = ReceiptSettingsModel.fromFirestore(doc);
      } else {
        // Create default settings if they don't exist
        _receiptSettings =
            ReceiptSettingsModel.defaultSettings(businessId: businessId);
        await saveReceiptSettings(_receiptSettings!);
      }
    } catch (e) {
      _error = e.toString();
      print('Error fetching receipt settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save receipt settings
  Future<void> saveReceiptSettings(ReceiptSettingsModel settings) async {
    if (_receiptSettings == null) return;

    try {
      final businessId = settings.businessId;
      final updatedSettings = settings.copyWith(
        id: businessId,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('receipt_settings')
          .doc(businessId)
          .set(updatedSettings.toFirestore());

      // Also persist a small receipt summary into the parent business document
      // to make it cheaper/safer for UI and background tasks to access common
      // receipt settings without querying a subcollection.
      try {
        final summary = {
          'businessId': businessId,
          'invoicePrefix': updatedSettings.invoicePrefix,
          'paperWidth': updatedSettings.paperWidth,
          'headerNote': updatedSettings.headerNote,
          'footerMessage': updatedSettings.footerMessage,
          'showQrCode': updatedSettings.showQrCode,
          'enableEmailReceipts': updatedSettings.enableEmailReceipts,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        await _firestore
            .collection('businesses')
            .doc(settings.businessId)
            .set({
          'settings': {'receipt': summary}
        }, SetOptions(merge: true));
      } catch (e) {
        // Non-fatal: log and continue
        print('Warning: failed to persist receipt summary to business doc: $e');
      }

      _receiptSettings = updatedSettings;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error saving receipt settings: $e');
      notifyListeners();
    }
  }

  /// Update a specific receipt setting
  Future<void> updateReceiptSetting(
      String businessId, String key, dynamic value) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('receipt_settings')
          .doc(businessId)
          .update({
        key: value,
        'updatedAt': Timestamp.now(),
      });

      // Update local state
      if (_receiptSettings != null) {
        await fetchReceiptSettings(businessId);
      }
    } catch (e) {
      _error = e.toString();
      print('Error updating receipt setting: $e');
      notifyListeners();
    }
  }

  /// Get next invoice number and increment
  Future<int> getNextInvoiceNumber(String businessId) async {
    try {
      if (_receiptSettings == null) {
        await fetchReceiptSettings(businessId);
      }

      final nextNumber = _receiptSettings?.nextInvoiceNumber ?? 1000;

      // Increment for next time
      await updateReceiptSetting(
        businessId,
        'nextInvoiceNumber',
        nextNumber + 1,
      );

      return nextNumber;
    } catch (e) {
      print('Error getting next invoice number: $e');
      return 1000;
    }
  }

  /// Generate formatted invoice number
  String formatInvoiceNumber(int number) {
    if (_receiptSettings == null) return 'INV-$number';
    return '${_receiptSettings!.invoicePrefix}${number.toString().padLeft(5, '0')}';
  }

  /// Fetch thermal receipt preferences from Firestore
  Future<void> fetchReceiptPreferences(String businessId) async {
    try {
      final doc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('receipt_settings')
          .doc('thermalPreferences')
          .get();

      if (doc.exists) {
        _receiptPreferences = doc.data() ?? {};
      } else {
        _receiptPreferences = _getDefaultThermalPreferences();
        // Save defaults
        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('receipt_settings')
            .doc('thermalPreferences')
            .set(_receiptPreferences);
      }
      notifyListeners();
    } catch (e) {
      print('Error fetching receipt preferences: $e');
      _receiptPreferences = _getDefaultThermalPreferences();
      notifyListeners();
    }
  }

  /// Update thermal receipt preferences
  Future<void> updateReceiptPreferences(
    Map<String, dynamic> updates,
  ) async {
    try {
      final businessId = _receiptSettings?.businessId;
      if (businessId == null) return;

      _receiptPreferences.addAll(updates);
      _receiptPreferences['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('receipt_settings')
          .doc('thermalPreferences')
          .set(_receiptPreferences, SetOptions(merge: true));

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error updating receipt preferences: $e');
      notifyListeners();
    }
  }

  /// Get default thermal receipt preferences
  Map<String, dynamic> _getDefaultThermalPreferences() {
    return {
      'bankName': '',
      'bankAccount': '',
      'website': '',
      'customHeaderText': '',
      'customFooterText': '',
      'currencySymbol': '₦',
      'receiptUrlBase': '',
      'qrCodeType': 'url',
      'showBankDetails': false,
      'showQrCode': false,
      'showQrImage': false,
      'enableQrImagePrinting': false,
      'compactLayout': false,
      'fontSize': 'medium',
      'stylePreset': 'professional',
      'accentColor': '#2C3E50',
      // Number of thermal receipt copies to print for each sale (default: 2 -> customer & business)
      'copies': 2,
    };
  }
}

