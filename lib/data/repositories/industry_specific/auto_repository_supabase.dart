import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/repositories/auto_repository.dart';

/// Supabase/Postgres-backed AutoRepository.
class AutoRepositorySupabase implements AutoRepository {
  final SupabaseClient _supabase;

  AutoRepositorySupabase({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<Map<String, dynamic>> getDashboardStats(String businessId) async {
    final activeJobs = await _supabase
        .from('auto_service_orders')
        .select('id')
        .eq('business_id', businessId)
        .inFilter('status', ['in_progress', 'pending']);

    final completedJobs = await _supabase
        .from('auto_service_orders')
        .select('id')
        .eq('business_id', businessId)
        .eq('status', 'completed');

    return {
      'activeJobs': activeJobs.length,
      'completedJobs': completedJobs.length,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getServiceOrders(
      String businessId) async {
    final result = await _supabase
        .from('auto_service_orders')
        .select('*, customers(*), vehicles(*)')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(50);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getJobCards(String businessId) async {
    final result = await _supabase
        .from('auto_job_cards')
        .select('*, auto_service_orders!inner(*)')
        .eq('auto_service_orders.business_id', businessId)
        .order('created_at', ascending: false)
        .limit(50);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getVehicles(String businessId) async {
    final result = await _supabase
        .from('vehicles')
        .select('*, customers(*)')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(100);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getInvoices(String businessId) async {
    final result = await _supabase
        .from('sales')
        .select('*, sale_items(*)')
        .eq('business_id', businessId)
        .eq('category', 'auto_service')
        .order('created_at', ascending: false)
        .limit(50);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getBookings(String businessId) async {
    final result = await _supabase
        .from('auto_bookings')
        .select('*, customers(*)')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(50);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getParts(String businessId) async {
    final result = await _supabase
        .from('inventory')
        .select('*')
        .eq('business_id', businessId)
        .eq('category', 'auto_parts')
        .order('name');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getServices(String businessId) async {
    final result = await _supabase
        .from('auto_services_definitions')
        .select('*')
        .eq('business_id', businessId)
        .order('name');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }
}

