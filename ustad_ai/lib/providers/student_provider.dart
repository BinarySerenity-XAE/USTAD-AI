// lib/providers/student_provider.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/student_model.dart';

class StudentProvider extends ChangeNotifier {
  List<StudentModel> _students = [];
  List<FamilyModel> _families = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedClass = '';

  List<StudentModel> get students => _filtered;
  List<FamilyModel> get families => _families;
  bool get isLoading => _isLoading;
  String get selectedClass => _selectedClass;

  List<StudentModel> get _filtered {
    var list = _students;
    if (_selectedClass.isNotEmpty) {
      list = list.where((s) => s.className == _selectedClass).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) =>
          s.name.toLowerCase().contains(q) ||
          s.fatherName.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void setSearchQuery(String q) { _searchQuery = q; notifyListeners(); }
  void setClassFilter(String cls) { _selectedClass = cls; notifyListeners(); }
  void clearFilters() { _searchQuery = ''; _selectedClass = ''; notifyListeners(); }

  Future<void> loadStudents() async {
    _isLoading = true;
    notifyListeners();
    _students = await DatabaseHelper.instance.getAllStudents();
    _families = await DatabaseHelper.instance.getAllFamilies();
    _isLoading = false;
    notifyListeners();
  }

  Future<List<StudentModel>> getStudentsByClass(String className) async {
    return await DatabaseHelper.instance.getStudentsByClass(className);
  }

  Future<int> addStudent(StudentModel student) async {
    final id = await DatabaseHelper.instance.insertStudent(student);
    _students.add(student.copyWith(id: id));
    notifyListeners();
    return id;
  }

  Future<void> updateStudent(StudentModel student) async {
    await DatabaseHelper.instance.updateStudent(student);
    final idx = _students.indexWhere((s) => s.id == student.id);
    if (idx >= 0) _students[idx] = student;
    notifyListeners();
  }

  Future<void> deleteStudent(int id) async {
    await DatabaseHelper.instance.deleteStudent(id);
    _students.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<int> addFamily(FamilyModel family) async {
    final id = await DatabaseHelper.instance.insertFamily(family);
    _families.add(FamilyModel(
      id: id, parentName: family.parentName,
      phone: family.phone, whatsappNumber: family.whatsappNumber,
    ));
    notifyListeners();
    return id;
  }

  Future<int> bulkImport(List<StudentModel> students) async {
    final count = await DatabaseHelper.instance.bulkInsertStudents(students);
    await loadStudents();
    return count;
  }

  FamilyModel? getFamilyById(int id) {
    try { return _families.firstWhere((f) => f.id == id); } catch (_) { return null; }
  }

  List<StudentModel> getStudentsInFamily(int familyId) =>
      _students.where((s) => s.familyId == familyId).toList();
}
