import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/utils/datetime_utils.dart';
import '../services/deletion_recovery_service.dart';
import '../services/email_service.dart';

/// Model for admin statistics
class AdminStats {
  final int totalBusinesses;
  final int activeUsers;
  final int totalRevenue;
  final int pendingPayments;
  final int totalTransactions;
  final int pendingSubscriptionApprovals;
  final int activeSubscriptions;
  final int restrictedBusinesses;
  final int totalMarketers;
  final List<Map<String, dynamic>> recentActivities;

  AdminStats({
    this.totalBusinesses = 0,
    this.activeUsers = 0,
    this.totalRevenue = 0,
    this.pendingPayments = 0,
    this.totalTransactions = 0,
    this.pendingSubscriptionApprovals = 0,
    this.activeSubscriptions = 0,
    this.restrictedBusinesses = 0,
    this.totalMarketers = 0,
    this.recentActivities = const [],
  });

  AdminStats copyWith({
    int? totalBusinesses,
    int? activeUsers,
    int? totalRevenue,
    int? pendingPayments,
    int? totalTransactions,
    int? pendingSubscriptionApprovals,
    int? activeSubscriptions,
    int? restrictedBusinesses,
    int? totalMarketers,
    List<Map<String, dynamic>>? recentActivities,
  }) {
    return AdminStats(
      totalBusinesses: totalBusinesses ?? this.totalBusinesses,
      activeUsers: activeUsers ?? this.activeUsers,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      pendingPayments: pendingPayments ?? this.pendingPayments,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      pendingSubscriptionApprovals:
          pendingSubscriptionApprovals ?? this.pendingSubscriptionApprovals,
      activeSubscriptions: activeSubscriptions ?? this.activeSubscriptions,
      restrictedBusinesses:
          restrictedBusinesses ?? this.restrictedBusinesses,
      totalMarketers: totalMarketers ?? this.totalMarketers,
      recentActivities: recentActivities ?? this.recentActivities,
    );
  }
}

