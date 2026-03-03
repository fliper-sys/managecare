import 'package:flutter/material.dart';
import '../../data/repositories/industry_specific/real_estate_repository.dart';

class LegacyRealEstateProvider extends ChangeNotifier {
  final RealEstateRepository? repository;
  String _businessId;

  LegacyRealEstateProvider({required String businessId, this.repository})
      : _businessId = businessId {
    _init();
  }

  final List<Map<String, dynamic>> _properties = [];
  final List<Map<String, dynamic>> _owners = [];
  final List<Map<String, dynamic>> _bookings = [];
  final List<Map<String, dynamic>> _payments = [];
  final List<Map<String, dynamic>> _documents = [];
  final List<Map<String, dynamic>> _escrows = [];
  final List<Map<String, dynamic>> _inventory = [];

  List<Map<String, dynamic>> get properties => List.unmodifiable(_properties);
  List<Map<String, dynamic>> get owners => List.unmodifiable(_owners);
  List<Map<String, dynamic>> get bookings => List.unmodifiable(_bookings);
  List<Map<String, dynamic>> get payments => List.unmodifiable(_payments);
  List<Map<String, dynamic>> get documents => List.unmodifiable(_documents);
  List<Map<String, dynamic>> get escrows => List.unmodifiable(_escrows);
  List<Map<String, dynamic>> get inventory => List.unmodifiable(_inventory);

  Future<void> _init() async {
    await fetchProperties();
    await fetchOwners();
    await fetchBookings();
    await fetchPayments();
    await fetchDocuments();
    await fetchEscrows();
    await fetchInventory();
  }

  // Bookings
  Future<void> fetchBookings() async {
    if (repository == null) return;
    try {
      final items = await repository!.fetchBookings(_businessId);
      _bookings.clear();
      _bookings.addAll(items);
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  Future<void> saveBooking(Map<String, dynamic> booking) async {
    if (repository == null) return;
    try {
      final saved = await repository!.saveBooking(_businessId, booking);
      final idx = _bookings.indexWhere((b) => b['id'] == saved['id']);
      if (idx >= 0) {
        _bookings[idx] = saved;
      } else {
        _bookings.insert(0, saved);
      }
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  Future<void> deleteBooking(String id) async {
    if (repository == null) return;
    try {
      await repository!.deleteBooking(_businessId, id);
      _bookings.removeWhere((b) => b['id'] == id);
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  // Payments
  Future<void> fetchPayments() async {
    if (repository == null) return;
    try {
      final items = await repository!.fetchPayments(_businessId);
      _payments.clear();
      _payments.addAll(items);
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  Future<void> savePayment(Map<String, dynamic> payment) async {
    if (repository == null) return;
    try {
      final saved = await repository!.savePayment(_businessId, payment);
      _payments.insert(0, saved);
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  // Documents
  Future<void> fetchDocuments({String? propertyId}) async {
    if (repository == null) return;
    try {
      final items =
          await repository!.fetchDocuments(_businessId, propertyId: propertyId);
      _documents.clear();
      _documents.addAll(items);
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  Future<void> saveDocument(Map<String, dynamic> doc) async {
    if (repository == null) return;
    try {
      final saved = await repository!.saveDocument(_businessId, doc);
      _documents.insert(0, saved);
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  // Escrows
  Future<void> fetchEscrows() async {
    if (repository == null) return;
    try {
      final items = await repository!.fetchEscrows(_businessId);
      _escrows.clear();
      _escrows.addAll(items);
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  Future<void> saveEscrow(Map<String, dynamic> escrow) async {
    if (repository == null) return;
    try {
      final saved = await repository!.saveEscrow(_businessId, escrow);
      final idx = _escrows.indexWhere((e) => e['id'] == saved['id']);
      if (idx >= 0) {
        _escrows[idx] = saved;
      } else {
        _escrows.insert(0, saved);
      }
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  // Inventory
  Future<void> fetchInventory() async {
    if (repository == null) return;
    try {
      final items = await repository!.fetchInventory(_businessId);
      _inventory.clear();
      _inventory.addAll(items);
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  Future<void> saveInventoryItem(Map<String, dynamic> item) async {
    if (repository == null) return;
    try {
      final saved = await repository!.saveInventoryItem(_businessId, item);
      final idx = _inventory.indexWhere((i) => i['id'] == saved['id']);
      if (idx >= 0) {
        _inventory[idx] = saved;
      } else {
        _inventory.insert(0, saved);
      }
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  Future<void> deleteInventoryItem(String id) async {
    if (repository == null) return;
    try {
      await repository!.deleteInventoryItem(_businessId, id);
      _inventory.removeWhere((i) => i['id'] == id);
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  Future<void> fetchProperties() async {
    if (repository == null) return;
    try {
      final items = await repository!.fetchProperties(_businessId);
      _properties.clear();
      _properties.addAll(items);
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  Future<void> fetchOwners() async {
    if (repository == null) return;
    try {
      final list = await repository!.fetchOwners(_businessId);
      _owners.clear();
      _owners.addAll(list);
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  Future<void> addOrUpdateProperty(Map<String, dynamic> property) async {
    if (repository == null) return;
    try {
      final id = property['id'] as String?;
      if (id == null || id.isEmpty) {
        final created = await repository!.saveProperty(_businessId, property);
        _properties.insert(0, created);
      } else {
        await repository!.saveProperty(_businessId, property);
        final idx = _properties.indexWhere((p) => p['id'] == id);
        if (idx >= 0) _properties[idx] = property;
      }
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  Future<void> deleteProperty(String id) async {
    if (repository == null) return;
    try {
      await repository!.deleteProperty(_businessId, id);
      _properties.removeWhere((p) => p['id'] == id);
      notifyListeners();
    } catch (e) {
      // Handle network/database errors silently
    }
  }

  Future<Map<String, dynamic>?> getPropertyById(String id) async {
    if (repository == null) return null;
    try {
      return await repository!.fetchPropertyById(_businessId, id);
    } catch (e) {
      return null;
    }
  }

  /// Change current business id and reload provider data
  Future<void> setBusinessId(String businessId) async {
    if (_businessId == businessId) return;
    _businessId = businessId;
    await _init();
    notifyListeners();
  }
}

