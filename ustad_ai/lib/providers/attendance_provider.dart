// lib/providers/attendance_provider.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/attendance_model.dart';

class AttendanceProvider extends ChangeNotifier {
  List<AttendanceModel> _todayAttendance = [];
  bool _isLoading = false;

  List<AttendanceModel> get todayAttendance => _todayAttendance;
  bool get isLoading => _isLoading;

  Future<void> loadAttendance(String className, DateTime date) async {
    _isLoading = true;
    notifyListeners();
    _todayAttendance = await DatabaseHelper.instance.getAttendanceByClassAndDate(className, date);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAttendance(AttendanceModel attendance) async {
    await DatabaseHelper.instance.insertOrUpdateAttendance(attendance);
    final idx = _todayAttendance.indexWhere((a) => a.studentId == attendance.studentId);
    if (idx >= 0) {
      _todayAttendance[idx] = attendance;
    } else {
      _todayAttendance.add(attendance);
    }
    notifyListeners();
  }

  Future<List<AttendanceModel>> getStudentMonthlyAttendance(int studentId, int month, int year) =>
      DatabaseHelper.instance.getStudentAttendance(studentId, month, year);

  String? getStatusForStudent(int studentId) {
    try {
      return _todayAttendance.firstWhere((a) => a.studentId == studentId).status;
    } catch (_) {
      return null;
    }
  }

  Future<double> getAttendanceRate() => DatabaseHelper.instance.getAttendanceRate();
}
