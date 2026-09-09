import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/teacher.dart';
import '../core/constants.dart';

class AuthService {
  static Future<Teacher?> login(String email, String password) async {
    final response = await ApiClient.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    
    final data = response.data;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, data['access_token']);
    
    final teacher = Teacher.fromJson(data['teacher']);
    await prefs.setString(AppConstants.teacherKey, jsonEncode(teacher.toJson()));
    
    return teacher;
  }

  static Future<Teacher?> register(String name, String email, String password) async {
    final response = await ApiClient.dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });
    
    final data = response.data;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, data['access_token']);
    
    final teacher = Teacher.fromJson(data['teacher']);
    await prefs.setString(AppConstants.teacherKey, jsonEncode(teacher.toJson()));
    
    return teacher;
  }

  static Future<Teacher> updateProfile(String name, String? college, String? department) async {
    final response = await ApiClient.dio.put('/auth/profile', data: {
      'name': name,
      'college': college,
      'department': department,
    });
    
    final updatedTeacher = Teacher.fromJson(response.data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.teacherKey, jsonEncode(updatedTeacher.toJson()));
    return updatedTeacher;
  }

  static Future<Teacher?> getCurrentTeacher() async {
    final prefs = await SharedPreferences.getInstance();
    final teacherStr = prefs.getString(AppConstants.teacherKey);
    if (teacherStr != null) {
      return Teacher.fromJson(jsonDecode(teacherStr));
    }
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.teacherKey);
  }
}
