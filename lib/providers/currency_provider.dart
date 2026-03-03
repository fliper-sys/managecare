import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../data/models/currency_model.dart';

class CurrencyProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currenciesCollection = 'currencies';
  final String _ratesCollection = 'currency_rates';

  List<Currency> _currencies = [];
  List<CurrencyRate> _rates = [];
  Currency? _selectedCurrency;
  bool _isLoading = false;
  String? _error;
  String? _businessId;

  // Getters
  List<Currency> get currencies => _currencies;
  List<CurrencyRate> get rates => _rates;
  Currency? get selectedCurrency => _selectedCurrency;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize with business ID
  void initialize(String businessId) {
    _businessId = businessId;
    loadCurrencies();
    loadRates();
  }

  // Load currencies for business
  Future<void> loadCurrencies() async {
    if (_businessId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection(_currenciesCollection)
          .where('businessId', isEqualTo: _businessId)
          .orderBy('isDefault', descending: true)
          .get();

      _currencies = snapshot.docs
          .map((doc) => Currency.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Set default currency
      _selectedCurrency = _currencies.firstWhere(
        (c) => c.isDefault,
        orElse: () => _currencies.isNotEmpty
            ? _currencies.first
            : Currency(
                code: 'USD',
                name: 'US Dollar',
                symbol: '\$',
                decimalPlaces: 2,
                isDefault: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
      );

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load currencies: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load currency rates
  Future<void> loadRates() async {
    if (_businessId == null) return;

    try {
      final snapshot = await _firestore
          .collection(_ratesCollection)
          .where('businessId', isEqualTo: _businessId)
          .where('isActive', isEqualTo: true)
          .get();

      _rates = snapshot.docs
          .map((doc) => CurrencyRate.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      notifyListeners();
    } catch (e) {
      _error = 'Failed to load rates: $e';
      notifyListeners();
    }
  }

  // Add currency
  Future<bool> addCurrency({
    required String code,
    required String name,
    required String symbol,
    required int decimalPlaces,
  }) async {
    if (_businessId == null) return false;

    try {
      final currency = Currency(
        code: code,
        name: name,
        symbol: symbol,
        decimalPlaces: decimalPlaces,
        isDefault: _currencies.isEmpty,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_currenciesCollection)
          .add({...currency.toJson(), 'businessId': _businessId});

      await loadCurrencies();
      return true;
    } catch (e) {
      _error = 'Failed to add currency: $e';
      notifyListeners();
      return false;
    }
  }

  // Set default currency
  Future<bool> setDefaultCurrency(String currencyCode) async {
    if (_businessId == null) return false;

    try {
      // Find the currency
      final currency = _currencies.firstWhere((c) => c.code == currencyCode);

      // Update to default
      final updated =
          currency.copyWith(isDefault: true, updatedAt: DateTime.now());

      await _firestore
          .collection(_currenciesCollection)
          .where('businessId', isEqualTo: _businessId)
          .where('code', isEqualTo: currencyCode)
          .get()
          .then((snapshot) {
        for (final doc in snapshot.docs) {
          doc.reference.update(updated.toJson());
        }
      });

      _selectedCurrency = updated;
      await loadCurrencies();
      return true;
    } catch (e) {
      _error = 'Failed to set default currency: $e';
      notifyListeners();
      return false;
    }
  }

  // Add or update exchange rate
  Future<bool> addExchangeRate({
    required String baseCurrency,
    required String targetCurrency,
    required double rate,
    DateTime? expiryDate,
  }) async {
    if (_businessId == null) return false;

    try {
      final rateId = const Uuid().v4();
      final currencyRate = CurrencyRate(
        id: rateId,
        baseCurrency: baseCurrency,
        targetCurrency: targetCurrency,
        rate: rate,
        effectiveDate: DateTime.now(),
        expiryDate: expiryDate ?? DateTime.now().add(const Duration(days: 365)),
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_ratesCollection)
          .doc(rateId)
          .set({...currencyRate.toJson(), 'businessId': _businessId});

      await loadRates();
      return true;
    } catch (e) {
      _error = 'Failed to add exchange rate: $e';
      notifyListeners();
      return false;
    }
  }

  // Convert amount between currencies
  double convertCurrency({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) {
    if (fromCurrency == toCurrency) return amount;

    final rate = getExchangeRate(fromCurrency, toCurrency);
    if (rate == null) return amount;

    return amount * rate.rate;
  }

  // Get exchange rate
  CurrencyRate? getExchangeRate(String fromCurrency, String toCurrency) {
    try {
      return _rates.firstWhere(
        (r) =>
            r.baseCurrency == fromCurrency &&
            r.targetCurrency == toCurrency &&
            !r.isExpired &&
            r.isActive,
      );
    } catch (e) {
      return null;
    }
  }

  // Format amount with currency
  String formatCurrency(double amount, {String? currencyCode}) {
    final currency = currencyCode != null
        ? _currencies.firstWhere(
            (c) => c.code == currencyCode,
            orElse: () => _selectedCurrency!,
          )
        : _selectedCurrency;

    if (currency == null) return amount.toStringAsFixed(2);

    return currency.formatAmount(amount);
  }

  // Get currency by code
  Currency? getCurrencyByCode(String code) {
    try {
      return _currencies.firstWhere((c) => c.code == code);
    } catch (e) {
      return null;
    }
  }

  // Clear
  void clear() {
    _currencies = [];
    _rates = [];
    _selectedCurrency = null;
    _error = null;
    notifyListeners();
  }
}

