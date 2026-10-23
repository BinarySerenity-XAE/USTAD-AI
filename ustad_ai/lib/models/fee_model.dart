// lib/models/fee_model.dart

class FeeTypeModel {
  final int? id;
  final String name; // Tuition, Transport, Uniform, Miscellaneous
  final double defaultAmount;
  final String? className; // null = applies to all classes

  static const List<String> defaultTypes = [
    'Tuition Fee',
    'Transport Fee',
    'Uniform Fee',
    'Miscellaneous',
  ];

  static const List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  FeeTypeModel({
    this.id,
    required this.name,
    required this.defaultAmount,
    this.className,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'default_amount': defaultAmount,
        'class_name': className,
      };

  factory FeeTypeModel.fromMap(Map<String, dynamic> map) => FeeTypeModel(
        id: map['id'],
        name: map['name'],
        defaultAmount: (map['default_amount'] as num).toDouble(),
        className: map['class_name'],
      );
}

class FeeRecordModel {
  final int? id;
  final int studentId;
  final int feeTypeId;
  final String feeTypeName;
  final int month; // 1-12
  final int year;
  final double amount;
  final bool isPaid;
  final DateTime? paidDate;
  final String? notes;

  FeeRecordModel({
    this.id,
    required this.studentId,
    required this.feeTypeId,
    required this.feeTypeName,
    required this.month,
    required this.year,
    required this.amount,
    this.isPaid = false,
    this.paidDate,
    this.notes,
  });

  String get monthName => FeeTypeModel.months[month - 1];

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'fee_type_id': feeTypeId,
        'fee_type_name': feeTypeName,
        'month': month,
        'year': year,
        'amount': amount,
        'is_paid': isPaid ? 1 : 0,
        'paid_date': paidDate?.toIso8601String(),
        'notes': notes,
      };

  factory FeeRecordModel.fromMap(Map<String, dynamic> map) => FeeRecordModel(
        id: map['id'],
        studentId: map['student_id'],
        feeTypeId: map['fee_type_id'],
        feeTypeName: map['fee_type_name'] ?? '',
        month: map['month'],
        year: map['year'],
        amount: (map['amount'] as num).toDouble(),
        isPaid: (map['is_paid'] ?? 0) == 1,
        paidDate: map['paid_date'] != null ? DateTime.parse(map['paid_date']) : null,
        notes: map['notes'],
      );

  FeeRecordModel copyWith({bool? isPaid, DateTime? paidDate, double? amount}) =>
      FeeRecordModel(
        id: id,
        studentId: studentId,
        feeTypeId: feeTypeId,
        feeTypeName: feeTypeName,
        month: month,
        year: year,
        amount: amount ?? this.amount,
        isPaid: isPaid ?? this.isPaid,
        paidDate: paidDate ?? this.paidDate,
        notes: notes,
      );
}
