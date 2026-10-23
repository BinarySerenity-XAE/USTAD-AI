// lib/providers/marks_provider.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/marks_model.dart';

class MarksProvider extends ChangeNotifier {
  List<SubjectModel> _subjects = [];
  bool _isLoading = false;

  List<SubjectModel> get subjects => _subjects;
  bool get isLoading => _isLoading;

  Future<void> loadSubjects(String className) async {
    _isLoading = true;
    notifyListeners();
    _subjects = await DatabaseHelper.instance.getSubjectsByClass(className);
    _isLoading = false;
    notifyListeners();
  }

  Future<List<SubjectModel>> getSubjectsByClass(String className) async {
    return await DatabaseHelper.instance.getSubjectsByClass(className);
  }

  Future<void> addSubject(SubjectModel subject) async {
    final id = await DatabaseHelper.instance.insertSubject(subject);
    _subjects.add(SubjectModel(
      id: id, name: subject.name, className: subject.className,
      teacherId: subject.teacherId,
    ));
    notifyListeners();
  }

  Future<void> deleteSubject(int id) async {
    await DatabaseHelper.instance.deleteSubject(id);
    _subjects.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<List<MarksModel>> getStudentMarks(int studentId) =>
      DatabaseHelper.instance.getMarksByStudent(studentId);

  Future<List<Map<String, dynamic>>> getSubjectMarksForClass(
          String className, int subjectId, String term) =>
      DatabaseHelper.instance.getSubjectMarksForClass(className, subjectId, term);

  Future<void> saveMarks(MarksModel marks) async {
    await DatabaseHelper.instance.insertMarks(marks);
    notifyListeners();
  }

  Map<String, double> calculateTermAverages(List<MarksModel> marks) {
    final Map<String, List<double>> termScores = {};
    for (final m in marks) {
      termScores.putIfAbsent(m.term, () => []).add(m.percentage);
    }
    final Map<String, double> averages = {};
    for (final entry in termScores.entries) {
      averages[entry.key] = entry.value.reduce((a, b) => a + b) / entry.value.length;
    }
    // Annual average
    if (averages.isNotEmpty) {
      averages['Annual'] =
          averages.values.reduce((a, b) => a + b) / averages.length;
    }
    return averages;
  }

  Future<List<Map<String, dynamic>>> getClassRanking(
      String className, String term) async {
    final students = await DatabaseHelper.instance.getStudentsByClass(className);
    final List<Map<String, dynamic>> ranking = [];
    for (final s in students) {
      final marks = await DatabaseHelper.instance.getMarksByStudent(s.id!);
      final termMarks = (term == 'Annual (Combined)' || term == 'All Terms')
          ? marks
          : marks.where((m) => m.term == term).toList();
      if (termMarks.isEmpty) continue;
      final avg = termMarks.map((m) => m.percentage).reduce((a, b) => a + b) /
          termMarks.length;
      ranking.add({'student': s, 'average': avg, 'marks': termMarks});
    }
    ranking.sort((a, b) => (b['average'] as double).compareTo(a['average'] as double));
    return ranking;
  }
}
