// lib/models/attendance_model.dart

class AttendanceModel {
  final int? id;
  final int studentId;
  final String studentName;
  final DateTime date;
  final String status; // 'present', 'absent', 'late', 'leave'

  static const String present = 'present';
  static const String absent = 'absent';
  static const String late = 'late';
  static const String leave = 'leave';

  AttendanceModel({
    this.id,
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.status,
  });

  String get statusDisplay {
    switch (status) {
      case present:
        return '✅ Present';
      case absent:
        return '❌ Absent';
      case late:
        return '⏰ Late';
      case leave:
        return '📋 Leave';
      default:
        return status;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'student_name': studentName,
        'date': date.toIso8601String().substring(0, 10),
        'status': status,
      };

  factory AttendanceModel.fromMap(Map<String, dynamic> map) => AttendanceModel(
        id: map['id'],
        studentId: map['student_id'],
        studentName: map['student_name'] ?? '',
        date: DateTime.parse(map['date']),
        status: map['status'],
      );
}
