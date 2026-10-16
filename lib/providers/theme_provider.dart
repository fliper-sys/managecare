import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme provider for light/dark mode.
class ThemeProvider extends ChangeNotifier {
  static const _themePreferenceKey = 'dark_mode';

  bool _isDarkMode =
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
  bool _isLoaded = false;
  bool _userChangedBeforeLoad = false;

  ThemeProvider() {
    _loadThemePreference();
  }

  bool get isDarkMode => _isDarkMode;
  bool get isLoaded => _isLoaded;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() => setDarkMode(!_isDarkMode);

  void setDarkMode(bool value) {
    if (_isLoaded && _isDarkMode == value) return;

    if (!_isLoaded) _userChangedBeforeLoad = true;
    _isDarkMode = value;
    notifyListeners();
    _persistThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedValue = prefs.getBool(_themePreferenceKey);

      if (!_userChangedBeforeLoad &&
          storedValue != null &&
          storedValue != _isDarkMode) {
        _isDarkMode = storedValue;
      }
    } catch (_) {
      // Use the platform brightness fallback when preferences are unavailable.
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _persistThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themePreferenceKey, _isDarkMode);
    } catch (_) {
      // Persisting the user's preference is best-effort.
    }
  }
}

