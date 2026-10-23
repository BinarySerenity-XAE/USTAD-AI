// lib/screens/admin/marks_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/student_provider.dart';
import '../../providers/marks_provider.dart';
import '../../models/student_model.dart';
import '../../models/marks_model.dart';
import '../../database/db_helper.dart';
import '../../services/auth_service.dart';
import '../../models/teacher_model.dart';

class MarksAdminScreen extends StatefulWidget {
  final String? initialClass;
  final String? initialSubject;
  const MarksAdminScreen({super.key, this.initialClass, this.initialSubject});

  @override
  State<MarksAdminScreen> createState() => _MarksAdminScreenState();
}

class _MarksAdminScreenState extends State<MarksAdminScreen> {
  String _selectedClass = 'Class 1';
  String _selectedTerm = 'Term 1';
  String _assessmentCategory = 'Exams'; // 'Exams' vs 'Class Tests'

  final List<String> _examTerms = ['Term 1', 'Term 2', 'Term 3', 'Annual (Combined)'];
  List<String> _classTests = [
    'Monthly Test (September)',
    'Monthly Test (October)',
    'Monthly Test (November)',
    'Monthly Test (December)',
    'Weekly / Chapter Test',
    '➕ Add Custom Test...',
  ];

  List<SubjectModel> _subjects = [];
  SubjectModel? _selectedSubject;
  List<StudentModel> _students = [];
  List<Map<String, dynamic>> _ranking = [];
  bool _loading = false;

  bool _isTeacher = false;
  String _teacherName = '';
  List<String> _teacherAllowedClasses = [];
  List<String> _teacherAllowedSubjects = [];
  TeacherModel? _teacherModel;

  @override
  void initState() {
    super.initState();
    final auth = AuthService.instance;
    _isTeacher = auth.isTeacher;
    if (_isTeacher && auth.currentUser != null) {
      _teacherName = auth.currentUser!.name;
    }
    if (widget.initialClass != null) {
      _selectedClass = widget.initialClass!;
    }
    _loadCustomTests();
    _initTeacherAndLoad();
  }

  Future<void> _loadCustomTests() async {
    final tests = await DatabaseHelper.instance.getCustomTests();
    if (mounted) {
      setState(() {
        _classTests = [
          'Monthly Test (September)',
          'Monthly Test (October)',
          'Monthly Test (November)',
          'Monthly Test (December)',
          'Weekly / Chapter Test',
          ...tests.where((t) => ![
            'Monthly Test (September)',
            'Monthly Test (October)',
            'Monthly Test (November)',
            'Monthly Test (December)',
            'Weekly / Chapter Test',
          ].contains(t)),
          '➕ Add Custom Test...',
        ];
      });
    }
  }

