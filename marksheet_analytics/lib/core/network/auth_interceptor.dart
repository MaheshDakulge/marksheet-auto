import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api_client.dart';

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _secureStorage;

  AuthInterceptor({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // ── Attach token to every request ─────────────────────────────────────────
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _secureStorage.read(key: 'access_token');
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // If secure storage fails, continue without token
    }
    handler.next(options);
  }

  // ── Handle errors globally ─────────────────────────────────────────────────
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid — clear all auth data and go to login
      try {
        await _secureStorage.deleteAll();
      } catch (_) {}

      // Redirect to login, clearing the entire navigation stack
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }

    // Always forward the error so the calling screen can handle it too
    handler.next(err);
  }

  // ── Log responses in debug mode ────────────────────────────────────────────
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    assert(() {
      debugPrint('[API] ${response.requestOptions.method} '
          '${response.requestOptions.path} → ${response.statusCode}');
      return true;
    }());
    handler.next(response);
  }
}
