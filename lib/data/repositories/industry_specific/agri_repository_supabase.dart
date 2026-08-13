import 'package:supabase_flutter/supabase_flutter.dart';
import 'agri_repository.dart';

/// Supabase/Postgres-backed AgriRepository.
class AgriRepositorySupabase implements AgriRepository {
  final SupabaseClient _supabase;

  AgriRepositorySupabase({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchFarms(String businessId) async {
    final result = await _supabase
        .from('agri_farms')
        .select('*')
        .eq('business_id', businessId)
        .order('name');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<void> addCrop(Map<String, dynamic> crop) async {
    final data = Map<String, dynamic>.from(crop)..remove('id');
    await _supabase.from('agri_crops').insert(data);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchInputs(String businessId) async {
    final result = await _supabase
        .from('agri_inputs')
        .select('*')
        .eq('business_id', businessId)
        .order('name');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<void> saveFarm(String businessId, Map<String, dynamic> farm) async {
    final id = farm['id'] as String?;
    final data = Map<String, dynamic>.from(farm)
      ..remove('id')
      ..['business_id'] = businessId;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('agri_farms').update(data).eq('id', id);
    } else {
      await _supabase.from('agri_farms').insert(data);
    }
  }

  @override
  Future<void> deleteFarm(String businessId, String farmId) async {
    await _supabase.from('agri_farms').delete().eq('id', farmId);
  }

  @override
  Future<void> saveHint(
      String businessId, String farmId, Map<String, dynamic> hint) async {
    await _supabase.from('agri_hints').insert({
      'business_id': businessId,
      'farm_id': farmId,
      'text': hint['text'] ?? '',
      'date': hint['date'] ?? DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchHints(String businessId,
      {String? farmId}) async {
    var query = _supabase
        .from('agri_hints')
        .select('*, agri_farms(name)')
        .eq('business_id', businessId);
    if (farmId != null) {
      query = query.eq('farm_id', farmId);
    }
    final result = await query.order('date', ascending: false);
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<void> saveLivestockGroup(
      String businessId, Map<String, dynamic> group) async {
    final id = group['id'] as String?;
    final data = Map<String, dynamic>.from(group)
      ..remove('id')
      ..['business_id'] = businessId;
    if (id != null && id.isNotEmpty) {
      await _supabase
          .from('agri_livestock_groups')
          .update(data)
          .eq('id', id);
    } else {
      await _supabase.from('agri_livestock_groups').insert(data);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLivestockGroups(
      String businessId) async {
    final result = await _supabase
        .from('agri_livestock_groups')
        .select('*')
        .eq('business_id', businessId)
        .order('name');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<void> deleteLivestockGroup(String businessId, String groupId) async {
    await _supabase.from('agri_livestock_groups').delete().eq('id', groupId);
  }
}

