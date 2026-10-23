// lib/models/marks_model.dart

class SubjectModel {
  final int? id;
  final String name;
  final String className;
  final int? teacherId;

  SubjectModel({
    this.id,
    required this.name,
    required this.className,
    this.teacherId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'class_name': className,
        'teacher_id': teacherId,
      };

  factory SubjectModel.fromMap(Map<String, dynamic> map) => SubjectModel(
        id: map['id'],
        name: map['name'],
        className: map['class_name'],
        teacherId: map['teacher_id'],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          className == other.className;

  @override
  int get hashCode => Object.hash(id, name, className);
}

class MarksModel {
  final int? id;
  final int studentId;
  final int subjectId;
  final String subjectName;
  final String term; // 'Term 1', 'Term 2', 'Term 3'
  final double score;
  final double maxScore;
  final String? remarks;
  final DateTime recordedAt;

  static const List<String> terms = ['Term 1', 'Term 2', 'Term 3', 'Annual (Combined)'];

  MarksModel({
    this.id,
    required this.studentId,
    required this.subjectId,
    required this.subjectName,
    required this.term,
    required this.score,
    required this.maxScore,
    this.remarks,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();

  double get percentage => maxScore > 0 ? (score / maxScore) * 100 : 0;

  String get grade {
    final p = percentage;
    if (p >= 90) return 'A+';
    if (p >= 80) return 'A';
    if (p >= 70) return 'B';
    if (p >= 60) return 'C';
    if (p >= 50) return 'D';
    return 'F';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'subject_id': subjectId,
        'subject_name': subjectName,
        'term': term,
        'score': score,
        'max_score': maxScore,
        'remarks': remarks,
        'recorded_at': recordedAt.toIso8601String(),
      };

  factory MarksModel.fromMap(Map<String, dynamic> map) => MarksModel(
        id: map['id'],
        studentId: map['student_id'],
        subjectId: map['subject_id'],
        subjectName: map['subject_name'] ?? '',
        term: map['term'],
        score: (map['score'] as num).toDouble(),
        maxScore: (map['max_score'] as num).toDouble(),
        remarks: map['remarks'],
        recordedAt: DateTime.parse(map['recorded_at']),
      );
}

class OralExamResult {
  final int? id;
  final int studentId;
  final String studentName;
  final String question;
  final String answerText;
  final double score;
  final String feedback;
  final String feedbackUrdu;
  final DateTime recordedAt;

  OralExamResult({
    this.id,
    required this.studentId,
    required this.studentName,
    required this.question,
    required this.answerText,
    required this.score,
    required this.feedback,
    required this.feedbackUrdu,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'student_name': studentName,
        'question': question,
        'answer_text': answerText,
        'score': score,
        'feedback': feedback,
        'feedback_urdu': feedbackUrdu,
        'recorded_at': recordedAt.toIso8601String(),
      };

  factory OralExamResult.fromMap(Map<String, dynamic> map) => OralExamResult(
        id: map['id'],
        studentId: map['student_id'],
        studentName: map['student_name'] ?? '',
        question: map['question'],
        answerText: map['answer_text'],
        score: (map['score'] as num).toDouble(),
        feedback: map['feedback'],
        feedbackUrdu: map['feedback_urdu'] ?? '',
        recordedAt: DateTime.parse(map['recorded_at']),
      );
}
