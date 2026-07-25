import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/repositories/drink_repository.dart';

/// Supabase/Postgres-backed DrinkRepository.
class DrinkRepositorySupabase implements DrinkRepository {
  final SupabaseClient _supabase;

  DrinkRepositorySupabase({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> getBrewingLogs(String businessId) async {
    final result = await _supabase
        .from('drink_brewing_logs')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(50);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getDistributionOrders(
      String businessId) async {
    final result = await _supabase
        .from('drink_distribution_orders')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(50);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getInventory(String businessId) async {
    final result = await _supabase
        .from('inventory')
        .select('*')
        .eq('business_id', businessId)
        .eq('category', 'beverage')
        .order('name');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }
}

