import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../data/models/user_model.dart';
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

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

      _marketers =
          snapshot.docs.map((doc) => MarketerModel.fromFirestore(doc)).toList();

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
      final normalizedEmail = email.trim().toLowerCase();

      // Check if email already exists
      final existing = await _firestore
          .collection('app_marketers')
          .where('email', isEqualTo: normalizedEmail)
          .get();

      if (existing.docs.isNotEmpty) {
        _errorMessage = 'Email already exists';
        notifyListeners();
        return null;
      }

      // Create new marketer document
      final newMarketer = MarketerModel(
        id: _firestore.collection('app_marketers').doc().id,
        email: normalizedEmail,
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
      if (profilePhotoUrl != null)
        updateData['profilePhotoUrl'] = profilePhotoUrl;
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
      final normalizedEmail = email.trim().toLowerCase();

      final snapshot = await _firestore
          .collection('app_marketers')
          .where('email', isEqualTo: normalizedEmail)
          .get();

      if (snapshot.docs.isEmpty) {
        _errorMessage = 'Marketer not found';
        notifyListeners();
        return null;
      }

      final marketerDoc = snapshot.docs.first;
      final marketerData = MarketerModel.fromFirestore(marketerDoc);

      if (!marketerData.isActive) {
        _errorMessage = 'This marketer account is currently disabled';
        notifyListeners();
        return null;
      }

      // Verify password
      final hashedPassword = _hashPassword(password);
      if (marketerData.password != hashedPassword) {
        _errorMessage = 'Invalid password';
        notifyListeners();
        return null;
      }

      // Update last login
      await _firestore.collection('app_marketers').doc(marketerData.id).update({
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
    _referrals = [];
    notifyListeners();
  }

  Future<bool> resetMarketerPassword({
    required String email,
    required String phoneNumber,
    required String newPassword,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final normalizedEmail = email.trim().toLowerCase();
      final normalizedPhone = phoneNumber.trim();
      final snapshot = await _firestore
          .collection('app_marketers')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _errorMessage = 'No marketer account found for that email';
        notifyListeners();
        return false;
      }

      final marketer = MarketerModel.fromFirestore(snapshot.docs.first);
      final savedPhone = (marketer.phoneNumber ?? '').trim();
      if (savedPhone.isEmpty || savedPhone != normalizedPhone) {
        _errorMessage = 'Phone number does not match this marketer account';
        notifyListeners();
        return false;
      }

      await snapshot.docs.first.reference.update({
        'password': _hashPassword(newPassword),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final index = _marketers.indexWhere((m) => m.id == marketer.id);
      if (index != -1) {
        _marketers[index] = _marketers[index].copyWith(
          password: _hashPassword(newPassword),
        );
      }

      if (_currentMarketer?.id == marketer.id) {
        _currentMarketer = _currentMarketer!.copyWith(
          password: _hashPassword(newPassword),
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error resetting password: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changeCurrentMarketerPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (_currentMarketer == null) {
        _errorMessage = 'No marketer is currently logged in';
        notifyListeners();
        return false;
      }

      final currentHash = _hashPassword(currentPassword);
      if (_currentMarketer!.password != currentHash) {
        _errorMessage = 'Current password is incorrect';
        notifyListeners();
        return false;
      }

      final newHash = _hashPassword(newPassword);
      await _firestore
          .collection('app_marketers')
          .doc(_currentMarketer!.id)
          .update({
        'password': newHash,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _currentMarketer = _currentMarketer!.copyWith(password: newHash);

      final index = _marketers.indexWhere((m) => m.id == _currentMarketer!.id);
      if (index != -1) {
        _marketers[index] = _marketers[index].copyWith(password: newHash);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error changing password: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
          'totalCommissionEarned':
              currentMarketer.totalCommissionEarned + commissionAmount,
          'totalReferralsApproved': currentMarketer.totalReferralsApproved + 1,
          'totalReferralsPending': currentMarketer.totalReferralsPending - 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // If this is the current logged-in marketer, update local state
        if (_currentMarketer?.email == marketerEmail) {
          _currentMarketer = _currentMarketer!.copyWith(
            balance: currentMarketer.balance + commissionAmount,
            totalCommissionEarned:
                currentMarketer.totalCommissionEarned + commissionAmount,
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

  /// Register a new user on behalf of the marketer
  Future<String?> registerNewUser({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (_currentMarketer == null) {
        throw Exception('No marketer logged in');
      }

      final normalizedEmail = email.trim().toLowerCase();

      // Create Firebase Auth user
      final result = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final userId = result.user!.uid;

      final trimmedFullName = fullName.trim();
      final normalizedPhone =
          phoneNumber?.trim().isNotEmpty == true ? phoneNumber!.trim() : null;
      final newUser = UserModel(
        id: userId,
        email: normalizedEmail,
        fullName: trimmedFullName,
        phoneNumber: normalizedPhone,
        role: 'owner',
        businessId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        isOwner: true,
        pin: '1234',
        referralEmail: _currentMarketer!.email,
      );

      // Create user document in Firestore using the same shape as the standard
      // owner registration flow, while preserving legacy alias fields used by
      // some admin screens.
      await _firestore.collection('users').doc(userId).set({
        ...newUser.toJson(),
        'name': trimmedFullName,
        'phone': normalizedPhone,
        'referredBy': _currentMarketer!.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create referral record
      await _firestore.collection('referrals').add({
        'marketerEmail': _currentMarketer!.email,
        'userId': userId,
        'userEmail': normalizedEmail,
        'commissionAmount': 0.0, // To be set when business is registered
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('app_marketers').doc(_currentMarketer!.id).update({
        'referredUserIds': FieldValue.arrayUnion([userId]),
        'totalReferralsPending': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final updatedUserIds = [..._currentMarketer!.referredUserIds, userId];
      _currentMarketer = _currentMarketer!.copyWith(
        referredUserIds: updatedUserIds,
        totalReferralsPending: _currentMarketer!.totalReferralsPending + 1,
      );

      final marketerIndex =
          _marketers.indexWhere((marketer) => marketer.id == _currentMarketer!.id);
      if (marketerIndex != -1) {
        _marketers[marketerIndex] = _marketers[marketerIndex].copyWith(
          referredUserIds: updatedUserIds,
          totalReferralsPending:
              _marketers[marketerIndex].totalReferralsPending + 1,
        );
      }

      await _auth.signOut();

      // Refresh referrals
      await fetchMarketerReferrals(_currentMarketer!.email);

      notifyListeners();
      return userId;
    } catch (e) {
      _errorMessage = 'Error registering user: $e';
      print(_errorMessage);
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register a business for an existing user
  Future<bool> registerBusinessForUser({
    required String userId,
    required Map<String, dynamic> businessData,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (_currentMarketer == null) {
        throw Exception('No marketer logged in');
      }

      // Get user data to associate
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final businessName = businessData['businessName'] as String;
      final businessType = businessData['businessType'] as String;
      final businessPhone =
          (businessData['phone'] as String?)?.trim().isNotEmpty == true
              ? (businessData['phone'] as String).trim()
              : null;
      final userPhone =
          businessPhone ?? userData['phoneNumber'] ?? userData['phone'] ?? '';
      final ownerName = userData['fullName'] ?? userData['name'] ?? '';

      // Create business document
      final businessRef = await _firestore.collection('businesses').add({
        'ownerId': userId,
        'ownerName': ownerName,
        'name': businessName,
        'businessName': businessName,
        'type': businessType,
        'businessType': businessType,
        'email': userData['email'],
        'phone': userPhone,
        'phoneNumber': userPhone,
        'address': businessData['address'],
        'landmark': businessData['landmark'],
        'businessClass': businessData['businessClass'] ?? 'small',
        'businessTier': businessData['businessTier'] ?? 'starter',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'subscriptionStatus': 'inactive', // Will be activated later
        'referredBy': _currentMarketer!.email,
        'referralEmail': _currentMarketer!.email,
      });

      final businessId = businessRef.id;

      await _firestore.collection('users').doc(userId).set({
        'businessId': businessId,
        'businessIds': FieldValue.arrayUnion([businessId]),
        'currentBusinessId': businessId,
        'preferredBusinessId': businessId,
        'businessName': businessName,
        'businessType': businessType,
        'name': ownerName,
        'fullName': ownerName,
        'phone': userPhone,
        'phoneNumber': userPhone,
        'isOwner': true,
        'referralEmail': _currentMarketer!.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update referral record with business ID and commission
      final referralQuery = await _firestore
          .collection('referrals')
          .where('userId', isEqualTo: userId)
          .where('marketerEmail', isEqualTo: _currentMarketer!.email)
          .get();

      if (referralQuery.docs.isNotEmpty) {
        final referralDoc = referralQuery.docs.first;
        await referralDoc.reference.update({
          'businessId': businessId,
          'commissionAmount': 5000.0, // Example commission amount
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Refresh referrals
      await fetchMarketerReferrals(_currentMarketer!.email);

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error registering business: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
