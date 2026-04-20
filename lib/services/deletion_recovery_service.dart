import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/user_model.dart';

class DeletionRecoveryState {
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? recoveryDeadlineAt;
  final String deletedByType;
  final String deletedByUserId;
  final String deletedByRole;
  final String recoveryAccess;
  final String reason;

  const DeletionRecoveryState({
    required this.isDeleted,
    this.deletedAt,
    this.recoveryDeadlineAt,
    this.deletedByType = '',
    this.deletedByUserId = '',
    this.deletedByRole = '',
    this.recoveryAccess = '',
    this.reason = '',
  });

  bool get isWithinGracePeriod {
    if (!isDeleted || recoveryDeadlineAt == null) return false;
    return DateTime.now().isBefore(recoveryDeadlineAt!);
  }

  bool get isExpired {
    if (!isDeleted || recoveryDeadlineAt == null) return false;
    return !isWithinGracePeriod;
  }

  bool get canSelfRecover => isWithinGracePeriod && recoveryAccess == 'self';

  bool get requiresAdminRecovery =>
      isWithinGracePeriod && recoveryAccess == 'admin';
}

class ResolvedUserAccess {
  final bool isAllowed;
  final UserModel? user;
  final String? message;
  final bool recoveredAccount;
  final bool recoveredBusiness;

  const ResolvedUserAccess({
    required this.isAllowed,
    this.user,
    this.message,
    this.recoveredAccount = false,
    this.recoveredBusiness = false,
  });
}

class DeletionRecoveryService {
  static const Duration gracePeriod = Duration(days: 30);

  final FirebaseFirestore _firestore;

  DeletionRecoveryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static DateTime parseNow() => DateTime.now();

  static DateTime computeRecoveryDeadline([DateTime? from]) =>
      (from ?? parseNow()).add(gracePeriod);

