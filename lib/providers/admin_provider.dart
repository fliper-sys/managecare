import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/utils/datetime_utils.dart';

/// Model for admin statistics
class AdminStats {
  final int totalBusinesses;
  final int activeUsers;
  final int totalRevenue;
  final int pendingPayments;
  final int totalTransactions;
  final List<Map<String, dynamic>> recentActivities;

  AdminStats({
    this.totalBusinesses = 0,
    this.activeUsers = 0,
    this.totalRevenue = 0,
    this.pendingPayments = 0,
    this.totalTransactions = 0,
    this.recentActivities = const [],
  });
}

/// Admin provider for managing admin-specific features
class AdminProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AdminStats _stats = AdminStats();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allBusinesses = [];

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
  Future<void> fetchAdminStats() async {
    // Prevent duplicate simultaneous requests
    if (_isStatsLoadInProgress) {
      print('[AdminProvider] ⏭️ Stats load already in progress, skipping duplicate request');
      return;
    }

    // Throttle: Don't reload if we loaded recently
    if (_lastStatsLoadTime != null) {
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
            userData['subscriptionTier'] = matchingBusiness['subscriptionTier'] ?? 'basic';
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
          userData['subscriptionTier'] = 'basic';
        }
        
        print('🔍 ENRICHMENT RESULT: "${userData['name']}" -> isSubscriptionActive=${userData['isSubscriptionActive']}');
        
        return userData;
      }).toList();

      // Calculate statistics from subscription tiers
      int totalRevenue = 0;
      int pendingPayments = 0;
      int totalTransactions = 0;

      // Define subscription pricing in Naira
      final subscriptionPricing = {
        'basic': 10000,
        'pro': 20000,
        'enterprise': 100000,
      };

      for (var business in _allBusinesses) {
        // Calculate revenue from subscription tier
        final tier =
            business['subscriptionTier']?.toString().toLowerCase() ?? 'basic';
        final tierRevenue = subscriptionPricing[tier] ?? 10000;
        totalRevenue += tierRevenue;

        // Also add any additional revenue if stored
        if (business['additionalRevenue'] != null) {
          totalRevenue += (business['additionalRevenue'] as num).toInt();
        }
      }

      // Fetch payments for pending status
      final paymentsSnapshot = await _firestore
          .collection('payments')
          .where('status', isEqualTo: 'pending')
          .get();
      pendingPayments = paymentsSnapshot.docs.length;

      // Count all transactions
      final transactionsSnapshot =
          await _firestore.collection('transactions').get();
      totalTransactions = transactionsSnapshot.docs.length;

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
      });

      // Update each user's notification list
      for (var userId in userIds) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
          'title': title,
          'body': body,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
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

      // Store email record in Firestore
      final emailId = _firestore.collection('emails').doc().id;

      await _firestore.collection('emails').doc(emailId).set({
        'subject': subject,
        'body': body,
        'recipients': userEmails,
        'createdAt': FieldValue.serverTimestamp(),
        'sentBy': _auth.currentUser?.email,
        'status': 'sent',
      });

      // You would typically call a Cloud Function here to send actual emails
      // For now, just storing the record

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
          .where((u) => u['email'] != null)
          .map((u) => u['email'] as String)
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
      final doc = await _firestore.collection('users').doc(userId).get();
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

  /// Permanently delete a business, remove known child data, and detach linked users.
  Future<bool> deleteBusinessCompletely(String businessId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final businessRef = _firestore.collection('businesses').doc(businessId);
      final businessSnap = await businessRef.get();
      final businessName =
          (businessSnap.data() ?? const {})['name']?.toString() ?? businessId;

      const subcollections = [
        'sales',
        'inventory',
        'orders',
        'bookings',
        'invoices',
        'payments',
        'payment_transactions',
        'serviceOrders',
        'restaurant_orders',
        'services',
        'products',
        'workers',
        'staff',
        'tables',
      ];

      for (final subcollection in subcollections) {
        try {
          final snap = await businessRef.collection(subcollection).get();
          for (final doc in snap.docs) {
            await doc.reference.delete();
          }
        } catch (_) {}
      }

      const rootCollections = [
        'subscriptions',
        'payments',
        'transactions',
        'activities',
        'serviceOrders',
      ];

      for (final collection in rootCollections) {
        try {
          final snap = await _firestore
              .collection(collection)
              .where('businessId', isEqualTo: businessId)
              .get();
          for (final doc in snap.docs) {
            await doc.reference.delete();
          }
        } catch (_) {}
      }

      try {
        final usersSnap = await _firestore
            .collection('users')
            .where('businessId', isEqualTo: businessId)
            .get();
        for (final doc in usersSnap.docs) {
          await doc.reference.set({
            'businessId': null,
            'isSubscriptionActive': false,
            'businessDeletedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (_) {}

      await businessRef.delete();

      _allBusinesses.removeWhere((b) => b['id'] == businessId);
      for (var i = 0; i < _allUsers.length; i++) {
        if (_allUsers[i]['businessId'] == businessId) {
          _allUsers[i] = {
            ..._allUsers[i],
            'businessId': null,
            'isSubscriptionActive': false,
          };
        }
      }

      await _firestore.collection('admin_notifications').add({
        'type': 'business',
        'title': 'Business Deleted',
        'message': '$businessName was permanently deleted by admin.',
        'data': {
          'businessId': businessId,
          'businessName': businessName,
          'eventType': 'deleted',
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _stats = AdminStats(
        totalBusinesses: _allBusinesses.length,
        activeUsers: _stats.activeUsers,
        totalRevenue: _stats.totalRevenue,
        pendingPayments: _stats.pendingPayments,
        totalTransactions: _stats.totalTransactions,
        recentActivities: _stats.recentActivities,
      );

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
    try {
      // DON'T notify here - wait until async work is done
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 365));

      // Update business with subscription details using the exact same fields
      // that the subscription checker expects
      print('🔷 DEBUG: Approving subscription for business: $businessId');
      print('🔷 DEBUG: Setting isSubscriptionActive=true, tier=$tier');
      
      await _firestore.collection('businesses').doc(businessId).update({
        'subscriptionTier': tier.toLowerCase(),
        'subscriptionStartDate': Timestamp.fromDate(now),
        'subscriptionEndDate': Timestamp.fromDate(endDate),
        'isSubscriptionActive': true, // Use isSubscriptionActive, not subscriptionStatus
        'subscriptionApprovedAt': Timestamp.now(),
        'subscriptionApprovedBy': _auth.currentUser?.uid ?? 'system',
        'updatedAt': Timestamp.now(),
      });
      
      print('🔷 DEBUG: Business updated successfully');
      
      // Verify the update was successful by reading it back
      final businessDoc = await _firestore.collection('businesses').doc(businessId).get();
      print('🔷 DEBUG: Business data after update: ${businessDoc.data()}');

      // Create subscription record for audit trail
      await _firestore.collection('subscriptions').add({
        'businessId': businessId,
        'businessName': businessName,
        'tier': tier.toLowerCase(),
        'startDate': Timestamp.fromDate(now),
        'endDate': Timestamp.fromDate(endDate),
        'isSubscriptionActive': true,
        'approvedAt': Timestamp.now(),
        'approvedBy': _auth.currentUser?.uid ?? 'system',
        'type': 'one_year',
      });

      // Update local cache - find and update the business
      final idx = _allBusinesses.indexWhere((b) => b['id'] == businessId);
      if (idx >= 0) {
        _allBusinesses[idx] = {
          ..._allBusinesses[idx],
          'subscriptionTier': tier.toLowerCase(),
          'isSubscriptionActive': true,
          'subscriptionEndDate': Timestamp.fromDate(endDate),
          'subscriptionStartDate': Timestamp.fromDate(now),
        };
      }

      // Update all users associated with this business
      for (int i = 0; i < _allUsers.length; i++) {
        if (_allUsers[i]['businessId'] == businessId) {
          _allUsers[i] = {
            ..._allUsers[i],
            'isSubscriptionActive': true,
            'subscriptionTier': tier.toLowerCase(),
            'subscriptionEndDate': Timestamp.fromDate(endDate),
            'subscriptionStartDate': Timestamp.fromDate(now),
          };
        }
      }

      _isLoading = false;
      notifyListeners(); // Single notification at the end
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

