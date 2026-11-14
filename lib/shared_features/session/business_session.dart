import '../../business_profiles/business_profiles.dart';
import '../ui_v2.dart';

/// Plain description of one business the signed-in user belongs to.
///
/// Kept free of Firebase and provider types so the session logic can be unit
/// tested without a backend. The adapter in `provider_adapter.dart` builds
/// these from `BusinessModel`.
class BusinessRef {
  const BusinessRef({
    required this.id,
    required this.name,
    required this.type,
    this.planActive = true,
    this.planEnd,
    this.logoUrl,
  });

  final String id;
  final String name;

  /// Business type id as stored on the business: retail, salon, hotel...
  final String type;
  final bool planActive;
  final DateTime? planEnd;
  final String? logoUrl;

  bool planExpiredAt(DateTime now) {
    if (!planActive) return true;
    final end = planEnd;
    return end != null && now.isAfter(end);
  }
}

/// What the app is doing about the business list and the selected business.
enum SessionPhase {
  /// First load of the user's businesses, nothing to show yet.
  loadingList,

  /// The user belongs to no business yet.
  noBusinesses,

  /// A switch is in flight; the target is [BusinessSessionState.pending].
  switching,

  /// A business is selected and usable.
  ready,

  /// Loading failed and there is nothing cached to fall back on.
  error,
}

/// Which UI a selected business gets. Resolved per business, so two
/// businesses owned by the same person can be on different UIs.
enum ProfileState {
  /// Migrated profile and the v2 flag is on: use the v2 screens.
  v2,

  /// No v2 for this business (not migrated, or flag off): keep old screens.
  legacy,

  /// Plan lapsed or inactive. Read-only recovery screen, then renew.
  planExpired,

  /// Business type text is empty or not one the app knows.
  unknownType,
}

class ResolvedProfile {
  const ResolvedProfile(this.state, [this.profile]);
  final ProfileState state;

  /// Set only when [state] is [ProfileState.v2] or [ProfileState.planExpired]
  /// for a migrated type, so the recovery screen can still use the accent.
  final BusinessProfile? profile;
}

/// Decides the profile state for [b]. Order matters: an unknown type is
/// reported first, then an expired plan, then v2 versus legacy.
ResolvedProfile resolveProfile(
  BusinessRef b, {
  DateTime? now,
  String? buildFlag,
  Set<String>? overrideSet,
}) {
  final type = b.type.trim().toLowerCase();
  if (type.isEmpty) return const ResolvedProfile(ProfileState.unknownType);
  final profile = BusinessProfiles.forType(type);
  if (b.planExpiredAt(now ?? DateTime.now())) {
    return ResolvedProfile(ProfileState.planExpired, profile);
  }
  final v2 = UiV2.enabledFor(type, buildFlag: buildFlag, overrideSet: overrideSet);
  return v2
      ? ResolvedProfile(ProfileState.v2, profile)
      : const ResolvedProfile(ProfileState.legacy);
}

/// Immutable snapshot the v2 shell renders from.
class BusinessSessionState {
  const BusinessSessionState({
    required this.phase,
    this.businesses = const [],
    this.currentId,
    this.pendingId,
    this.usingCache = false,
    this.errorMessage,
  });

  final SessionPhase phase;
  final List<BusinessRef> businesses;
  final String? currentId;
  final String? pendingId;

  /// Data came from the device cache because the network failed.
  final bool usingCache;
  final String? errorMessage;

  /// Mirrors the provider's flags. A switch wins over everything, then a
  /// failure with nothing to show, then the first load.
  factory BusinessSessionState.derive({
    required List<BusinessRef> businesses,
    required String? currentId,
    required bool isLoading,
    required bool isSwitching,
    String? pendingId,
    bool usingCache = false,
    String? errorMessage,
  }) {
    final hasCurrent = currentId != null && businesses.any((b) => b.id == currentId);
    final SessionPhase phase;
    if (isSwitching && pendingId != null) {
      phase = SessionPhase.switching;
    } else if (hasCurrent) {
      phase = SessionPhase.ready;
    } else if (isLoading) {
      phase = SessionPhase.loadingList;
    } else if (errorMessage != null && businesses.isEmpty) {
      phase = SessionPhase.error;
    } else if (businesses.isEmpty) {
      phase = SessionPhase.noBusinesses;
    } else {
      // Businesses exist but none is selected yet: treat as loading the
      // selection so the gate shows a skeleton rather than a blank screen.
      phase = SessionPhase.loadingList;
    }
    return BusinessSessionState(
      phase: phase,
      businesses: List.unmodifiable(businesses),
      currentId: currentId,
      pendingId: pendingId,
      usingCache: usingCache,
      errorMessage: errorMessage,
    );
  }

  BusinessRef? _byId(String? id) {
    if (id == null) return null;
    for (final b in businesses) {
      if (b.id == id) return b;
    }
    return null;
  }

  BusinessRef? get current => _byId(currentId);
  BusinessRef? get pending => _byId(pendingId);

  /// Key that scopes per-business UI state. While switching it is the target,
  /// so the old business's cart and filters are gone before the new data lands.
  String? get tenantKey => phase == SessionPhase.switching ? pendingId : currentId;

  bool get canSwitch => businesses.length > 1 && phase != SessionPhase.switching;
}
