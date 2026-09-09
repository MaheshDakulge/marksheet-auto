import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ApiClient {
  static SharedPreferences? _prefs;
  static final Dio dio = _createDio();

  // FIX 1: cache SharedPreferences — avoid calling getInstance() on every single request
  static Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Dio _createDio() {
    final d = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      // FIX 2: was 30s — too short. Gemini OCR takes 60–120s per page
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(minutes: 2),
      headers: {'Content-Type': 'application/json'},
    ));
    _setupInterceptors(d);
    return d;
  }

  static void _setupInterceptors(Dio d) {
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final prefs = await _sharedPrefs;
          final token = prefs.getString(AppConstants.tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {
          // Storage failure — continue request without token
        }
        return handler.next(options);
      },

      // FIX 3: added response logging for debug builds
      onResponse: (response, handler) {
        if (kDebugMode) {
          print('[API] ${response.requestOptions.method} '
              '${response.requestOptions.path} → ${response.statusCode}');
        }
        return handler.next(response);
      },

      onError: (DioException e, handler) async {
        if (kDebugMode) {
          print('[API] ERROR ${e.requestOptions.method} '
              '${e.requestOptions.path} → '
              '${e.response?.statusCode} ${e.message}');
        }

        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          try {
            final prefs = await _sharedPrefs;
            await prefs.remove(AppConstants.tokenKey);
            await prefs.remove(AppConstants.teacherKey);
            _prefs = null; // reset cache so next login gets fresh instance
          } catch (_) {}

          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
        return handler.next(e);
      },
    ));
  }
}
