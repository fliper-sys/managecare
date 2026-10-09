import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdministrativeRepositorySupabase {
  AdministrativeRepositorySupabase({Dio? http, SupabaseClient? supabase})
      : _http = http ??
            Dio(BaseOptions(
              baseUrl: '${SupabaseConfig.url}/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            )),
        _supabase = supabase ?? Supabase.instance.client;

  final Dio _http;
  final SupabaseClient _supabase;

  Options get _options => Options(headers: {
        'Authorization':
            'Bearer ${_supabase.auth.currentSession?.accessToken ?? ''}',
        'Content-Type': 'application/json',
      });

  Future<List<Map<String, dynamic>>> getTasks(String businessId) =>
      _getList('/administrative/$businessId/tasks');

  Future<List<Map<String, dynamic>>> getTasksForClient(
    String businessId,
    String clientId,
  ) =>
      _getList('/administrative/$businessId/tasks', query: {'clientId': clientId});

  Future<List<Map<String, dynamic>>> getFolders(
    String businessId,
    String clientId,
  ) =>
      _getList('/administrative/$businessId/clients/$clientId/folders');

  Future<Map<String, dynamic>> createFolder(
    String businessId,
    String clientId,
    String name,
  ) async {
    final response = await _http.post(
      '/administrative/$businessId/clients/$clientId/folders',
      data: {'name': name},
      options: _options,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> getDocuments(
    String businessId,
    String clientId, {
    String? query,
    String? folderId,
    String? mimeType,
  }) =>
      _getList(
        '/administrative/$businessId/clients/$clientId/documents',
        query: {
          if (query != null && query.isNotEmpty) 'q': query,
          if (folderId != null) 'folderId': folderId,
          if (mimeType != null) 'mimeType': mimeType,
        },
      );

  Future<Map<String, dynamic>> uploadFile(
    String businessId, {
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final data = FormData.fromMap({
      'folder': 'administrative',
      'file': MultipartFile.fromBytes(bytes, filename: fileName, contentType: DioMediaType.parse(mimeType)),
    });
    final response = await _http.post('/upload/$businessId', data: data,
        options: Options(headers: {'Authorization': _options.headers?['Authorization']}));
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> createDocument(
    String businessId,
    String clientId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _http.post(
      '/administrative/$businessId/clients/$clientId/documents',
      data: payload,
      options: _options,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> getDocumentVersions(
    String businessId,
    String documentId,
  ) =>
      _getList('/administrative/$businessId/documents/$documentId/versions');

  Future<Map<String, dynamic>> getDocumentDownload(
    String businessId,
    String documentId,
  ) async {
    final response = await _http.get(
      '/administrative/$businessId/documents/$documentId/download',
      options: _options,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> createDocumentVersion(
    String businessId,
    String documentId,
    Map<String, dynamic> payload,
  ) =>
      _http.post(
        '/administrative/$businessId/documents/$documentId/versions',
        data: payload,
        options: _options,
      );

  Future<List<Map<String, dynamic>>> getObligations(String businessId) =>
      _getList('/administrative/$businessId/obligations');

  Future<List<Map<String, dynamic>>> getClients(
    String businessId, {
    String? query,
    bool? active,
  }) =>
      _getList(
        '/administrative/$businessId/clients',
        query: {
          if (query != null && query.trim().isNotEmpty) 'q': query,
          if (active != null) 'active': active.toString(),
        },
      );

  Future<List<Map<String, dynamic>>> getCalendar(
    String businessId, {
    required DateTime from,
    required DateTime to,
  }) =>
      _getList(
        '/administrative/$businessId/calendar',
        query: {'from': from.toIso8601String(), 'to': to.toIso8601String()},
      );

  Future<List<Map<String, dynamic>>> getStaffing(String businessId) =>
      _getList('/administrative/$businessId/staffing');

  Future<void> assignWorkerToClient(
    String businessId,
    String clientId,
    String workerId,
  ) => _http.put(
        '/administrative/$businessId/clients/$clientId/workers/$workerId',
        options: _options,
      );

  Future<void> unassignWorkerFromClient(
    String businessId,
    String clientId,
    String workerId,
  ) => _http.delete(
        '/administrative/$businessId/clients/$clientId/workers/$workerId',
        options: _options,
      );

  Future<List<Map<String, dynamic>>> getActivity(String businessId) =>
      _getList('/administrative/$businessId/activity');

  Future<List<Map<String, dynamic>>> getFinancialEntries(
    String businessId, {
    String? type,
    String? clientId,
  }) =>
      _getList(
        '/administrative/$businessId/financial-entries',
        query: {
          if (type != null) 'type': type,
          if (clientId != null) 'clientId': clientId,
        },
      );

  Future<List<Map<String, dynamic>>> getInvoices(String businessId) =>
      _getList('/administrative/$businessId/invoices');

  Future<Map<String, dynamic>> getInvoice(
    String businessId,
    String invoiceId,
  ) async {
    final response = await _http.get(
      '/administrative/$businessId/invoices/$invoiceId',
      options: _options,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> emailInvoice(
    String businessId,
    String invoiceId,
    String email,
  ) =>
      _http.post(
        '/administrative/$businessId/invoices/$invoiceId/email',
        data: {'email': email},
        options: _options,
      );

  Future<void> createCalendarEvent(
    String businessId,
    Map<String, dynamic> payload,
  ) =>
      _http.post(
        '/administrative/$businessId/calendar-events',
        data: payload,
        options: _options,
      );

  Future<Map<String, dynamic>> createClient(
    String businessId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _http.post(
      '/administrative/$businessId/clients',
      data: payload,
      options: _options,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateClient(
    String businessId,
    String clientId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _http.patch(
      '/administrative/$businessId/clients/$clientId',
      data: payload,
      options: _options,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> createInvoice(
    String businessId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _http.post(
      '/administrative/$businessId/invoices',
      data: payload,
      options: _options,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> sendInvoice(String businessId, String invoiceId) =>
      _http.post('/administrative/$businessId/invoices/$invoiceId/send', options: _options);

  Future<void> voidInvoice(String businessId, String invoiceId) =>
      _http.post('/administrative/$businessId/invoices/$invoiceId/void', options: _options);

  Future<void> recordInvoicePayment(
    String businessId,
    String invoiceId,
    double amount,
  ) =>
      _http.post(
        '/administrative/$businessId/invoices/$invoiceId/payments',
        data: {'amount': amount},
        options: _options,
      );

  Future<void> createFinancialEntry(
    String businessId,
    Map<String, dynamic> payload,
  ) =>
      _http.post(
        '/administrative/$businessId/financial-entries',
        data: payload,
        options: _options,
      );

  Future<void> updateFinancialEntry(
    String businessId,
    String entryId,
    Map<String, dynamic> payload,
  ) =>
      _http.patch(
        '/administrative/$businessId/financial-entries/$entryId',
        data: payload,
        options: _options,
      );

  Future<void> updateTaskStatus(
    String businessId,
    String taskId, {
    required String status,
    String? reviewAction,
  }) async {
    await _http.patch(
      '/administrative/$businessId/tasks/$taskId/status',
      data: {
        'status': status,
        if (reviewAction != null) 'review_action': reviewAction,
      },
      options: _options,
    );
  }

  Future<Map<String, dynamic>> createTask(
    String businessId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _http.post(
      '/administrative/$businessId/tasks',
      data: payload,
      options: _options,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> getTaskComments(
    String businessId,
    String taskId,
  ) =>
      _getList('/administrative/$businessId/tasks/$taskId/comments');

  Future<void> addTaskComment(
    String businessId,
    String taskId,
    String body,
  ) =>
      _http.post(
        '/administrative/$businessId/tasks/$taskId/comments',
        data: {'body': body},
        options: _options,
      );

  Future<void> completeObligation(
    String businessId,
    String obligationId,
  ) async {
    await _http.post(
      '/administrative/$businessId/obligations/$obligationId/complete',
      options: _options,
    );
  }

  Future<List<Map<String, dynamic>>> _getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _http.get(
      path,
      queryParameters: query,
      options: _options,
    );
    final data = response.data;
    if (data is! Map || data['data'] is! List) return const [];
    return (data['data'] as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}
