import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import '../core/config/supabase_config.dart';

/// Thrown when the backend returns a non-2xx response.
class ManagecareApiException implements Exception {
  final int statusCode;
  final String message;

  ManagecareApiException(this.statusCode, this.message);

  @override
  String toString() => 'ManagecareApiException($statusCode): $message';
}

/// Thin REST client for the custom ManageCare backend's `/api/*` routes.
///
/// Every business-scoped provider needs the same handful of things: attach
/// the current session's bearer token, build `/api/<resource>/<businessId>`
/// URLs, decode JSON, and turn `{error: "..."}` responses into a catchable
/// exception. This centralizes that instead of every provider re-implementing
/// its own HTTP plumbing.
class ManagecareApiClient {
  static final ManagecareApiClient instance = ManagecareApiClient._();
  ManagecareApiClient._();

  static const String _baseUrl = SupabaseConfig.url;

  String? get _accessToken =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanQuery = query?.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    )?..removeWhere((key, value) => value.isEmpty);
    return Uri.parse('$_baseUrl$path').replace(
      queryParameters: cleanQuery?.isNotEmpty == true ? cleanQuery : null,
    );
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String message = 'Request failed (${response.statusCode})';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] != null) {
        message = body['error'].toString();
      }
    } catch (_) {
      // Non-JSON error body - keep the generic message.
    }
    throw ManagecareApiException(response.statusCode, message);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final response = await http.get(_uri(path, query), headers: _headers);
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final response = await http.post(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final response = await http.put(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(response);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final response = await http.patch(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(_uri(path), headers: _headers);
    return _decode(response);
  }
}
