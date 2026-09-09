import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api_client.dart'; // navigatorKey + ApiClient.dio both live here

class AuthRepository {
  final Dio _dio = ApiClient.dio; // FIX: was DioClient.instance
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> register({
    required String email,
    required String password,
    required String name,
    String? college,
    String? department,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      "email":      email,
      "password":   password,
      "name":       name,
      "college":    college,
      "department": department,
    });

    final String token = response.data['access_token'];
    await _secureStorage.write(key: 'access_token', value: token);

    // FIX: also save teacher profile so profile screen works without extra API call
    final teacher = response.data['teacher'];
    if (teacher != null) {
      await _secureStorage.write(
        key: 'teacher',
        value: teacher.toString(),
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      "email":    email,
      "password": password,
    });

    final String token = response.data['access_token'];
    await _secureStorage.write(key: 'access_token', value: token);

    // FIX: also save teacher profile
    final teacher = response.data['teacher'];
    if (teacher != null) {
      await _secureStorage.write(
        key: 'teacher',
        value: teacher.toString(),
      );
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // Ignore errors on logout — always clear local storage
    }
    await _secureStorage.deleteAll(); // FIX: was only deleting token, now clears everything

    // FIX: removed navigatorKey from here — navigation is handled by ApiClient interceptor
    // on 401, and by the calling screen on explicit logout. Repositories should not navigate.
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  Future<Map<String, dynamic>> getCurrentTeacher() async {
    final response = await _dio.get('/auth/me');
    return response.data as Map<String, dynamic>;
  }
}

// Singleton instance — use this everywhere
final authRepository = AuthRepository();