  static Map<String, dynamic> buildSoftDeleteFields({
    required String actorId,
    required String actorType,
    String? actorRole,
    String? reason,
    DateTime? now,
  }) {
    final deletedAt = now ?? parseNow();
    final recoveryDeadlineAt = computeRecoveryDeadline(deletedAt);

    return {
      'isDeleted': true,
      'isActive': false,
      'deletedAt': Timestamp.fromDate(deletedAt),
      'recoveryDeadlineAt': Timestamp.fromDate(recoveryDeadlineAt),
      'deletedByUserId': actorId,
      'deletedByType': actorType,
      'deletedByRole': actorRole ?? actorType,
      'recoveryAccess': actorType == 'admin' ? 'admin' : 'self',
      if (reason != null && reason.trim().isNotEmpty)
        'deletionReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> buildRestoreFields({
    bool restoreActive = true,
  }) {
    return {
      'isDeleted': false,
      'isActive': restoreActive,
      'deletedAt': FieldValue.delete(),
      'recoveryDeadlineAt': FieldValue.delete(),
      'deletedByUserId': FieldValue.delete(),
      'deletedByType': FieldValue.delete(),
      'deletedByRole': FieldValue.delete(),
      'recoveryAccess': FieldValue.delete(),
      'deletionReason': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DeletionRecoveryState stateFromData(Map<String, dynamic>? data) {
    if (data == null) {
      return const DeletionRecoveryState(isDeleted: false);
    }

    return DeletionRecoveryState(
      isDeleted: data['isDeleted'] == true,
      deletedAt: parseDate(data['deletedAt']),
      recoveryDeadlineAt: parseDate(data['recoveryDeadlineAt']),
      deletedByType: _readString(data['deletedByType']),
      deletedByUserId: _readString(data['deletedByUserId']),
      deletedByRole: _readString(data['deletedByRole']),
      recoveryAccess: _readString(data['recoveryAccess']),
      reason: _readString(data['deletionReason']),
    );
  }

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) return DateTime.tryParse(value);
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      final nanos = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;
      if (seconds is int && nanos is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanos ~/ 1000000),
        );
      }
    }
    return null;
  }

  static String buildAccessBlockedMessage({
    required String subject,
    required DeletionRecoveryState state,
    String? alternateActorLabel,
  }) {
    final deadline = state.recoveryDeadlineAt == null
        ? ''
        : ' until ${_formatDate(state.recoveryDeadlineAt!)}';

    if (state.canSelfRecover) {
      return '$subject was deleted and can still be recovered$deadline by signing in again.';
    }

    if (state.requiresAdminRecovery) {
      final actorLabel = alternateActorLabel ??
          (state.deletedByType == 'admin' ? 'an admin' : 'the administrator');
      return '$subject was deleted by $actorLabel and only admin can recover it$deadline.';
    }

    return '$subject is no longer available.';
  }

  Future<void> softDeleteBusiness({
    required String businessId,
    required String actorId,
    required String actorType,
    String? actorRole,
    String? reason,
  }) async {
    final businessRef = _firestore.collection('businesses').doc(businessId);
    final businessSnap = await businessRef.get();
    if (!businessSnap.exists) return;

    final now = parseNow();
    final recoveryDeadlineAt = computeRecoveryDeadline(now);
    final businessData = businessSnap.data() ?? <String, dynamic>{};

    await businessRef.set(
      {
        ...buildSoftDeleteFields(
          actorId: actorId,
          actorType: actorType,
          actorRole: actorRole,
          reason: reason,
          now: now,
        ),
        'deletedBusinessName': _readString(businessData['name']),
      },
      SetOptions(merge: true),
    );

    await _annotateLinkedUsersForDeletedBusiness(
      businessId: businessId,
      deletedByType: actorType,
      recoveryDeadlineAt: recoveryDeadlineAt,
    );
  }

  Future<void> restoreBusiness({
    required String businessId,
  }) async {
    final businessRef = _firestore.collection('businesses').doc(businessId);
    final businessSnap = await businessRef.get();
    if (!businessSnap.exists) return;

    final businessData = businessSnap.data() ?? <String, dynamic>{};
    final ownerId = _readString(businessData['ownerId']);

    await businessRef.set(
      {
        ...buildRestoreFields(),
        'deletedBusinessName': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );

    if (ownerId.isNotEmpty) {
      await _restoreOwnerBusinessLink(
        ownerId: ownerId,
        businessId: businessId,
      );
    }

    await _restoreLinkedUsersForBusiness(businessId);
  }

  Future<void> softDeleteUserAccount({
    required String userId,
    required String actorId,
    required String actorType,
    String? actorRole,
    String? reason,
    bool cascadeOwnedBusinesses = false,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userSnap = await userRef.get();
    if (!userSnap.exists) return;

    final now = parseNow();
    final updates = buildSoftDeleteFields(
      actorId: actorId,
      actorType: actorType,
      actorRole: actorRole,
      reason: reason,
      now: now,
    );

    await userRef.set(updates, SetOptions(merge: true));

    final workerRef = _firestore.collection('workers').doc(userId);
    final workerSnap = await workerRef.get();
    if (workerSnap.exists) {
      await workerRef.set(updates, SetOptions(merge: true));
    }

    final userData = userSnap.data() ?? <String, dynamic>{};
    final isOwner =
        userData['isOwner'] == true || _readString(userData['role']) == 'owner';

    if (cascadeOwnedBusinesses && isOwner) {
      final ownedBusinesses = await _firestore
          .collection('businesses')
          .where('ownerId', isEqualTo: userId)
          .get();

      for (final businessDoc in ownedBusinesses.docs) {
        final businessData = businessDoc.data();
        if (businessData['isDeleted'] == true) continue;
        await softDeleteBusiness(
          businessId: businessDoc.id,
          actorId: actorId,
          actorType: actorType,
          actorRole: actorRole,
          reason: reason ?? 'Deleted because the owner account was deleted.',
        );
      }
    }
  }

  Future<void> restoreUserAccount({
    required String userId,
    bool restoreOwnedBusinesses = false,
    bool adminOverride = false,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userSnap = await userRef.get();
    if (!userSnap.exists) return;

    await userRef.set(buildRestoreFields(), SetOptions(merge: true));

    final workerRef = _firestore.collection('workers').doc(userId);
    final workerSnap = await workerRef.get();
    if (workerSnap.exists) {
      await workerRef.set(buildRestoreFields(), SetOptions(merge: true));
    }

    if (!restoreOwnedBusinesses) return;

    final ownedBusinesses = await _firestore
        .collection('businesses')
        .where('ownerId', isEqualTo: userId)
        .get();

    for (final businessDoc in ownedBusinesses.docs) {
      final state = stateFromData(businessDoc.data());
      if (!state.isDeleted || state.isExpired) continue;
      if (!adminOverride && !state.canSelfRecover) continue;
      await restoreBusiness(businessId: businessDoc.id);
    }
  }

  Future<ResolvedUserAccess> resolveUserAccess(
    String userId, {
    bool allowSelfRecovery = false,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userSnap = await userRef.get();
    if (!userSnap.exists || userSnap.data() == null) {
      return const ResolvedUserAccess(
        isAllowed: false,
        message: 'User profile not found in database.',
      );
    }

    var userData = <String, dynamic>{'id': userSnap.id, ...userSnap.data()!};
    var userDeletion = stateFromData(userData);
    var recoveredAccount = false;
    var recoveredBusiness = false;

    if (userDeletion.isDeleted) {
      if (userDeletion.isExpired) {
        return ResolvedUserAccess(
          isAllowed: false,
          message:
              'This account has passed the 30-day recovery window and can no longer be restored.',
        );
      }

      if (allowSelfRecovery && userDeletion.canSelfRecover) {
        await restoreUserAccount(
          userId: userId,
          restoreOwnedBusinesses: true,
        );
        final restoredSnap = await userRef.get();
        if (!restoredSnap.exists || restoredSnap.data() == null) {
          return const ResolvedUserAccess(
            isAllowed: false,
            message: 'This account could not be restored right now.',
          );
        }
        userData = <String, dynamic>{'id': restoredSnap.id, ...restoredSnap.data()!};
        userDeletion = stateFromData(userData);
        recoveredAccount = true;
      } else {
        return ResolvedUserAccess(
          isAllowed: false,
          message: buildAccessBlockedMessage(
            subject: 'This account',
            state: userDeletion,
          ),
        );
      }
    }

    var user = UserModel.fromJson(userData);
    await _syncLegacyBusinessFields(user);

    final ownerResolution = await _resolveOwnerBusinessAccess(
      user: user,
      allowSelfRecovery: allowSelfRecovery,
    );

    if (!ownerResolution.isAllowed) {
      return ownerResolution;
    }

    if (ownerResolution.user != null) {
      user = ownerResolution.user!;
      recoveredBusiness = ownerResolution.recoveredBusiness;
    }

    final workerMessage = await _resolveWorkerBusinessAccess(userData, user);
    if (workerMessage != null) {
      return ResolvedUserAccess(
        isAllowed: false,
        message: workerMessage,
        recoveredAccount: recoveredAccount,
      );
    }

    return ResolvedUserAccess(
      isAllowed: true,
      user: user,
      recoveredAccount: recoveredAccount,
      recoveredBusiness: recoveredBusiness,
    );
  }

  Future<void> _syncLegacyBusinessFields(UserModel user) async {
    if (user.businessIds.isEmpty && user.businessId.isNotEmpty) {
      await _firestore.collection('users').doc(user.id).set({
        'businessIds': [user.businessId],
        'currentBusinessId': user.businessId,
        'preferredBusinessId':
            _readString(user.preferredBusinessId).isNotEmpty
                ? user.preferredBusinessId
                : user.businessId,
        'businessId': user.businessId,
      }, SetOptions(merge: true));
      return;
    }

    final primaryBusinessId = user.primaryBusinessId;
    if (primaryBusinessId.isNotEmpty && primaryBusinessId != user.businessId) {
      await _firestore
          .collection('users')
          .doc(user.id)
          .set({'businessId': primaryBusinessId}, SetOptions(merge: true));
    }
  }

  Future<ResolvedUserAccess> _resolveOwnerBusinessAccess({
    required UserModel user,
    required bool allowSelfRecovery,
  }) async {
    if (!user.isOwner) {
      return ResolvedUserAccess(isAllowed: true, user: user);
    }

    final businessQuery = await _firestore
        .collection('businesses')
        .where('ownerId', isEqualTo: user.id)
        .get();

    final activeBusinessIds = <String>[];
    final deletedBusinesses = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final doc in businessQuery.docs) {
      final data = doc.data();
      if (data['isDeleted'] == true) {
        deletedBusinesses.add(doc);
      } else if (data['isActive'] != false) {
        activeBusinessIds.add(doc.id);
      }
    }

    if (activeBusinessIds.isNotEmpty) {
      final preferredBusinessId = _firstMatchingBusinessId(user, activeBusinessIds);
      if (preferredBusinessId != null) {
        final needsUpdate =
            user.currentBusinessId != preferredBusinessId ||
            user.businessId != preferredBusinessId ||
            user.preferredBusinessId != preferredBusinessId ||
            !user.businessIds.contains(preferredBusinessId);

        if (needsUpdate) {
          final mergedBusinessIds =
              List<String>.from({...user.businessIds, ...activeBusinessIds});
          await _firestore.collection('users').doc(user.id).set({
            'businessId': preferredBusinessId,
            'currentBusinessId': preferredBusinessId,
            'preferredBusinessId': preferredBusinessId,
            'businessIds': mergedBusinessIds,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          return ResolvedUserAccess(
            isAllowed: true,
            user: user.copyWith(
              businessId: preferredBusinessId,
              currentBusinessId: preferredBusinessId,
              preferredBusinessId: preferredBusinessId,
              businessIds: mergedBusinessIds,
            ),
          );
        }
      }

      return ResolvedUserAccess(isAllowed: true, user: user);
    }

    if (deletedBusinesses.isEmpty) {
      return ResolvedUserAccess(isAllowed: true, user: user);
    }

    deletedBusinesses.sort((a, b) {
      final aDate = parseDate(a.data()['deletedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = parseDate(b.data()['deletedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    for (final deletedBusiness in deletedBusinesses) {
      final state = stateFromData(deletedBusiness.data());
      if (!state.isDeleted) continue;
      if (state.isExpired) continue;

      if (allowSelfRecovery && state.canSelfRecover) {
        await restoreBusiness(businessId: deletedBusiness.id);
        final refreshedUserSnap =
            await _firestore.collection('users').doc(user.id).get();
        if (refreshedUserSnap.exists && refreshedUserSnap.data() != null) {
          return ResolvedUserAccess(
            isAllowed: true,
            user: UserModel.fromJson({
              'id': refreshedUserSnap.id,
              ...refreshedUserSnap.data()!,
            }),
            recoveredBusiness: true,
          );
        }

        return ResolvedUserAccess(
          isAllowed: true,
          user: user.copyWith(
            businessId: deletedBusiness.id,
            currentBusinessId: deletedBusiness.id,
            preferredBusinessId: deletedBusiness.id,
            businessIds: List<String>.from({...user.businessIds, deletedBusiness.id}),
          ),
          recoveredBusiness: true,
        );
      }

      return ResolvedUserAccess(
        isAllowed: false,
        message: buildAccessBlockedMessage(
          subject: 'Your business account',
          state: state,
        ),
      );
    }

    return const ResolvedUserAccess(
      isAllowed: false,
      message:
          'All businesses linked to this owner account have passed the 30-day recovery window.',
    );
  }

  Future<String?> _resolveWorkerBusinessAccess(
    Map<String, dynamic> rawUserData,
    UserModel user,
  ) async {
    if (user.isOwner) return null;

    final candidateBusinessIds = <String>{
      if (_readString(rawUserData['currentBusinessId']).isNotEmpty)
        _readString(rawUserData['currentBusinessId']),
      if (_readString(rawUserData['businessId']).isNotEmpty)
        _readString(rawUserData['businessId']),
      if (_readString(rawUserData['lastDeletedBusinessId']).isNotEmpty)
        _readString(rawUserData['lastDeletedBusinessId']),
      ...user.businessIds.where((id) => id.trim().isNotEmpty),
      ...((rawUserData['deletedBusinessIds'] as List<dynamic>?) ?? const [])
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty),
    };

    if (candidateBusinessIds.isEmpty) return null;

    for (final businessId in candidateBusinessIds) {
      final businessSnap =
          await _firestore.collection('businesses').doc(businessId).get();
      if (!businessSnap.exists || businessSnap.data() == null) continue;

      final data = businessSnap.data()!;
      final state = stateFromData(data);
      if (!state.isDeleted) return null;

      if (state.isExpired) {
        return 'Your last assigned business has passed the recovery period and is no longer available.';
      }

      final recoveryDeadline = state.recoveryDeadlineAt == null
          ? ''
          : ' until ${_formatDate(state.recoveryDeadlineAt!)}';

      if (state.requiresAdminRecovery) {
        return 'This business was deleted by admin and only admin can restore access$recoveryDeadline.';
      }

      return 'This business was deleted by its owner and only the owner can restore access$recoveryDeadline.';
    }

    return null;
  }

  Future<void> _annotateLinkedUsersForDeletedBusiness({
    required String businessId,
    required String deletedByType,
    required DateTime recoveryDeadlineAt,
  }) async {
    final userRefs = <String, DocumentReference<Map<String, dynamic>>>{};

    final queries = await Future.wait([
      _firestore.collection('users').where('businessId', isEqualTo: businessId).get(),
      _firestore
          .collection('users')
          .where('currentBusinessId', isEqualTo: businessId)
          .get(),
      _firestore
          .collection('users')
          .where('businessIds', arrayContains: businessId)
          .get(),
    ]);

    for (final snapshot in queries) {
      for (final doc in snapshot.docs) {
        userRefs[doc.id] = doc.reference;
      }
    }

    for (final entry in userRefs.entries) {
      final doc = await entry.value.get();
      if (!doc.exists || doc.data() == null) continue;

      final data = doc.data()!;
      final businessIds = ((data['businessIds'] as List<dynamic>?) ?? const [])
          .map((value) => value.toString())
          .where((id) => id.trim().isNotEmpty && id != businessId)
          .toList();

      final nextBusinessId = businessIds.isNotEmpty ? businessIds.first : null;
      final updates = <String, dynamic>{
        'deletedBusinessIds': FieldValue.arrayUnion([businessId]),
        'lastDeletedBusinessId': businessId,
        'lastBusinessDeletedAt': Timestamp.fromDate(parseNow()),
        'lastBusinessRecoveryDeadlineAt': Timestamp.fromDate(recoveryDeadlineAt),
        'lastBusinessRecoveryAccess':
            deletedByType == 'admin' ? 'admin' : 'self',
        'lastBusinessDeletedByType': deletedByType,
        'businessIds': businessIds,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final currentBusinessId = _readString(data['currentBusinessId']);
      final preferredBusinessId = _readString(data['preferredBusinessId']);
      final primaryBusinessId = _readString(data['businessId']);

      if (currentBusinessId == businessId) {
        updates['currentBusinessId'] = nextBusinessId;
      }
      if (preferredBusinessId == businessId) {
        updates['preferredBusinessId'] = nextBusinessId;
      }
      if (primaryBusinessId == businessId) {
        updates['businessId'] = nextBusinessId ?? '';
      }

      await entry.value.set(updates, SetOptions(merge: true));
    }
  }

  Future<void> _restoreOwnerBusinessLink({
    required String ownerId,
    required String businessId,
  }) async {
    final ownerRef = _firestore.collection('users').doc(ownerId);
    final ownerSnap = await ownerRef.get();
    if (!ownerSnap.exists || ownerSnap.data() == null) return;

    final ownerData = ownerSnap.data()!;
    final businessIds = ((ownerData['businessIds'] as List<dynamic>?) ?? const [])
        .map((value) => value.toString())
        .where((id) => id.trim().isNotEmpty)
        .toList();

    final mergedBusinessIds = List<String>.from({...businessIds, businessId});
    final currentBusinessId = _readString(ownerData['currentBusinessId']);
    final preferredBusinessId = _readString(ownerData['preferredBusinessId']);
    final primaryBusinessId = _readString(ownerData['businessId']);

    await ownerRef.set({
      'businessIds': mergedBusinessIds,
      'businessId':
          primaryBusinessId.isNotEmpty ? primaryBusinessId : businessId,
      'currentBusinessId':
          currentBusinessId.isNotEmpty ? currentBusinessId : businessId,
      'preferredBusinessId':
          preferredBusinessId.isNotEmpty ? preferredBusinessId : businessId,
      'deletedBusinessIds': FieldValue.arrayRemove([businessId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _restoreLinkedUsersForBusiness(String businessId) async {
    final snapshot = await _firestore
        .collection('users')
        .where('deletedBusinessIds', arrayContains: businessId)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final businessIds = ((data['businessIds'] as List<dynamic>?) ?? const [])
          .map((value) => value.toString())
          .where((id) => id.trim().isNotEmpty)
          .toList();
      final mergedBusinessIds = List<String>.from({...businessIds, businessId});

      final currentBusinessId = _readString(data['currentBusinessId']);
      final preferredBusinessId = _readString(data['preferredBusinessId']);
      final primaryBusinessId = _readString(data['businessId']);
      final lastDeletedBusinessId = _readString(data['lastDeletedBusinessId']);

      final updates = <String, dynamic>{
        'deletedBusinessIds': FieldValue.arrayRemove([businessId]),
        'businessIds': mergedBusinessIds,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (primaryBusinessId.isEmpty) {
        updates['businessId'] = businessId;
      }
      if (currentBusinessId.isEmpty) {
        updates['currentBusinessId'] = businessId;
      }
      if (preferredBusinessId.isEmpty) {
        updates['preferredBusinessId'] = businessId;
      }
      if (lastDeletedBusinessId == businessId) {
        updates.addAll({
          'lastDeletedBusinessId': FieldValue.delete(),
          'lastBusinessDeletedAt': FieldValue.delete(),
          'lastBusinessRecoveryDeadlineAt': FieldValue.delete(),
          'lastBusinessRecoveryAccess': FieldValue.delete(),
          'lastBusinessDeletedByType': FieldValue.delete(),
        });
      }

      await doc.reference.set(updates, SetOptions(merge: true));
    }
  }

  String? _firstMatchingBusinessId(UserModel user, List<String> activeBusinessIds) {
    final orderedCandidates = <String>[
      if (user.currentBusinessId?.trim().isNotEmpty == true)
        user.currentBusinessId!.trim(),
      if (user.preferredBusinessId?.trim().isNotEmpty == true)
        user.preferredBusinessId!.trim(),
      if (user.businessId.trim().isNotEmpty) user.businessId.trim(),
      ...user.businessIds.map((id) => id.trim()),
    ];

    for (final candidate in orderedCandidates) {
      if (activeBusinessIds.contains(candidate)) {
        return candidate;
      }
    }

    return activeBusinessIds.isNotEmpty ? activeBusinessIds.first : null;
  }

  static String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
