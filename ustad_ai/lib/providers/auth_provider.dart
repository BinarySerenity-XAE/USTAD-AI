// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user ?? AuthService.instance.currentUser;
  UserModel? get currentUser => _user ?? AuthService.instance.currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => user != null;
  bool get isAdmin => AuthService.instance.isAdmin || (user?.role == 'admin' || user?.role == 'principal');
  bool get isTeacher => AuthService.instance.isTeacher || (user?.role == 'teacher');

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final user = await AuthService.instance.login(username, password);
      if (user != null) {
        _user = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Invalid username or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.instance.logout();
    _user = null;
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final user = await AuthService.instance.tryAutoLogin();
    if (user != null) {
      _user = user;
      notifyListeners();
      return true;
    }
    return false;
  }
}
