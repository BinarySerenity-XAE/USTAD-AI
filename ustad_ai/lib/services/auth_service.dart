// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';

class AuthService {
  static const String _keyUserId = 'logged_user_id';
  static const String _keyUserRole = 'logged_user_role';
  static const String _keyUserName = 'logged_user_name';
  static const String _keyUserClass = 'logged_user_class';

  static AuthService? _instance;
  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }
  AuthService._();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  Future<UserModel?> login(String username, String password) async {
    final user = await DatabaseHelper.instance.getUserByUsername(username.toLowerCase().trim());
    if (user == null) return null;
    final hash = DatabaseHelper.instance.hashPassword(password);
    if (user.passwordHash != hash) return null;

    String? assignedClass;
    if (user.role == 'teacher') {
      final teacher = await DatabaseHelper.instance.getTeacherByUserId(user.id!);
      if (teacher == null) {
        // Teacher profile was removed/deleted; reject login
        return null;
      }
      if (teacher.assignedClasses.isNotEmpty) {
        assignedClass = teacher.assignedClasses.first;
      } else {
        assignedClass = DatabaseHelper.defaultTeacherAssignments[user.username.toLowerCase()] ?? 'Class 5';
      }
    }

    _currentUser = user.copyWith(assignedClass: assignedClass);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, user.id!);
    await prefs.setString(_keyUserRole, user.role);
    await prefs.setString(_keyUserName, user.name);
    if (assignedClass != null) {
      await prefs.setString(_keyUserClass, assignedClass);
    }
    return _currentUser;
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserClass);
  }

  Future<UserModel?> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyUserId);
    if (userId == null) return null;
    final users = await DatabaseHelper.instance.getAllUsers();
    try {
      final user = users.firstWhere((u) => u.id == userId);
      if (user.role == 'teacher') {
        final teacher = await DatabaseHelper.instance.getTeacherByUserId(user.id!);
        if (teacher == null) {
          await logout();
          return null;
        }
      }
      final savedClass = prefs.getString(_keyUserClass);
      _currentUser = user.copyWith(
        assignedClass: savedClass ?? DatabaseHelper.defaultTeacherAssignments[user.username.toLowerCase()] ?? 'Class 5',
      );
      return _currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isAdmin => _currentUser?.role == 'admin' || _currentUser?.role == 'principal';
  bool get isTeacher => _currentUser?.role == 'teacher';
  bool get isPrincipal => _currentUser?.role == 'principal';
}
