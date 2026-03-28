import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/user_model.dart';

/// Service to manage local user data persistence on device
class LocalUserStorage {
  static const String _userKey = 'cached_user_data';
  static const String _emailKey = 'last_logged_in_email';
  static const String _autoLoginKey = 'auto_login_enabled';

  final SharedPreferences _prefs;

  LocalUserStorage(this._prefs);

  static Future<LocalUserStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalUserStorage(prefs);
  }

  /// Save user data to local storage after login
  Future<bool> saveUser(UserModel user) async {
    try {
      final json = jsonEncode(user.toJson());
      await _prefs.setString(_userKey, json);
      await _prefs.setString(_emailKey, user.email);
      await _prefs.setBool(_autoLoginKey, true);
      return true;
    } catch (e) {
      print('Error saving user to local storage: $e');
      return false;
    }
  }

  /// Retrieve cached user data from local storage
  UserModel? getCachedUser() {
    try {
      final json = _prefs.getString(_userKey);
      if (json == null) return null;

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return UserModel.fromJson(decoded);
    } catch (e) {
      print('Error retrieving cached user: $e');
      return null;
    }
  }

  /// Get the last logged-in email (for pre-filling login form, etc.)
  String? getLastLoggedInEmail() {
    return _prefs.getString(_emailKey);
  }

  /// Check if auto-login is enabled
  bool isAutoLoginEnabled() {
    return _prefs.getBool(_autoLoginKey) ?? false;
  }

  /// Clear all user data (call on logout)
  Future<bool> clearUser() async {
    try {
      await _prefs.remove(_userKey);
      await _prefs.remove(_emailKey);
      await _prefs.setBool(_autoLoginKey, false);
      return true;
    } catch (e) {
      print('Error clearing user from local storage: $e');
      return false;
    }
  }

  /// Update only specific user fields in local storage
  /// Supports adding businessIds and setting currentBusinessId
  Future<bool> updateCachedUser({
    String? email,
    String? fullName,
    String? phoneNumber,
    String? photoUrl,
    String? businessId,
    List<String>? businessIds,
    String? currentBusinessId,
    bool? isOwner,
  }) async {
    try {
      final cached = getCachedUser();
      if (cached == null) return false;

      // Merge businessIds if provided; otherwise keep existing
      List<String> mergedBusinessIds = cached.businessIds;
      if (businessIds != null) {
        mergedBusinessIds = List<String>.from({...mergedBusinessIds, ...businessIds});
      } else if (businessId != null && businessId.isNotEmpty) {
        if (!mergedBusinessIds.contains(businessId)) mergedBusinessIds.add(businessId);
      }

      final updated = cached.copyWith(
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        photoUrl: photoUrl,
        businessId: businessId ?? cached.businessId,
        businessIds: mergedBusinessIds,
        currentBusinessId: currentBusinessId ?? cached.currentBusinessId,
        isOwner: isOwner ?? cached.isOwner,
      );

      return saveUser(updated);
    } catch (e) {
      print('Error updating cached user: $e');
      return false;
    }
  }

  // --- Per-user UI preferences ---
  static const String _suppressBusinessSwitchPrefix = 'suppress_business_switch_';

  /// Set whether the confirmation dialog for business switching should be suppressed for a given user
  Future<bool> setSuppressBusinessSwitchConfirmationForUser(String userId, bool value) async {
    try {
      final key = '$_suppressBusinessSwitchPrefix$userId';
      await _prefs.setBool(key, value);
      return true;
    } catch (e) {
      print('Error setting suppressBusinessSwitch flag for $userId: $e');
      return false;
    }
  }

  /// Get the suppression flag for a given user
  bool getSuppressBusinessSwitchConfirmationForUser(String userId) {
    try {
      final key = '$_suppressBusinessSwitchPrefix$userId';
      return _prefs.getBool(key) ?? false;
    } catch (e) {
      print('Error reading suppressBusinessSwitch flag for $userId: $e');
      return false;
    }
  }

  // --- Per-user diagnostic/edge logging flag ---
  static const String _edgeLoggingPrefix = 'edge_logging_';

  /// Enable or disable detailed edge diagnostic logging for a specific user
  Future<bool> setEdgeLoggingForUser(String userId, bool value) async {
    try {
      final key = '$_edgeLoggingPrefix$userId';
      await _prefs.setBool(key, value);
      return true;
    } catch (e) {
      print('Error setting edge logging flag for $userId: $e');
      return false;
    }
  }

  /// Read the diagnostic logging flag for a specific user
  bool getEdgeLoggingForUser(String userId) {
    try {
      final key = '$_edgeLoggingPrefix$userId';
      return _prefs.getBool(key) ?? false;
    } catch (e) {
      print('Error reading edge logging flag for $userId: $e');
      return false;
    }
  }
}

