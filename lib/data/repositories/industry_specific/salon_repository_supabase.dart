import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/repositories/salon_repository.dart';

/// Supabase/Postgres-backed SalonRepository.
class SalonRepositorySupabase implements SalonRepository {
  final SupabaseClient _supabase;

  SalonRepositorySupabase({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<Map<String, dynamic>> getDashboardStats(String businessId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final appointments = await _supabase
        .from('salon_appointments')
        .select('id')
        .eq('business_id', businessId)
        .gte('appointment_date', '$today 00:00:00')
        .lte('appointment_date', '$today 23:59:59');

    final totalRevenue = await _supabase
        .rpc('get_daily_sales_summary', params: {
          'p_business_id': businessId,
          'p_date': today,
        });

    return {
      'appointmentsToday': appointments.length,
      'revenue': totalRevenue is Map ? totalRevenue['total_sales'] ?? 0 : 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getTodayAppointments(
      String businessId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await _supabase
        .from('salon_appointments')
        .select('*, customers(*)')
        .eq('business_id', businessId)
        .gte('appointment_date', '$today 00:00:00')
        .lte('appointment_date', '$today 23:59:59')
        .order('appointment_time');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getStylists(String businessId) async {
    final result = await _supabase
        .from('salon_stylists')
        .select('*')
        .eq('business_id', businessId)
        .eq('is_active', true)
        .order('name');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }
}

