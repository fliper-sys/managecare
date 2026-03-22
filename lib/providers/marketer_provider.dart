import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/marketer_model.dart';

/// Provider for managing App Marketers
class MarketerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<MarketerModel> _marketers = [];
  MarketerModel? _currentMarketer;
  List<ReferralRecord> _referrals = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<MarketerModel> get marketers => _marketers;
  MarketerModel? get currentMarketer => _currentMarketer;
  List<ReferralRecord> get referrals => _referrals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetch all marketers
  Future<void> fetchMarketers() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection('app_marketers')
          .orderBy('createdAt', descending: true)
          .get();

      _marketers = snapshot.docs
          .map((doc) => MarketerModel.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching marketers: $e';
      print(_errorMessage);
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new marketer
  Future<String?> createMarketer({
    required String email,
    required String fullName,
    required String password,
    String? phoneNumber,
    String? profilePhotoUrl,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Hash the password
      final hashedPassword = _hashPassword(password);

      // Check if email already exists
      final existing = await _firestore
          .collection('app_marketers')
          .where('email', isEqualTo: email)
          .get();

      if (existing.docs.isNotEmpty) {
        _errorMessage = 'Email already exists';
        notifyListeners();
        return null;
      }

      // Create new marketer document
      final newMarketer = MarketerModel(
        id: _firestore.collection('app_marketers').doc().id,
        email: email,
        fullName: fullName,
        password: hashedPassword,
        phoneNumber: phoneNumber,
        profilePhotoUrl: profilePhotoUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        balance: 0.0,
        referredUserIds: [],
        referrals: [],
        isActive: true,
      );

      await _firestore
          .collection('app_marketers')
          .doc(newMarketer.id)
          .set(newMarketer.toFirestore());

      _marketers.add(newMarketer);
      notifyListeners();

      return newMarketer.id;
    } catch (e) {
      _errorMessage = 'Error creating marketer: $e';
      print(_errorMessage);
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update marketer information
  Future<bool> updateMarketer(
    String marketerId, {
    String? fullName,
    String? phoneNumber,
    String? profilePhotoUrl,
    bool? isActive,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (fullName != null) updateData['fullName'] = fullName;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (profilePhotoUrl != null) updateData['profilePhotoUrl'] = profilePhotoUrl;
      if (isActive != null) updateData['isActive'] = isActive;

      await _firestore
          .collection('app_marketers')
          .doc(marketerId)
          .update(updateData);

      // Update local list
      final index = _marketers.indexWhere((m) => m.id == marketerId);
      if (index != -1) {
        _marketers[index] = _marketers[index].copyWith(
          fullName: fullName,
          phoneNumber: phoneNumber,
          profilePhotoUrl: profilePhotoUrl,
          isActive: isActive,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error updating marketer: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete marketer
  Future<bool> deleteMarketer(String marketerId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('app_marketers').doc(marketerId).delete();

      _marketers.removeWhere((m) => m.id == marketerId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error deleting marketer: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login marketer with email and password
  Future<MarketerModel?> loginMarketer(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection('app_marketers')
          .where('email', isEqualTo: email)
          .get();

      if (snapshot.docs.isEmpty) {
        _errorMessage = 'Marketer not found';
        notifyListeners();
        return null;
      }

      final marketerDoc = snapshot.docs.first;
      final marketerData = MarketerModel.fromFirestore(marketerDoc);

      // Verify password
      final hashedPassword = _hashPassword(password);
      if (marketerData.password != hashedPassword) {
        _errorMessage = 'Invalid password';
        notifyListeners();
        return null;
      }

      // Update last login
      await _firestore
          .collection('app_marketers')
          .doc(marketerData.id)
          .update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      _currentMarketer = marketerData.copyWith(
        lastLoginAt: DateTime.now(),
      );

      notifyListeners();
      return _currentMarketer;
    } catch (e) {
      _errorMessage = 'Error logging in: $e';
      print(_errorMessage);
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logout current marketer
  void logoutMarketer() {
    _currentMarketer = null;
    notifyListeners();
  }

  /// Fetch all referrals for a specific marketer
  Future<void> fetchMarketerReferrals(String marketerEmail) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection('referrals')
          .where('marketerEmail', isEqualTo: marketerEmail)
          .orderBy('createdAt', descending: true)
          .get();

      _referrals = snapshot.docs
          .map((doc) => ReferralRecord.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching referrals: $e';
      print(_errorMessage);
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Approve a referral and update marketer balance
  Future<bool> approveReferral(
    String referralId,
    String marketerEmail,
    double commissionAmount,
  ) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Start a batch write
      final batch = _firestore.batch();

      // Update referral status
      final referralRef = _firestore.collection('referrals').doc(referralId);
      batch.update(referralRef, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Get marketer document
      final marketerSnapshot = await _firestore
          .collection('app_marketers')
          .where('email', isEqualTo: marketerEmail)
          .get();

      if (marketerSnapshot.docs.isNotEmpty) {
        final marketerDoc = marketerSnapshot.docs.first;
        final currentMarketer = MarketerModel.fromFirestore(marketerDoc);

        // Update marketer balance and stats
        batch.update(marketerDoc.reference, {
          'balance': currentMarketer.balance + commissionAmount,
          'totalCommissionEarned': currentMarketer.totalCommissionEarned + commissionAmount,
          'totalReferralsApproved': currentMarketer.totalReferralsApproved + 1,
          'totalReferralsPending': currentMarketer.totalReferralsPending - 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // If this is the current logged-in marketer, update local state
        if (_currentMarketer?.email == marketerEmail) {
          _currentMarketer = _currentMarketer!.copyWith(
            balance: currentMarketer.balance + commissionAmount,
            totalCommissionEarned: currentMarketer.totalCommissionEarned + commissionAmount,
            totalReferralsApproved: currentMarketer.totalReferralsApproved + 1,
            totalReferralsPending: currentMarketer.totalReferralsPending - 1,
          );
        }
      }

      await batch.commit();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error approving referral: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reject a referral
  Future<bool> rejectReferral(String referralId, String? reason) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('referrals').doc(referralId).update({
        'status': 'rejected',
        'notes': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error rejecting referral: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Hash password using SHA256
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Update marketer balance (used when admin approves referrals)
  Future<bool> updateMarketerBalance(String marketerId, double amount) async {
    try {
      final marketer = _marketers.firstWhere((m) => m.id == marketerId);

      await _firestore.collection('app_marketers').doc(marketerId).update({
        'balance': marketer.balance + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final index = _marketers.indexWhere((m) => m.id == marketerId);
      if (index != -1) {
        _marketers[index] = _marketers[index].copyWith(
          balance: marketer.balance + amount,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error updating balance: $e';
      print(_errorMessage);
      return false;
    }
  }
}
