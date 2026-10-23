// lib/screens/admin/staff_attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../database/db_helper.dart';
import '../../models/teacher_model.dart';
import '../../models/student_model.dart';
import '../../models/attendance_model.dart';
import 'student_management_screen.dart';

class StaffAttendanceScreen extends StatefulWidget {
  final int initialTab;
  final String? initialClass;
  const StaffAttendanceScreen({super.key, this.initialTab = 0, this.initialClass});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  DateTime _selectedDate = DateTime.now();

  // Teacher Attendance State
  List<TeacherModel> _teachers = [];
  Map<int, String> _teacherStatuses = {}; // teacherId -> 'present' | 'absent' | 'late' | 'leave'
  bool _isLoadingTeachers = true;
  bool _isSavingTeachers = false;

  // Student Attendance State
  List<String> _classes = StudentModel.classes;
  String _selectedClass = 'Class 1';
  Map<String, int> _classStudentCounts = {};
  List<StudentModel> _students = [];
  Map<int, String> _studentStatuses = {}; // studentId -> status
  bool _isLoadingStudents = true;
  bool _isSavingStudents = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
    if (widget.initialClass != null && StudentModel.classes.contains(widget.initialClass)) {
      _selectedClass = widget.initialClass!;
    }
    _loadTeacherData();
    _loadClassData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoadingTeachers = true);
    final teachers = await DatabaseHelper.instance.getAllTeachers();
    final savedStatuses = await DatabaseHelper.instance.getTeacherAttendanceByDate(_selectedDate);

    final statuses = <int, String>{};
    for (final t in teachers) {
      final tid = t.id ?? t.userId;
      statuses[tid] = savedStatuses[tid] ?? 'present';
    }

    if (mounted) {
      setState(() {
        _teachers = teachers;
        _teacherStatuses = statuses;
        _isLoadingTeachers = false;
      });
    }
  }

  Future<void> _loadClassData() async {
    final counts = await DatabaseHelper.instance.getClassWiseStudentCount();
    if (mounted) {
      setState(() {
        _classStudentCounts = counts;
        _classes = StudentModel.classes;
        if (!_classes.contains(_selectedClass)) {
          _selectedClass = _classes.first;
        }
      });
    }
    await _loadStudentsForClass();
  }

  Future<void> _loadStudentsForClass() async {
    setState(() => _isLoadingStudents = true);
    final students = await DatabaseHelper.instance.getStudentsByClass(_selectedClass);
    final savedRecords = await DatabaseHelper.instance
        .getAttendanceByClassAndDate(_selectedClass, _selectedDate);

    final statuses = <int, String>{};
    for (final s in students) {
      final existing = savedRecords.where((r) => r.studentId == s.id);
      if (existing.isNotEmpty) {
        statuses[s.id!] = existing.first.status;
      } else {
        statuses[s.id!] = AttendanceModel.present;
      }
    }

    if (mounted) {
      setState(() {
        _students = students;
        _studentStatuses = statuses;
        _isLoadingStudents = false;
      });
    }
  }

  Future<void> _saveTeacherAttendance() async {
    setState(() => _isSavingTeachers = true);
    for (final t in _teachers) {
      final tid = t.id ?? t.userId;
      final status = _teacherStatuses[tid] ?? 'present';
      await DatabaseHelper.instance.insertOrUpdateTeacherAttendance(
        teacherId: tid,
        teacherName: t.name,
        date: _selectedDate,
        status: status,
      );
    }
    setState(() => _isSavingTeachers = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Teacher attendance saved for ${DateFormat('d MMM yyyy').format(_selectedDate)}!')),
      );
    }
  }

  Future<void> _saveStudentAttendance() async {
    setState(() => _isSavingStudents = true);
    for (final s in _students) {
      final status = _studentStatuses[s.id!] ?? AttendanceModel.present;
      await DatabaseHelper.instance.insertOrUpdateAttendance(AttendanceModel(
        studentId: s.id!,
        studentName: s.name,
        date: _selectedDate,
        status: status,
      ));
    }
    setState(() => _isSavingStudents = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ $_selectedClass student attendance saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Attendance Management'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.accentGold,
          indicatorWeight: 3,
          labelColor: AppTheme.white,
          unselectedLabelColor: AppTheme.white.withValues(alpha: 0.7),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Teachers Staff (11)', icon: Icon(Icons.badge_rounded, size: 18)),
            Tab(text: 'Students (by Class)', icon: Icon(Icons.school_rounded, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildTeachersTab(),
          _buildStudentsTab(),
        ],
      ),
    );
  }

  // ── Teachers Tab ───────────────────────────────────────────────────────────

  Widget _buildTeachersTab() {
    if (_isLoadingTeachers) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = _teachers.length;
    final present = _teacherStatuses.values.where((s) => s == 'present').length;
    final absent = _teacherStatuses.values.where((s) => s == 'absent').length;
    final lateCount = _teacherStatuses.values.where((s) => s == 'late').length;

    return Column(
      children: [
        // Date & Quick Actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2027),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadTeacherData();
                        _loadStudentsForClass();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.navyBlue),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEE, d MMM yyyy').format(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyBlue, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('All Present'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      setState(() {
                        for (final t in _teachers) {
                          final tid = t.id ?? t.userId;
                          _teacherStatuses[tid] = 'present';
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Summary Chips
              Row(
                children: [
                  _SummaryBadge('$present Present', AppTheme.successGreen),
                  const SizedBox(width: 8),
                  _SummaryBadge('$absent Absent', AppTheme.errorRed),
                  const SizedBox(width: 8),
                  _SummaryBadge('$lateCount Late', AppTheme.warningOrange),
                  const Spacer(),
                  Text(
                    total > 0 ? '${((present / total) * 100).toStringAsFixed(0)}% Rate' : '0%',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Teacher List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _teachers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final teacher = _teachers[idx];
              final tid = teacher.id ?? teacher.userId;
              final status = _teacherStatuses[tid] ?? 'present';
              return _StaffAttendanceCard(
                name: teacher.name,
                subtitle: teacher.subjects.isNotEmpty ? teacher.subjects.join(', ') : 'Faculty Member',
                status: status,
                onStatusChanged: (newStatus) {
                  setState(() => _teacherStatuses[tid] = newStatus);
                },
              );
            },
          ),
        ),

        // Save Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: _isSavingTeachers
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: Text(_isSavingTeachers ? 'Saving...' : 'Save Teacher Attendance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navyBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSavingTeachers ? null : _saveTeacherAttendance,
            ),
          ),
        ),
      ],
    );
  }

  // ── Students Tab ───────────────────────────────────────────────────────────

  Widget _buildStudentsTab() {
    final total = _students.length;
    final present = _studentStatuses.values.where((s) => s == AttendanceModel.present).length;
    final absent = _studentStatuses.values.where((s) => s == AttendanceModel.absent).length;
    final lateCount = _studentStatuses.values.where((s) => s == AttendanceModel.late).length;
    final leaveCount = _studentStatuses.values.where((s) => s == AttendanceModel.leave).length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          color: AppTheme.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Picker & Quick Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2027),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadStudentsForClass();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.navyBlue),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEE, d MMM yyyy').format(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyBlue, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.done_all_rounded, size: 15),
                        label: const Text('All Present', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _students.isEmpty ? null : () {
                          setState(() {
                            for (final s in _students) {
                              _studentStatuses[s.id!] = AttendanceModel.present;
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.close_rounded, size: 15, color: AppTheme.errorRed),
                        label: const Text('All Absent', style: TextStyle(fontSize: 12, color: AppTheme.errorRed)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.errorRed),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _students.isEmpty ? null : () {
                          setState(() {
                            for (final s in _students) {
                              _studentStatuses[s.id!] = AttendanceModel.absent;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Class Header & Dropdown Shortcut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_rounded, size: 18, color: AppTheme.navyBlue),
                      const SizedBox(width: 6),
                      Text(
                        'Select Class to Mark:',
                        style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.bold, color: AppTheme.navyBlue, fontSize: 13),
                      ),
                    ],
                  ),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.offWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedClass,
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyBlue, fontSize: 12),
                        items: _classes.map((c) {
                          final count = _classStudentCounts[c] ?? 0;
                          return DropdownMenuItem(
                            value: c,
                            child: Text('$c ($count)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null && val != _selectedClass) {
                            setState(() => _selectedClass = val);
                            _loadStudentsForClass();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Horizontal Class Chips Bar (Class 1 to Class 10)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _classes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final c = _classes[idx];
                    final isSelected = c == _selectedClass;
                    final count = _classStudentCounts[c] ?? 0;
                    return GestureDetector(
                      onTap: () {
                        if (_selectedClass != c) {
                          setState(() => _selectedClass = c);
                          _loadStudentsForClass();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppTheme.navyGradient : null,
                          color: isSelected ? null : AppTheme.offWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.accentGold : AppTheme.borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: AppTheme.navyBlue.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.accentGold),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              c,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.accentGold.withValues(alpha: 0.3) : AppTheme.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppTheme.accentGold : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Summary Badges
              Row(
                children: [
                  _SummaryBadge('$present Present', AppTheme.successGreen),
                  const SizedBox(width: 6),
                  _SummaryBadge('$absent Absent', AppTheme.errorRed),
                  const SizedBox(width: 6),
                  _SummaryBadge('$lateCount Late', AppTheme.warningOrange),
                  const SizedBox(width: 6),
                  _SummaryBadge('$leaveCount Leave', AppTheme.navyBlue),
                  const Spacer(),
                  Text(
                    total > 0 ? '${(((present + lateCount) / total) * 100).toStringAsFixed(0)}% Rate' : '0%',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoadingStudents
              ? const Center(child: CircularProgressIndicator())
              : _students.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: AppTheme.lightBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.school_outlined, size: 48, color: AppTheme.navyBlue),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No students enrolled in $_selectedClass yet',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.navyBlue),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Select another class above or add new students to this class.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.person_add_rounded, size: 18),
                              label: Text('Add Students to $_selectedClass'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.navyBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const StudentManagementScreen()),
                                ).then((_) => _loadClassData());
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final student = _students[idx];
                        final status = _studentStatuses[student.id!] ?? AttendanceModel.present;
                        return _StaffAttendanceCard(
                          name: student.name,
                          subtitle: 'Roll #${student.rollNumber ?? student.id} • Father: ${student.fatherName}',
                          status: status,
                          onStatusChanged: (newStatus) {
                            setState(() => _studentStatuses[student.id!] = newStatus);
                          },
                        );
                      },
                    ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: _isSavingStudents
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: Text(_isSavingStudents ? 'Saving...' : 'Save $_selectedClass Attendance ($total students)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navyBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (_isSavingStudents || _students.isEmpty) ? null : _saveStudentAttendance,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _StaffAttendanceCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String status;
  final ValueChanged<String> onStatusChanged;

  const _StaffAttendanceCard({
    required this.name,
    required this.subtitle,
    required this.status,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadowList,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.lightBlue,
            radius: 20,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status Chips: P, A, L, LV
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusPill('P', AppTheme.successGreen, status == 'present', () => onStatusChanged('present')),
              const SizedBox(width: 4),
              _StatusPill('A', AppTheme.errorRed, status == 'absent', () => onStatusChanged('absent')),
              const SizedBox(width: 4),
              _StatusPill('L', AppTheme.warningOrange, status == 'late', () => onStatusChanged('late')),
              const SizedBox(width: 4),
              _StatusPill('LV', AppTheme.navyBlue, status == 'leave', () => onStatusChanged('leave')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusPill(this.label, this.color, this.isSelected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
