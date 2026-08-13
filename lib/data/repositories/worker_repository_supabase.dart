import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/worker_repository.dart';
import '../../core/config/supabase_config.dart';

/// Supabase/Postgres-backed implementation of WorkerRepository.
///
/// Replaces WorkerRepositoryImpl (Firebase Firestore).
class WorkerRepositorySupabase implements WorkerRepository {
  final Dio _http;
  final SupabaseClient _supabase;

  WorkerRepositorySupabase({
    Dio? http,
    SupabaseClient? supabase,
  })  : _http = http ??
            Dio(BaseOptions(
              baseUrl: '${SupabaseConfig.url}/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            )),
        _supabase = supabase ?? Supabase.instance.client;

  String? get _accessToken => _supabase.auth.currentSession?.accessToken;
  Map<String, dynamic> get _headers => {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      if (data is String) return data;
    } catch (_) {}
    return e.message ?? 'Unknown error';
  }

  @override
  Future<dynamic> addWorker(Map<String, dynamic> workerData) async {
    try {
      final businessId = workerData['businessId']?.toString() ?? '';
      if (businessId.isEmpty) throw Exception('businessId is required');

      final response = await _http.post(
        '/workers/$businessId',
        data: _buildPayload(workerData),
        options: Options(headers: _headers),
      );
      return _normalizeWorker(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw Exception('Failed to add worker: ${_extractError(e)}');
    }
  }

  @override
  Future<void> updateWorker(
      String workerId, Map<String, dynamic> workerData) async {
    try {
      final businessId = workerData['businessId']?.toString() ?? '';
      if (businessId.isEmpty) throw Exception('businessId is required');

      await _http.put(
        '/workers/$businessId/$workerId',
        data: _buildPayload(workerData),
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to update worker: ${_extractError(e)}');
    }
  }

  @override
  Future<void> deleteWorker(String workerId) async {
    throw UnimplementedError(
        'Use deleteWorkerForBusiness(businessId, workerId) instead');
  }

  Future<void> deleteWorkerForBusiness(
      String businessId, String workerId) async {
    try {
      await _http.delete(
        '/workers/$businessId/$workerId',
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to delete worker: ${_extractError(e)}');
    }
  }

  @override
  Future<List<dynamic>> getWorkers(String businessId) async {
    try {
      final response = await _http.get(
        '/workers/$businessId',
        options: Options(headers: _headers),
      );
      return ((response.data['data'] as List?) ?? [])
          .whereType<Map>()
          .map((row) => _normalizeWorker(Map<String, dynamic>.from(row)))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to fetch workers: ${_extractError(e)}');
    }
  }

  @override
  Future<dynamic> getWorkerById(String workerId) async {
    try {
      final businesses = await _supabase
          .from('business_members')
          .select('business_id')
          .eq('user_id', _supabase.auth.currentUser?.id ?? '')
          .eq('is_active', true);

      for (final b in businesses) {
        try {
          final response = await _http.get(
            '/workers/${b['business_id']}/$workerId',
            options: Options(headers: _headers),
          );
          if (response.statusCode == 200) {
            return _normalizeWorker(Map<String, dynamic>.from(response.data as Map));
          }
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> recordAttendance(
      String workerId, Map<String, dynamic> attendanceData) async {
    try {
      await _supabase.from('attendance').insert({
        'worker_id': workerId,
        'business_id': attendanceData['businessId'],
        'timestamp': attendanceData['timestamp'] ?? DateTime.now().toIso8601String(),
        'status': attendanceData['status'],
        'verify_mode': attendanceData['verifyMode'],
      });
    } catch (e) {
      throw Exception('Failed to record attendance: $e');
    }
  }

  @override
  Future<List<dynamic>> getWorkerAttendance(String workerId) async {
    try {
      final result = await _supabase
          .from('attendance')
          .select('*')
          .eq('worker_id', workerId)
          .order('timestamp', ascending: false)
          .limit(100);
      return result;
    } catch (e) {
      throw Exception('Failed to fetch attendance: $e');
    }
  }

  Map<String, dynamic> _buildPayload(Map<String, dynamic> data) {
    final permissions = data['permissions'] ?? data['customPermissions'] ?? {};
    return {
      'email': data['email'],
      'full_name': data['fullName'] ?? data['full_name'] ?? data['name'],
      'phone': data['phone'] ?? data['phoneNumber'],
      'role': data['role'] ?? 'staff',
      'store_id': data['storeId'] ?? data['store_id'],
      'permissions': permissions,
      'pin': data['pin'],
      if (data.containsKey('isActive') || data.containsKey('is_active'))
        'is_active': data['isActive'] ?? data['is_active'],
    };
  }

  Map<String, dynamic> _normalizeWorker(Map<String, dynamic> row) {
    final worker = Map<String, dynamic>.from(row);
    final role = (worker['role'] ?? 'staff').toString();
    final rawPermissions = worker['permissions'];
    final permissionList = rawPermissions is Map
        ? rawPermissions.entries
            .where((entry) => entry.value == true)
            .map((entry) => entry.key.toString())
            .toList()
        : rawPermissions is List
            ? rawPermissions
                .map((entry) => entry.toString())
                .where((entry) => entry.trim().isNotEmpty)
                .toList()
            : <String>[];

    worker['fullName'] ??= worker['full_name'] ?? worker['name'];
    worker['name'] ??= worker['fullName'] ?? worker['full_name'];
    worker['phoneNumber'] ??= worker['phone'];
    worker['businessId'] ??= worker['business_id'];
    worker['storeId'] ??= worker['store_id'];
    worker['isActive'] ??= worker['is_active'] != false;
    worker['createdAt'] ??= worker['created_at'];
    worker['updatedAt'] ??= worker['updated_at'];
    worker['roles'] ??= [role];
    worker['permissions'] = permissionList;
    worker['customPermissions'] ??= permissionList;
    return worker;
  }
}

