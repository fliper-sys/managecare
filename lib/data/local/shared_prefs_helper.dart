import 'package:shared_preferences/shared_preferences.dart';

/// Helper for SharedPreferences operations
class SharedPrefsHelper {
  static final SharedPrefsHelper _instance = SharedPrefsHelper._init();
  static SharedPreferences? _prefs;

  SharedPrefsHelper._init();

  static SharedPrefsHelper get instance => _instance;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Auth preferences
  Future<bool> setAuthToken(String token) async {
    return await _prefs?.setString('auth_token', token) ?? false;
  }

  String? getAuthToken() {
    return _prefs?.getString('auth_token');
  }

  Future<bool> setUserId(String userId) async {
    return await _prefs?.setString('user_id', userId) ?? false;
  }

  String? getUserId() {
    return _prefs?.getString('user_id');
  }

  Future<bool> setBusinessId(String businessId) async {
    return await _prefs?.setString('business_id', businessId) ?? false;
  }

  String? getBusinessId() {
    return _prefs?.getString('business_id');
  }

  // Theme preference
  Future<bool> setDarkMode(bool isDark) async {
    return await _prefs?.setBool('dark_mode', isDark) ?? false;
  }

  bool getDarkMode() {
    return _prefs?.getBool('dark_mode') ?? false;
  }

  // Last sync time
  Future<bool> setLastSyncTime(DateTime dateTime) async {
    return await _prefs?.setString('last_sync', dateTime.toIso8601String()) ??
        false;
  }

  DateTime? getLastSyncTime() {
    final syncTime = _prefs?.getString('last_sync');
    return syncTime != null ? DateTime.parse(syncTime) : null;
  }

  // Pending sync count
  Future<bool> setPendingSyncCount(int count) async {
    return await _prefs?.setInt('pending_sync_count', count) ?? false;
  }

  int getPendingSyncCount() {
    return _prefs?.getInt('pending_sync_count') ?? 0;
  }

  // Clear all preferences
  Future<bool> clearAll() async {
    return await _prefs?.clear() ?? false;
  }

  // Clear auth data
  Future<bool> clearAuth() async {
    await _prefs?.remove('auth_token');
    await _prefs?.remove('user_id');
    return true;
  }
}

