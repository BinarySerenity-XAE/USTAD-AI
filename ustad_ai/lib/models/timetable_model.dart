// lib/models/timetable_model.dart

class TimetableSlotModel {
  final int? id;
  final String className;
  final String dayOfWeek; // 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  final int periodNumber; // 1 to 8
  final String startTime; // '08:00 AM'
  final String endTime;   // '08:45 AM'
  final String subjectName;
  final String teacherName;
  final String? roomNumber;

  static const List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  TimetableSlotModel({
    this.id,
    required this.className,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    required this.teacherName,
    this.roomNumber,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'class_name': className,
        'day_of_week': dayOfWeek,
        'period_number': periodNumber,
        'start_time': startTime,
        'end_time': endTime,
        'subject_name': subjectName,
        'teacher_name': teacherName,
        'room_number': roomNumber,
      };

  factory TimetableSlotModel.fromMap(Map<String, dynamic> map) =>
      TimetableSlotModel(
        id: map['id'],
        className: map['class_name'],
        dayOfWeek: map['day_of_week'],
        periodNumber: map['period_number'],
        startTime: map['start_time'] ?? '',
        endTime: map['end_time'] ?? '',
        subjectName: map['subject_name'] ?? '',
        teacherName: map['teacher_name'] ?? '',
        roomNumber: map['room_number'],
      );
}

class WeeklyDiaryModel {
  final int? id;
  final String className;
  final String subjectName;
  final String weekStartDate; // 'YYYY-MM-DD'
  final String weekEndDate;   // 'YYYY-MM-DD'
  final String dayPlansJson;  // JSON array of daily topics & homework
  final String? parentSummaryUrdu;
  final DateTime createdAt;

  WeeklyDiaryModel({
    this.id,
    required this.className,
    required this.subjectName,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.dayPlansJson,
    this.parentSummaryUrdu,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'class_name': className,
        'subject_name': subjectName,
        'week_start_date': weekStartDate,
        'week_end_date': weekEndDate,
        'day_plans_json': dayPlansJson,
        'parent_summary_urdu': parentSummaryUrdu,
        'created_at': createdAt.toIso8601String(),
      };

  factory WeeklyDiaryModel.fromMap(Map<String, dynamic> map) =>
      WeeklyDiaryModel(
        id: map['id'],
        className: map['class_name'],
        subjectName: map['subject_name'] ?? '',
        weekStartDate: map['week_start_date'],
        weekEndDate: map['week_end_date'],
        dayPlansJson: map['day_plans_json'] ?? '[]',
        parentSummaryUrdu: map['parent_summary_urdu'],
        createdAt: DateTime.parse(map['created_at']),
      );
}
