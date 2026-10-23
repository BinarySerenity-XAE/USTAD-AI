// lib/screens/teacher/class_marks_screen.dart
import 'package:flutter/material.dart';
import '../admin/marks_admin_screen.dart';

class ClassMarksScreen extends StatelessWidget {
  final String? initialClass;
  final String? initialSubject;
  const ClassMarksScreen({super.key, this.initialClass, this.initialSubject});

  @override
  Widget build(BuildContext context) {
    return MarksAdminScreen(
      initialClass: initialClass,
      initialSubject: initialSubject,
    );
  }
}
