import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase/Postgres-backed DeletionRecoveryService.
///
/// Replaces the Firestore-based DeletionRecoveryService. Soft-delete and
/// recovery are handled through `profiles` and `businesses` tables in
/// PostgreSQL instead of Firestore.
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
      'deleted_by_user_id': actorId,
      'deletion_reason': reason ?? '',
    }).eq('id', userId);
  }

  Future<void> restoreUser({required String userId}) async {
    await _supabase.from('profiles').update({
      'is_deleted': false,
      'is_active': true,
      'deleted_at': null,
      'recovery_deadline_at': null,
      'deleted_by_user_id': null,
      'deletion_reason': null,
    }).eq('id', userId);
  }

  Future<String?> checkUserAccess(String userId) async {
    final profile = await _supabase
        .from('profiles')
        .select('is_deleted, is_active, deleted_at, recovery_deadline_at, deletion_reason')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) return 'User profile not found.';
    if (profile['is_deleted'] != true) return null;

    final deadlineStr = profile['recovery_deadline_at'] as String?;
    if (deadlineStr != null) {
      final deadline = DateTime.tryParse(deadlineStr);
      if (deadline != null && DateTime.now().isAfter(deadline)) {
        return 'This account has passed the 30-day recovery window and can no longer be restored.';
      }
    }

    return 'This account has been deleted. Please contact support for recovery.';
  }

  Future<bool> trySelfRecover(String userId) async {
    final profile = await _supabase
        .from('profiles')
        .select('is_deleted, recovery_deadline_at, deleted_by_user_id')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) return false;
    if (profile['is_deleted'] != true) return false;

    final deadlineStr = profile['recovery_deadline_at'] as String?;
    if (deadlineStr == null) return false;
    final deadline = DateTime.tryParse(deadlineStr);
    if (deadline == null || DateTime.now().isAfter(deadline)) return false;

    final deletedBy = profile['deleted_by_user_id'] as String?;
    if (deletedBy == userId) {
      await restoreUser(userId: userId);
      return true;
    }

    return false;
  }

  Future<Map<String, dynamic>?> getDeletionState(String userId) async {
    return await _supabase
        .from('profiles')
        .select('is_deleted, is_active, deleted_at, recovery_deadline_at, deletion_reason')
        .eq('id', userId)
        .maybeSingle();
  }
}
