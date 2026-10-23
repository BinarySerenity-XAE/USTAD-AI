// lib/app.dart
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin/admin_home.dart';
import 'screens/teacher/teacher_home.dart';

class UstadAiApp extends StatelessWidget {
  const UstadAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ustad-AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scrollBehavior: const NoScrollbarBehavior(),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/admin': (_) => const AdminHome(),
        '/teacher': (_) => const TeacherHome(),
      },
    );
  }
}
