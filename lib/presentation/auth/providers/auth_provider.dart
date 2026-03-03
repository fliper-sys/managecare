import 'package:flutter/material.dart';

/// Placeholder Auth Provider used only for local demos/tests
/// DO NOT use in production; the real `AuthProvider` is in `lib/providers/auth_provider.dart`.
/// Renamed to avoid class name collision with the production provider implementation.
class PlaceholderAuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _currentUserId;
  String? _currentUserEmail;

  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserId => _currentUserId;
  String? get currentUserEmail => _currentUserEmail;

  Future<void> login(String email, String password) async {
    // TODO: Implement actual login logic
    _isAuthenticated = true;
    _currentUserId = 'user_123';
    _currentUserEmail = email;
    notifyListeners();
  }

  Future<void> register(String email, String password, String name,
      String businessName, String businessType) async {
    // TODO: Implement actual registration logic
    _isAuthenticated = true;
    _currentUserId = 'user_new_123';
    _currentUserEmail = email;
    notifyListeners();
  }

  Future<void> logout() async {
    // TODO: Implement actual logout logic
    _isAuthenticated = false;
    _currentUserId = null;
    _currentUserEmail = null;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    // TODO: Implement password reset logic
  }
}