  Future<void> _initTeacherAndLoad() async {
    if (_isTeacher) {
      final clean = _teacherName.toLowerCase().replaceAll('sir', '').replaceAll('miss', '').replaceAll('teacher', '').trim();
      final teachers = await DatabaseHelper.instance.getAllTeachers();
      _teacherModel = teachers.where((t) => t.name.toLowerCase().contains(clean)).firstOrNull;

      // Determine classes
      if (_teacherModel != null && _teacherModel!.assignedClasses.isNotEmpty) {
        _teacherAllowedClasses = _teacherModel!.assignedClasses;
      } else {
        final lower = _teacherName.toLowerCase().trim();
        if (lower.contains('haroon')) {
          _teacherAllowedClasses = ['Class 9'];
        } else if (lower.contains('ramzan')) {
          _teacherAllowedClasses = ['Class 10'];
        } else if (lower.contains('arisha') || lower.contains('areesha')) {
          _teacherAllowedClasses = ['Class 8'];
        } else if (lower.contains('aleeza')) {
          _teacherAllowedClasses = ['Nursery', 'KG', 'PG'];
        } else if (lower.contains('munza') || lower.contains('maham') || lower.contains('nisa') ||
            lower.contains('lubaba') || lower.contains('zainab') || lower.contains('kainat') ||
            lower.contains('laika')) {
          _teacherAllowedClasses = ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7'];
        } else {
          final assigned = AuthService.instance.currentUser?.assignedClass;
          if (assigned != null && assigned.isNotEmpty) {
            _teacherAllowedClasses = assigned.split(',').map((e) => e.trim()).where((c) => StudentModel.classes.contains(c)).toList();
          }
        }
      }
      if (_teacherAllowedClasses.isEmpty) {
        _teacherAllowedClasses = ['Class 1'];
      }
      if (!_teacherAllowedClasses.contains(_selectedClass)) {
        _selectedClass = _teacherAllowedClasses.first;
      }

      // Determine subjects
      if (_teacherModel != null && _teacherModel!.subjects.isNotEmpty && !_teacherModel!.subjects.first.contains('All Subjects')) {
        _teacherAllowedSubjects = _teacherModel!.subjects;
      } else {
        final lower = _teacherName.toLowerCase().trim();
        if (lower.contains('munza')) _teacherAllowedSubjects = ['English'];
        else if (lower.contains('maham')) _teacherAllowedSubjects = ['Urdu'];
        else if (lower.contains('nisa')) _teacherAllowedSubjects = ['Mathematics'];
        else if (lower.contains('lubaba')) _teacherAllowedSubjects = ['General Science', 'Science'];
        else if (lower.contains('zainab')) _teacherAllowedSubjects = ['Islamiyat'];
        else if (lower.contains('kainat')) _teacherAllowedSubjects = ['Social Studies'];
        else if (lower.contains('laika')) _teacherAllowedSubjects = ['Computer'];
        else if (lower.contains('aleeza')) _teacherAllowedSubjects = ['English', 'Urdu', 'General Knowledge', 'Rhymes'];
        else if (lower.contains('haroon')) _teacherAllowedSubjects = ['Physics', 'Mathematics', 'Chemistry', 'Biology', 'English', 'Urdu', 'Pakistan Studies'];
        else if (lower.contains('ramzan')) _teacherAllowedSubjects = ['Chemistry', 'Physics', 'Mathematics', 'Biology', 'Computer Science', 'English', 'Urdu'];
        else if (lower.contains('arisha') || lower.contains('areesha')) _teacherAllowedSubjects = ['General Science', 'Mathematics', 'English', 'Urdu', 'Islamiyat'];
      }
    }

    await _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final subs = await context.read<MarksProvider>().getSubjectsByClass(_selectedClass);
    List<SubjectModel> filtered = subs;
    if (_isTeacher && _teacherAllowedSubjects.isNotEmpty) {
      filtered = subs.where((s) {
        final sName = s.name.toLowerCase();
        return _teacherAllowedSubjects.any((allowed) {
          final a = allowed.toLowerCase();
          return sName.contains(a) || a.contains(sName);
        });
      }).toList();
    }
    setState(() {
      _subjects = filtered;
      if (_isTeacher) {
        _selectedSubject = filtered.isNotEmpty ? filtered.first : null;
      } else {
        if (_selectedSubject != null && !filtered.any((s) => s.id == _selectedSubject!.id)) {
          _selectedSubject = null;
        }
      }
    });
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final sp = context.read<StudentProvider>();
    _students = await sp.getStudentsByClass(_selectedClass);
    if (_selectedSubject == null) {
      _ranking = await context.read<MarksProvider>().getClassRanking(_selectedClass, _selectedTerm);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final termList = _assessmentCategory == 'Exams' ? _examTerms : _classTests;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(_isTeacher ? 'Class Marks — $_selectedClass' : 'Academic Records & Marks'),
        automaticallyImplyLeading: Navigator.canPop(context),
        actions: [
          if (!_isTeacher)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add Subject',
              onPressed: () => _showAddSubjectDialog(context),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filters
          Container(
            color: AppTheme.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isTeacher) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.navyBlue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.navyBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.navyBlue),
                        const SizedBox(width: 6),
                        Text(
                          'Teacher Mode: $_teacherName${_teacherAllowedSubjects.isNotEmpty ? " (${_teacherAllowedSubjects.join(', ')} Specialist)" : ""}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyBlue),
                        ),
                      ],
                    ),
                  ),
                ],
                // Category switch: Exams vs Class Tests
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('🏆 Terminal Exams (3 Terms)'),
                        selected: _assessmentCategory == 'Exams',
                        selectedColor: AppTheme.navyBlue,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _assessmentCategory == 'Exams' ? Colors.white : AppTheme.navyBlue,
                        ),
                        onSelected: (sel) {
                          if (sel) {
                            setState(() {
                              _assessmentCategory = 'Exams';
                              _selectedTerm = 'Term 1';
                            });
                            _loadData();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('📝 Class & Monthly Tests'),
                        selected: _assessmentCategory == 'Class Tests',
                        selectedColor: AppTheme.navyBlue,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _assessmentCategory == 'Class Tests' ? Colors.white : AppTheme.navyBlue,
                        ),
                        onSelected: (sel) {
                          if (sel) {
                            setState(() {
                              _assessmentCategory = 'Class Tests';
                              _selectedTerm = 'Monthly Test (October)';
                            });
                            _loadData();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        _isTeacher ? 'Assigned Class' : 'Class',
                        _isTeacher ? _teacherAllowedClasses : StudentModel.classes,
                        (_isTeacher ? _teacherAllowedClasses : StudentModel.classes).contains(_selectedClass)
                            ? _selectedClass
                            : (_isTeacher ? _teacherAllowedClasses.first : 'Class 1'),
                        (v) {
                          if (v != null) {
                            setState(() {
                              _selectedClass = v;
                              if (!_isTeacher) _selectedSubject = null;
                              _ranking = [];
                            });
                            _loadSubjects();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDropdown(
                        _assessmentCategory == 'Exams' ? 'Exam Term' : 'Test Type',
                        termList.contains(_selectedTerm) ? termList : [...termList, _selectedTerm],
                        _selectedTerm,
                        (v) {
                          if (v == '➕ Add Custom Test...' || v == 'Custom Test...') {
                            _promptAddCustomTestDialog(context);
                          } else if (v != null) {
                            setState(() => _selectedTerm = v);
                            _loadData();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Subject & Ranking tabs
          Container(
            height: 42,
            color: AppTheme.white,
            child: ScrollConfiguration(
              behavior: const NoScrollbarBehavior(),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  // Tab 1: Overall Ranking (Admin Mode Only)
                  if (!_isTeacher)
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedSubject = null);
                        _loadData();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _selectedSubject == null ? AppTheme.navyBlue : AppTheme.lightBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            '🏆 Overall Ranking',
                            style: AppTheme.bodySmall.copyWith(
                              color: _selectedSubject == null ? AppTheme.white : AppTheme.navyBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Subject Tabs
                  ..._subjects.map((sub) {
                    final selected = _selectedSubject?.id == sub.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedSubject = sub);
                        _loadData();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.navyBlue : AppTheme.lightBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            sub.name,
                            style: AppTheme.bodySmall.copyWith(
                              color: selected ? AppTheme.white : AppTheme.navyBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Quick info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.navyBlue.withOpacity(0.04),
            child: Row(
              children: [
                Icon(
                  _selectedSubject == null ? Icons.leaderboard_rounded : Icons.touch_app_outlined,
                  size: 16,
                  color: AppTheme.navyBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedSubject == null
                        ? 'Overall Class Leaderboard • Tap any student for 3-terms card'
                        : '${_selectedSubject!.name} • $_selectedTerm (Tap student to enter/edit marks)',
                    style: const TextStyle(fontSize: 11, color: AppTheme.navyBlue, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (_selectedSubject != null)
                  ElevatedButton.icon(
                    onPressed: () => _showEnterMarksDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navyBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                    label: const Text('Enter All', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),

          // Main content: Overall Ranking list OR Subject Students list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _selectedSubject == null
                    ? (_ranking.isEmpty
                        ? _emptyState()
                        : ScrollConfiguration(
                            behavior: const NoScrollbarBehavior(),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                              itemCount: _ranking.length,
                              itemBuilder: (_, i) => _RankCard(
                                rank: i + 1,
                                data: _ranking[i],
                                onTap: () => _showStudentReportCardDialog(
                                  context,
                                  _ranking[i]['student'] as StudentModel,
                                ),
                              ),
                            ),
                          ))
                    : (_students.isEmpty
                        ? _emptyState()
                        : ScrollConfiguration(
                            behavior: const NoScrollbarBehavior(),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                              itemCount: _students.length,
                              itemBuilder: (_, i) => _AdminStudentMarkRow(
                                student: _students[i],
                                term: _selectedTerm,
                                subject: _selectedSubject!,
                                onUpdated: _loadData,
                              ),
                            ),
                          )),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: FloatingActionButton.extended(
          onPressed: () => _showEnterMarksDialog(context),
          icon: const Icon(Icons.edit_rounded),
          label: Text(_selectedSubject == null ? 'Enter Marks' : 'Enter ${_selectedSubject!.name} Marks'),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart_rounded, size: 60, color: AppTheme.textLight),
          const SizedBox(height: 12),
          Text(
            _selectedSubject == null
                ? 'No overall marks recorded yet for $_selectedTerm'
                : 'No marks entered for ${_selectedSubject!.name} in $_selectedTerm',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text('Tap "Enter Marks" to begin recording', style: AppTheme.bodySmall),
          const SizedBox(height: 16),
          if (_subjects.isEmpty)
            ElevatedButton(
              onPressed: () => _showAddSubjectDialog(context),
              child: const Text('Add Subjects First'),
            ),
        ],
      ),
    );
  }

  Future<void> _promptAddCustomTestDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final previousTerm = _selectedTerm;

    final testName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.edit_note_rounded, color: AppTheme.navyBlue),
            SizedBox(width: 8),
            Text('Add Custom Test / Exam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the name of the new test or quiz:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Test Name',
                hintText: 'e.g. Unit 3 Quiz, Mid-Term 2026',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) Navigator.pop(ctx, t);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyBlue),
            child: const Text('Add Test', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (testName != null && testName.trim().isNotEmpty) {
      final clean = testName.trim();
      await DatabaseHelper.instance.addCustomTest(clean);
      await _loadCustomTests();
      setState(() {
        _assessmentCategory = 'Class Tests';
        _selectedTerm = clean;
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Added and selected "$clean"')),
        );
      }
    } else {
      setState(() {
        _selectedTerm = previousTerm;
      });
    }
  }

  void _showAddSubjectDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Subject — $_selectedClass', style: AppTheme.headingSmall),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Subject Name (e.g. Mathematics)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                await context.read<MarksProvider>().addSubject(
                    SubjectModel(name: ctrl.text.trim(), className: _selectedClass));
                await _loadSubjects();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEnterMarksDialog(BuildContext context, [SubjectModel? subjectToUse]) async {
    final targetSubject = subjectToUse ?? _selectedSubject;
    if (targetSubject == null) {
      if (_subjects.isEmpty) {
        _showAddSubjectDialog(context);
        return;
      }
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Subject to Enter Marks', style: AppTheme.headingSmall),
              const SizedBox(height: 12),
              ..._subjects.map((s) => ListTile(
                leading: const Icon(Icons.book_rounded, color: AppTheme.navyBlue),
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedSubject = s);
                  _showEnterMarksDialog(context, s);
                },
              )),
            ],
          ),
        ),
      );
      return;
    }

    final students = _students.isNotEmpty
        ? _students
        : await context.read<StudentProvider>().getStudentsByClass(_selectedClass);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EnterMarksSheet(
        students: students,
        subject: targetSubject,
        term: _selectedTerm,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _showStudentReportCardDialog(BuildContext context, StudentModel student) async {
    final allMarks = await DatabaseHelper.instance.getMarksByStudent(student.id!);
    final t1 = allMarks.where((m) => m.term == 'Term 1').toList();
    final t2 = allMarks.where((m) => m.term == 'Term 2').toList();
    final t3 = allMarks.where((m) => m.term == 'Term 3').toList();
    final tests = allMarks.where((m) => m.term != 'Term 1' && m.term != 'Term 2' && m.term != 'Term 3' && m.term != 'Annual (Combined)').toList();

    double sumScore(List<MarksModel> list) => list.fold(0.0, (acc, m) => acc + m.score);
    double sumMax(List<MarksModel> list) => list.fold(0.0, (acc, m) => acc + m.maxScore);

    final t1Score = sumScore(t1);
    final t1Max = sumMax(t1);
    final t1Pct = t1Max > 0 ? (t1Score / t1Max * 100) : 0.0;

    final t2Score = sumScore(t2);
    final t2Max = sumMax(t2);
    final t2Pct = t2Max > 0 ? (t2Score / t2Max * 100) : 0.0;

    final t3Score = sumScore(t3);
    final t3Max = sumMax(t3);
    final t3Pct = t3Max > 0 ? (t3Score / t3Max * 100) : 0.0;

    final totalScore = t1Score + t2Score + t3Score;
    final totalMax = t1Max + t2Max + t3Max;
    final annualPct = totalMax > 0 ? (totalScore / totalMax * 100) : 0.0;

    String computeGrade(double p) {
      if (p >= 90) return 'A+';
      if (p >= 80) return 'A';
      if (p >= 70) return 'B';
      if (p >= 60) return 'C';
      if (p >= 50) return 'D';
      return 'F';
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.navyGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        student.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name, style: AppTheme.headingSmall),
                        Text('S/O: ${student.fatherName} • ${student.className}', style: AppTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Annual Grand Total Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.navyGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ANNUAL (COMBINED 3 TERMS)',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('Grade ${computeGrade(annualPct)}',
                              style: const TextStyle(color: AppTheme.navyBlue, fontWeight: FontWeight.w800, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ResultStat(label: 'Total Marks', value: '${totalScore.toStringAsFixed(0)} / ${totalMax.toStringAsFixed(0)}'),
                        _ResultStat(label: 'Overall %', value: '${annualPct.toStringAsFixed(1)}%'),
                        _ResultStat(label: 'Terms Count', value: '${(t1.isNotEmpty ? 1 : 0) + (t2.isNotEmpty ? 1 : 0) + (t3.isNotEmpty ? 1 : 0)} / 3'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Individual Terms Calculation', style: AppTheme.headingSmall),
              const SizedBox(height: 10),
              _buildTermResultCard('Term 1', t1, t1Score, t1Max, t1Pct, computeGrade(t1Pct)),
              const SizedBox(height: 10),
              _buildTermResultCard('Term 2', t2, t2Score, t2Max, t2Pct, computeGrade(t2Pct)),
              const SizedBox(height: 10),
              _buildTermResultCard('Term 3', t3, t3Score, t3Max, t3Pct, computeGrade(t3Pct)),
              if (tests.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Class & Monthly Tests', style: AppTheme.headingSmall),
                const SizedBox(height: 10),
                ...tests.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.term, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue)),
                          Text(t.subjectName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      Text('${t.score.toStringAsFixed(0)} / ${t.maxScore.toStringAsFixed(0)} (${t.percentage.toStringAsFixed(1)}%)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue)),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermResultCard(String term, List<MarksModel> marks, double score, double max, double pct, String grade) {
    if (marks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.offWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(term, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text('No records', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightBlue),
        boxShadow: AppTheme.cardShadowList,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(term, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navyBlue)),
              Row(
                children: [
                  Text('${score.toStringAsFixed(0)}/${max.toStringAsFixed(0)} (${pct.toStringAsFixed(1)}%)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.navyBlue)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: pct >= 50 ? AppTheme.successGreen.withOpacity(0.12) : AppTheme.errorRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(grade,
                        style: TextStyle(
                            color: pct >= 50 ? AppTheme.successGreen : AppTheme.errorRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 10)),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 14),
          ...marks.map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m.subjectName, style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary)),
                    Text('${m.score.toStringAsFixed(0)} / ${m.maxScore.toStringAsFixed(0)} (${m.percentage.toStringAsFixed(0)}%)',
                        style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: items
          .map((i) => DropdownMenuItem(
                value: i,
                child: Text(i, style: AppTheme.bodyMedium, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  const _ResultStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}

class _RankCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  const _RankCard({required this.rank, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final student = data['student'] as StudentModel;
    final avg = data['average'] as double;

    Color rankColor = AppTheme.textSecondary;
    if (rank == 1) rankColor = AppTheme.accentGold;
    if (rank == 2) rankColor = const Color(0xFFC0C0C0);
    if (rank == 3) rankColor = const Color(0xFFCD7F32);

    String grade = 'F';
    if (avg >= 90) grade = 'A+';
    else if (avg >= 80) grade = 'A';
    else if (avg >= 70) grade = 'B';
    else if (avg >= 60) grade = 'C';
    else if (avg >= 50) grade = 'D';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadowList,
          border: rank <= 3 ? Border.all(color: rankColor.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('#$rank',
                    style: TextStyle(color: rankColor, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: AppTheme.labelMedium),
                  Text('${student.className} • Tap for 3-terms card', style: AppTheme.bodySmall.copyWith(color: AppTheme.navyBlue)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${avg.toStringAsFixed(1)}%', style: AppTheme.headingSmall.copyWith(color: AppTheme.navyBlue, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: avg >= 50 ? AppTheme.successGreen.withOpacity(0.1) : AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(grade,
                      style: TextStyle(
                          color: avg >= 50 ? AppTheme.successGreen : AppTheme.errorRed,
                          fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnterMarksSheet extends StatefulWidget {
  final List<StudentModel> students;
  final SubjectModel subject;
  final String term;
  final VoidCallback onSaved;

  const _EnterMarksSheet({
    required this.students,
    required this.subject,
    required this.term,
    required this.onSaved,
  });

  @override
  State<_EnterMarksSheet> createState() => _EnterMarksSheetState();
}

class _EnterMarksSheetState extends State<_EnterMarksSheet> {
  final Map<int, TextEditingController> _controllers = {};
  final _maxCtrl = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    for (final s in widget.students) {
      _controllers[s.id!] = TextEditingController();
    }
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    for (final s in widget.students) {
      final marks = await DatabaseHelper.instance.getMarksByStudent(s.id!);
      final m = marks.where((x) => x.subjectId == widget.subject.id && x.term == widget.term).firstOrNull;
      if (m != null && mounted) {
        _controllers[s.id!]?.text = m.score.toStringAsFixed(m.score.truncateToDouble() == m.score ? 0 : 1);
        _maxCtrl.text = m.maxScore.toStringAsFixed(m.maxScore.truncateToDouble() == m.maxScore ? 0 : 1);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAll() async {
    final mp = context.read<MarksProvider>();
    final max = double.tryParse(_maxCtrl.text) ?? 100;
    int saved = 0;
    for (final s in widget.students) {
      final txt = _controllers[s.id!]?.text ?? '';
      if (txt.isEmpty) continue;
      final score = double.tryParse(txt);
      if (score == null) continue;
      await mp.saveMarks(MarksModel(
        studentId: s.id!,
        subjectId: widget.subject.id!,
        subjectName: widget.subject.name,
        term: widget.term,
        score: score,
        maxScore: max,
      ));
      saved++;
    }
    widget.onSaved();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Saved marks for $saved students')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text('${widget.subject.name} — ${widget.term}', style: AppTheme.headingSmall),
          const SizedBox(height: 4),
          Text('${widget.students.length} students', style: AppTheme.bodySmall),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Max Marks: ', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(
                width: 80,
                child: TextField(controller: _maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: widget.students.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(s.name, style: AppTheme.bodyMedium)),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _controllers[s.id!],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _saveAll, child: const Text('Save All Marks')),
        ],
      ),
    );
  }
}

class _AdminStudentMarkRow extends StatefulWidget {
  final StudentModel student;
  final String term;
  final SubjectModel subject;
  final VoidCallback onUpdated;

  const _AdminStudentMarkRow({
    required this.student,
    required this.term,
    required this.subject,
    required this.onUpdated,
  });

  @override
  State<_AdminStudentMarkRow> createState() => _AdminStudentMarkRowState();
}

class _AdminStudentMarkRowState extends State<_AdminStudentMarkRow> {
  MarksModel? _marks;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_AdminStudentMarkRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.term != widget.term || oldWidget.subject.id != widget.subject.id || oldWidget.student.id != widget.student.id) {
      _loaded = false;
      _load();
    }
  }

  Future<void> _load() async {
    final allMarks = await DatabaseHelper.instance.getMarksByStudent(widget.student.id!);
    try {
      _marks = allMarks.firstWhere((m) => m.term == widget.term && m.subjectId == widget.subject.id);
    } catch (_) {
      _marks = null;
    }
    if (mounted) {
      setState(() => _loaded = true);
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final scoreCtrl = TextEditingController(
      text: _marks?.score != null
          ? _marks!.score.toStringAsFixed(_marks!.score.truncateToDouble() == _marks!.score ? 0 : 1)
          : '',
    );
    final maxCtrl = TextEditingController(
      text: (_marks?.maxScore ?? 100).toStringAsFixed((_marks?.maxScore ?? 100).truncateToDouble() == (_marks?.maxScore ?? 100) ? 0 : 1),
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppTheme.navyBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Marks: ${widget.student.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.subject.name} • ${widget.term}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: scoreCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Obtained Score',
                      hintText: 'e.g. 85',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: maxCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Total Marks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final score = double.tryParse(scoreCtrl.text.trim());
              final max = double.tryParse(maxCtrl.text.trim()) ?? 100;
              if (score != null) {
                await context.read<MarksProvider>().saveMarks(
                  MarksModel(
                    id: _marks?.id,
                    studentId: widget.student.id!,
                    subjectId: widget.subject.id!,
                    subjectName: widget.subject.name,
                    term: widget.term,
                    score: score,
                    maxScore: max,
                  ),
                );
                await _load();
                widget.onUpdated();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Marks saved for ${widget.student.name}')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyBlue),
            child: const Text('Save Marks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = _marks?.score;
    final max = _marks?.maxScore ?? 100;
    final pct = score != null ? (score / max * 100) : null;

    String grade = 'F';
    Color gradeColor = AppTheme.errorRed;
    if (pct != null) {
      if (pct >= 90) { grade = 'A+'; gradeColor = AppTheme.successGreen; }
      else if (pct >= 80) { grade = 'A'; gradeColor = AppTheme.successGreen; }
      else if (pct >= 70) { grade = 'B'; gradeColor = AppTheme.navyBlue; }
      else if (pct >= 60) { grade = 'C'; gradeColor = AppTheme.warningOrange; }
      else if (pct >= 50) { grade = 'D'; gradeColor = AppTheme.warningOrange; }
    }

    return InkWell(
      onTap: () => _showEditDialog(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.cardShadowList,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  widget.student.name.isNotEmpty ? widget.student.name.substring(0, 1).toUpperCase() : '?',
                  style: const TextStyle(color: AppTheme.navyBlue, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.student.name, style: AppTheme.labelMedium),
                  Text('S/O: ${widget.student.fatherName} • ${widget.student.className}', style: AppTheme.bodySmall),
                ],
              ),
            ),
            if (!_loaded)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else if (score == null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.lightBlue, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Enter', style: TextStyle(color: AppTheme.navyBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                    SizedBox(width: 2),
                    Icon(Icons.edit_note_rounded, size: 14, color: AppTheme.navyBlue),
                  ],
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${score.toStringAsFixed(score.truncateToDouble() == score ? 0 : 1)} / ${max.toStringAsFixed(max.truncateToDouble() == max ? 0 : 1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue),
                      ),
                      Text(
                        '${pct!.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: gradeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      grade,
                      style: TextStyle(color: gradeColor, fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade400),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
