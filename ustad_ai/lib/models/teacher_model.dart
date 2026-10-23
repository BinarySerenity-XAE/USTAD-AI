// lib/models/teacher_model.dart

class TeacherModel {
  final int? id;
  final int userId;
  final String name;
  final List<String> assignedClasses;
  final List<String> subjects;

  TeacherModel({
    this.id,
    required this.userId,
    required this.name,
    List<String>? assignedClasses,
    List<String>? subjects,
  })  : assignedClasses = assignedClasses ?? [],
        subjects = subjects ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'assigned_classes': assignedClasses.join(','),
        'subjects': subjects.join(','),
      };

  factory TeacherModel.fromMap(Map<String, dynamic> map) => TeacherModel(
        id: map['id'],
        userId: map['user_id'],
        name: map['name'],
        assignedClasses: map['assigned_classes'] != null && (map['assigned_classes'] as String).isNotEmpty
            ? (map['assigned_classes'] as String).split(',')
            : [],
        subjects: map['subjects'] != null && (map['subjects'] as String).isNotEmpty
            ? (map['subjects'] as String).split(',')
            : [],
      );

  TeacherModel copyWith({
    List<String>? assignedClasses,
    List<String>? subjects,
    String? name,
  }) =>
      TeacherModel(
        id: id,
        userId: userId,
        name: name ?? this.name,
        assignedClasses: assignedClasses ?? this.assignedClasses,
        subjects: subjects ?? this.subjects,
      );
}
