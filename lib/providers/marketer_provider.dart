import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../core/utils/datetime_utils.dart';
import '../data/models/user_model.dart';
import '../models/marketer_analytics_model.dart';
import '../models/marketer_model.dart';
import '../services/subscription_service.dart';

/// Provider for managing App Marketers
class MarketerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<MarketerModel> _marketers = [];
  MarketerModel? _currentMarketer;
  List<ReferralRecord> _referrals = [];
  final Map<String, List<MarketerClientRecord>> _clientsByMarketerEmail = {};
  final Map<String, MarketerPerformanceSnapshot> _performanceByMarketerEmail =
      {};
  List<MarketerLeaderboardEntry> _leaderboard = [];
  MarketerRewardConfig _rewardConfig = const MarketerRewardConfig();
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<MarketerModel> get marketers => _marketers;
  MarketerModel? get currentMarketer => _currentMarketer;
  List<ReferralRecord> get referrals => _referrals;
  List<MarketerLeaderboardEntry> get leaderboard => _leaderboard;
  MarketerRewardConfig get rewardConfig => _rewardConfig;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, MarketerPerformanceSnapshot> get performanceByMarketerEmail =>
      _performanceByMarketerEmail;

  List<MarketerClientRecord> clientsForMarketer(String marketerEmail) {
    return List.unmodifiable(
      _clientsByMarketerEmail[_normalizeEmail(marketerEmail)] ?? const [],
    );
  }

  MarketerPerformanceSnapshot? performanceForMarketer(String marketerEmail) {
    return _performanceByMarketerEmail[_normalizeEmail(marketerEmail)];
  }

  List<MarketerClientRecord> get currentMarketerClients {
    final marketerEmail = _currentMarketer?.email;
    if (marketerEmail == null || marketerEmail.isEmpty) return const [];
    return clientsForMarketer(marketerEmail);
  }

  MarketerPerformanceSnapshot? get currentMarketerPerformance {
    final marketerEmail = _currentMarketer?.email;
    if (marketerEmail == null || marketerEmail.isEmpty) return null;
    return performanceForMarketer(marketerEmail);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _normalizeEmail(String value) => value.trim().toLowerCase();

  String _readString(dynamic value) => value?.toString().trim() ?? '';

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = _readString(value).toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'active' ||
        normalized == 'approved';
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_readString(value).replaceAll(',', '')) ?? 0.0;
  }

  DateTime _monthStart(DateTime value) => DateTime(value.year, value.month);

  bool _isWithinMonth(DateTime value, DateTime monthStart) {
    return value.year == monthStart.year && value.month == monthStart.month;
  }

  String _buildPeriodKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }

  String _sanitizeLedgerId(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  String _resolveDetectedTier(Map<String, dynamic> businessData) {
    final seededTier = SubscriptionService.normalizeStoredPlanLevel(
      subscriptionTier: businessData['subscriptionTier']?.toString(),
      businessClass: businessData['businessClass']?.toString(),
    );
    final products = businessData['productCount'] is num
        ? (businessData['productCount'] as num).toInt()
        : int.tryParse(businessData['productCount']?.toString() ?? '') ?? 0;
    final staff = businessData['staffCount'] is num
        ? (businessData['staffCount'] as num).toInt()
        : int.tryParse(businessData['staffCount']?.toString() ?? '') ?? 0;
    final monthlyRevenue = businessData['monthlyRevenue'] is num
        ? (businessData['monthlyRevenue'] as num).toDouble()
        : double.tryParse(businessData['monthlyRevenue']?.toString() ?? '') ??
            0.0;

    final detectedFromMetrics = SubscriptionService.detectTier(
      products: products,
      staff: staff,
      monthlyIncome: monthlyRevenue,
      businessType: businessData['businessType']?.toString(),
    );

    return SubscriptionService.normalizeStoredPlanLevel(
      subscriptionTier: seededTier,
      businessClass: detectedFromMetrics,
    );
  }

  ReferralRecord? _pickPrimaryReferral(List<ReferralRecord> referrals) {
    if (referrals.isEmpty) return null;

    final sorted = [...referrals]..sort((a, b) {
        final statusOrder = {
          'approved': 3,
          'pending': 2,
          'rejected': 1,
        };
        final leftScore = statusOrder[a.status] ?? 0;
        final rightScore = statusOrder[b.status] ?? 0;
        if (leftScore != rightScore) {
          return rightScore.compareTo(leftScore);
        }

        return b.createdAt.compareTo(a.createdAt);
      });

    return sorted.first;
  }

  MarketerClientStatus _resolveClientStatus({
    required bool hasBusiness,
    required bool hasActiveSubscription,
    required String referralStatus,
    required DateTime? subscriptionEndDate,
  }) {
    final normalizedReferralStatus = referralStatus.toLowerCase();
    if (normalizedReferralStatus == 'rejected') {
      return MarketerClientStatus.rejected;
    }

    if (!hasBusiness) {
      return MarketerClientStatus.needsBusiness;
    }

    if (hasActiveSubscription) {
      if (subscriptionEndDate != null &&
          subscriptionEndDate.isAfter(DateTime.now()) &&
          subscriptionEndDate
                  .difference(DateTime.now())
                  .inDays
                  .clamp(-9999, 9999) <=
              _rewardConfig.expiryWarningDays) {
        return MarketerClientStatus.expiringSoon;
      }
      return MarketerClientStatus.active;
    }

    if (subscriptionEndDate != null &&
        subscriptionEndDate.isBefore(DateTime.now())) {
      return MarketerClientStatus.expired;
    }

    return MarketerClientStatus.inactive;
  }

  bool _rewardCountsTowardsMonthlyPerformance(String rewardType) {
    return rewardType == 'new_subscription_commission' ||
        rewardType == 'renewal_commission' ||
        rewardType == 'subscription_commission';
  }

  bool _rewardIsRenewal(String rewardType) {
    return rewardType == 'renewal_commission';
  }

  int _clientStatusSortValue(MarketerClientStatus status) {
    switch (status) {
      case MarketerClientStatus.expiringSoon:
        return 0;
      case MarketerClientStatus.active:
        return 1;
      case MarketerClientStatus.inactive:
        return 2;
      case MarketerClientStatus.needsBusiness:
        return 3;
      case MarketerClientStatus.expired:
        return 4;
      case MarketerClientStatus.rejected:
        return 5;
    }
  }

  Future<void> fetchMarketingOverview() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final results = await Future.wait([
        _firestore
            .collection('app_marketers')
            .orderBy('createdAt', descending: true)
            .get(),
        _firestore.collection('users').get(),
        _firestore.collection('businesses').get(),
        _firestore.collection('referrals').get(),
        _firestore.collection('marketer_reward_ledger').get(),
        _firestore.collection('system').doc('admin_settings').get(),
      ]);

      final marketersSnapshot =
          results[0] as QuerySnapshot<Map<String, dynamic>>;
      final usersSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final businessesSnapshot =
          results[2] as QuerySnapshot<Map<String, dynamic>>;
      final referralsSnapshot =
          results[3] as QuerySnapshot<Map<String, dynamic>>;
      final rewardsSnapshot = results[4] as QuerySnapshot<Map<String, dynamic>>;
      final settingsSnapshot =
          results[5] as DocumentSnapshot<Map<String, dynamic>>;

      final now = DateTime.now();
      final monthStart = _monthStart(now);
      final periodKey = _buildPeriodKey(monthStart);

      _rewardConfig =
          MarketerRewardConfig.fromSettings(settingsSnapshot.data());
      _marketers = marketersSnapshot.docs
          .map((doc) => MarketerModel.fromFirestore(doc))
          .toList();

      final usersById = <String, Map<String, dynamic>>{};
      final linkedUserIdsByMarketer = <String, Set<String>>{};
      for (final doc in usersSnapshot.docs) {
        final data = {'id': doc.id, ...doc.data()};
        usersById[doc.id] = data;

        final marketerEmail = _normalizeEmail(
          _readString(data['referralEmail']).isNotEmpty
              ? data['referralEmail']
              : data['referredBy'],
        );
        if (marketerEmail.isNotEmpty) {
          linkedUserIdsByMarketer.putIfAbsent(marketerEmail, () => <String>{});
          linkedUserIdsByMarketer[marketerEmail]!.add(doc.id);
        }
      }

      final businessesById = <String, Map<String, dynamic>>{};
      final businessesByOwnerId = <String, List<Map<String, dynamic>>>{};
      for (final doc in businessesSnapshot.docs) {
        final data = {'id': doc.id, ...doc.data()};
        businessesById[doc.id] = data;

        final ownerId = _readString(data['ownerId']);
        if (ownerId.isEmpty) continue;
        businessesByOwnerId.putIfAbsent(
            ownerId, () => <Map<String, dynamic>>[]);
        businessesByOwnerId[ownerId]!.add(data);
      }

      for (final entry in businessesByOwnerId.entries) {
        entry.value.sort((a, b) {
          final left = parseTimestamp(
            a['updatedAt'] ??
                a['createdAt'] ??
                DateTime.fromMicrosecondsSinceEpoch(0),
          );
          final right = parseTimestamp(
            b['updatedAt'] ??
                b['createdAt'] ??
                DateTime.fromMicrosecondsSinceEpoch(0),
          );
          return right.compareTo(left);
        });
      }

      final referralsByMarketer = <String, List<ReferralRecord>>{};
      final referralsByMarketerUser = <String, List<ReferralRecord>>{};
      final allReferrals = referralsSnapshot.docs
          .map((doc) => ReferralRecord.fromFirestore(doc))
          .toList();
      for (final referral in allReferrals) {
        final marketerEmail = _normalizeEmail(referral.marketerEmail);
        if (marketerEmail.isEmpty) continue;

        referralsByMarketer.putIfAbsent(
            marketerEmail, () => <ReferralRecord>[]);
        referralsByMarketer[marketerEmail]!.add(referral);

        if (referral.userId.isNotEmpty) {
          final key = '$marketerEmail|${referral.userId}';
          referralsByMarketerUser.putIfAbsent(key, () => <ReferralRecord>[]);
          referralsByMarketerUser[key]!.add(referral);
          linkedUserIdsByMarketer.putIfAbsent(marketerEmail, () => <String>{});
          linkedUserIdsByMarketer[marketerEmail]!.add(referral.userId);
        }
      }

      final rewardsByMarketer = <String, List<MarketerRewardEntry>>{};
      final rewardsByMarketerUser = <String, List<MarketerRewardEntry>>{};
      final allRewards = rewardsSnapshot.docs
          .map((doc) => MarketerRewardEntry.fromFirestore(doc))
          .toList();
      for (final reward in allRewards) {
        final marketerEmail = _normalizeEmail(reward.marketerEmail);
        if (marketerEmail.isEmpty) continue;

        rewardsByMarketer.putIfAbsent(
            marketerEmail, () => <MarketerRewardEntry>[]);
        rewardsByMarketer[marketerEmail]!.add(reward);

        if (reward.userId.isNotEmpty) {
          final key = '$marketerEmail|${reward.userId}';
          rewardsByMarketerUser.putIfAbsent(key, () => <MarketerRewardEntry>[]);
          rewardsByMarketerUser[key]!.add(reward);
        }
      }

      final clientsByEmail = <String, List<MarketerClientRecord>>{};
      final performanceByEmail = <String, MarketerPerformanceSnapshot>{};

      for (final marketer in _marketers) {
        final marketerEmail = _normalizeEmail(marketer.email);
        
        // Find users with matching referralEmail
        final usersWithReferralEmail = usersById.entries
            .where((entry) => _normalizeEmail(_readString(entry.value['referralEmail'] ?? entry.value['referredBy'])) == marketerEmail)
            .map((entry) => entry.key)
            .toList();

        final businessesWithReferralEmailOwnerIds = businessesById.values
            .where((b) => _normalizeEmail(_readString(b['referralEmail'] ?? b['referredBy'])) == marketerEmail)
            .map((b) => _readString(b['ownerId']))
            .where((id) => id.isNotEmpty)
            .toList();

        final linkedUserIds = <String>{
          ...marketer.referredUserIds,
          ...?linkedUserIdsByMarketer[marketerEmail],
          ...usersWithReferralEmail,
          ...businessesWithReferralEmailOwnerIds,
        };
        
        final marketerRewards =
            rewardsByMarketer[marketerEmail] ?? const <MarketerRewardEntry>[];
        final marketerReferrals =
            referralsByMarketer[marketerEmail] ?? const <ReferralRecord>[];
        final clients = <MarketerClientRecord>[];

        for (final userId in linkedUserIds) {
          final userData = usersById[userId] ?? const <String, dynamic>{};
          final rewardKey = '$marketerEmail|$userId';
          final rewardsForUser = [
            ...(rewardsByMarketerUser[rewardKey] ??
                const <MarketerRewardEntry>[])
          ]..sort((a, b) => b.awardedAt.compareTo(a.awardedAt));
          final referralsForUser =
              referralsByMarketerUser[rewardKey] ?? const <ReferralRecord>[];
          final primaryReferral = _pickPrimaryReferral(referralsForUser);

          Map<String, dynamic>? business;
          final currentBusinessId = _readString(userData['currentBusinessId']);
          final businessIdFromUser = currentBusinessId.isNotEmpty
              ? currentBusinessId
              : _readString(userData['businessId']);

          if (businessIdFromUser.isNotEmpty) {
            business = businessesById[businessIdFromUser];
          }
          final referralBusinessId = primaryReferral?.businessId;
          if (business == null &&
              referralBusinessId != null &&
              referralBusinessId.isNotEmpty) {
            business = businessesById[referralBusinessId];
          }
          if (business == null &&
              (businessesByOwnerId[userId]?.isNotEmpty ?? false)) {
            business = businessesByOwnerId[userId]!.first;
          }

          final subscriptionStatus = _readString(
            business?['subscriptionStatus'] ?? userData['subscriptionStatus'],
          );
          final rawSubscriptionEndDate = business?['subscriptionEndDate'] ??
              userData['subscriptionEndDate'];
          final subscriptionEndDate = rawSubscriptionEndDate != null
              ? parseTimestamp(rawSubscriptionEndDate)
              : null;

          bool hasActiveSubscription = _readBool(
            business?['isSubscriptionActive'] ??
                business?['hasActiveSubscription'] ??
                userData['hasActiveSubscription'],
          );
          if (subscriptionEndDate != null) {
            hasActiveSubscription = subscriptionEndDate.isAfter(now) &&
                (hasActiveSubscription ||
                    subscriptionStatus.toLowerCase() == 'approved' ||
                    subscriptionStatus.toLowerCase() == 'active');
          }

          final monthlyRewardsForUser = rewardsForUser
              .where((reward) =>
                  _isWithinMonth(reward.awardedAt, monthStart) &&
                  _rewardCountsTowardsMonthlyPerformance(reward.rewardType))
              .toList();
          final latestReward =
              rewardsForUser.isNotEmpty ? rewardsForUser.first : null;

          final approvedReferralAmount = primaryReferral?.status == 'approved'
              ? primaryReferral!.commissionAmount
              : 0.0;
          final monthlyReferralFallback = primaryReferral != null &&
                  primaryReferral.status == 'approved' &&
                  primaryReferral.approvedAt != null &&
                  _isWithinMonth(primaryReferral.approvedAt!, monthStart)
              ? primaryReferral.commissionAmount
              : 0.0;

          final fullName = _readString(userData['fullName']).isNotEmpty
              ? _readString(userData['fullName'])
              : _readString(userData['name']).isNotEmpty
                  ? _readString(userData['name'])
                  : (primaryReferral?.userEmail?.isNotEmpty == true)
                      ? primaryReferral!.userEmail!.split('@').first
                      : 'Registered lead';
          final userEmail = _readString(userData['email']).isNotEmpty
              ? _readString(userData['email'])
              : _readString(primaryReferral?.userEmail);

          final clientStatus = _resolveClientStatus(
            hasBusiness: business != null,
            hasActiveSubscription: hasActiveSubscription,
            referralStatus: primaryReferral?.status ?? 'pending',
            subscriptionEndDate: subscriptionEndDate,
          );

          clients.add(
            MarketerClientRecord(
              userId: userId,
              marketerEmail: marketerEmail,
              userEmail: userEmail,
              fullName: fullName,
              phoneNumber: _readString(
                userData['phoneNumber'] ?? userData['phone'],
              ).isEmpty
                  ? null
                  : _readString(userData['phoneNumber'] ?? userData['phone']),
              businessId: business?['id']?.toString(),
              businessName: _readString(
                business?['name'] ?? business?['businessName'],
              ).isEmpty
                  ? null
                  : _readString(business?['name'] ?? business?['businessName']),
              businessType: _readString(
                business?['businessType'] ?? business?['type'],
              ).isEmpty
                  ? null
                  : _readString(business?['businessType'] ?? business?['type']),
              hasBusiness: business != null,
              hasActiveSubscription: hasActiveSubscription,
              subscriptionStatus: subscriptionStatus,
              subscriptionEndDate: subscriptionEndDate,
              registeredAt: userData.isNotEmpty
                  ? parseTimestamp(
                      userData['createdAt'] ??
                          userData['updatedAt'] ??
                          DateTime.now(),
                    )
                  : primaryReferral?.createdAt ?? DateTime.now(),
              lastRewardAt: latestReward?.awardedAt,
              lastApprovedAt: primaryReferral?.approvedAt,
              totalRewardEarned: rewardsForUser.isNotEmpty
                  ? rewardsForUser.fold<double>(
                      0,
                      (sum, reward) => sum + reward.amount,
                    )
                  : approvedReferralAmount,
              monthlyRewardEarned: monthlyRewardsForUser.isNotEmpty
                  ? monthlyRewardsForUser.fold<double>(
                      0,
                      (sum, reward) => sum + reward.amount,
                    )
                  : monthlyReferralFallback,
              monthlyRewardCount: monthlyRewardsForUser.isNotEmpty
                  ? monthlyRewardsForUser.length
                  : monthlyReferralFallback > 0
                      ? 1
                      : 0,
              lastCommissionAmount: latestReward?.amount ??
                  primaryReferral?.commissionAmount ??
                  0,
              referralStatus: primaryReferral?.status ?? 'pending',
              notes: primaryReferral?.notes,
              status: clientStatus,
            ),
          );
        }

        clients.sort((a, b) {
          final statusCompare = _clientStatusSortValue(a.status)
              .compareTo(_clientStatusSortValue(b.status));
          if (statusCompare != 0) return statusCompare;
          return b.registeredAt.compareTo(a.registeredAt);
        });
        clientsByEmail[marketerEmail] = clients;

        final activeClients =
            clients.where((client) => client.isCurrentlyActive).length;
        final expiringSoonClients =
            clients.where((client) => client.isExpiringSoon).length;
        final inactiveClients = clients.length - activeClients;
        final businessesAttached =
            clients.where((client) => client.hasBusiness).length;

        final monthlyRewardEntries = marketerRewards
            .where((reward) =>
                reward.periodKey == periodKey ||
                _isWithinMonth(reward.awardedAt, monthStart))
            .where((reward) =>
                _rewardCountsTowardsMonthlyPerformance(reward.rewardType))
            .toList();
        final monthlyPerformanceCount = monthlyRewardEntries.isNotEmpty
            ? monthlyRewardEntries.length
            : clients.fold<int>(
                0,
                (sum, client) => sum + client.monthlyRewardCount,
              );
        final monthlyActiveClients = monthlyRewardEntries
                    .where((reward) => reward.isFirstActivation)
                    .map((reward) => reward.userId)
                    .toSet()
                    .length >
                0
            ? monthlyRewardEntries
                .where((reward) => reward.isFirstActivation)
                .map((reward) => reward.userId)
                .toSet()
                .length
            : clients
                .where((client) =>
                    client.isCurrentlyActive &&
                    client.lastApprovedAt != null &&
                    _isWithinMonth(client.lastApprovedAt!, monthStart))
                .length;
        final monthlyRenewals = monthlyRewardEntries
            .where((reward) => _rewardIsRenewal(reward.rewardType))
            .length;
        final monthlyRewardEarned = monthlyRewardEntries.isNotEmpty
            ? monthlyRewardEntries.fold<double>(
                0,
                (sum, reward) => sum + reward.amount,
              )
            : clients.fold<double>(
                0,
                (sum, client) => sum + client.monthlyRewardEarned,
              );
        final approvedReferralTotal = marketerReferrals
            .where((referral) => referral.status == 'approved')
            .fold<double>(
              0,
              (sum, referral) => sum + referral.commissionAmount,
            );
        final rewardLedgerTotal = marketerRewards.fold<double>(
          0,
          (sum, reward) => sum + reward.amount,
        );
        final lifetimeRewardEarned = <double>[
          marketer.totalCommissionEarned,
          rewardLedgerTotal,
          approvedReferralTotal,
        ].reduce((left, right) => left > right ? left : right);

        final targetProgress = _rewardConfig.monthlyTargetSubscriptions <= 0
            ? 0.0
            : (monthlyPerformanceCount /
                    _rewardConfig.monthlyTargetSubscriptions)
                .clamp(0.0, 1.0);

        performanceByEmail[marketerEmail] = MarketerPerformanceSnapshot(
          marketerId: marketer.id,
          marketerEmail: marketerEmail,
          fullName: marketer.fullName,
          registeredClients: clients.length,
          activeClients: activeClients,
          inactiveClients: inactiveClients,
          expiringSoonClients: expiringSoonClients,
          businessesAttached: businessesAttached,
          monthlyPerformanceCount: monthlyPerformanceCount,
          monthlyActiveClients: monthlyActiveClients,
          monthlyRenewals: monthlyRenewals,
          monthlyRewardEarned: monthlyRewardEarned,
          lifetimeRewardEarned: lifetimeRewardEarned,
          monthlyTarget: _rewardConfig.monthlyTargetSubscriptions,
          targetProgress: targetProgress,
          targetReached: monthlyPerformanceCount >=
              _rewardConfig.monthlyTargetSubscriptions,
          rank: 0,
          projectedBonus: 0,
          monthStart: monthStart,
        );
      }

      final rankedSnapshots = performanceByEmail.values.toList()
        ..sort((a, b) {
          if (b.monthlyPerformanceCount != a.monthlyPerformanceCount) {
            return b.monthlyPerformanceCount
                .compareTo(a.monthlyPerformanceCount);
          }
          if (b.monthlyRewardEarned != a.monthlyRewardEarned) {
            return b.monthlyRewardEarned.compareTo(a.monthlyRewardEarned);
          }
          if (b.activeClients != a.activeClients) {
            return b.activeClients.compareTo(a.activeClients);
          }
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        });

      final leaderboard = <MarketerLeaderboardEntry>[];
      for (var index = 0; index < rankedSnapshots.length; index++) {
        final snapshot = rankedSnapshots[index];
        final rank = index + 1;
        final projectedBonus = _rewardConfig.podiumBonusForRank(rank) +
            (snapshot.targetReached ? _rewardConfig.targetBonusAmount : 0);
        final updatedSnapshot = snapshot.copyWith(
          rank: rank,
          projectedBonus: projectedBonus,
        );
        performanceByEmail[snapshot.marketerEmail] = updatedSnapshot;
        leaderboard.add(
          MarketerLeaderboardEntry(
            marketerId: updatedSnapshot.marketerId,
            marketerEmail: updatedSnapshot.marketerEmail,
            fullName: updatedSnapshot.fullName,
            rank: rank,
            monthlyPerformanceCount: updatedSnapshot.monthlyPerformanceCount,
            monthlyActiveClients: updatedSnapshot.monthlyActiveClients,
            totalActiveClients: updatedSnapshot.activeClients,
            monthlyRewardEarned: updatedSnapshot.monthlyRewardEarned,
            targetProgress: updatedSnapshot.targetProgress,
            targetReached: updatedSnapshot.targetReached,
            projectedBonus: projectedBonus,
          ),
        );
      }

      _clientsByMarketerEmail
        ..clear()
        ..addAll(clientsByEmail);
      _performanceByMarketerEmail
        ..clear()
        ..addAll(performanceByEmail);
      _leaderboard = leaderboard;

      if (_currentMarketer != null) {
        final refreshedIndex = _marketers.indexWhere(
          (marketer) => marketer.id == _currentMarketer!.id,
        );
        if (refreshedIndex != -1) {
          final refreshedCurrent = _marketers[refreshedIndex];
          _currentMarketer = refreshedCurrent.copyWith(
            lastLoginAt:
                _currentMarketer!.lastLoginAt ?? refreshedCurrent.lastLoginAt,
          );
        }
      }
    } catch (e) {
      _errorMessage = 'Error loading marketer insights: $e';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    double? commissionRateOverride,
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
      if (commissionRateOverride != null) {
        // -1 acts as a sentinel value to clear the override
        if (commissionRateOverride < 0) {
          updateData['commissionRateOverride'] = FieldValue.delete();
        } else {
          updateData['commissionRateOverride'] = commissionRateOverride;
        }
      }

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
          commissionRateOverride: commissionRateOverride != null && commissionRateOverride < 0 ? null : commissionRateOverride,
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

      final normalizedEmail = _normalizeEmail(marketerEmail);
      final trimmedEmail = marketerEmail.trim();
      final emails = {
        if (trimmedEmail.isNotEmpty) trimmedEmail,
        if (normalizedEmail.isNotEmpty) normalizedEmail,
      }.toList();

      if (emails.isEmpty) {
        _referrals = [];
        notifyListeners();
        return;
      }

      final query = emails.length == 1
          ? _firestore.collection('referrals').where(
                'marketerEmail',
                isEqualTo: emails.first,
              )
          : _firestore.collection('referrals').where(
                'marketerEmail',
                whereIn: emails,
              );

      final snapshot = await query.get();

      _referrals = snapshot.docs
          .map((doc) => ReferralRecord.fromFirestore(doc))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
  Future<bool> updateMarketerBalance(
    String marketerId,
    double amount, {
    bool addToLifetimeCommission = true,
  }) async {
    try {
      MarketerModel marketer;
      final localIndex = _marketers.indexWhere((m) => m.id == marketerId);
      if (localIndex != -1) {
        marketer = _marketers[localIndex];
      } else {
        final snapshot =
            await _firestore.collection('app_marketers').doc(marketerId).get();
        if (!snapshot.exists) {
          throw Exception('Marketer not found');
        }
        marketer = MarketerModel.fromFirestore(snapshot);
      }

      final updatedBalance = marketer.balance + amount;
      final updatedLifetime = addToLifetimeCommission
          ? marketer.totalCommissionEarned + amount
          : marketer.totalCommissionEarned;

      await _firestore.collection('app_marketers').doc(marketerId).update({
        'balance': updatedBalance,
        if (addToLifetimeCommission) 'totalCommissionEarned': updatedLifetime,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final index = _marketers.indexWhere((m) => m.id == marketerId);
      if (index != -1) {
        _marketers[index] = _marketers[index].copyWith(
          balance: updatedBalance,
          totalCommissionEarned: updatedLifetime,
        );
      }

      if (_currentMarketer?.id == marketerId) {
        _currentMarketer = _currentMarketer!.copyWith(
          balance: updatedBalance,
          totalCommissionEarned: updatedLifetime,
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

  Future<bool> creditMarketerRewardForSubscription({
    required String userId,
    required String businessId,
    required String planId,
    required double amount,
    String? marketerEmail,
    String? userEmail,
    String? businessName,
    String? requestId,
    String? transactionId,
    DateTime? approvedAt,
    String approvedBy = 'admin',
    bool refreshInsights = true,
  }) async {
    try {
      final normalizedUserId = userId.trim();
      if (normalizedUserId.isEmpty) return false;

      final approvalTime = approvedAt ?? DateTime.now();
      final periodKey = _buildPeriodKey(_monthStart(approvalTime));
      final userDoc =
          await _firestore.collection('users').doc(normalizedUserId).get();
      final userData = userDoc.data() ?? const <String, dynamic>{};

      var resolvedBusinessId = businessId.trim();
      if (resolvedBusinessId.isEmpty) {
        resolvedBusinessId = _readString(
          userData['currentBusinessId'] ?? userData['businessId'],
        );
      }

      Map<String, dynamic> businessData = const <String, dynamic>{};
      if (resolvedBusinessId.isNotEmpty) {
        final businessDoc = await _firestore
            .collection('businesses')
            .doc(resolvedBusinessId)
            .get();
        businessData = businessDoc.data() ?? const <String, dynamic>{};
      }

      final normalizedMarketerEmail = _normalizeEmail(
        marketerEmail ??
            _readString(
              userData['referralEmail'] ??
                  userData['referredBy'] ??
                  businessData['referralEmail'] ??
                  businessData['referredBy'],
            ),
      );
      if (normalizedMarketerEmail.isEmpty) return false;

      final marketerSnapshot = await _firestore
          .collection('app_marketers')
          .where('email', isEqualTo: normalizedMarketerEmail)
          .limit(1)
          .get();
      if (marketerSnapshot.docs.isEmpty) return false;

      final marketerDoc = marketerSnapshot.docs.first;
      final marketer = MarketerModel.fromFirestore(marketerDoc);
      final commissionRate = marketer.commissionRateOverride ?? _rewardConfig.subscriptionCommissionRate;
      final commissionAmount = amount * commissionRate;
      if (commissionAmount <= 0) return false;

      final referralSnapshot = await _firestore
          .collection('referrals')
          .where('userId', isEqualTo: normalizedUserId)
          .get();
      final matchingReferralDocs = referralSnapshot.docs.where((doc) {
        return _normalizeEmail(doc.data()['marketerEmail']?.toString() ?? '') ==
            normalizedMarketerEmail;
      }).toList();
      final primaryReferral = matchingReferralDocs.isNotEmpty
          ? ReferralRecord.fromFirestore(matchingReferralDocs.first)
          : null;
      final isFirstActivation = primaryReferral?.status != 'approved';
      final rewardType = isFirstActivation
          ? 'new_subscription_commission'
          : 'renewal_commission';

      final rewardKeySource = requestId?.trim().isNotEmpty == true
          ? 'request_${requestId!.trim()}'
          : transactionId?.trim().isNotEmpty == true
              ? 'tx_${transactionId!.trim()}'
              : 'fallback_${normalizedUserId}_${resolvedBusinessId}_${planId}_${approvalTime.millisecondsSinceEpoch}_$rewardType';
      final rewardDocId = _sanitizeLedgerId(rewardKeySource);
      final rewardDocRef =
          _firestore.collection('marketer_reward_ledger').doc(rewardDocId);
      final existingRewardDoc = await rewardDocRef.get();
      if (existingRewardDoc.exists) return true;

      final resolvedUserEmail = _readString(userEmail).isNotEmpty
          ? _readString(userEmail)
          : _readString(userData['email']);
      final resolvedBusinessName = _readString(businessName).isNotEmpty
          ? _readString(businessName)
          : _readString(businessData['name'] ?? businessData['businessName']);

      final batch = _firestore.batch();
      batch.set(rewardDocRef, {
        'marketerId': marketer.id,
        'marketerEmail': normalizedMarketerEmail,
        'userId': normalizedUserId,
        'userEmail': resolvedUserEmail,
        'businessId': resolvedBusinessId,
        'businessName': resolvedBusinessName,
        'planId': planId,
        'amount': commissionAmount,
        'rewardType': rewardType,
        'periodKey': periodKey,
        'awardedAt': Timestamp.fromDate(approvalTime),
        'createdAt': FieldValue.serverTimestamp(),
        'sourceRequestId': requestId,
        'sourceTransactionId': transactionId,
        'approvedBy': approvedBy,
        'status': 'awarded',
        'isFirstActivation': isFirstActivation,
      });

      final nextPendingCount = marketer.totalReferralsPending > 0
          ? marketer.totalReferralsPending - 1
          : 0;
      batch.set(
          marketerDoc.reference,
          {
            'balance': marketer.balance + commissionAmount,
            'totalCommissionEarned':
                marketer.totalCommissionEarned + commissionAmount,
            'referredUserIds': FieldValue.arrayUnion([normalizedUserId]),
            if (isFirstActivation)
              'totalReferralsApproved': marketer.totalReferralsApproved + 1,
            if (isFirstActivation) 'totalReferralsPending': nextPendingCount,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      if (matchingReferralDocs.isNotEmpty) {
        for (final referralDoc in matchingReferralDocs) {
          batch.set(
              referralDoc.reference,
              {
                'marketerEmail': normalizedMarketerEmail,
                'userId': normalizedUserId,
                'userEmail': resolvedUserEmail,
                if (resolvedBusinessId.isNotEmpty)
                  'businessId': resolvedBusinessId,
                'commissionAmount': commissionAmount,
                'status': 'approved',
                'approvedAt': Timestamp.fromDate(approvalTime),
                'approvingAdminId': approvedBy,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        }
      } else {
        final newReferralRef = _firestore.collection('referrals').doc();
        batch.set(newReferralRef, {
          'marketerEmail': normalizedMarketerEmail,
          'userId': normalizedUserId,
          'userEmail': resolvedUserEmail,
          if (resolvedBusinessId.isNotEmpty) 'businessId': resolvedBusinessId,
          'commissionAmount': commissionAmount,
          'status': 'approved',
          'createdAt': Timestamp.fromDate(approvalTime),
          'approvedAt': Timestamp.fromDate(approvalTime),
          'approvingAdminId': approvedBy,
        });
      }

      await batch.commit();

      final updatedReferredUsers = <String>{
        ...marketer.referredUserIds,
        normalizedUserId,
      }.toList(growable: false);
      final updatedMarketer = marketer.copyWith(
        balance: marketer.balance + commissionAmount,
        referredUserIds: updatedReferredUsers,
        totalCommissionEarned:
            marketer.totalCommissionEarned + commissionAmount,
        totalReferralsApproved: isFirstActivation
            ? marketer.totalReferralsApproved + 1
            : marketer.totalReferralsApproved,
        totalReferralsPending: isFirstActivation
            ? nextPendingCount
            : marketer.totalReferralsPending,
      );

      final marketerIndex = _marketers.indexWhere((m) => m.id == marketer.id);
      if (marketerIndex != -1) {
        _marketers[marketerIndex] = updatedMarketer;
      }
      if (_currentMarketer?.id == marketer.id) {
        _currentMarketer = updatedMarketer;
      }

      if (refreshInsights) {
        await fetchMarketingOverview();
      } else {
        notifyListeners();
      }

      return true;
    } catch (e) {
      _errorMessage = 'Error crediting marketer reward: $e';
      print(_errorMessage);
      notifyListeners();
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

      await _firestore
          .collection('app_marketers')
          .doc(_currentMarketer!.id)
          .update({
        'referredUserIds': FieldValue.arrayUnion([userId]),
        'totalReferralsPending': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final updatedUserIds = [..._currentMarketer!.referredUserIds, userId];
      _currentMarketer = _currentMarketer!.copyWith(
        referredUserIds: updatedUserIds,
        totalReferralsPending: _currentMarketer!.totalReferralsPending + 1,
      );

      final marketerIndex = _marketers
          .indexWhere((marketer) => marketer.id == _currentMarketer!.id);
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
      final detectedTier = _resolveDetectedTier(businessData);
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
        'businessClass': detectedTier,
        'businessTier': detectedTier,
        'subscriptionPlan': null, // To be set by owner during subscription selection
        'subscriptionTier': detectedTier,
        'productCount': businessData['productCount'] ?? 0,
        'staffCount': businessData['staffCount'] ?? 0,
        'monthlyRevenue': businessData['monthlyRevenue'] ?? 0.0,
        'detectedTierSource': 'marketer_auto_detection',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'subscriptionStatus': 'pending', // Waiting for owner to select subscription
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

  Future<bool> updateRewardConfig({
    required int monthlyTargetSubscriptions,
    required double targetBonusAmount,
    required double rank1BonusAmount,
    required double rank2BonusAmount,
    required double rank3BonusAmount,
    required double subscriptionCommissionRate,
    required int expiryWarningDays,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('system').doc('admin_settings').set({
        'marketerMonthlyTarget': monthlyTargetSubscriptions,
        'marketerTargetBonusAmount': targetBonusAmount,
        'marketerRank1BonusAmount': rank1BonusAmount,
        'marketerRank2BonusAmount': rank2BonusAmount,
        'marketerRank3BonusAmount': rank3BonusAmount,
        'marketerSubscriptionCommissionRate': subscriptionCommissionRate,
        'marketerExpiryWarningDays': expiryWarningDays,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      }, SetOptions(merge: true));

      _rewardConfig = MarketerRewardConfig(
        monthlyTargetSubscriptions: monthlyTargetSubscriptions,
        targetBonusAmount: targetBonusAmount,
        rank1BonusAmount: rank1BonusAmount,
        rank2BonusAmount: rank2BonusAmount,
        rank3BonusAmount: rank3BonusAmount,
        subscriptionCommissionRate: subscriptionCommissionRate,
        expiryWarningDays: expiryWarningDays,
      );

      await fetchMarketingOverview();
      return true;
    } catch (e) {
      _errorMessage = 'Error updating marketer reward settings: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
