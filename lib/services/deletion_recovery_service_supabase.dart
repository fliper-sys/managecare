import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase/Postgres-backed DeletionRecoveryService.
///
/// Replaces the Firestore-based DeletionRecoveryService. Soft-delete and
/// recovery are handled through `profiles` and `businesses` tables in
/// PostgreSQL instead of Firestore. Both tables' PATCH is already gated
/// server-side (profiles: self-only; businesses: owner-only), so these
/// calls need no dedicated backend routes.
///
/// The actual login-time gate lives in
/// `AuthenticationService.resolveUserAccess` - this class just performs the
/// mutations (soft-delete/restore) that the UI (settings screens,
/// BusinessProvider.deleteBusiness) triggers directly.
class DeletionRecoveryServiceSupabase {
  static const Duration recoveryGracePeriod = Duration(days: 30);

  final SupabaseClient _supabase;

  DeletionRecoveryServiceSupabase({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<void> softDeleteUser({
    required String userId,
    required String actorId,
    String? reason,
  }) async {
    final now = DateTime.now().toIso8601String();
    final deadline = DateTime.now().add(recoveryGracePeriod).toIso8601String();

    await _supabase.from('profiles').update({
      'is_deleted': true,
      'is_active': false,
      'deleted_at': now,
      'recovery_deadline_at': deadline,
      'deleted_by_id': actorId,
      'deletion_reason': reason ?? '',
    }).eq('id', userId);
  }

  Future<void> restoreUser({required String userId}) async {
    await _supabase.from('profiles').update({
      'is_deleted': false,
      'is_active': true,
      'deleted_at': null,
      'recovery_deadline_at': null,
      'deleted_by_id': null,
      'deletion_reason': null,
    }).eq('id', userId);
  }

  /// Soft-delete a business (owner-only - enforced server-side by the
  /// businesses PATCH gate). business_members rows are left untouched:
  /// membership stays real, the business is just hidden from use until
  /// restored.
  Future<void> softDeleteBusiness({
    required String businessId,
    required String actorId,
    String? reason,
  }) async {
    final now = DateTime.now().toIso8601String();
    final deadline = DateTime.now().add(recoveryGracePeriod).toIso8601String();

    await _supabase.from('businesses').update({
      'is_deleted': true,
      'is_active': false,
      'deleted_at': now,
      'recovery_deadline_at': deadline,
      'deleted_by_id': actorId,
      'deleted_by_type': 'owner',
      'deletion_reason': reason ?? '',
    }).eq('id', businessId);
  }

  Future<void> restoreBusiness({required String businessId}) async {
    await _supabase.from('businesses').update({
      'is_deleted': false,
      'is_active': true,
      'deleted_at': null,
      'recovery_deadline_at': null,
      'deleted_by_id': null,
      'deleted_by_type': null,
      'deletion_reason': null,
    }).eq('id', businessId);
  }
}
