import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/repositories/restaurant_repository.dart';

/// Supabase/Postgres-backed RestaurantRepository.
class RestaurantRepositorySupabase implements RestaurantRepository {
  final SupabaseClient _supabase;

  RestaurantRepositorySupabase({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<Map<String, dynamic>> getDashboardStats(String businessId) async {
    final activeTables = await _supabase
        .from('restaurant_tables')
        .select('id')
        .eq('business_id', businessId)
        .eq('status', 'occupied');

    final kitchenQueue = await _supabase
        .from('sales')
        .select('id')
        .eq('business_id', businessId)
        .eq('category', 'dine-in')
        .inFilter('status', ['preparing', 'ready']);

    final todayRevenue = await _supabase
        .rpc('get_daily_sales_summary', params: {
          'p_business_id': businessId,
          'p_date': DateTime.now().toIso8601String().substring(0, 10),
        });

    return {
      'activeTables': activeTables.length,
      'kitchenQueue': kitchenQueue.length,
      'revenue': todayRevenue is Map ? todayRevenue['total_sales'] ?? 0 : 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getTables(String businessId) async {
    final result = await _supabase
        .from('restaurant_tables')
        .select('*')
        .eq('business_id', businessId)
        .order('table_number');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveOrders(
      String businessId) async {
    final result = await _supabase
        .from('sales')
        .select('*, sale_items(*)')
        .eq('business_id', businessId)
        .inFilter('status', ['preparing', 'ready'])
        .order('created_at', ascending: false);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }
}

