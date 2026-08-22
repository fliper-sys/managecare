import 'dart:convert';
import 'package:business_manager/core/utils/datetime_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/business_model.dart';

/// Service to manage local business data persistence on device
/// Enables offline access to business data and caches current business selection
class LocalBusinessStorage {
  static const String _businessListKey = 'cached_business_list';
  static const String _currentBusinessKey = 'current_business_id';
  static const String _currentBusinessTypeKey = 'current_business_type';
  static const String _lastSyncKey = 'business_last_sync_timestamp';
  static const String _businessPrefix = 'business_';

  final SharedPreferences _prefs;

  LocalBusinessStorage(this._prefs);

  static Future<LocalBusinessStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalBusinessStorage(prefs);
  }

  /// Save user's business list to local storage
  /// Called after fetching businesses from Firebase
  Future<bool> saveBusinessList(List<BusinessModel> businesses) async {
    try {
      // Use JSON-friendly serialization for prefs (avoid Firestore Timestamps)
      final jsonList = jsonEncode(
        businesses.map((b) => b.toJson()).toList(),
      );
      await _prefs.setString(_businessListKey, jsonList);

      // Update last sync timestamp
      await _prefs.setInt(
        _lastSyncKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      print(
          '[LocalBusinessStorage] Saved ${businesses.length} businesses to local storage');
      return true;
    } catch (e) {
      print('[LocalBusinessStorage] Error saving business list: $e');
      return false;
    }
  }

  /// Save a single business to local storage
  /// Useful for updating individual business details
  Future<bool> saveBusiness(BusinessModel business) async {
    try {
      final json = jsonEncode(business.toJson());
      await _prefs.setString('$_businessPrefix${business.id}', json);

      // Also ensure the master cached list is updated so getCachedBusinesses
      // returns a complete list even if individual businesses were saved.
      try {
        final list = getCachedBusinesses();
        final idx = list.indexWhere((b) => b.id == business.id);
        if (idx != -1) {
          list[idx] = business;
        } else {
          list.add(business);
        }
        await saveBusinessList(list);
      } catch (e) {
        print(
            '[LocalBusinessStorage] Warning: Failed to merge business into cached list: $e');
      }

      print(
          '[LocalBusinessStorage] Saved business ${business.id} to local storage');
      return true;
    } catch (e) {
      print('[LocalBusinessStorage] Error saving business ${business.id}: $e');
      return false;
    }
  }

  /// Get all cached businesses for the user
  /// Get all cached businesses for the user
  List<BusinessModel> getCachedBusinesses() {
    try {
      final json = _prefs.getString(_businessListKey);
      if (json == null || json.isEmpty) {
        print('[LocalBusinessStorage] No cached businesses found');
        return [];
      }

      final List<dynamic> decoded = jsonDecode(json);
      final businesses = decoded
          .map((item) => _businessFromMap(item as Map<String, dynamic>))
          .toList();

      print(
          '[LocalBusinessStorage] Retrieved ${businesses.length} cached businesses');
      return businesses;
    } catch (e) {
      print('[LocalBusinessStorage] Error retrieving cached businesses: $e');
      return [];
    }
  }

  /// Get a single cached business by ID
  BusinessModel? getCachedBusiness(String businessId) {
    try {
      final json = _prefs.getString('$_businessPrefix$businessId');
      if (json == null) return null;

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return _businessFromMap(decoded);
    } catch (e) {
      print('[LocalBusinessStorage] Error retrieving business $businessId: $e');
      return null;
    }
  }

  /// Set the currently selected business
  Future<bool> setCurrentBusiness(String businessId) async {
    try {
      await _prefs.setString(_currentBusinessKey, businessId);
      print('[LocalBusinessStorage] Set current business to: $businessId');

      // Also persist business type if we have the business cached locally
      try {
        final cached = getCachedBusiness(businessId);
        if (cached != null && cached.businessType.isNotEmpty) {
          await _prefs.setString(_currentBusinessTypeKey, cached.businessType);
          print('[LocalBusinessStorage] Also set current business type to: ${cached.businessType}');
        }
      } catch (e) {
        print('[LocalBusinessStorage] Warning: failed to persist current business type: $e');
      }

      return true;
    } catch (e) {
      print('[LocalBusinessStorage] Error setting current business: $e');
      return false;
    }
  }

  /// Get the currently selected business ID
  String? getCurrentBusinessId() {
    return _prefs.getString(_currentBusinessKey);
  }

  /// Get the currently selected business (from cache)
  BusinessModel? getCurrentBusiness() {
    try {
      final businessId = getCurrentBusinessId();
      if (businessId == null || businessId.isEmpty) {
        print('[LocalBusinessStorage] No current business ID set');
        return null;
      }

      return getCachedBusiness(businessId);
    } catch (e) {
      print('[LocalBusinessStorage] Error getting current business: $e');
      return null;
    }
  }

  /// Get the current business type saved (if available)
  String? getCurrentBusinessType() {
    try {
      return _prefs.getString(_currentBusinessTypeKey);
    } catch (e) {
      print('[LocalBusinessStorage] Error getting current business type: $e');
      return null;
    }
  }

  Future<bool> clearCurrentBusiness() async {
    try {
      await _prefs.remove(_currentBusinessKey);
      await _prefs.remove(_currentBusinessTypeKey);
      return true;
    } catch (e) {
      print('[LocalBusinessStorage] Error clearing current business: $e');
      return false;
    }
  }

  Future<bool> removeBusiness(String businessId) async {
    try {
      await _prefs.remove('$_businessPrefix$businessId');
      final filtered = getCachedBusinesses()
          .where((business) => business.id != businessId)
          .toList();
      await saveBusinessList(filtered);

      if (getCurrentBusinessId() == businessId) {
        await clearCurrentBusiness();
      }
      return true;
    } catch (e) {
      print('[LocalBusinessStorage] Error removing business $businessId: $e');
      return false;
    }
  }

  /// Get timestamp of last sync with Firebase
  DateTime? getLastSyncTime() {
    try {
      final timestamp = _prefs.getInt(_lastSyncKey);
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      print('[LocalBusinessStorage] Error getting last sync time: $e');
      return null;
    }
  }

  /// Check if cached data is stale (older than maxAgeMinutes)
  bool isCacheStale({int maxAgeMinutes = 60}) {
    try {
      final lastSync = getLastSyncTime();
      if (lastSync == null) return true;

      final ageInMinutes = DateTime.now().difference(lastSync).inMinutes;
      return ageInMinutes > maxAgeMinutes;
    } catch (e) {
      print('[LocalBusinessStorage] Error checking cache staleness: $e');
      return true;
    }
  }

  /// Clear all business data (call on logout)
  Future<bool> clearAllBusinessData() async {
    try {
      await _prefs.remove(_businessListKey);
      await _prefs.remove(_currentBusinessKey);
      await _prefs.remove(_lastSyncKey);

      // Also remove individual business caches
      final keys = _prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_businessPrefix)) {
          await _prefs.remove(key);
        }
      }

      print('[LocalBusinessStorage] Cleared all cached business data');
      return true;
    } catch (e) {
      print('[LocalBusinessStorage] Error clearing business data: $e');
      return false;
    }
  }

  /// Update a cached business with new data
  /// Merges updated fields while preserving other data
  Future<bool> updateCachedBusiness(
    String businessId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final existing = getCachedBusiness(businessId);
      if (existing == null) {
        print(
            '[LocalBusinessStorage] Cannot update: business $businessId not found in cache');
        return false;
      }

      // Merge updates with existing data
      final firestoreData = existing.toJson();
      firestoreData.addAll(updates);

      final updated = _businessFromMap(firestoreData);
      return saveBusiness(updated);
    } catch (e) {
      print(
          '[LocalBusinessStorage] Error updating cached business $businessId: $e');
      return false;
    }
  }

  /// Helper to convert Map to BusinessModel
  /// Since BusinessModel.fromFirestore expects DocumentSnapshot,
  /// we reconstruct it from the serialized map
  BusinessModel _businessFromMap(Map<String, dynamic> data) {
    return BusinessModel(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      businessType: data['businessType'] ?? data['business_type'] ?? '',
      description: data['description'],
      ownerId: data['ownerId'] ?? data['owner_id'] ?? '',
      logoUrl: data['logoUrl'] ?? data['logo_url'],
      photoUrl: data['photoUrl'] ?? data['photo_url'],
      currency: data['currency'] ?? 'NGN',
      taxId: data['taxId'] ?? data['tax_id'],
      taxRate: _asDouble(data['taxRate'] ?? data['tax_rate']),
      email: data['email'],
      phone: data['phone'],
      website: data['website'],
      address: data['address'],
      city: data['city'],
      state: data['state'],
      country: data['country'],
      postalCode: data['postalCode'] ?? data['postal_code'],
      location: data['location'],
      subscriptionTier: data['subscriptionTier'] ?? data['subscription_tier'] ?? 'free',
      businessClass: data['businessClass'] ?? data['business_class'] ?? 'tier1',
      subscriptionPlan: data['subscriptionPlan'] ?? data['subscription_plan'],
      isSubscriptionActive:
          data['isSubscriptionActive'] ?? data['is_subscription_active'] ?? true,
      subscriptionStartDate:
          (data['subscriptionStartDate'] ?? data['subscription_start_date']) != null
          ? parseTimestamp(data['subscriptionStartDate'] ?? data['subscription_start_date'])
          : null,
      subscriptionEndDate:
          (data['subscriptionEndDate'] ?? data['subscription_end_date']) != null
          ? parseTimestamp(data['subscriptionEndDate'] ?? data['subscription_end_date'])
          : null,
      settings: data['settings'] as Map<String, dynamic>?,
      industrySpecificSettings:
          (data['industrySpecificSettings'] ?? data['industry_specific_settings'])
              as Map<String, dynamic>?,
      isActive: data['isActive'] ?? data['is_active'] ?? true,
      createdAt: (data['createdAt'] ?? data['created_at']) != null
          ? parseTimestamp(data['createdAt'] ?? data['created_at'])
          : DateTime.now(),
      updatedAt: (data['updatedAt'] ?? data['updated_at']) != null
          ? parseTimestamp(data['updatedAt'] ?? data['updated_at'])
          : null,
      totalWorkers: _asInt(data['totalWorkers'] ?? data['total_workers']),
      totalProducts: _asInt(data['totalProducts'] ?? data['total_products']),
      totalCustomers: _asInt(data['totalCustomers'] ?? data['total_customers']),
    );
  }

  double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    try {
      final businesses = getCachedBusinesses();
      final currentBusinessId = getCurrentBusinessId();
      final lastSync = getLastSyncTime();

      return {
        'totalCachedBusinesses': businesses.length,
        'currentBusinessId': currentBusinessId,
        'lastSyncTime': lastSync?.toIso8601String(),
        'isCacheStale': isCacheStale(),
        'businessesInCache': businesses
            .map((b) => {
                  'id': b.id,
                  'name': b.name,
                  'type': b.businessType,
                  'isActive': b.isActive,
                })
            .toList(),
      };
    } catch (e) {
      print('[LocalBusinessStorage] Error getting cache stats: $e');
      return {'error': e.toString()};
    }
  }
}

