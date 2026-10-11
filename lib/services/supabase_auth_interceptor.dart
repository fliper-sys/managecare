import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

/// Keeps backend requests authenticated with the current Supabase session.
/// A rejected request is retried at most once after refreshing the session.
class SupabaseSessionTokens {
  static final Map<SupabaseClient, Future<Session?>> _refreshInFlight = {};

  final SupabaseClient _supabase;

  SupabaseSessionTokens(this._supabase);

  Future<Session?> _refreshSession() async {
    final active = _refreshInFlight[_supabase];
    if (active != null) return active;

    final refresh =
        _supabase.auth.refreshSession().then((result) => result.session);
    _refreshInFlight[_supabase] = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight[_supabase], refresh)) {
        _refreshInFlight.remove(_supabase);
      }
    }
  }

  Future<String?> accessToken({bool forceRefresh = false}) async {
    var session = _supabase.auth.currentSession;
    if (session == null) return null;

    final expiresAt = session.expiresAt;
    final wasExpired = session.isExpired;
    final expiresSoon = expiresAt != null &&
        expiresAt <= DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
    if (forceRefresh || wasExpired || expiresSoon) {
      try {
        session = await _refreshSession();
      } catch (_) {
        // A transient refresh failure should not invalidate a still-live token.
        if (wasExpired || forceRefresh) rethrow;
      }
    }
    return session?.accessToken;
  }
}

class SupabaseAuthInterceptor extends Interceptor {
  SupabaseAuthInterceptor(this._dio, SupabaseClient supabase)
      : _tokens = SupabaseSessionTokens(supabase);

  static const _retriedKey = 'supabaseAuthRetried';
  final Dio _dio;
  final SupabaseSessionTokens _tokens;
  final Uri _backendUri = Uri.parse(SupabaseConfig.url);

  bool _isBackendRequest(RequestOptions options) =>
      options.uri.origin == _backendUri.origin;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isBackendRequest(options)) return handler.next(options);
    try {
      final token = await _tokens.accessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      } else {
        options.headers.remove('Authorization');
      }
      handler.next(options);
    } catch (error) {
      handler.reject(DioException(
        requestOptions: options,
        error: error,
        type: DioExceptionType.unknown,
      ));
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        !_isBackendRequest(request) ||
        request.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    try {
      final token = await _tokens.accessToken(forceRefresh: true);
      if (token == null || token.isEmpty) return handler.next(err);

      final data = request.data;
      final retryOptions = request.copyWith(
        data: data is FormData ? data.clone() : data,
        headers: {
          ...request.headers,
          'Authorization': 'Bearer $token',
        },
        extra: {
          ...request.extra,
          _retriedKey: true,
        },
      );
      final response = await _dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }
}

void installSupabaseAuthInterceptor(Dio dio, SupabaseClient supabase) {
  if (dio.interceptors
      .any((interceptor) => interceptor is SupabaseAuthInterceptor)) {
    return;
  }
  dio.interceptors.add(SupabaseAuthInterceptor(dio, supabase));
}
