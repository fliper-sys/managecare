import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/repositories/pharmacy_repository.dart';

/// Supabase/Postgres-backed PharmacyRepository.
class PharmacyRepositorySupabase implements PharmacyRepository {
  final SupabaseClient _supabase;

  PharmacyRepositorySupabase({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<Map<String, dynamic>> getDashboardStats(String businessId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final prescriptionsToday = await _supabase
        .from('prescriptions')
        .select('id')
        .eq('business_id', businessId)
        .gte('created_at', '$today 00:00:00')
        .lte('created_at', '$today 23:59:59');

    final expiringSoon = await _supabase
        .from('inventory')
        .select('id')
        .eq('business_id', businessId)
        .lte('expiry_date',
            DateTime.now().add(const Duration(days: 7)).toIso8601String())
        .gt('expiry_date', DateTime.now().toIso8601String());

    return {
      'prescriptionsToday': prescriptionsToday.length,
      'expiringSoon': expiringSoon.length,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentPrescriptions(
      String businessId) async {
    final result = await _supabase
        .from('prescriptions')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(20);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<int> getExpiringItemCount(String businessId) async {
    final result = await _supabase
        .from('inventory')
        .select('id')
        .eq('business_id', businessId)
        .lte('expiry_date',
            DateTime.now().add(const Duration(days: 7)).toIso8601String())
        .gt('expiry_date', DateTime.now().toIso8601String());
    return result.length;
  }
}