/// Admin provider for managing admin-specific features
class AdminProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeletionRecoveryService _deletionRecoveryService =
      DeletionRecoveryService(firestore: FirebaseFirestore.instance);
  final EmailService _emailService = EmailService();

  AdminStats _stats = AdminStats();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allBusinesses = [];
  int _usersCollectionCount = 0;
  int _workersCollectionCount = 0;

  // Installation requests pending count
  int _pendingInstallationRequests = 0;
  StreamSubscription<QuerySnapshot>? _installationSub;
  
  // Throttling: Prevent redundant Firestore calls
  DateTime? _lastStatsLoadTime;
  static const Duration _minStatsRefreshInterval = Duration(minutes: 2);
  bool _isStatsLoadInProgress = false;

  // Getters
  AdminStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get allUsers => _allUsers;
  List<Map<String, dynamic>> get allBusinesses => _allBusinesses;
  int get pendingInstallationRequestsCount => _pendingInstallationRequests;
  int get pendingSubscriptionApprovalsCount =>
      _stats.pendingSubscriptionApprovals;
  int get activeSubscriptionsCount => _stats.activeSubscriptions;
  int get restrictedBusinessesCount => _stats.restrictedBusinesses;
  int get marketersCount => _stats.totalMarketers;
  int get usersTableCount => _usersCollectionCount;
  int get workersTableCount => _workersCollectionCount;
  int get activeBusinessesCount =>
      _allBusinesses.where(_isBusinessAvailable).length;

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'active';
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0.0;

    final normalized = value.toString().replaceAll(',', '').trim();
    return double.tryParse(normalized) ?? 0.0;
  }

  String _readString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  String _buildMergedUserKey(String docId, Map<String, dynamic> data) {
    final email = _readString(data['email']).toLowerCase();
    if (email.isNotEmpty) return 'email:$email';

    final workerId = _readString(data['workerId']);
    if (workerId.isNotEmpty) return 'worker:$workerId';

    return 'id:$docId';
  }

  String _buildRevenueKey(String docId, Map<String, dynamic> data) {
    final transactionId =
        _readString(data['transactionId'] ?? data['processorTransactionId']);
    if (transactionId.isNotEmpty) return 'tx:$transactionId';

    final requestId = _readString(data['requestId'] ?? data['uploadId']);
    if (requestId.isNotEmpty) return 'request:$requestId';

    return 'doc:$docId';
  }

  List<Map<String, dynamic>> _mergeAdminAccessibleUsers(
    QuerySnapshot<Map<String, dynamic>> usersSnapshot,
    QuerySnapshot<Map<String, dynamic>> workersSnapshot,
  ) {
    final mergedUsers = <String, Map<String, dynamic>>{};

    void mergeDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      String tableName,
    ) {
      final data = <String, dynamic>{'id': doc.id, ...doc.data()};
      final fullName = _readString(data['fullName']);
      if (_readString(data['name']).isEmpty && fullName.isNotEmpty) {
        data['name'] = fullName;
      }

      if (tableName == 'workers') {
        data['workerDocumentId'] = doc.id;
        if (_readString(data['type']).isEmpty) {
          data['type'] = 'worker';
        }
        if (_readString(data['role']).isEmpty) {
          data['role'] = 'worker';
        }
      }

      final mergeKey = _buildMergedUserKey(doc.id, data);
      final existing = mergedUsers[mergeKey];

      Map<String, dynamic> merged;
      if (existing == null) {
        merged = {...data};
      } else if (tableName == 'users') {
        merged = {...existing, ...data};
      } else {
        merged = {...data, ...existing};
      }

      final tableSources = <String>{
        if (existing != null && existing['tableSources'] is List)
          ...List<String>.from(
            (existing['tableSources'] as List)
                .map((entry) => entry.toString()),
          ),
        tableName,
      }.toList()
        ..sort();

      merged['tableSources'] = tableSources;
      merged['tableSource'] =
          tableSources.length > 1 ? 'users+workers' : tableName;
      merged['isWorker'] =
          _readBool(merged['isWorker']) ||
          _readString(merged['role']).toLowerCase() == 'worker' ||
          _readString(merged['type']).toLowerCase() == 'worker' ||
          tableSources.contains('workers');

      mergedUsers[mergeKey] = merged;
    }

    for (final doc in usersSnapshot.docs) {
      mergeDoc(doc, 'users');
    }

    for (final doc in workersSnapshot.docs) {
      mergeDoc(doc, 'workers');
    }

    final result = mergedUsers.values.toList();
    result.sort((a, b) {
      final left = _readString(a['name']).isNotEmpty
          ? _readString(a['name']).toLowerCase()
          : _readString(a['email']).toLowerCase();
      final right = _readString(b['name']).isNotEmpty
          ? _readString(b['name']).toLowerCase()
          : _readString(b['email']).toLowerCase();
      return left.compareTo(right);
    });
    return result;
  }

  Future<int> _computeRecognizedRevenue() async {
    double totalRevenue = 0.0;
    final recognizedKeys = <String>{};

    final approvalsSnapshot =
        await _firestore.collection('subscription_approvals').get();
    for (final doc in approvalsSnapshot.docs) {
      final data = doc.data();
      final status = _readString(data['status']).toLowerCase();
      if (status != 'approved' &&
          status != 'recognized' &&
          status != 'processed') {
        continue;
      }

      final amount = _readDouble(data['amount']);
      if (amount <= 0) continue;

      final revenueKey = _buildRevenueKey(doc.id, data);
      if (recognizedKeys.add(revenueKey)) {
        totalRevenue += amount;
      }
    }

    final transactionsSnapshot =
        await _firestore.collection('payment_transactions').get();
    for (final doc in transactionsSnapshot.docs) {
      final data = doc.data();
      final approvalStatus = _readString(data['approvalStatus']).toLowerCase();
      final status = _readString(data['status']).toLowerCase();
      final recognized = _readBool(data['revenueRecognized']) ||
          approvalStatus == 'approved' ||
          approvalStatus == 'recognized' ||
          approvalStatus == 'processed' ||
          status == 'approved' ||
          status == 'recognized' ||
          status == 'processed';
      if (!recognized) continue;

      final amount = _readDouble(data['amount']);
      if (amount <= 0) continue;

      final revenueKey = _buildRevenueKey(doc.id, data);
      if (recognizedKeys.add(revenueKey)) {
        totalRevenue += amount;
      }
    }

    return totalRevenue.round();
  }

  bool _isBusinessAvailable(Map<String, dynamic> business) {
    return !_isBusinessRestricted(business) &&
        (business['isActive'] == null || _readBool(business['isActive'])) &&
        _isSubscriptionActive(business);
  }

  bool _isBusinessRestricted(Map<String, dynamic> business) {
    final restrictionStatus =
        (business['restrictionStatus'] ?? business['status'] ?? '')
            .toString()
            .toLowerCase();
    return _readBool(business['isRestricted']) ||
        restrictionStatus == 'restricted' ||
        restrictionStatus == 'suspended' ||
        restrictionStatus == 'blocked';
  }

  bool _isSubscriptionActive(Map<String, dynamic> business) {
    if (_readBool(
      business['isSubscriptionActive'] ?? business['hasActiveSubscription'],
    )) {
      return true;
    }

    final endDateRaw = business['subscriptionEndDate'];
    if (endDateRaw == null) {
      return false;
    }

    try {
      final endDate = parseTimestamp(endDateRaw);
      return endDate.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  bool _hasPendingSubscriptionReview(Map<String, dynamic> business) {
    final pendingStates = {
      'pending',
      'submitted',
      'awaiting_approval',
      'awaiting-review',
      'awaiting_review',
    };
    final reviewStatus = (business['subscriptionStatus'] ??
            business['subscriptionReviewStatus'] ??
            business['requestStatus'] ??
            '')
        .toString()
        .toLowerCase();
    return pendingStates.contains(reviewStatus);
  }

  void _refreshDerivedStatsFromCache() {
    final pendingFromCache =
        _allBusinesses.where(_hasPendingSubscriptionReview).length;
    _stats = _stats.copyWith(
      totalBusinesses: _allBusinesses.length,
      activeSubscriptions:
          _allBusinesses.where(_isSubscriptionActive).length,
      restrictedBusinesses:
          _allBusinesses.where(_isBusinessRestricted).length,
      pendingSubscriptionApprovals: pendingFromCache > 0
          ? pendingFromCache
          : _stats.pendingSubscriptionApprovals,
    );
  }

  /// Load persisted admin settings.
  Future<Map<String, dynamic>> getAdminSettings() async {
    try {
      final doc = await _firestore.collection('system').doc('admin_settings').get();
      return doc.data() ?? const {};
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return const {};
    }
  }

  /// Persist admin settings to Firestore.
  Future<bool> saveAdminSettings(Map<String, dynamic> settings) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('system').doc('admin_settings').set({
        ...settings,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      }, SetOptions(merge: true));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetch real-time admin statistics from Firestore
  Future<void> fetchAdminStats({bool force = false}) async {
    // Prevent duplicate simultaneous requests
    if (_isStatsLoadInProgress) {
      print('[AdminProvider] ⏭️ Stats load already in progress, skipping duplicate request');
      return;
    }

    // Throttle: Don't reload if we loaded recently
    if (!force && _lastStatsLoadTime != null) {
      final elapsed = DateTime.now().difference(_lastStatsLoadTime!);
      if (elapsed < _minStatsRefreshInterval) {
        print('[AdminProvider] ⏭️ Skipping reload - stats refreshed ${elapsed.inSeconds}s ago');
        return;
      }
    }

    try {
      _isStatsLoadInProgress = true;
      _errorMessage = null;
      // DON'T notify yet - wait until data is fetched to avoid rebuild loop

      print('[AdminProvider] 🔄 Fetching admin statistics...');

      // Fetch all businesses
      final businessesSnapshot =
          await _firestore.collection('businesses').get();
      _allBusinesses = businessesSnapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();

      // Fetch all users
      final usersSnapshot = await _firestore.collection('users').get();
      _allUsers = usersSnapshot.docs.map((doc) {
        final userData = {'id': doc.id, ...doc.data()};
        
        print('🔍 ENRICHMENT: Processing user "${userData['name']}" with businessId="${userData['businessId']}"');
        
        // Enrich user data with business subscription status
        final businessId = userData['businessId'] as String?;
        if (businessId != null && businessId.isNotEmpty) {
          final matchingBusiness = _allBusinesses.firstWhere(
            (b) => b['id'] == businessId,
            orElse: () => {},
          );
          if (matchingBusiness.isNotEmpty) {
            print('🔍 ENRICHMENT: Found business for "${userData['name']}": isSubscriptionActive=${matchingBusiness['isSubscriptionActive']}');
            userData['isSubscriptionActive'] = matchingBusiness['isSubscriptionActive'] ?? false;
            userData['subscriptionTier'] = matchingBusiness['subscriptionTier'] ?? 'tier1';
            userData['subscriptionEndDate'] = matchingBusiness['subscriptionEndDate'];
            userData['subscriptionStartDate'] = matchingBusiness['subscriptionStartDate'];
            userData['businessName'] = matchingBusiness['businessName'] ?? 'N/A';
          } else {
            print('🔍 ENRICHMENT: NO business found for businessId="$businessId" in ${_allBusinesses.length} businesses');
          }
        } else {
          // If no businessId, set default values
          print('🔍 ENRICHMENT: No businessId for "${userData['name']}"');
          userData['isSubscriptionActive'] = false;
          userData['subscriptionTier'] = 'tier1';
        }
        
        print('🔍 ENRICHMENT RESULT: "${userData['name']}" -> isSubscriptionActive=${userData['isSubscriptionActive']}');
        
        return userData;
      }).toList();

      // Merge in the separate workers table so admin can inspect every user
      // record source from one consolidated list.
      final workersSnapshot = await _firestore.collection('workers').get();
      _usersCollectionCount = usersSnapshot.docs.length;
      _workersCollectionCount = workersSnapshot.docs.length;
      _allUsers = _mergeAdminAccessibleUsers(usersSnapshot, workersSnapshot)
          .map((userData) {
        final resolvedBusinessId = _readString(userData['currentBusinessId'])
                .isNotEmpty
            ? _readString(userData['currentBusinessId'])
            : _readString(userData['businessId']);

        if (resolvedBusinessId.isNotEmpty) {
          final matchingBusiness = _allBusinesses.firstWhere(
            (b) => b['id'] == resolvedBusinessId,
            orElse: () => {},
          );
          if (matchingBusiness.isNotEmpty) {
            userData['businessId'] = resolvedBusinessId;
            userData['isSubscriptionActive'] =
                matchingBusiness['isSubscriptionActive'] ?? false;
            userData['subscriptionTier'] =
                matchingBusiness['subscriptionTier'] ?? 'tier1';
            userData['subscriptionEndDate'] =
                matchingBusiness['subscriptionEndDate'];
            userData['subscriptionStartDate'] =
                matchingBusiness['subscriptionStartDate'];
            userData['businessName'] =
                matchingBusiness['name'] ??
                matchingBusiness['businessName'] ??
                'N/A';
            userData['businessRestricted'] =
                _isBusinessRestricted(matchingBusiness);
            userData['businessRestrictionReason'] =
                matchingBusiness['restrictionReason'];
          } else {
            userData['isSubscriptionActive'] =
                userData['isSubscriptionActive'] ?? false;
            userData['subscriptionTier'] =
                userData['subscriptionTier'] ?? 'tier1';
          }
        } else {
          userData['isSubscriptionActive'] = false;
          userData['subscriptionTier'] = 'tier1';
        }

        return userData;
      }).toList();

      // Calculate statistics from subscription tiers
      int totalRevenue = 0;
      int pendingPayments = 0;
      int totalTransactions = 0;
      int pendingSubscriptionApprovals = 0;
      int totalMarketers = 0;

      // Define subscription pricing in Naira
      final subscriptionPricing = {
        'tier1': 10000,
        'tier2': 20000,
        'tier3': 100000,
        'unlimited': 150000,
      };

      for (var business in _allBusinesses) {
        // Calculate revenue from subscription tier
        final tier =
            business['subscriptionTier']?.toString().toLowerCase() ?? 'tier1';
        final tierRevenue = subscriptionPricing[tier] ?? 10000;
        totalRevenue += tierRevenue;

        // Also add any additional revenue if stored
        if (business['additionalRevenue'] != null) {
          totalRevenue += (business['additionalRevenue'] as num).toInt();
        }
      }

      // Use approved and recognized payment records as the revenue source of
      // truth instead of estimating revenue from active subscription tiers.
      totalRevenue = await _computeRecognizedRevenue();

      // Fetch payments for pending status
      final paymentsSnapshot = await _firestore
          .collection('payments')
          .where('status', isEqualTo: 'pending')
          .get();
      pendingPayments = paymentsSnapshot.docs.length;

      final subscriptionRequestsSnapshot = await _firestore
          .collection('subscription_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      pendingSubscriptionApprovals = subscriptionRequestsSnapshot.docs.length;

      // Count all transactions
      final transactionsSnapshot =
          await _firestore.collection('transactions').get();
      totalTransactions = transactionsSnapshot.docs.length;

      final paymentTransactionsSnapshot =
          await _firestore.collection('payment_transactions').get();
      totalTransactions = paymentTransactionsSnapshot.docs.length;

      final marketersSnapshot = await _firestore.collection('app_marketers').get();
      totalMarketers = marketersSnapshot.docs.length;

      // Get recent activities (last 10)
      final activitiesSnapshot = await _firestore
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final recentActivities = activitiesSnapshot.docs.map((doc) {
        return doc.data();
      }).toList();

      // Calculate active users (with proper Timestamp handling)
      int activeUsersCount = 0;
      for (var user in _allUsers) {
        if (user['lastActive'] == null) continue;
        final lastActiveDate = parseTimestamp(user['lastActive']);

        if (lastActiveDate.isAfter(DateTime.now().subtract(const Duration(hours: 24)))) {
          activeUsersCount++;
        }
      }

      _stats = AdminStats(
        totalBusinesses: _allBusinesses.length,
        activeUsers: activeUsersCount,
        totalRevenue: totalRevenue,
        pendingPayments: pendingPayments,
        totalTransactions: totalTransactions,
        pendingSubscriptionApprovals: pendingSubscriptionApprovals,
        activeSubscriptions:
            _allBusinesses.where(_isSubscriptionActive).length,
        restrictedBusinesses:
            _allBusinesses.where(_isBusinessRestricted).length,
        totalMarketers: totalMarketers,
        recentActivities: recentActivities,
      );

      // Start listening to installation requests count (real-time)
      _startInstallationRequestsListener();

      _lastStatsLoadTime = DateTime.now();
      _isLoading = false;
      _isStatsLoadInProgress = false;
      print('[AdminProvider] ✅ Admin stats fetched successfully');
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _isStatsLoadInProgress = false;
      print('[AdminProvider] ❌ Error fetching stats: $e');
      notifyListeners();
    }
  }

  /// Send notification to specific users
  Future<bool> sendNotificationToUsers({
    required String title,
    required String body,
    required List<String> userIds,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Store notification in Firestore
      final notificationId = _firestore.collection('notifications').doc().id;

      await _firestore.collection('notifications').doc(notificationId).set({
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'targetUsers': userIds,
        'type': 'notification',
        'sentBy': _auth.currentUser?.uid,
      });

      // Update each user's notification list. Support both users and workers
      // records because admin views can be sourced from either collection.
      for (var userId in userIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final workerDoc =
            await _firestore.collection('workers').doc(userId).get();

        final targets = <DocumentReference<Map<String, dynamic>>>[
          if (userDoc.exists) userDoc.reference,
          if (workerDoc.exists) workerDoc.reference,
        ];

        for (final ref in targets) {
          await ref.collection('notifications').add({
            'title': title,
            'body': body,
            'read': false,
            'type': 'notification',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> grantBusinessSubscription({
    required String businessId,
    required String businessName,
    required String tier,
    required int durationDays,
    String source = 'admin_manual',
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final now = DateTime.now();
      final endDate = now.add(Duration(days: durationDays));
      final normalizedTier = tier.toLowerCase();
      final businessRef = _firestore.collection('businesses').doc(businessId);
      var approvedPendingCount = 0;

      await businessRef.set({
        'subscriptionTier': normalizedTier,
        'subscriptionPlan': '${normalizedTier}_${durationDays}d',
        'subscriptionStartDate': Timestamp.fromDate(now),
        'subscriptionEndDate': Timestamp.fromDate(endDate),
        'subscriptionDurationDays': durationDays,
        'isSubscriptionActive': true,
        'subscriptionStatus': 'approved',
        'subscriptionReviewStatus': 'approved',
        'subscriptionApprovedAt': Timestamp.now(),
        'subscriptionApprovedBy': _auth.currentUser?.uid ?? 'system',
        'subscriptionSource': source,
        'subscriptionDeclineReason': FieldValue.delete(),
        'subscriptionDeclinedAt': FieldValue.delete(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      try {
        final pendingRequests = await _firestore
            .collection('subscription_requests')
            .where('businessId', isEqualTo: businessId)
            .where('status', isEqualTo: 'pending')
            .get();
        approvedPendingCount = pendingRequests.docs.length;

        for (final doc in pendingRequests.docs) {
          await doc.reference.set({
            'status': 'approved',
            'subscriptionStatus': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
            'approvedBy': _auth.currentUser?.uid ?? 'system',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (_) {}

      await _firestore.collection('subscriptions').add({
        'businessId': businessId,
        'businessName': businessName,
        'tier': normalizedTier,
        'startDate': Timestamp.fromDate(now),
        'endDate': Timestamp.fromDate(endDate),
        'durationDays': durationDays,
        'isSubscriptionActive': true,
        'approvedAt': Timestamp.now(),
        'approvedBy': _auth.currentUser?.uid ?? 'system',
        'type': source,
      });

      final idx = _allBusinesses.indexWhere((b) => b['id'] == businessId);
      if (idx >= 0) {
        _allBusinesses[idx] = {
          ..._allBusinesses[idx],
          'subscriptionTier': normalizedTier,
          'subscriptionPlan': '${normalizedTier}_${durationDays}d',
          'subscriptionDurationDays': durationDays,
          'isSubscriptionActive': true,
          'subscriptionStatus': 'approved',
          'subscriptionReviewStatus': 'approved',
          'subscriptionEndDate': Timestamp.fromDate(endDate),
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionDeclineReason': null,
          'subscriptionDeclinedAt': null,
        };
      }

      for (int i = 0; i < _allUsers.length; i++) {
        if (_allUsers[i]['businessId'] == businessId) {
          _allUsers[i] = {
            ..._allUsers[i],
            'isSubscriptionActive': true,
            'subscriptionStatus': 'approved',
            'subscriptionTier': normalizedTier,
            'subscriptionPlan': '${normalizedTier}_${durationDays}d',
            'subscriptionDurationDays': durationDays,
            'subscriptionEndDate': Timestamp.fromDate(endDate),
            'subscriptionStartDate': Timestamp.fromDate(now),
          };
        }
      }

      final affectedUsers = await _firestore
          .collection('users')
          .where('businessId', isEqualTo: businessId)
          .get();
      final endLabel =
          '${endDate.day}/${endDate.month}/${endDate.year}';
      for (final userDoc in affectedUsers.docs) {
        await userDoc.reference.collection('notifications').add({
          'title': 'Subscription Activated',
          'body':
              '$businessName now has a ${normalizedTier.toUpperCase()} subscription active until $endLabel.',
          'read': false,
          'type': 'subscription',
          'businessId': businessId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _refreshDerivedStatsFromCache();
      if (approvedPendingCount > 0 && _stats.pendingSubscriptionApprovals > 0) {
        _stats = _stats.copyWith(
          pendingSubscriptionApprovals:
              (_stats.pendingSubscriptionApprovals - approvedPendingCount)
                  .clamp(0, 999999),
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Send email to specific users
  Future<bool> sendEmailToUsers({
    required String subject,
    required String body,
    required List<String> userEmails,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final normalizedRecipients = userEmails
          .map((email) => email.trim())
          .where((email) =>
              email.isNotEmpty &&
              RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))
          .toSet()
          .toList();
      if (normalizedRecipients.isEmpty) {
        _errorMessage = 'No valid recipient emails found.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Store email record in Firestore
      final emailId = _firestore.collection('emails').doc().id;

      await _firestore.collection('emails').doc(emailId).set({
        'subject': subject,
        'body': body,
        'recipients': normalizedRecipients,
        'createdAt': FieldValue.serverTimestamp(),
        'sentBy': _auth.currentUser?.email,
        'status': 'processing',
      });

      final failedRecipients = <String>[];
      int sentCount = 0;
      final payload = <String, dynamic>{
        'subject': subject,
        'body': body,
        'sentAt': DateTime.now().toIso8601String(),
        'senderLabel': _auth.currentUser?.email ?? 'Platform Admin',
      };

      const batchSize = 10;
      for (var i = 0; i < normalizedRecipients.length; i += batchSize) {
        final batch = normalizedRecipients.skip(i).take(batchSize).toList();
        final results = await Future.wait(
          batch.map((recipient) async {
            try {
              final ok = await _emailService.sendAdminBroadcastEmail(
                recipient,
                payload,
                subject: subject,
              );
              return MapEntry(recipient, ok);
            } catch (_) {
              return MapEntry(recipient, false);
            }
          }),
        );

        for (final result in results) {
          if (result.value) {
            sentCount += 1;
          } else {
            failedRecipients.add(result.key);
          }
        }
      }

      final status = sentCount == normalizedRecipients.length
          ? 'sent'
          : sentCount == 0
              ? 'failed'
              : 'partial';
      _errorMessage = failedRecipients.isEmpty
          ? null
          : 'Some emails failed to send (${failedRecipients.length}/${normalizedRecipients.length}).';

      await _firestore.collection('emails').doc(emailId).set({
        'status': status,
        'sentCount': sentCount,
        'failedCount': failedRecipients.length,
        'failedRecipients': failedRecipients,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _isLoading = false;
      notifyListeners();
      return sentCount > 0;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Activate a yearly subscription for all workers of a business.
  ///
  /// This sets a subscription flag on each worker's user document and
  /// annotates common business records that reference the worker so that
  /// workers are not restricted from accessing the app due to subscription checks.
  Future<bool> activateYearlySubscriptionForWorkers(String businessId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final expiry = DateTime.now().add(const Duration(days: 365));

      // Find worker users for this business
      final usersQuery = await _firestore
          .collection('users')
          .where('businessId', isEqualTo: businessId)
          .where('role', isEqualTo: 'worker')
          .get();

      // Collections under the business to annotate (workerId or createdBy)
      final workerCollections = [
        'sales',
        'serviceOrders',
        'bookings',
        'invoices',
        'payments',
        'payment_transactions',
        'orders',
      ];

      final batch = _firestore.batch();
      final updatedUids = <String>[];

      for (final u in usersQuery.docs) {
        final uid = u.id;
        updatedUids.add(uid);

        // Queue user doc update in batch (merge)
        batch.set(
          u.reference,
          {
            'hasActiveSubscription': true,
            'subscriptionPlan': 'admin_yearly',
            'subscriptionStartDate': DateTime.now().toIso8601String(),
            'subscriptionEndDate': expiry.toIso8601String(),
            'subscriptionPaymentRequired': false,
            'subscriptionSource': 'admin-grant',
            'subscriptionActivatedBy': 'admin',
          },
          SetOptions(merge: true),
        );

        // For each business subcollection, annotate records referencing this worker
        for (final coll in workerCollections) {
          final colRef = _firestore.collection('businesses').doc(businessId).collection(coll);
          // Query by workerId
          try {
            final byWorker = await colRef.where('workerId', isEqualTo: uid).get();
            for (final d in byWorker.docs) {
              try {
                // update directly (not batching business documents to avoid hitting large write limits)
                await d.reference.update({'workerSubscriptionActive': true});
              } catch (_) {}
            }
          } catch (_) {}

          // Query by createdBy
          try {
            final byCreator = await colRef.where('createdBy', isEqualTo: uid).get();
            for (final d in byCreator.docs) {
              try {
                await d.reference.update({'workerSubscriptionActive': true});
              } catch (_) {}
            }
          } catch (_) {}
        }
      }

      // Commit batched user updates
      if (updatedUids.isNotEmpty) {
        await batch.commit();

        // Update local cache for immediate UI feedback
        for (var i = 0; i < _allUsers.length; i++) {
          final u = _allUsers[i];
          final id = (u['id'] ?? u['uid'] ?? '').toString();
          if (updatedUids.contains(id)) {
            _allUsers[i] = {
              ...u,
              'hasActiveSubscription': true,
              'subscriptionPlan': 'admin_yearly',
              'subscriptionStartDate': DateTime.now().toIso8601String(),
              'subscriptionEndDate': expiry.toIso8601String(),
              'subscriptionPaymentRequired': false,
              'subscriptionSource': 'admin-grant',
              'subscriptionActivatedBy': 'admin',
            };
          }
        }
        notifyListeners();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AdminProvider] activateYearlySubscriptionForWorkers failed: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Grant yearly subscription to a single worker and annotate their records.
  Future<bool> activateYearlySubscriptionForWorker(String userId, String businessId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final expiry = DateTime.now().add(const Duration(days: 365));
      final userRef = _firestore.collection('users').doc(userId);

      await userRef.set({
        'hasActiveSubscription': true,
        'subscriptionPlan': 'admin_yearly',
        'subscriptionStartDate': DateTime.now().toIso8601String(),
        'subscriptionEndDate': expiry.toIso8601String(),
        'subscriptionPaymentRequired': false,
        'subscriptionSource': 'admin-grant',
        'subscriptionActivatedBy': 'admin',
      }, SetOptions(merge: true));

      // Update local cache immediately
      for (var i = 0; i < _allUsers.length; i++) {
        final u = _allUsers[i];
        final id = (u['id'] ?? u['uid'] ?? '').toString();
        if (id == userId) {
          _allUsers[i] = {
            ...u,
            'hasActiveSubscription': true,
            'subscriptionPlan': 'admin_yearly',
            'subscriptionStartDate': DateTime.now().toIso8601String(),
            'subscriptionEndDate': expiry.toIso8601String(),
            'subscriptionPaymentRequired': false,
            'subscriptionSource': 'admin-grant',
            'subscriptionActivatedBy': 'admin',
          };
          break;
        }
      }
      notifyListeners();

      // annotate related business records
      final workerCollections = [
        'sales',
        'serviceOrders',
        'bookings',
        'invoices',
        'payments',
        'payment_transactions',
        'orders',
      ];

      for (final coll in workerCollections) {
        final colRef = _firestore.collection('businesses').doc(businessId).collection(coll);
        try {
          final byWorker = await colRef.where('workerId', isEqualTo: userId).get();
          for (final d in byWorker.docs) {
            try { await d.reference.update({'workerSubscriptionActive': true}); } catch (_) {}
          }
        } catch (_) {}
        try {
          final byCreator = await colRef.where('createdBy', isEqualTo: userId).get();
          for (final d in byCreator.docs) {
            try { await d.reference.update({'workerSubscriptionActive': true}); } catch (_) {}
          }
        } catch (_) {}
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AdminProvider] activateYearlySubscriptionForWorker failed: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Send notification to all users
  Future<bool> sendBroadcastNotification({
    required String title,
    required String body,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get all user IDs
      final userIds = _allUsers.map((u) => u['id'] as String).toList();

      return await sendNotificationToUsers(
        title: title,
        body: body,
        userIds: userIds,
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Send email to all users
  Future<bool> sendBroadcastEmail({
    required String subject,
    required String body,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get all user emails
      final userEmails = _allUsers
          .map((u) => (u['email'] ?? '').toString())
          .toList();

      return await sendEmailToUsers(
        subject: subject,
        body: body,
        userEmails: userEmails,
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get user details
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final workerDoc = await _firestore.collection('workers').doc(userId).get();

      if (!userDoc.exists && !workerDoc.exists) {
        return null;
      }

      final merged = <String, dynamic>{
        'id': userId,
        if (workerDoc.exists) ...?workerDoc.data(),
        if (userDoc.exists) ...?userDoc.data(),
      };

      final fullName = _readString(merged['fullName']);
      if (_readString(merged['name']).isEmpty && fullName.isNotEmpty) {
        merged['name'] = fullName;
      }

      final sources = <String>[
        if (userDoc.exists) 'users',
        if (workerDoc.exists) 'workers',
      ];
      merged['tableSources'] = sources;
      merged['tableSource'] =
          sources.length > 1 ? 'users+workers' : sources.first;

      return merged;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ---------------------- Installation requests listener ------------------
  void _startInstallationRequestsListener() {
    // Avoid multiple subscriptions
    if (_installationSub != null) return;

    try {
      // Count requests that are awaiting processing/evaluation/payment
      final statuses = ['pending', 'scheduled', 'evaluated'];
      _installationSub = _firestore
          .collection('product_installation_requests')
          .where('status', whereIn: statuses)
          .snapshots()
          .listen((snap) {
        _pendingInstallationRequests = snap.docs.length;
        notifyListeners();
      });
    } catch (e) {
      // Some Firestore servers may not support whereIn on certain indexes during dev,
      // gracefully fallback to a broad listener and compute client-side.
      _installationSub = _firestore
          .collection('product_installation_requests')
          .snapshots()
          .listen((snap) {
        _pendingInstallationRequests = snap.docs.where((d) {
          final data = d.data();
          final status = (data['status'] ?? '').toString();
          return status != 'rejected' && status != 'approved' && status != 'closed';
        }).length;
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _installationSub?.cancel();
    super.dispose();
  }

  /// Update user document fields
  Future<bool> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('users').doc(userId).update(updates);

      // Update local cache if present
      final idx = _allUsers.indexWhere((u) => u['id'] == userId);
      if (idx >= 0) {
        _allUsers[idx] = {..._allUsers[idx], ...updates};
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Remove a worker from a business without deleting the underlying user.
  Future<bool> removeWorkerFromBusiness(String userId, String businessId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('users').doc(userId).set({
        'businessId': null,
        'role': 'user',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final businessRef = _firestore.collection('businesses').doc(businessId);
      final businessSnap = await businessRef.get();
      if (businessSnap.exists) {
        final data = businessSnap.data() ?? const {};
        final currentWorkers = (data['totalWorkers'] as num?)?.toInt() ?? 0;
        await businessRef.set({
          'totalWorkers': currentWorkers > 0 ? currentWorkers - 1 : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final userIdx = _allUsers.indexWhere((u) => u['id'] == userId);
      if (userIdx >= 0) {
        _allUsers[userIdx] = {
          ..._allUsers[userIdx],
          'businessId': null,
          'role': 'user',
        };
      }

      final businessIdx = _allBusinesses.indexWhere((b) => b['id'] == businessId);
      if (businessIdx >= 0) {
        final currentWorkers = (_allBusinesses[businessIdx]['totalWorkers'] as num?)?.toInt() ?? 0;
        _allBusinesses[businessIdx] = {
          ..._allBusinesses[businessIdx],
          'totalWorkers': currentWorkers > 0 ? currentWorkers - 1 : 0,
        };
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get business details
  Future<Map<String, dynamic>?> getBusinessDetails(String businessId) async {
    try {
      final doc =
          await _firestore.collection('businesses').doc(businessId).get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data() ?? {}};
      }
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Get daily sales summary for a business on a specific date
  /// Returns a map with totalSales, transactionCount and items aggregation
  Future<Map<String, dynamic>> getDailySalesSummary(
      String businessId, DateTime date) async {
    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      // Try querying using createdAt (Timestamp)
      Query salesQuery = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));

      final snapshot = await salesQuery.get();
      List<QueryDocumentSnapshot> docs = snapshot.docs;

      // Fallback to numeric timestamp if no docs found
      if (docs.isEmpty) {
        final tsQuery = _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('sales')
            .where('timestamp',
                isGreaterThanOrEqualTo: start.millisecondsSinceEpoch)
            .where('timestamp',
                isLessThanOrEqualTo: end.millisecondsSinceEpoch);
        final tsSnapshot = await tsQuery.get();
        docs = tsSnapshot.docs;
      }

      double totalSales = 0.0;
      double totalCost = 0.0; // cost of goods sold
      int transactionCount = docs.length;
      final Map<String, Map<String, double>> items = {};
      final Map<String, double> cashierTotals = {};
      final Map<String, double> paymentMethodTotals = {};
      final List<Map<String, dynamic>> transactions = []; 

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final saleAmount =
          (data['finalAmount'] ?? data['totalAmount'] ?? data['total'] ?? 0)
            .toDouble();
        totalSales += saleAmount;

        // cashier / worker / seller name detection
        final cashierName = data['cashierName']?.toString() ??
          data['workerName']?.toString() ??
          data['seller']?.toString() ??
          data['userName']?.toString() ??
          'Unknown';
        cashierTotals[cashierName] = (cashierTotals[cashierName] ?? 0) + saleAmount;

        // payment method tracking
        final paymentMethod = data['paymentMethod']?.toString() ?? 'Unknown';
        paymentMethodTotals[paymentMethod] = (paymentMethodTotals[paymentMethod] ?? 0) + saleAmount;

        // record transaction details for message display
        
        final rawItems = (data['items'] as List<dynamic>?) ?? [];
        for (var item in rawItems) {
          try {
            final name = item['productName']?.toString() ??
                item['name']?.toString() ??
                'Unknown';
            final qty = (item['quantity'] ?? item['qty'] ?? 0).toDouble();
            final lineTotal = (item['total'] ??
                    item['lineTotal'] ??
                    (item['unitPrice'] ?? 0) * qty)
                .toDouble();

            // Determine cost per unit from item, nested product information,
            // or fall back to the business inventory document for the product.
            double costPerUnit = 0.0;
            try {
              if (item['cost'] != null) {
                costPerUnit = (item['cost'] as num).toDouble();
              } else if (item['costPrice'] != null) {
                costPerUnit = (item['costPrice'] as num).toDouble();
              } else if (item['unitCost'] != null) {
                costPerUnit = (item['unitCost'] as num).toDouble();
              } else if (item['product'] is Map) {
                final prod = item['product'] as Map<String, dynamic>;
                costPerUnit = ((prod['cost'] ?? prod['costPrice'] ?? prod['unitCost']) as num?)?.toDouble() ?? 0.0;
              }
            } catch (_) {
              costPerUnit = 0.0;
            }

            // Inventory fallback: if cost still unknown, try to fetch from
            // businesses/{businessId}/inventory/{productId} when a product id is present.
            if (costPerUnit <= 0.0) {
              try {
                String? pid;
                if (item['productId'] != null) pid = item['productId'].toString();
                else if (item['product'] is Map && (item['product'] as Map).containsKey('id')) pid = (item['product']['id'] ?? '').toString();
                else if (item['id'] != null) pid = item['id'].toString();

                if (pid != null && pid.isNotEmpty) {
                  final invDoc = await _firestore
                      .collection('businesses')
                      .doc(businessId)
                      .collection('inventory')
                      .doc(pid)
                      .get();
                  if (invDoc.exists) {
                    final invData = invDoc.data() as Map<String, dynamic>? ?? {};
                    costPerUnit = (invData['costPrice'] as num?)?.toDouble() ??
                                  (invData['unitCost'] as num?)?.toDouble() ??
                                  (invData['cost'] as num?)?.toDouble() ?? costPerUnit;
                  }
                }
              } catch (_) {
                // ignore inventory lookup failures - keep costPerUnit as-is
              }
            }

            final lineCost = costPerUnit * qty;
            totalCost += lineCost;

            if (!items.containsKey(name)) {
              items[name] = {'quantity': 0.0, 'sales': 0.0};
            }
            items[name]!['quantity'] = items[name]!['quantity']! + qty;
            items[name]!['sales'] = items[name]!['sales']! + lineTotal; 
          } catch (_) {
            // ignore malformed item entries
          }
        }
        transactions.add({
          'id': doc.id,
          'cashier': cashierName,
          'total': saleAmount,
          'items': rawItems,
          'createdAt': data['createdAt'] ?? data['timestamp'] ?? null,
        });

      }

      // compute previous day totals for growth
      double previousDayTotal = 0.0;
      try {
        final prevStart = start.subtract(const Duration(days: 1));
        final prevEnd = start;
        Query prevQuery = _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('sales')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(prevStart))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(prevEnd));

        final prevSnap = await prevQuery.get();
        List<QueryDocumentSnapshot> prevDocs = prevSnap.docs;
        if (prevDocs.isEmpty) {
          final tsPrevQuery = _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('sales')
              .where('timestamp', isGreaterThanOrEqualTo: prevStart.millisecondsSinceEpoch)
              .where('timestamp', isLessThanOrEqualTo: prevEnd.millisecondsSinceEpoch);
          final tsPrevSnap = await tsPrevQuery.get();
          prevDocs = tsPrevSnap.docs;
        }

        for (var d in prevDocs) {
          final pdata = d.data() as Map<String, dynamic>;
          previousDayTotal += (pdata['finalAmount'] ?? pdata['totalAmount'] ?? pdata['total'] ?? 0).toDouble();
        }
      } catch (_) {}

      final grossProfit = totalSales - totalCost;
      final grossMarginPercent = totalSales > 0 ? (grossProfit / totalSales) * 100.0 : 0.0;

      return {
        'totalSales': totalSales,
        'totalCost': totalCost,
        'grossProfit': grossProfit,
        'grossMarginPercent': grossMarginPercent,
        'transactionCount': transactionCount,
        'items': items,
        'cashierTotals': cashierTotals,
        'paymentMethodTotals': paymentMethodTotals,
        'transactions': transactions,
        'previousDayTotal': previousDayTotal,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  /// Update business document with provided fields
  Future<bool> updateBusiness(
      String businessId, Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('businesses').doc(businessId).update(updates);

      // Update local cache if present
      final idx = _allBusinesses.indexWhere((b) => b['id'] == businessId);
      if (idx >= 0) {
        _allBusinesses[idx] = {..._allBusinesses[idx], ...updates};
      }

      _refreshDerivedStatsFromCache();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Soft-delete a business for 30 days. Only admin can restore it.
  Future<bool> deleteBusinessCompletely(String businessId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final businessRef = _firestore.collection('businesses').doc(businessId);
      final businessSnap = await businessRef.get();
      if (!businessSnap.exists) {
        throw Exception('Business not found.');
      }
      final businessName =
          (businessSnap.data() ?? const {})['name']?.toString() ?? businessId;
      final adminId = _auth.currentUser?.uid ?? 'system';
      final recoveryDeadlineAt =
          DeletionRecoveryService.computeRecoveryDeadline();

      await _deletionRecoveryService.softDeleteBusiness(
        businessId: businessId,
        actorId: adminId,
        actorType: 'admin',
        actorRole: 'admin',
        reason: 'Deleted by admin. Recoverable only by admin for 30 days.',
      );

      await _firestore.collection('admin_notifications').add({
        'type': 'business',
        'title': 'Business Deleted',
        'message':
            '$businessName was deleted by admin and moved to a 30-day recovery window.',
        'data': {
          'businessId': businessId,
          'businessName': businessName,
          'eventType': 'deleted',
          'recoveryAccess': 'admin',
          'recoveryDeadlineAt': Timestamp.fromDate(recoveryDeadlineAt),
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await fetchAdminStats(force: true);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreDeletedBusiness(String businessId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final businessRef = _firestore.collection('businesses').doc(businessId);
      final businessSnap = await businessRef.get();
      if (!businessSnap.exists) {
        throw Exception('Business not found.');
      }
      final businessState = DeletionRecoveryService.stateFromData(
        businessSnap.data(),
      );
      if (!businessState.isDeleted) {
        throw Exception('This business is not awaiting recovery.');
      }
      if (businessState.isExpired) {
        throw Exception(
          'This business has passed the 30-day recovery window and can no longer be restored.',
        );
      }

      final businessName =
          (businessSnap.data() ?? const {})['name']?.toString() ?? businessId;
      await _deletionRecoveryService.restoreBusiness(businessId: businessId);

      await _firestore.collection('admin_notifications').add({
        'type': 'business',
        'title': 'Business Restored',
        'message': '$businessName was restored by admin.',
        'data': {
          'businessId': businessId,
          'businessName': businessName,
          'eventType': 'restored',
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await fetchAdminStats(force: true);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUserWithRecovery(String userId) async {
    try {
      if ((_auth.currentUser?.uid ?? '') == userId) {
        throw Exception('You cannot delete the currently signed-in admin account.');
      }

      _isLoading = true;
      notifyListeners();

      final userRef = _firestore.collection('users').doc(userId);
      final workerRef = _firestore.collection('workers').doc(userId);
      final userSnap = await userRef.get();
      final workerSnap = await workerRef.get();
      if (!userSnap.exists && !workerSnap.exists) {
        throw Exception('User account not found.');
      }

      final userData = userSnap.data() ??
          workerSnap.data() ??
          const <String, dynamic>{};
      final displayName = _readString(
        userData['fullName'] ?? userData['name'] ?? userData['email'],
      );
      final tableSources = <String>[
        if (userSnap.exists) 'users',
        if (workerSnap.exists) 'workers',
      ];

      if (userSnap.exists) {
        await userRef.delete();
      }
      if (workerSnap.exists) {
        await workerRef.delete();
      }

      await _firestore.collection('admin_notifications').add({
        'type': 'user',
        'title': 'User Permanently Deleted',
        'message':
            '${displayName.isNotEmpty ? displayName : userId} was permanently deleted from ${tableSources.join(' and ')} by admin.',
        'data': {
          'userId': userId,
          'displayName': displayName,
          'eventType': 'permanently_deleted',
          'deletedFrom': tableSources,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await fetchAdminStats(force: true);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreDeletedUserAccount(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userRef = _firestore.collection('users').doc(userId);
      final userSnap = await userRef.get();
      if (!userSnap.exists) {
        throw Exception('User account not found.');
      }
      final userState = DeletionRecoveryService.stateFromData(userSnap.data());
      if (!userState.isDeleted) {
        throw Exception('This account is not awaiting recovery.');
      }
      if (userState.isExpired) {
        throw Exception(
          'This account has passed the 30-day recovery window and can no longer be restored.',
        );
      }

      final userData = userSnap.data() ?? const <String, dynamic>{};
      final displayName = _readString(
        userData['fullName'] ?? userData['name'] ?? userData['email'],
      );

      await _deletionRecoveryService.restoreUserAccount(
        userId: userId,
        restoreOwnedBusinesses: true,
        adminOverride: true,
      );

      await _firestore.collection('admin_notifications').add({
        'type': 'user',
        'title': 'User Restored',
        'message':
            '${displayName.isNotEmpty ? displayName : userId} was restored by admin.',
        'data': {
          'userId': userId,
          'displayName': displayName,
          'eventType': 'restored',
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await fetchAdminStats(force: true);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Stream real-time stats updates
  Stream<AdminStats> streamAdminStats() {
    return _firestore.collection('system').doc('stats').snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() ?? {};
        return AdminStats(
          totalBusinesses: data['totalBusinesses'] ?? 0,
          activeUsers: data['activeUsers'] ?? 0,
          totalRevenue: data['totalRevenue'] ?? 0,
          pendingPayments: data['pendingPayments'] ?? 0,
          totalTransactions: data['totalTransactions'] ?? 0,
          pendingSubscriptionApprovals:
              data['pendingSubscriptionApprovals'] ?? 0,
          activeSubscriptions: data['activeSubscriptions'] ?? 0,
          restrictedBusinesses: data['restrictedBusinesses'] ?? 0,
          totalMarketers: data['totalMarketers'] ?? 0,
        );
      }
      return AdminStats();
    });
  }

  /// Approve one-year subscription for a user or business
  Future<bool> approveOneYearSubscription(
      {required String businessId,
      required String businessName,
      required String tier}) async {
    return grantBusinessSubscription(
      businessId: businessId,
      businessName: businessName,
      tier: tier,
      durationDays: 365,
      source: 'admin_one_year',
    );
  }

  Future<bool> declineOneYearSubscription({
    required String businessId,
    required String businessName,
    String? reason,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final declineReason = (reason?.trim().isNotEmpty ?? false)
          ? reason!.trim()
          : 'Declined by admin review.';
      final businessRef = _firestore.collection('businesses').doc(businessId);

      await businessRef.set({
        'isSubscriptionActive': false,
        'subscriptionStatus': 'declined',
        'subscriptionReviewStatus': 'declined',
        'subscriptionDeclineReason': declineReason,
        'subscriptionDeclinedAt': FieldValue.serverTimestamp(),
        'subscriptionDeclinedBy': _auth.currentUser?.uid ?? 'system',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      try {
        final pendingRequests = await _firestore
            .collection('subscription_requests')
            .where('businessId', isEqualTo: businessId)
            .where('status', isEqualTo: 'pending')
            .get();

        for (final doc in pendingRequests.docs) {
          await doc.reference.set({
            'status': 'rejected',
            'subscriptionStatus': 'declined',
            'rejectedAt': FieldValue.serverTimestamp(),
            'rejectedBy': _auth.currentUser?.uid ?? 'system',
            'rejectedReason': declineReason,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        if (pendingRequests.docs.isNotEmpty) {
          _stats = _stats.copyWith(
            pendingSubscriptionApprovals:
                (_stats.pendingSubscriptionApprovals -
                        pendingRequests.docs.length)
                    .clamp(0, 999999),
          );
        }
      } catch (_) {}

      await _firestore.collection('subscription_approvals').add({
        'businessId': businessId,
        'businessName': businessName,
        'declineReason': declineReason,
        'declinedAt': FieldValue.serverTimestamp(),
        'declinedBy': _auth.currentUser?.uid ?? 'system',
        'status': 'declined',
        'type': 'one_year',
      });

      final businessIndex =
          _allBusinesses.indexWhere((b) => b['id'] == businessId);
      if (businessIndex != -1) {
        _allBusinesses[businessIndex] = {
          ..._allBusinesses[businessIndex],
          'isSubscriptionActive': false,
          'subscriptionStatus': 'declined',
          'subscriptionReviewStatus': 'declined',
          'subscriptionDeclineReason': declineReason,
          'subscriptionDeclinedAt': Timestamp.now(),
        };
      }

      for (var i = 0; i < _allUsers.length; i++) {
        if (_allUsers[i]['businessId'] == businessId) {
          _allUsers[i] = {
            ..._allUsers[i],
            'isSubscriptionActive': false,
            'subscriptionStatus': 'declined',
            'subscriptionDeclineReason': declineReason,
          };
        }
      }

      _refreshDerivedStatsFromCache();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setBusinessRestriction({
    required String businessId,
    required bool restricted,
    String? reason,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final trimmedReason = (reason?.trim().isNotEmpty ?? false)
          ? reason!.trim()
          : restricted
              ? 'Access restricted by admin.'
              : null;
      final businessRef = _firestore.collection('businesses').doc(businessId);
      final businessSnap = await businessRef.get();
      final adminSettings =
          await _firestore.collection('system').doc('admin_settings').get();
      final adminSettingsData = adminSettings.data() ?? const <String, dynamic>{};
      final customerCareWhatsapp = _readString(
        adminSettingsData['customerCareWhatsapp'] ??
            adminSettingsData['supportWhatsapp'] ??
            adminSettingsData['customerCarePhone'],
      );
      final businessName =
          (businessSnap.data() ?? const {})['name']?.toString() ?? businessId;
      final userNotificationMessage = restricted
          ? [
              '$businessName has been restricted by admin.',
              if (trimmedReason != null && trimmedReason.isNotEmpty)
                'Reason: $trimmedReason',
              if (customerCareWhatsapp.isNotEmpty)
                'Contact customer care on WhatsApp: $customerCareWhatsapp',
            ].join('\n')
          : '$businessName access has been restored. You can continue using the app.';

      await businessRef.set({
        'isRestricted': restricted,
        'restrictionStatus': restricted ? 'restricted' : 'active',
        'restrictionReason':
            restricted ? trimmedReason : FieldValue.delete(),
        'restrictedAt':
            restricted ? FieldValue.serverTimestamp() : FieldValue.delete(),
        'restrictedBy': restricted
            ? (_auth.currentUser?.uid ?? 'system')
            : FieldValue.delete(),
        'restrictionLiftedAt':
            restricted ? FieldValue.delete() : FieldValue.serverTimestamp(),
        'isActive': restricted ? false : true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final businessIndex =
          _allBusinesses.indexWhere((b) => b['id'] == businessId);
      if (businessIndex != -1) {
        _allBusinesses[businessIndex] = {
          ..._allBusinesses[businessIndex],
          'isRestricted': restricted,
          'restrictionStatus': restricted ? 'restricted' : 'active',
          'restrictionReason': restricted ? trimmedReason : null,
          'restrictedAt': restricted ? Timestamp.now() : null,
          'restrictionLiftedAt': restricted ? null : Timestamp.now(),
          'isActive': restricted ? false : true,
        };
      }

      for (var i = 0; i < _allUsers.length; i++) {
        if (_allUsers[i]['businessId'] == businessId) {
          _allUsers[i] = {
            ..._allUsers[i],
            'businessRestricted': restricted,
            'businessRestrictionReason': restricted ? trimmedReason : null,
          };
        }
      }

      final affectedUsers = await _firestore
          .collection('users')
          .where('businessId', isEqualTo: businessId)
          .get();
      final affectedUserIds =
          affectedUsers.docs.map((doc) => doc.id).toList(growable: false);

      await _firestore.collection('admin_notifications').add({
        'type': 'business_restriction',
        'title': restricted ? 'Business Restricted' : 'Business Restored',
        'message': restricted
            ? '$businessName was restricted by admin.'
            : '$businessName access was restored by admin.',
        'data': {
          'businessId': businessId,
          'businessName': businessName,
          'restricted': restricted,
          'reason': trimmedReason,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('notifications').add({
        'title': restricted ? 'Business Restricted' : 'Business Restored',
        'body': userNotificationMessage,
        'type': 'business_restriction',
        'targetUsers': affectedUserIds,
        'businessId': businessId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (final userDoc in affectedUsers.docs) {
        await userDoc.reference.collection('notifications').add({
          'title': restricted ? 'Business Restricted' : 'Business Restored',
          'body': userNotificationMessage,
          'read': false,
          'type': 'business_restriction',
          'businessId': businessId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _refreshDerivedStatsFromCache();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
