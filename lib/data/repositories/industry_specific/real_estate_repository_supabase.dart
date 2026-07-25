import 'package:supabase_flutter/supabase_flutter.dart';
import 'real_estate_repository.dart';

/// Supabase/Postgres-backed RealEstateRepository (comprehensive).
class RealEstateRepositorySupabase implements RealEstateRepository {
  final SupabaseClient _supabase;

  RealEstateRepositorySupabase({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchProperties(String businessId) async {
    final result = await _supabase
        .from('real_estate_properties')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', ascending: false);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchPropertyById(
      String businessId, String id) async {
    final result = await _supabase
        .from('real_estate_properties')
        .select('*')
        .eq('id', id)
        .maybeSingle();
    if (result == null) return null;
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<Map<String, dynamic>> saveProperty(
      String businessId, Map<String, dynamic> property) async {
    final data = Map<String, dynamic>.from(property)
      ..remove('id')
      ..['business_id'] = businessId;
    final id = property['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('real_estate_properties').update(data).eq('id', id);
      return {...data, 'id': id};
    } else {
      final response = await _supabase
          .from('real_estate_properties')
          .insert(data)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    }
  }

  @override
  Future<void> deleteProperty(String businessId, String id) async {
    await _supabase.from('real_estate_properties').delete().eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOwners(String businessId) async {
    final result = await _supabase
        .from('real_estate_owners')
        .select('*')
        .eq('business_id', businessId)
        .order('name');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<Map<String, dynamic>> saveOwner(
      String businessId, Map<String, dynamic> owner) async {
    final data = Map<String, dynamic>.from(owner)
      ..remove('id')
      ..['business_id'] = businessId;
    final id = owner['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('real_estate_owners').update(data).eq('id', id);
      return {...data, 'id': id};
    } else {
      final response = await _supabase
          .from('real_estate_owners')
          .insert(data)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBookings(String businessId) async {
    final result = await _supabase
        .from('real_estate_bookings')
        .select('*, real_estate_properties(title, address)')
        .eq('business_id', businessId)
        .order('start_at', ascending: false)
        .limit(100);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<Map<String, dynamic>> saveBooking(
      String businessId, Map<String, dynamic> booking) async {
    final data = Map<String, dynamic>.from(booking)
      ..remove('id')
      ..['business_id'] = businessId;
    final id = booking['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('real_estate_bookings').update(data).eq('id', id);
      return {...data, 'id': id};
    } else {
      final response = await _supabase
          .from('real_estate_bookings')
          .insert(data)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    }
  }

  @override
  Future<void> deleteBooking(String businessId, String id) async {
    await _supabase.from('real_estate_bookings').delete().eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPayments(String businessId) async {
    final result = await _supabase
        .from('real_estate_payments')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(100);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<Map<String, dynamic>> savePayment(
      String businessId, Map<String, dynamic> payment) async {
    final data = Map<String, dynamic>.from(payment)
      ..remove('id')
      ..['business_id'] = businessId;
    final response = await _supabase
        .from('real_estate_payments')
        .insert(data)
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDocuments(String businessId,
      {String? propertyId}) async {
    var query = _supabase
        .from('real_estate_documents')
        .select('*, real_estate_properties(title)')
        .eq('business_id', businessId);
    if (propertyId != null && propertyId.isNotEmpty) {
      query = query.eq('property_id', propertyId);
    }
    final result = await query.order('created_at', ascending: false);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<Map<String, dynamic>> saveDocument(
      String businessId, Map<String, dynamic> document) async {
    final data = Map<String, dynamic>.from(document)
      ..remove('id')
      ..['business_id'] = businessId;
    final response = await _supabase
        .from('real_estate_documents')
        .insert(data)
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEscrows(String businessId) async {
    final result = await _supabase
        .from('real_estate_escrows')
        .select('*, real_estate_properties(title)')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(100);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<Map<String, dynamic>> saveEscrow(
      String businessId, Map<String, dynamic> escrow) async {
    final data = Map<String, dynamic>.from(escrow)
      ..remove('id')
      ..['business_id'] = businessId;
    final id = escrow['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('real_estate_escrows').update(data).eq('id', id);
      return {...data, 'id': id};
    } else {
      final response = await _supabase
          .from('real_estate_escrows')
          .insert(data)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchInventory(String businessId) async {
    final result = await _supabase
        .from('real_estate_inventory')
        .select('*')
        .eq('business_id', businessId)
        .order('name');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<Map<String, dynamic>> saveInventoryItem(
      String businessId, Map<String, dynamic> item) async {
    final data = Map<String, dynamic>.from(item)
      ..remove('id')
      ..['business_id'] = businessId;
    final id = item['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('real_estate_inventory').update(data).eq('id', id);
      return {...data, 'id': id};
    } else {
      final response = await _supabase
          .from('real_estate_inventory')
          .insert(data)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    }
  }

  @override
  Future<void> deleteInventoryItem(String businessId, String id) async {
    await _supabase.from('real_estate_inventory').delete().eq('id', id);
  }
}

