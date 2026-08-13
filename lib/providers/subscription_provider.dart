import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../data/models/user_model.dart';

/// Provider to manage user subscription state
class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _subscriptionService;

  UserModel? _currentUser;
  bool _isSubscriptionActive = false;
  bool _isValidating = false;
  String? _error;
  SubscriptionPlan? _currentPlan;

  SubscriptionProvider({SubscriptionService? subscriptionService})
      : _subscriptionService = subscriptionService ?? SubscriptionService();

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isSubscriptionActive => _isSubscriptionActive;
  bool get isValidating => _isValidating;
  String? get error => _error;
  SubscriptionPlan? get currentPlan => _currentPlan;

  /// Set current user and validate subscription
  Future<bool> setUserAndValidateSubscription(UserModel user) async {
    _currentUser = user;
    _isValidating = true;
    _error = null;
    notifyListeners();

    try {
      // Workers do not require subscription validation
      final role = user.role.toLowerCase();
      if (role == 'worker') {
        _isSubscriptionActive = true;
        _currentPlan = null;
        return true;
      }

      // Validate subscription status
      _isSubscriptionActive = await _subscriptionService
          .validateAndUpdateSubscriptionStatus(
        user.id,
        businessId: user.primaryBusinessId.isNotEmpty
            ? user.primaryBusinessId
            : user.businessId,
      );

      // Get current plan if subscribed
      if (_isSubscriptionActive && user.subscriptionPlan != null) {
        _currentPlan = SubscriptionService.getPlanById(user.subscriptionPlan!);
      }

      return _isSubscriptionActive;
    } catch (e) {
      _error = 'Failed to validate subscription: $e';
      _isSubscriptionActive = false;
      return false;
    } finally {
      _isValidating = false;
      notifyListeners();
    }
  }

  /// Process subscription payment
  Future<bool> processSubscriptionPayment({
    required String planId,
    required String transactionId,
    required double amount,
  }) async {
    if (_currentUser == null) return false;

    try {
      final success = await _subscriptionService.createSubscription(
        userId: _currentUser!.id,
        planId: planId,
        transactionId: transactionId,
        amount: amount,
        businessId: _currentUser!.primaryBusinessId.isNotEmpty
            ? _currentUser!.primaryBusinessId
            : _currentUser!.businessId,
      );

      if (success) {
        _isSubscriptionActive = true;
        _currentPlan = SubscriptionService.getPlanById(planId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = 'Failed to process subscription payment: $e';
      return false;
    }
  }

  /// Renew subscription
  Future<bool> renewSubscription({
    required String planId,
    required String transactionId,
    required double amount,
  }) async {
    if (_currentUser == null) return false;

    try {
      final success = await _subscriptionService.renewSubscription(
        userId: _currentUser!.id,
        planId: planId,
        transactionId: transactionId,
        amount: amount,
        businessId: _currentUser!.primaryBusinessId.isNotEmpty
            ? _currentUser!.primaryBusinessId
            : _currentUser!.businessId,
      );

      if (success) {
        _isSubscriptionActive = true;
        _currentPlan = SubscriptionService.getPlanById(planId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = 'Failed to renew subscription: $e';
      return false;
    }
  }

  /// Cancel subscription
  Future<bool> cancelSubscription() async {
    if (_currentUser == null) return false;

    try {
      final success =
          await _subscriptionService.cancelSubscription(_currentUser!.id);

      if (success) {
        _isSubscriptionActive = false;
        _currentPlan = null;
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = 'Failed to cancel subscription: $e';
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider
  void reset() {
    _currentUser = null;
    _isSubscriptionActive = false;
    _error = null;
    _currentPlan = null;
    _isValidating = false;
    notifyListeners();
  }
}

