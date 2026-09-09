import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/api_client.dart';
import 'core/constants.dart';
import 'core/transitions.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/project/project_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MarksheetAnalyticsApp());
}

class MarksheetAnalyticsApp extends StatelessWidget {
  const MarksheetAnalyticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marksheet Analytics',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/':
            page = const SplashScreen();
            break;
          case '/login':
            page = const LoginScreen();
            break;
          case '/signup':
            page = const SignupScreen();
            break;
          case '/home':
            page = const HomeScreen();
            break;
          case '/project':
            final args = settings.arguments as String?;
            page = ProjectScreen(projectId: args ?? '');
            break;
          default:
            page = const Scaffold(body: Center(child: Text('Page not found')));
        }
        return SlideFadeTransition(page: page);
      },
    );
  }
}
