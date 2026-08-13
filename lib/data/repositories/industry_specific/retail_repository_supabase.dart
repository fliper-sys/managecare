import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/repositories/retail_repository.dart';

/// Supabase/Postgres-backed RetailRepository.
class RetailRepositorySupabase implements RetailRepository {
  final SupabaseClient _supabase;

  RetailRepositorySupabase({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> getWholesaleOrders(
      String businessId) async {
    final result = await _supabase
        .from('sales')
        .select('*, sale_items(*)')
        .eq('business_id', businessId)
        .eq('category', 'wholesale')
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
        .order('name');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getSales(String businessId) async {
    final result = await _supabase
        .from('sales')
        .select('*, sale_items(*)')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(100);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }
}

