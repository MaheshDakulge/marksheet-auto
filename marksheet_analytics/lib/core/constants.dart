import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';

class AppConstants {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    if (kIsWeb) {
      // In Web production, default to live Render backend API
      return 'https://marksheet-analytics-api.onrender.com';
    }
    // Local testing IP for mobile devices / emulators
    return 'http://172.19.244.12:8000'; 
  }
  
  static const String tokenKey = 'auth_token';
  static const String teacherKey = 'teacher';
}

class AppColors {
  static const Color primary = Color(0xFF2563EB); // Modern Blue
  static const Color secondary = Color(0xFF3B82F6);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
}

class AppTextStyles {
  static const TextStyle h1 = TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static const TextStyle h2 = TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const TextStyle body = TextStyle(fontSize: 16, color: AppColors.textPrimary);
  static const TextStyle caption = TextStyle(fontSize: 14, color: AppColors.textSecondary);
}
