// lib/models/user_model.dart

class UserModel {
  final int? id;
  final String name;
  final String username;
  final String passwordHash;
  final String role; // 'principal', 'admin', 'teacher'
  final String? phone;
  final String? assignedClass;
  final String? assignedSubject;
  final DateTime createdAt;

  UserModel({
    this.id,
    required this.name,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.phone,
    this.assignedClass,
    this.assignedSubject,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'username': username,
        'password_hash': passwordHash,
        'role': role,
        'phone': phone,
        'assigned_class': assignedClass,
        'assigned_subject': assignedSubject,
        'created_at': createdAt.toIso8601String(),
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'],
        name: map['name'],
        username: map['username'],
        passwordHash: map['password_hash'],
        role: map['role'],
        phone: map['phone'],
        assignedClass: map['assigned_class'],
        assignedSubject: map['assigned_subject'],
        createdAt: DateTime.parse(map['created_at']),
      );

  UserModel copyWith({
    int? id,
    String? name,
    String? username,
    String? passwordHash,
    String? role,
    String? phone,
    String? assignedClass,
    String? assignedSubject,
  }) =>
      UserModel(
        id: id ?? this.id,
        name: name ?? this.name,
        username: username ?? this.username,
        passwordHash: passwordHash ?? this.passwordHash,
        role: role ?? this.role,
        phone: phone ?? this.phone,
        assignedClass: assignedClass ?? this.assignedClass,
        assignedSubject: assignedSubject ?? this.assignedSubject,
        createdAt: createdAt,
      );
}
