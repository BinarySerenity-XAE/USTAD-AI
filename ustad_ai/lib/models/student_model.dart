// lib/models/student_model.dart

class StudentModel {
  final int? id;
  final String name;
  final String fatherName;
  final String className; // PG, Nursery, KG, 1-10
  final String section;
  final String? phone;
  final String? whatsappNumber;
  final int? familyId;
  final String? rollNumber;
  final DateTime enrolledAt;
  final bool isActive;

  static const List<String> classes = [
    'PG',
    'Nursery',
    'KG',
    'Class 1',
    'Class 2',
    'Class 3',
    'Class 4',
    'Class 5',
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
  ];

  static const List<String> sections = ['A', 'B', 'C', 'D'];

  StudentModel({
    this.id,
    required this.name,
    required this.fatherName,
    required this.className,
    this.section = 'A',
    this.phone,
    this.whatsappNumber,
    this.familyId,
    this.rollNumber,
    DateTime? enrolledAt,
    this.isActive = true,
  }) : enrolledAt = enrolledAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'father_name': fatherName,
        'class_name': className,
        'section': section,
        'phone': phone,
        'whatsapp_number': whatsappNumber,
        'family_id': familyId,
        'roll_number': rollNumber,
        'enrolled_at': enrolledAt.toIso8601String(),
        'is_active': isActive ? 1 : 0,
      };

  factory StudentModel.fromMap(Map<String, dynamic> map) => StudentModel(
        id: map['id'],
        name: map['name'],
        fatherName: map['father_name'],
        className: map['class_name'],
        section: map['section'] ?? 'A',
        phone: map['phone'],
        whatsappNumber: map['whatsapp_number'],
        familyId: map['family_id'],
        rollNumber: map['roll_number'],
        enrolledAt: DateTime.parse(map['enrolled_at']),
        isActive: (map['is_active'] ?? 1) == 1,
      );

  StudentModel copyWith({
    int? id,
    String? name,
    String? fatherName,
    String? className,
    String? section,
    String? phone,
    String? whatsappNumber,
    int? familyId,
    String? rollNumber,
    bool? isActive,
  }) =>
      StudentModel(
        id: id ?? this.id,
        name: name ?? this.name,
        fatherName: fatherName ?? this.fatherName,
        className: className ?? this.className,
        section: section ?? this.section,
        phone: phone ?? this.phone,
        whatsappNumber: whatsappNumber ?? this.whatsappNumber,
        familyId: familyId ?? this.familyId,
        rollNumber: rollNumber ?? this.rollNumber,
        enrolledAt: enrolledAt,
        isActive: isActive ?? this.isActive,
      );

  @override
  String toString() => name;
}

class FamilyModel {
  final int? id;
  final String parentName;
  final String? phone;
  final String? whatsappNumber;
  final String? address;

  FamilyModel({
    this.id,
    required this.parentName,
    this.phone,
    this.whatsappNumber,
    this.address,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'parent_name': parentName,
        'phone': phone,
        'whatsapp_number': whatsappNumber,
        'address': address,
      };

  factory FamilyModel.fromMap(Map<String, dynamic> map) => FamilyModel(
        id: map['id'],
        parentName: map['parent_name'],
        phone: map['phone'],
        whatsappNumber: map['whatsapp_number'],
        address: map['address'],
      );
}
