// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/teacher_model.dart';

class SettingsProvider extends ChangeNotifier {
  String _schoolName = 'Sublime Grammar School';
  List<TeacherModel> _teachers = [];
  bool _isLoading = false;

  String get schoolName => _schoolName;
  List<TeacherModel> get teachers => _teachers;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _schoolName = await DatabaseHelper.instance.getSetting('school_name') ?? 'Sublime Grammar School';
    _teachers = await DatabaseHelper.instance.getAllTeachers();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateTeacher(TeacherModel teacher) async {
    await DatabaseHelper.instance.updateTeacher(teacher);
    final idx = _teachers.indexWhere((t) => t.id == teacher.id);
    if (idx >= 0) _teachers[idx] = teacher;
    notifyListeners();
  }

  Future<void> reloadTeachers() async {
    _teachers = await DatabaseHelper.instance.getAllTeachers();
    notifyListeners();
  }

  Future<void> deleteTeacher(int id) async {
    await DatabaseHelper.instance.deleteTeacher(id);
    _teachers.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}
