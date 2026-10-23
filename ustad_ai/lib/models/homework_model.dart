// lib/models/homework_model.dart

class HomeworkModel {
  final int? id;
  final String className;
  final String subjectName;
  final int? teacherId;
  final String title;
  final String description;
  final DateTime assignedDate;
  final DateTime dueDate;
  final bool isBroadcasted;
  final String? imagePath;
  final String? instructionsImagePath;
  final int? targetStudentId;

  HomeworkModel({
    this.id,
    required this.className,
    required this.subjectName,
    this.teacherId,
    required this.title,
    required this.description,
    DateTime? assignedDate,
    required this.dueDate,
    this.isBroadcasted = false,
    this.imagePath,
    this.instructionsImagePath,
    this.targetStudentId,
  }) : assignedDate = assignedDate ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'class_name': className,
        'subject_name': subjectName,
        'teacher_id': teacherId,
        'title': title,
        'description': description,
        'assigned_date': assignedDate.toIso8601String().substring(0, 10),
        'due_date': dueDate.toIso8601String().substring(0, 10),
        'is_broadcasted': isBroadcasted ? 1 : 0,
        'image_path': imagePath,
        'instructions_image_path': instructionsImagePath,
        'target_student_id': targetStudentId,
      };

  factory HomeworkModel.fromMap(Map<String, dynamic> map) => HomeworkModel(
        id: map['id'],
        className: map['class_name'],
        subjectName: map['subject_name'] ?? '',
        teacherId: map['teacher_id'],
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        assignedDate: DateTime.parse(map['assigned_date']),
        dueDate: DateTime.parse(map['due_date']),
        isBroadcasted: (map['is_broadcasted'] ?? 0) == 1,
        imagePath: map['image_path'],
        instructionsImagePath: map['instructions_image_path'],
        targetStudentId: map['target_student_id'],
      );

  HomeworkModel copyWith({
    int? id,
    String? className,
    String? subjectName,
    int? teacherId,
    String? title,
    String? description,
    DateTime? assignedDate,
    DateTime? dueDate,
    bool? isBroadcasted,
    String? imagePath,
    String? instructionsImagePath,
    int? targetStudentId,
  }) =>
      HomeworkModel(
        id: id ?? this.id,
        className: className ?? this.className,
        subjectName: subjectName ?? this.subjectName,
        teacherId: teacherId ?? this.teacherId,
        title: title ?? this.title,
        description: description ?? this.description,
        assignedDate: assignedDate ?? this.assignedDate,
        dueDate: dueDate ?? this.dueDate,
        isBroadcasted: isBroadcasted ?? this.isBroadcasted,
        imagePath: imagePath ?? this.imagePath,
        instructionsImagePath: instructionsImagePath ?? this.instructionsImagePath,
        targetStudentId: targetStudentId ?? this.targetStudentId,
      );
}

class HomeworkCheckModel {
  final int? id;
  final int homeworkId;
  final int studentId;
  final String studentName;
  final bool isCompleted;
  final DateTime checkedAt;
  final String? remarks;

  HomeworkCheckModel({
    this.id,
    required this.homeworkId,
    required this.studentId,
    required this.studentName,
    this.isCompleted = true,
    DateTime? checkedAt,
    this.remarks,
  }) : checkedAt = checkedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'homework_id': homeworkId,
        'student_id': studentId,
        'student_name': studentName,
        'is_completed': isCompleted ? 1 : 0,
        'checked_at': checkedAt.toIso8601String(),
        'remarks': remarks,
      };

  factory HomeworkCheckModel.fromMap(Map<String, dynamic> map) => HomeworkCheckModel(
        id: map['id'],
        homeworkId: map['homework_id'],
        studentId: map['student_id'],
        studentName: map['student_name'] ?? '',
        isCompleted: (map['is_completed'] ?? 1) == 1,
        checkedAt: DateTime.parse(map['checked_at']),
        remarks: map['remarks'],
      );
}
