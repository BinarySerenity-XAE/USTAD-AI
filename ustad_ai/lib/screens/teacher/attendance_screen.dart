// lib/screens/teacher/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/student_model.dart';
import '../../models/attendance_model.dart';
import '../../database/db_helper.dart';
import '../../services/auth_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _selectedClass = 'Class 1';
  DateTime _selectedDate = DateTime.now();
  List<StudentModel> _students = [];
  Map<int, String> _statuses = {};
  String _myTeacherStatus = 'present';
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = AuthService.instance;
    if (auth.isTeacher && auth.currentUser?.assignedClass != null) {
      _selectedClass = auth.currentUser!.assignedClass!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final auth = AuthService.instance;
    if (auth.isTeacher && auth.currentUser?.assignedClass != null) {
      _selectedClass = auth.currentUser!.assignedClass!;
      final myTeacher = await DatabaseHelper.instance.getTeacherByName(auth.currentUser?.name ?? '');
      if (myTeacher?.id != null) {
        final attMap = await DatabaseHelper.instance.getTeacherAttendanceByDate(_selectedDate);
        if (attMap.containsKey(myTeacher!.id)) {
          _myTeacherStatus = attMap[myTeacher.id]!;
        }
      }
    }
    _students = await DatabaseHelper.instance.getStudentsByClass(_selectedClass);
    final existing = await DatabaseHelper.instance
        .getAttendanceByClassAndDate(_selectedClass, _selectedDate);
    _statuses = {for (var a in existing) a.studentId: a.status};
    // Default all to present if no attendance yet
    for (final s in _students) {
      _statuses.putIfAbsent(s.id!, () => AttendanceModel.present);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateMyTeacherStatus(String status) async {
    setState(() => _myTeacherStatus = status);
    final auth = AuthService.instance;
    final myTeacher = await DatabaseHelper.instance.getTeacherByName(auth.currentUser?.name ?? '');
    if (myTeacher?.id != null) {
      await DatabaseHelper.instance.insertOrUpdateTeacherAttendance(
        teacherId: myTeacher!.id!,
        teacherName: myTeacher.name,
        date: _selectedDate,
        status: status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Check-in recorded: ${status.toUpperCase()}'), duration: const Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isSaving = true);
    for (final s in _students) {
      final status = _statuses[s.id!] ?? AttendanceModel.present;
      await DatabaseHelper.instance.insertOrUpdateAttendance(AttendanceModel(
        studentId: s.id!,
        studentName: s.name,
        date: _selectedDate,
        status: status,
      ));
    }
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Attendance saved for ${DateFormat('d MMM').format(_selectedDate)}')));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final isTeacher = auth.isTeacher;
    final teacherClass = auth.currentUser?.assignedClass ?? 'Class 5';
    final availableClasses = isTeacher ? [teacherClass] : StudentModel.classes;

    if (isTeacher && _selectedClass != teacherClass) {
      _selectedClass = teacherClass;
    }

    final present = _statuses.values.where((s) => s == AttendanceModel.present).length;
    final absent = _statuses.values.where((s) => s == AttendanceModel.absent).length;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(isTeacher ? 'My Attendance & Class' : 'Class Attendance'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveAttendance,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white)))
                : const Icon(Icons.save_rounded, color: AppTheme.white, size: 20),
            label: const Text('Save', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Teacher Self-Attendance Card (if logged in as Teacher)
          if (isTeacher)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppTheme.navyGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadowList,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('👩‍🏫', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(
                            'My Attendance (${auth.currentUser?.name ?? "Teacher"})',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _myTeacherStatus == 'present'
                              ? AppTheme.successGreen
                              : (_myTeacherStatus == 'late'
                                  ? AppTheme.warningOrange
                                  : AppTheme.errorRed),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _myTeacherStatus.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _teacherStatusBtn('present', 'Present [P]', AppTheme.successGreen),
                      const SizedBox(width: 6),
                      _teacherStatusBtn('late', 'Late [L]', AppTheme.warningOrange),
                      const SizedBox(width: 6),
                      _teacherStatusBtn('absent', 'Absent [A]', AppTheme.errorRed),
                      const SizedBox(width: 6),
                      _teacherStatusBtn('leave', 'Leave [LV]', Colors.blueAccent),
                    ],
                  ),
                ],
              ),
            ),

          // Filters
          Container(
            color: AppTheme.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedClass,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isTeacher ? 'Assigned Class' : 'Class',
                      isDense: true,
                      helperText: isTeacher ? '🔒 Designated Class Only' : null,
                      helperStyle: const TextStyle(color: AppTheme.navyBlue, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    items: availableClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: isTeacher
                        ? null
                        : (v) {
                            setState(() => _selectedClass = v!);
                            _loadData();
                          },
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.navyBlue),
                        const SizedBox(width: 6),
                        Text(DateFormat('d MMM').format(_selectedDate),
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.navyBlue, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Summary bar
          Container(
            color: AppTheme.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _SummaryChip('${_students.length} Total', AppTheme.navyBlue),
                const SizedBox(width: 8),
                _SummaryChip('$present Present', AppTheme.successGreen),
                const SizedBox(width: 8),
                _SummaryChip('$absent Absent', AppTheme.errorRed),
              ],
            ),
          ),

          // Quick actions
          Container(
            color: AppTheme.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(child: OutlinedButton(
                  onPressed: () { setState(() { for (final s in _students) _statuses[s.id!] = AttendanceModel.present; }); },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.successGreen, side: const BorderSide(color: AppTheme.successGreen),
                    minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('All Present', style: TextStyle(fontSize: 12)),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(
                  onPressed: () { setState(() { for (final s in _students) _statuses[s.id!] = AttendanceModel.absent; }); },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed, side: const BorderSide(color: AppTheme.errorRed),
                    minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('All Absent', style: TextStyle(fontSize: 12)),
                )),
              ],
            ),
          ),

          const Divider(height: 1),

          // Student list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? const Center(child: Text('No students in this class'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _students.length,
                        itemBuilder: (_, i) {
                          final s = _students[i];
                          final status = _statuses[s.id!] ?? AttendanceModel.present;
                          return _AttendanceRow(
                            student: s,
                            status: status,
                            onStatusChanged: (newStatus) => setState(() => _statuses[s.id!] = newStatus),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _teacherStatusBtn(String status, String label, Color color) {
    final isSelected = _myTeacherStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => _updateMyTeacherStatus(status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 10.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final StudentModel student;
  final String status;
  final void Function(String) onStatusChanged;

  const _AttendanceRow({
    required this.student,
    required this.status,
    required this.onStatusChanged,
  });

  Color get _color {
    switch (status) {
      case AttendanceModel.present: return AppTheme.successGreen;
      case AttendanceModel.absent: return AppTheme.errorRed;
      case AttendanceModel.late: return AppTheme.warningOrange;
      case AttendanceModel.leave: return AppTheme.navyBlue;
      default: return AppTheme.textSecondary;
    }
  }

  String get _emoji {
    switch (status) {
      case AttendanceModel.present: return '✅';
      case AttendanceModel.absent: return '❌';
      case AttendanceModel.late: return '⏰';
      case AttendanceModel.leave: return '📋';
      default: return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _color, width: 4)),
        boxShadow: AppTheme.cardShadowList,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(_emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: AppTheme.labelMedium),
                  Text(student.className, style: AppTheme.bodySmall),
                ],
              ),
            ),
            // Status buttons
            _StatusBtn('P', AppTheme.successGreen, status == AttendanceModel.present,
                () => onStatusChanged(AttendanceModel.present)),
            const SizedBox(width: 6),
            _StatusBtn('A', AppTheme.errorRed, status == AttendanceModel.absent,
                () => onStatusChanged(AttendanceModel.absent)),
            const SizedBox(width: 6),
            _StatusBtn('L', AppTheme.warningOrange, status == AttendanceModel.late,
                () => onStatusChanged(AttendanceModel.late)),
            const SizedBox(width: 6),
            _StatusBtn('LV', AppTheme.navyBlue, status == AttendanceModel.leave,
                () => onStatusChanged(AttendanceModel.leave)),
          ],
        ),
      ),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StatusBtn(this.label, this.color, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: selected ? AppTheme.white : color,
                  fontWeight: FontWeight.w800,
                  fontSize: 11)),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: AppTheme.bodySmall.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
