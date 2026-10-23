// lib/screens/admin/timetable_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../models/timetable_model.dart';
import '../../models/teacher_model.dart';
import '../../database/db_helper.dart';
import '../../services/api_service.dart';
import '../../services/whatsapp_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/network_banner.dart';
import '../../utils/pdf_fonts.dart';

class TimetableScreen extends StatefulWidget {
  final String? initialClass;
  final int initialTab;

  const TimetableScreen({super.key, this.initialClass, this.initialTab = 0});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedClass;
  String _viewMode = 'Class'; // 'Class', 'Teacher', 'Subject'
  String _selectedTeacher = '';
  String _selectedSubject = 'Mathematics';
  bool _isLoading = false;

  List<TimetableSlotModel> _currentSlots = [];
  List<TeacherModel> _allTeachers = [];
  List<String> _availableSubjects = ['Mathematics', 'General Science', 'English', 'Urdu', 'Islamiyat', 'Social Studies', 'Computer'];
  final List<String> _allSubjectsList = [
    'Mathematics',
    'English',
    'Urdu',
    'General Science',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'Islamiyat',
    'Social Studies',
    'Pakistan Studies',
    'History',
  ];

  // Weekly Learning Schedule state
  String _weeklyFilterMode = 'Class'; // 'Class', 'Teacher', or 'Subject'
  String _selectedWeeklyTeacher = 'Haroon';
  String _selectedWeeklySubject = 'Mathematics';
  String _weeklySubjectFilter = 'All Subjects'; // 'All Subjects' or a specific subject name

  bool get _isAdmin {
    final auth = context.read<AuthProvider>();
    return auth.isAdmin ||
        AuthService.instance.isAdmin ||
        auth.user?.role == 'admin' ||
        auth.user?.role == 'principal';
  }

  bool get _isTeacher {
    final auth = context.read<AuthProvider>();
    return !_isAdmin &&
        (auth.isTeacher ||
            AuthService.instance.isTeacher ||
            auth.user?.role == 'teacher');
  }

  String get _loggedInTeacherName {
    final user = AuthService.instance.currentUser ?? context.read<AuthProvider>().user;
    return user?.name ?? user?.username ?? '';
  }
  Map<String, Map<String, String>> _weeklySchedule = {}; // day -> subject -> topic
  String _activeEditingSubjectKey = ''; // e.g. "Monday_English"
  final Map<String, TextEditingController> _subjectControllers = {};
  String _subjectDictationLang = 'Urdu'; // 'Urdu' or 'English'
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  final List<String> _classes = [
    'Nursery', 'KG', 'Class 1', 'Class 2', 'Class 3', 'Class 4',
    'Class 5', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10'
  ];

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  List<String> _getSubjectsForClass(String className) {
    if (className == 'Class 9') {
      return ['Physics', 'Mathematics', 'Chemistry', 'Biology', 'English', 'Urdu', 'Pakistan Studies'];
    } else if (className == 'Class 10') {
      return ['Chemistry', 'Physics', 'Mathematics', 'Biology', 'Computer Science', 'English', 'Urdu'];
    } else if (className == 'Class 8') {
      return ['Mathematics', 'General Science', 'English', 'Urdu', 'Islamiyat', 'History', 'Computer'];
    } else if (className == 'Nursery' || className == 'PG') {
      return ['English Phonics', 'Urdu Haroof', 'Mathematics Numbers', 'General Knowledge', 'Art & Activity', 'Story Time'];
    } else if (className == 'KG' || className == 'Prep') {
      return ['English Reading', 'Urdu Alfaz', 'Mathematics Addition', 'General Science', 'Rhymes & Singing', 'Islamiyat Basics'];
    } else {
      return ['English', 'Urdu', 'Mathematics', 'General Science', 'Islamiyat', 'Social Studies', 'Computer'];
    }
  }

  final List<String> _lowerClasses = [
    'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7'
  ];

  List<String> _getTeacherAssignedClasses(String teacherName) {
    final clean = teacherName.toLowerCase().replaceAll('sir', '').replaceAll('miss', '').replaceAll('teacher', '').trim();
    final teacher = _allTeachers.where((t) => t.name.toLowerCase().contains(clean)).firstOrNull;
    if (teacher != null && teacher.assignedClasses.isNotEmpty) {
      return teacher.assignedClasses;
    }
    final lower = teacherName.toLowerCase().trim();
    if (lower.contains('haroon')) return ['Class 9'];
    if (lower.contains('ramzan')) return ['Class 10'];
    if (lower.contains('arisha') || lower.contains('areesha')) return ['Class 8'];
    if (lower.contains('aleeza')) return ['Nursery', 'KG', 'PG'];
    if (lower.contains('munza') || lower.contains('maham') || lower.contains('nisa') ||
        lower.contains('lubaba') || lower.contains('zainab') || lower.contains('kainat') ||
        lower.contains('laika')) {
      return _lowerClasses;
    }
    return _classes;
  }

  List<String> _getTeacherSubjects(String teacherName, String className) {
    final clean = teacherName.toLowerCase().replaceAll('sir', '').replaceAll('miss', '').replaceAll('teacher', '').trim();
    final teacher = _allTeachers.where((t) => t.name.toLowerCase().contains(clean)).firstOrNull;
    if (teacher != null && teacher.subjects.isNotEmpty) {
      return teacher.subjects;
    }
    final lower = teacherName.toLowerCase().trim();
    if (lower.contains('munza')) return ['English'];
    if (lower.contains('maham')) return ['Urdu'];
    if (lower.contains('nisa')) return ['Mathematics'];
    if (lower.contains('lubaba')) return ['General Science'];
    if (lower.contains('zainab')) return ['Islamiyat'];
    if (lower.contains('kainat')) return ['Social Studies'];
    if (lower.contains('laika')) return ['Computer'];
    if (lower.contains('aleeza')) return ['English Phonics', 'Urdu Haroof', 'Mathematics Numbers', 'General Knowledge'];
    return _getSubjectsForClass(className);
  }

  void _updateWeeklyTeacherSubjectsAndClass() {
    final teacherClasses = _getTeacherAssignedClasses(_selectedWeeklyTeacher);
    if (!teacherClasses.contains(_selectedClass)) {
      _selectedClass = teacherClasses.isNotEmpty ? teacherClasses.first : 'Class 5';
    }
    _availableSubjects = _getTeacherSubjects(_selectedWeeklyTeacher, _selectedClass);
  }

  String _getTeacherDisplayName(String rawName) {
    final lower = rawName.toLowerCase().trim();
    if (lower.contains('haroon')) return 'Sir Haroon (Class 9 Lead)';
    if (lower.contains('ramzan')) return 'Sir Ramzan (Class 10 Lead)';
    if (lower.contains('arisha') || lower.contains('areesha')) return 'Miss Arisha (Class 8 Lead)';
    if (lower.contains('munza')) return 'Miss Munza (English Specialist)';
    if (lower.contains('maham')) return 'Miss Maham (Urdu Specialist)';
    if (lower.contains('nisa')) return 'Miss Nisa (Mathematics Specialist)';
    if (lower.contains('lubaba')) return 'Miss Lubaba (Science Specialist)';
    if (lower.contains('zainab')) return 'Miss Zainab (Islamiyat Specialist)';
    if (lower.contains('kainat')) return 'Miss Kainat (Social Studies Specialist)';
    if (lower.contains('laika')) return 'Miss Laika (Computer Specialist)';
    if (lower.contains('aleeza')) return 'Miss Aleeza (Early Years Specialist)';
    return rawName.startsWith('Sir ') || rawName.startsWith('Miss ') ? rawName : 'Teacher $rawName';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _selectedClass = widget.initialClass ?? 'Class 5';
    _availableSubjects = _getSubjectsForClass(_selectedClass);
    _initSpeech();
    _initData();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _speech.stop();
    for (final c in _subjectControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    var teachers = await DatabaseHelper.instance.getAllTeachers();
    if (teachers.isEmpty) {
      teachers = [
        TeacherModel(id: 1, userId: 1, name: 'Sir Haroon', assignedClasses: ['Class 9'], subjects: ['Physics', 'Mathematics', 'Chemistry', 'Biology', 'English', 'Urdu', 'Pakistan Studies']),
        TeacherModel(id: 2, userId: 2, name: 'Sir Ramzan', assignedClasses: ['Class 10'], subjects: ['Chemistry', 'Physics', 'Mathematics', 'Biology', 'Computer Science', 'English', 'Urdu']),
        TeacherModel(id: 3, userId: 3, name: 'Miss Arisha', assignedClasses: ['Class 8'], subjects: ['Mathematics', 'General Science', 'English', 'Urdu', 'Islamiyat', 'History', 'Computer']),
        TeacherModel(id: 4, userId: 4, name: 'Miss Munza', assignedClasses: ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7'], subjects: ['English']),
        TeacherModel(id: 5, userId: 5, name: 'Miss Maham', assignedClasses: ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7'], subjects: ['Urdu']),
        TeacherModel(id: 6, userId: 6, name: 'Miss Nisa', assignedClasses: ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7'], subjects: ['Mathematics']),
        TeacherModel(id: 7, userId: 7, name: 'Miss Lubaba', assignedClasses: ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7'], subjects: ['General Science']),
        TeacherModel(id: 8, userId: 8, name: 'Miss Zainab', assignedClasses: ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7'], subjects: ['Islamiyat']),
        TeacherModel(id: 9, userId: 9, name: 'Miss Kainat', assignedClasses: ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7'], subjects: ['Social Studies']),
        TeacherModel(id: 10, userId: 10, name: 'Miss Laika', assignedClasses: ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7'], subjects: ['Computer']),
        TeacherModel(id: 11, userId: 11, name: 'Miss Aleeza', assignedClasses: ['Nursery', 'KG'], subjects: ['Early Learning']),
      ];
    }
    _allTeachers = teachers;

    final isAdmin = _isAdmin;
    final isTeacher = _isTeacher;
    if (isTeacher) {
      _viewMode = 'Teacher';
      _weeklyFilterMode = 'Teacher';
      final cleanLoggedIn = _loggedInTeacherName.toLowerCase().replaceAll('sir', '').replaceAll('miss', '').replaceAll('teacher', '').trim();
      final matchedTeacher = teachers.where((t) => t.name.toLowerCase().contains(cleanLoggedIn)).firstOrNull;
      _selectedTeacher = matchedTeacher?.name ?? (_loggedInTeacherName.isNotEmpty ? _loggedInTeacherName : (teachers.isNotEmpty ? teachers.first.name : 'Sir Haroon'));
      _selectedWeeklyTeacher = _selectedTeacher;
      _updateWeeklyTeacherSubjectsAndClass();
    } else {
      _viewMode = 'Class';
      if (teachers.isNotEmpty && _selectedTeacher.isEmpty) {
        _selectedTeacher = teachers.first.name;
      }
      _selectedWeeklyTeacher = _selectedTeacher.isNotEmpty ? _selectedTeacher : 'Sir Haroon';
      _availableSubjects = _getSubjectsForClass(_selectedClass);
    }

    await _loadTimetable();
    await _loadWeeklySchedule();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadTimetable() async {
    List<TimetableSlotModel> slots;
    if (_isTeacher) {
      _viewMode = 'Teacher';
      final teacherToQuery = _selectedTeacher.isNotEmpty ? _selectedTeacher : _loggedInTeacherName;
      slots = await DatabaseHelper.instance.getTimetableByTeacher(teacherToQuery);
    } else if (_viewMode == 'Teacher' && _selectedTeacher.isNotEmpty) {
      slots = await DatabaseHelper.instance.getTimetableByTeacher(_selectedTeacher);
    } else if (_viewMode == 'Subject' && _selectedSubject.isNotEmpty) {
      slots = await DatabaseHelper.instance.getTimetableBySubject(_selectedSubject);
    } else {
      slots = await DatabaseHelper.instance.getTimetableByClass(_selectedClass);
    }
    if (mounted) {
      setState(() {
        _currentSlots = slots;
      });
    }
  }

  Future<void> _loadWeeklySchedule() async {
    if (_weeklyFilterMode == 'Teacher') {
      _updateWeeklyTeacherSubjectsAndClass();
    } else if (_weeklyFilterMode == 'Subject') {
      _availableSubjects = _getSubjectsForClass(_selectedClass);
      if (!_availableSubjects.contains(_selectedWeeklySubject)) {
        _availableSubjects = [_selectedWeeklySubject, ..._availableSubjects];
      }
    } else {
      _availableSubjects = _getSubjectsForClass(_selectedClass);
    }
    final diaries = await DatabaseHelper.instance.getWeeklyDiariesByClass(_selectedClass);
    final Map<String, Map<String, String>> scheduleMap = {};

    for (final day in _days) {
      scheduleMap[day] = {};
    }

    if (diaries.isNotEmpty) {
      for (final d in diaries) {
        try {
          final List list = jsonDecode(d.dayPlansJson);
          for (final item in list) {
            final day = item['day'] as String? ?? '';
            final topic = item['topic'] as String? ?? '';
            if (scheduleMap.containsKey(day)) {
              scheduleMap[day]![d.subjectName] = topic;
            }
          }
        } catch (_) {}
      }
    }

    final defaultTopics = {
      'Mathematics': 'Fractions, Decimals & Word Problems',
      'General Science': 'Classification of Living Organisms & Ecosystems',
      'English': 'Reading Comprehension, Grammar & Creative Writing',
      'Urdu': 'اسباق، فصاحت و بلاغت اور جملہ سازی',
      'Islamiyat': 'سیرت النبی ﷺ اور آداب معاشرت',
      'Social Studies': 'Geography of Pakistan & Map Reading',
      'Physics': 'Motion, Force, Gravitation & Laws of Motion',
      'Chemistry': 'Atomic Structure, Chemical Bonding & Reactions',
      'Biology': 'Cell Biology, Genetics & Human Organ Systems',
      'Computer': 'Fundamentals of IT & Office Productivity',
      'Computer Science': 'Computer Systems, Programming & Algorithms',
      'Pakistan Studies': 'Ideology of Pakistan, Constitution & Geography',
      'History': 'Indus Valley Civilization & Subcontinent History',
      'English Phonics': 'Phonics sounds, Blends & Sight Words',
      'Urdu Haroof': 'حروفِ تہجی اور بنیادی الفاظ',
      'Mathematics Numbers': 'Counting 1-100 & Basic Shapes',
      'General Knowledge': 'Seasons, Plants & Animals',
      'Art & Activity': 'Coloring, Drawing & Motor Skills',
      'Story Time': 'Moral Stories & Islamic Tales',
    };

    for (final day in _days) {
      for (final sub in _availableSubjects) {
        if (!scheduleMap[day]!.containsKey(sub) || scheduleMap[day]![sub]!.isEmpty) {
          scheduleMap[day]![sub] = defaultTopics[sub] ?? 'Standard SNC Lesson on $sub';
        }
      }
    }

    for (final day in _days) {
      for (final sub in _availableSubjects) {
        final key = '${day}_$sub';
        final topic = scheduleMap[day]?[sub] ?? '';
        if (_subjectControllers.containsKey(key)) {
          _subjectControllers[key]!.text = topic;
        } else {
          _subjectControllers[key] = TextEditingController(text: topic);
        }
      }
    }

    setState(() {
      _weeklySchedule = scheduleMap;
    });
  }

  Future<void> _saveWeeklySchedule() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final isTeacher = auth.isTeacher;
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = "${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
      final weekEnd = "${monday.year}-${monday.month.toString().padLeft(2, '0')}-${(monday.day + 6).toString().padLeft(2, '0')}";

      final subjectsToSave = isTeacher
          ? _getTeacherSubjects(_selectedWeeklyTeacher, _selectedClass)
          : _availableSubjects;

      for (final sub in subjectsToSave) {
        final List<Map<String, String>> dayPlans = [];
        for (final day in _days) {
          final topic = _weeklySchedule[day]?[sub] ?? 'Standard SNC Lesson';
          dayPlans.add({'day': day, 'topic': topic, 'homework': 'Practice worksheet for $topic'});
        }

        final diary = WeeklyDiaryModel(
          className: _selectedClass,
          subjectName: sub,
          weekStartDate: weekStart,
          weekEndDate: weekEnd,
          dayPlansJson: jsonEncode(dayPlans),
          parentSummaryUrdu: 'ہفتہ وار تدریسی شیڈول یکساں قومی نصاب (SNC) کے مطابق مرتب کر دیا گیا ہے۔',
        );

        await DatabaseHelper.instance.saveOrUpdateWeeklyDiary(diary);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Weekly learning schedule saved and synced with Parent Portal for $_selectedClass!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving weekly schedule: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  (String, String) _calculatePeriodTimes(int periodNumber, String startTimeStr, int durationMinutes, bool isFriday) {
    int startHour = 8;
    int startMinute = 0;
    try {
      final parts = startTimeStr.replaceAll('AM', '').replaceAll('PM', '').trim().split(':');
      startHour = int.parse(parts[0].trim());
      startMinute = int.parse(parts[1].trim());
      if (startTimeStr.toUpperCase().contains('PM') && startHour < 12) startHour += 12;
    } catch (_) {}

    final base = DateTime(2026, 1, 1, startHour, startMinute);
    int currentOffsetMinutes = 0;

    for (int p = 1; p < periodNumber; p++) {
      currentOffsetMinutes += durationMinutes;
      // Recess break after Period 4 on regular days (30 mins), or after Period 3 on Friday (25 mins)
      if (!isFriday && p == 4) {
        currentOffsetMinutes += 30;
      } else if (isFriday && p == 3) {
        currentOffsetMinutes += 25;
      }
    }

    final pStart = base.add(Duration(minutes: currentOffsetMinutes));
    final pEnd = pStart.add(Duration(minutes: durationMinutes));

    String formatTime(DateTime dt) {
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${h.toString().padLeft(2, '0')}:$m $ampm';
    }

    return (formatTime(pStart), formatTime(pEnd));
  }

  IconData _getSubjectIcon(String sub) {
    final s = sub.toLowerCase();
    if (s.contains('math')) return Icons.calculate_rounded;
    if (s.contains('sci') || s.contains('phys') || s.contains('chem') || s.contains('bio')) return Icons.science_rounded;
    if (s.contains('eng')) return Icons.menu_book_rounded;
    if (s.contains('urdu')) return Icons.auto_stories_rounded;
    if (s.contains('islam')) return Icons.mosque_rounded;
    if (s.contains('comp')) return Icons.computer_rounded;
    if (s.contains('soc') || s.contains('pak') || s.contains('hist') || s.contains('geo')) return Icons.public_rounded;
    return Icons.school_rounded;
  }

  Color _getSubjectColor(String sub) {
    final s = sub.toLowerCase();
    if (s.contains('math')) return const Color(0xFF0284C7);
    if (s.contains('sci') || s.contains('phys') || s.contains('chem') || s.contains('bio')) return const Color(0xFF059669);
    if (s.contains('eng')) return const Color(0xFF2563EB);
    if (s.contains('urdu')) return const Color(0xFFD97706);
    if (s.contains('islam')) return const Color(0xFF0F382C);
    if (s.contains('comp')) return const Color(0xFF7C3AED);
    if (s.contains('soc') || s.contains('pak') || s.contains('hist') || s.contains('geo')) return const Color(0xFFB45309);
    return AppTheme.navyBlue;
  }

  Future<void> _toggleSubjectDictation(String day, String sub) async {
    final key = '${day}_$sub';
    if (_isListening && _activeEditingSubjectKey == key) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      await _initSpeech();
    }

    setState(() {
      _activeEditingSubjectKey = key;
      _isListening = true;
    });

    final locale = _subjectDictationLang == 'Urdu' ? 'ur_PK' : 'en_US';
    await _speech.listen(
      localeId: locale,
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) {
          setState(() {
            _weeklySchedule[day]?[sub] = result.recognizedWords;
            if (_subjectControllers.containsKey(key)) {
              _subjectControllers[key]!.text = result.recognizedWords;
            }
          });
        }
      },
    );
  }

  // ── Setup & Generate Timetable Dialog ──────────────────────────────────────
  Future<void> _showSetupTimetableDialog() async {
    String startTime = '08:00 AM';
    int periodDuration = 40;
    int numPeriods = 7;
    String breakTime = '10:40 AM';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.tune, color: AppTheme.navyBlue),
                  const SizedBox(width: 8),
                  Text('Setup Timetable — $_selectedClass', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Configure class timing parameters:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: startTime,
                      decoration: const InputDecoration(labelText: 'School Start Time', border: OutlineInputBorder()),
                      items: ['07:30 AM', '08:00 AM', '08:30 AM']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setDlgState(() => startTime = v!),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: periodDuration,
                            decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                            items: [35, 40, 45, 50]
                                .map((d) => DropdownMenuItem(value: d, child: Text('$d mins')))
                                .toList(),
                            onChanged: (v) => setDlgState(() => periodDuration = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: numPeriods,
                            decoration: const InputDecoration(labelText: 'Periods', border: OutlineInputBorder()),
                            items: [6, 7, 8]
                                .map((p) => DropdownMenuItem(value: p, child: Text('$p Periods')))
                                .toList(),
                            onChanged: (v) => setDlgState(() => numPeriods = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: breakTime,
                      decoration: const InputDecoration(labelText: 'Recess / Break Time', border: OutlineInputBorder()),
                      items: ['10:00 AM', '10:30 AM', '10:40 AM', '11:00 AM']
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (v) => setDlgState(() => breakTime = v!),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Conflict-Free Timetable Generation Policy:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• Upper Classes (Class 10, 9, 8): Dedicated Single Lead Teacher (Sir Ramzan, Sir Haroon, Miss Arisha)\n• Lower Classes (Nursery - Class 7): Period-by-period rotating subject specialists',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Create Manually'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _createStandardManualSlots(numPeriods, startTime, periodDuration);
                  },
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyBlue),
                  icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  label: const Text('Generate with AI', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _generateAiTimetable();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createStandardManualSlots(int numPeriods, String startTime, int duration) async {
    setState(() => _isLoading = true);
    final List<TimetableSlotModel> manualSlots = [];

    final isUpper10 = _selectedClass == 'Class 10';
    final isUpper9 = _selectedClass == 'Class 9';
    final isUpper8 = _selectedClass == 'Class 8';

    String? leadTeacher;
    List<String> classSubjects;
    if (isUpper10) {
      leadTeacher = 'Ramzan';
      classSubjects = ['Chemistry', 'Physics', 'Mathematics', 'Biology', 'Computer Science', 'English', 'Urdu'];
    } else if (isUpper9) {
      leadTeacher = 'Haroon';
      classSubjects = ['Physics', 'Mathematics', 'Chemistry', 'Biology', 'English', 'Urdu', 'Pakistan Studies'];
    } else if (isUpper8) {
      leadTeacher = 'Areesha';
      classSubjects = ['Mathematics', 'General Science', 'English', 'Urdu', 'Islamiyat', 'History', 'Computer'];
    } else if (_selectedClass == 'Nursery' || _selectedClass == 'KG') {
      leadTeacher = 'Aleeza';
      classSubjects = ['English', 'Urdu', 'Mathematics', 'General Knowledge', 'Rhymes', 'Story Time', 'Art'];
    } else {
      classSubjects = ['English', 'Urdu', 'Mathematics', 'General Science', 'Islamiyat', 'Social Studies', 'Computer'];
    }

    final specialists = [
      {'subject': 'English', 'teacher': 'Munza'},
      {'subject': 'Urdu', 'teacher': 'Maham'},
      {'subject': 'Mathematics', 'teacher': 'Nisa'},
      {'subject': 'General Science', 'teacher': 'Lubaba'},
      {'subject': 'Islamiyat', 'teacher': 'Zainab'},
      {'subject': 'Social Studies', 'teacher': 'Kainat'},
      {'subject': 'Computer', 'teacher': 'Laika'},
    ];

    final lowerClasses = ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7'];
    final cIdx = lowerClasses.indexOf(_selectedClass);

    for (int dIdx = 0; dIdx < _days.length; dIdx++) {
      final day = _days[dIdx];
      final isFriday = day == 'Friday';

      for (int p = 1; p <= numPeriods; p++) {
        final (pStart, pEnd) = _calculatePeriodTimes(p, startTime, duration, isFriday);

        String subName;
        String tName;

        if (leadTeacher != null) {
          subName = classSubjects[(p - 1 + dIdx) % classSubjects.length];
          tName = leadTeacher;
        } else {
          final specIdx = ((cIdx >= 0 ? cIdx : 0) + (p - 1) + dIdx) % specialists.length;
          subName = specialists[specIdx]['subject']!;
          tName = specialists[specIdx]['teacher']!;
        }

        manualSlots.add(TimetableSlotModel(
          className: _selectedClass,
          dayOfWeek: day,
          periodNumber: p,
          startTime: pStart,
          endTime: pEnd,
          subjectName: subName,
          teacherName: tName,
        ));
      }
    }

    await DatabaseHelper.instance.clearTimetableForClass(_selectedClass);
    for (final s in manualSlots) {
      await DatabaseHelper.instance.insertTimetableSlot(s);
    }

    setState(() {
      _currentSlots = manualSlots;
      _isLoading = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Conflict-free timetable created for $_selectedClass with sequential period timings!')),
    );
  }

  // ── Allocate / Edit Slot Dialog (Admin Only) ──────────────────────────────
  Future<void> _showEditSlotDialog(TimetableSlotModel slot) async {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.user?.role == 'admin' || auth.user?.role == 'principal';

    if (!isAdmin) {
      // Read-only info dialog for teachers
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(_getSubjectIcon(slot.subjectName), color: _getSubjectColor(slot.subjectName)),
              const SizedBox(width: 8),
              Text('${slot.className} — Period ${slot.periodNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Day:', slot.dayOfWeek),
              _detailRow('Timing:', '${slot.startTime} – ${slot.endTime}'),
              _detailRow('Subject:', slot.subjectName),
              _detailRow('Teacher:', slot.teacherName),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(child: Text('Timetable is managed by Administration. Teachers have read-only access.', style: TextStyle(fontSize: 11, color: Colors.blue))),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
      return;
    }

    String selectedSub = slot.subjectName;
    String selectedTchr = slot.teacherName;
    String startTime = slot.startTime;
    String endTime = slot.endTime;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit_calendar, color: AppTheme.navyBlue),
                  const SizedBox(width: 8),
                  Text('Allocate Period ${slot.periodNumber} (${slot.dayOfWeek})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Class: ${slot.className}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _availableSubjects.contains(selectedSub) ? selectedSub : _availableSubjects.first,
                    decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                    items: _availableSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setDlgState(() => selectedSub = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _allTeachers.any((t) => t.name == selectedTchr)
                        ? selectedTchr
                        : (_allTeachers.where((t) => t.name.toLowerCase().contains(selectedTchr.toLowerCase().replaceAll('sir', '').replaceAll('miss', '').trim())).firstOrNull?.name ??
                           (_allTeachers.isNotEmpty ? _allTeachers.first.name : selectedTchr)),
                    decoration: const InputDecoration(labelText: 'Allocate to Teacher', border: OutlineInputBorder()),
                    items: _allTeachers.map((t) => DropdownMenuItem(value: t.name, child: Text('${_getTeacherDisplayName(t.name).split(" (")[0]} (${t.subjects.join(", ")})', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setDlgState(() => selectedTchr = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: startTime,
                          decoration: const InputDecoration(labelText: 'Start Time', border: OutlineInputBorder()),
                          onChanged: (v) => startTime = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: endTime,
                          decoration: const InputDecoration(labelText: 'End Time', border: OutlineInputBorder()),
                          onChanged: (v) => endTime = v,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyBlue),
                  icon: const Icon(Icons.sync, color: Colors.white, size: 16),
                  label: const Text('Save & Sync with Teacher', style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    final updated = TimetableSlotModel(
                      id: slot.id,
                      className: slot.className,
                      dayOfWeek: slot.dayOfWeek,
                      periodNumber: slot.periodNumber,
                      startTime: startTime,
                      endTime: endTime,
                      subjectName: selectedSub,
                      teacherName: selectedTchr,
                    );
                    await DatabaseHelper.instance.updateTimetableSlot(updated);
                    await _loadTimetable();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ Period allocated to $selectedTchr and synced with Teacher\'s Portal!')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.navyBlue))),
        ],
      ),
    );
  }

  // ── AI Timetable Generator ────────────────────────────────────────────────
  Future<void> _generateAiTimetable() async {
    setState(() => _isLoading = true);
    try {
      final subjects = await DatabaseHelper.instance.getSubjectsByClass(_selectedClass);
      final subNames = subjects.map((s) => s.name).toList();
      final teachers = await DatabaseHelper.instance.getAllTeachers();

      final teacherPayload = teachers.map((t) => {
        'teacher_name': t.name,
        'subjects': t.subjects,
        'assigned_classes': t.assignedClasses,
      }).toList();

      final res = await ApiService.instance.generateTimetable(
        className: _selectedClass,
        subjects: subNames.isNotEmpty ? subNames : _availableSubjects,
        availableTeachers: teacherPayload,
      );

      final scheduleData = (res['schedule'] as List?) ?? [];
      final List<TimetableSlotModel> generatedSlots = [];

      for (final dayData in scheduleData) {
        final day = dayData['day'] as String? ?? 'Monday';
        final periods = (dayData['periods'] as List?) ?? [];
        for (final p in periods) {
          generatedSlots.add(TimetableSlotModel(
            className: _selectedClass,
            dayOfWeek: day,
            periodNumber: p['period_number'] ?? 1,
            startTime: p['start_time'] ?? '08:00 AM',
            endTime: p['end_time'] ?? '08:45 AM',
            subjectName: p['subject_name'] ?? 'General',
            teacherName: p['teacher_name'] ?? 'Teacher',
          ));
        }
      }

      await DatabaseHelper.instance.clearTimetableForClass(_selectedClass);
      for (final s in generatedSlots) {
        await DatabaseHelper.instance.insertTimetableSlot(s);
      }

      setState(() {
        _currentSlots = generatedSlots;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Conflict-free AI timetable generated & saved for $_selectedClass!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Timetable generation error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── PDF Exports ───────────────────────────────────────────────────────────
  Future<void> _exportTimetablePdf() async {
    if (_currentSlots.isEmpty) return;
    await PdfFonts.ensureLoaded();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: PdfFonts.theme,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('SUBLIME GRAMMAR SCHOOL', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Official Master Academic Timetable — $_selectedClass ($_viewMode View)', style: pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
                      pw.SizedBox(height: 8),
                      pw.Divider(thickness: 1.5),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Day', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        for (int p = 1; p <= 7; p++)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Period $p', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                      ],
                    ),
                    for (final day in _days)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(day, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          for (int p = 1; p <= 7; p++) ...[
                            () {
                              final slot = _currentSlots.where((s) => s.dayOfWeek == day && s.periodNumber == p).toList();
                              if (slot.isNotEmpty) {
                                return pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    children: [
                                      pw.Text(slot.first.subjectName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                      pw.Text(slot.first.teacherName, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                                    ],
                                  ),
                                );
                              }
                              return pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('-', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)));
                            }(),
                          ],
                        ],
                      ),
                  ],
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Sublime Grammar School • Verified by Ustad-AI System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    pw.Text('Authorized Signature: __________________', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Timetable_${_selectedClass}_$_viewMode.pdf',
    );
  }

  Future<void> _exportWeeklySchedulePdf() async {
    await PdfFonts.ensureLoaded();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: PdfFonts.theme,
        build: (pw.Context context) {
          final activeExportSubject = _weeklyFilterMode == 'Subject' ? _selectedWeeklySubject : _weeklySubjectFilter;
          final exportSubs = activeExportSubject == 'All Subjects'
              ? _availableSubjects
              : _availableSubjects.where((s) => s.toLowerCase() == activeExportSubject.toLowerCase()).toList().isEmpty
                  ? [activeExportSubject]
                  : _availableSubjects.where((s) => s.toLowerCase() == activeExportSubject.toLowerCase()).toList();

          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('SUBLIME GRAMMAR SCHOOL', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Official 6-Day SNC Weekly Teaching Diary & Learning Schedule — $_selectedClass', style: pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
                      pw.SizedBox(height: 8),
                      pw.Divider(thickness: 1.5),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Subject', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        for (final day in _days)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(day, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                      ],
                    ),
                    for (final sub in exportSubs)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(sub, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          for (final day in _days)
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                _weeklySchedule[day]?[sub] ?? 'Standard SNC Lesson',
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Aligned with Single National Curriculum (SNC) • Verified by Ustad-AI System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    pw.Text('Principal Signature: __________________', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Weekly_Schedule_$_selectedClass.pdf',
    );
  }

  Future<void> _broadcastTimetableWhatsApp() async {
    final urduText =
        'محترم والدین، السلام علیکم!\nسبلائم گرامر اسکول کی جانب سے جماعت ${_selectedClass} کا نیا ہفتہ وار تدریسی شیڈول (Timetable) جاری کر دیا گیا ہے۔\n\n'
        'روزانہ اوقات: صبح 8:00 بجے تا دوپہر 1:30 بجے (جمعہ المبارک: 12:30 بجے تک)۔\n\n'
        'برائے مہربانی شیڈول کے مطابق بچے کی کتابیں اور کاپیاں روانہ فرمائیں۔\nشکریہ، انتظامیہ سبلائم گرامر اسکول';

    final students = context.read<StudentProvider>().students.where((s) => s.className == _selectedClass).toList();

    await WhatsAppService.showShareDialog(
      context: context,
      title: _tabController.index == 1 ? 'Share Weekly Learning Schedule' : 'Share Class Timetable',
      subtitle: 'Class: ' + _selectedClass + ' (' + students.length.toString() + ' students)',
      message: urduText,
      students: students,
    );
  }

  // ── Build Method ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Timetable & Learning Schedule'),
        backgroundColor: AppTheme.navyBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print PDF',
            onPressed: () {
              if (_tabController.index == 0) {
                _exportTimetablePdf();
              } else {
                _exportWeeklySchedulePdf();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.greenAccent),
            tooltip: 'Share via WhatsApp',
            onPressed: _broadcastTimetableWhatsApp,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentGold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month, size: 18), text: 'Class Timetable'),
            Tab(icon: Icon(Icons.menu_book, size: 18), text: 'Weekly Learning Schedule'),
          ],
        ),
      ),
      body: Column(
        children: [
          const NetworkBanner(),
          Expanded(
            child: _tabController.index == 0
                ? _buildTimetableTab()
                : _buildWeeklyScheduleTab(),
          ),
        ],
      ),
    );
  }

  // ── Tab 0: Class Timetable ────────────────────────────────────────────────
  Widget _buildTimetableTab() {
    final isAdmin = _isAdmin;
    final isTeacher = _isTeacher;

    if (isTeacher) {
      _viewMode = 'Teacher';
      final cleanLoggedIn = _loggedInTeacherName.toLowerCase().replaceAll('sir', '').replaceAll('miss', '').replaceAll('teacher', '').trim();
      final matched = _allTeachers.where((t) => t.name.toLowerCase().contains(cleanLoggedIn)).firstOrNull;
      if (matched != null) {
        _selectedTeacher = matched.name;
      } else if (_loggedInTeacherName.isNotEmpty) {
        _selectedTeacher = _loggedInTeacherName;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls / Filters Bar (Admin gets full switcher; Teacher is strictly locked to their own schedule)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAdmin) ...[
                Row(
                  children: [
                    const Text('View By: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            {'id': 'Class', 'label': '🏫 By Class'},
                            {'id': 'Teacher', 'label': '👨‍🏫 By Teacher'},
                            {'id': 'Subject', 'label': '📚 By Subject'},
                          ].map((mode) {
                            final isSel = _viewMode == mode['id'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(mode['label']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppTheme.navyBlue)),
                                selected: isSel,
                                selectedColor: AppTheme.navyBlue,
                                backgroundColor: Colors.grey.shade100,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() => _viewMode = mode['id']!);
                                    _loadTimetable();
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_viewMode == 'Class') ...[
                  // Horizontal Class Switcher Chips (Nursery through Class 10)
                  const Text('Select Class to View Timetable:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _classes.map((c) {
                        final isSel = _selectedClass == c;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(c, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppTheme.navyBlue)),
                            selected: isSel,
                            selectedColor: AppTheme.navyBlue,
                            backgroundColor: AppTheme.lightBlue,
                            checkmarkColor: Colors.white,
                            onSelected: (sel) {
                              if (sel) {
                                setState(() => _selectedClass = c);
                                _loadTimetable();
                                _loadWeeklySchedule();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.lightBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Showing: $_selectedClass Timetable (All 7 Periods)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyBlue),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _showSetupTimetableDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.navyBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.settings_suggest, color: Colors.white, size: 16),
                        label: const Text('Setup / AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ] else if (_viewMode == 'Teacher') ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _allTeachers.any((t) => t.name == _selectedTeacher)
                              ? _selectedTeacher
                              : (_allTeachers.isNotEmpty ? _allTeachers.first.name : null),
                          decoration: const InputDecoration(labelText: 'Select Teacher', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: _allTeachers.map((t) => DropdownMenuItem(value: t.name, child: Text(_getTeacherDisplayName(t.name).split(" (")[0], overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedTeacher = v);
                              _loadTimetable();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _showSetupTimetableDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.navyBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.settings_suggest, color: Colors.white, size: 18),
                        label: const Text('Setup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ] else if (_viewMode == 'Subject') ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _allSubjectsList.contains(_selectedSubject) ? _selectedSubject : _allSubjectsList.first,
                          decoration: const InputDecoration(labelText: 'Select Subject', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: _allSubjectsList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedSubject = v);
                              _loadTimetable();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _showSetupTimetableDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.navyBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.settings_suggest, color: Colors.white, size: 18),
                        label: const Text('Setup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                // Teacher Mode: Strictly locked to teacher identity and schedule
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.navyBlue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.navyBlue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.navyBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Teaching Schedule: ${_getTeacherDisplayName(_selectedTeacher).split(" (")[0]}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Assigned Classes: ${_getTeacherAssignedClasses(_selectedTeacher).join(", ")}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_outlined, size: 12, color: Colors.green),
                            SizedBox(width: 3),
                            Text('My Classes', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Grid View
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentSlots.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No timetable slots found for $_viewMode view', style: const TextStyle(fontSize: 15, color: Colors.grey)),
                          if (isAdmin) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showSetupTimetableDialog,
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyBlue),
                              icon: const Icon(Icons.tune, color: Colors.white),
                              label: const Text('Setup Timetable (AI or Manual)', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ScrollConfiguration(
                      behavior: const NoScrollbarBehavior(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _days.length,
                        itemBuilder: (context, dIdx) {
                          final day = _days[dIdx];
                          final isFriday = day == 'Friday';
                          final daySlots = _currentSlots.where((s) => s.dayOfWeek == day).toList()
                            ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

                          List<Widget> periodCards = [];

                          if (_viewMode == 'Subject') {
                            // Subject Mode: Show all periods across classes where this subject is scheduled
                            if (daySlots.isEmpty) {
                              periodCards.add(
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text('No $_selectedSubject classes on $day', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ),
                              );
                            } else {
                              for (final slot in daySlots) {
                                periodCards.add(_buildUnifiedPeriodCard(
                                  slot: slot,
                                  periodNumber: slot.periodNumber,
                                  isFriday: isFriday,
                                  isAdmin: isAdmin,
                                ));
                              }
                            }
                          } else {
                            // Class View or Teacher View: Show sequential 7 periods
                            for (int p = 1; p <= 7; p++) {
                              final slot = daySlots.where((s) => s.periodNumber == p).firstOrNull;
                              if (slot != null) {
                                periodCards.add(_buildUnifiedPeriodCard(
                                  slot: slot,
                                  periodNumber: p,
                                  isFriday: isFriday,
                                  isAdmin: isAdmin,
                                ));
                              } else {
                                periodCards.add(_buildFreePeriodCard(
                                  periodNumber: p,
                                  isFriday: isFriday,
                                ));
                              }
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.navyBlue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _viewMode == 'Class'
                                              ? '$day • $_selectedClass Timetable'
                                              : (_viewMode == 'Teacher'
                                                  ? '$day • ${_getTeacherDisplayName(_selectedTeacher).split(" (")[0]}'
                                                  : '$day • $_selectedSubject Schedule'),
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyBlue, fontSize: 13),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(_viewMode == 'Teacher' ? '7 Periods' : '${daySlots.length} Periods', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                  const Divider(height: 18),
                                  ScrollConfiguration(
                                    behavior: const NoScrollbarBehavior(),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: periodCards.isEmpty
                                            ? [const Padding(padding: EdgeInsets.all(10), child: Text('No classes scheduled for this day', style: TextStyle(color: Colors.grey, fontSize: 12)))]
                                            : periodCards,
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
        ),
      ],
    );
  }

  Widget _buildUnifiedPeriodCard({
    required TimetableSlotModel slot,
    required int periodNumber,
    required bool isFriday,
    required bool isAdmin,
  }) {
    final times = _calculatePeriodTimes(periodNumber, '08:00 AM', 45, isFriday);
    final teacherDisplay = _getTeacherDisplayName(slot.teacherName);
    final teacherClean = teacherDisplay.split(" (")[0];

    return InkWell(
      onTap: isAdmin ? () => _showEditSlotDialog(slot) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 155,
        height: 115,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.navyBlue.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Number + Timing Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.navyBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Period $periodNumber',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                if (isAdmin)
                  const Icon(Icons.edit, size: 13, color: AppTheme.navyBlue)
                else
                  const Icon(Icons.lock_outline, size: 12, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${slot.startTime.isNotEmpty ? slot.startTime : times.$1} – ${slot.endTime.isNotEmpty ? slot.endTime : times.$2}',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade700),
            ),
            const Divider(height: 10),

            if (_viewMode == 'Class') ...[
              // In Class mode (e.g. Class 7): Show Subject & Teacher in line, university style!
              Row(
                children: [
                  const Text('📚 ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      slot.subjectName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('👨‍🏫 ', style: TextStyle(fontSize: 11)),
                  Expanded(
                    child: Text(
                      teacherClean,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ] else if (_viewMode == 'Teacher') ...[
              // In Teacher mode: Show Class & Subject in line!
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '🏫 ${slot.className}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B5E00),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Text('📚 ', style: TextStyle(fontSize: 11)),
                  Expanded(
                    child: Text(
                      slot.subjectName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // In Subject mode: Show Class & Teacher in line!
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '🏫 ${slot.className}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B5E00),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Text('👨‍🏫 ', style: TextStyle(fontSize: 11)),
                  Expanded(
                    child: Text(
                      teacherClean,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFreePeriodCard({
    required int periodNumber,
    required bool isFriday,
  }) {
    final times = _calculatePeriodTimes(periodNumber, '08:00 AM', 45, isFriday);

    return Container(
      width: 140,
      height: 115,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Period $periodNumber',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${times.$1} – ${times.$2}',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.coffee_rounded, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                'Free Period',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Weekly Learning Schedule ───────────────────────────────────────
  Widget _buildWeeklyScheduleTab() {
    final isAdmin = _isAdmin;
    final isTeacher = _isTeacher;

    if (isTeacher) {
      final cleanLoggedIn = _loggedInTeacherName.toLowerCase().replaceAll('sir', '').replaceAll('miss', '').replaceAll('teacher', '').trim();
      final matched = _allTeachers.where((t) => t.name.toLowerCase().contains(cleanLoggedIn)).firstOrNull;
      _selectedWeeklyTeacher = matched?.name ?? (_loggedInTeacherName.isNotEmpty ? _loggedInTeacherName : _selectedWeeklyTeacher);
      _weeklyFilterMode = 'Teacher';
    }

    final List<String> teacherClasses = _getTeacherAssignedClasses(_selectedWeeklyTeacher);
    if (!teacherClasses.contains(_selectedClass)) {
      _selectedClass = teacherClasses.isNotEmpty ? teacherClasses.first : 'Class 5';
    }

    if (isTeacher) {
      _availableSubjects = _getTeacherSubjects(_selectedWeeklyTeacher, _selectedClass);
    }

    // Determine the active subject filter
    final activeSubject = _weeklyFilterMode == 'Subject' ? _selectedWeeklySubject : _weeklySubjectFilter;
    final List<String> subjectsToShow = isTeacher
        ? (_weeklySubjectFilter != 'All Subjects' && _availableSubjects.contains(_weeklySubjectFilter)
            ? [_weeklySubjectFilter]
            : _availableSubjects)
        : (activeSubject == 'All Subjects'
            ? _availableSubjects
            : _availableSubjects.where((s) => s.toLowerCase() == activeSubject.toLowerCase()).toList().isEmpty
                ? [activeSubject]
                : _availableSubjects.where((s) => s.toLowerCase() == activeSubject.toLowerCase()).toList());

    return Column(
      children: [
        // Controls / Filters Bar (Accessible to all: Filter By Class, Teacher, Subject)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isTeacher) ...[
                // Restricted Teacher Header: Strictly locked to teacher identity
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.navyBlue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.navyBlue.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, size: 14, color: AppTheme.navyBlue),
                          const SizedBox(width: 4),
                          Text(
                            'My Diary: ${_getTeacherDisplayName(_selectedWeeklyTeacher).split(' (')[0]}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyBlue),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveWeeklySchedule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navyBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.save, color: Colors.white, size: 16),
                      label: const Text('Save & Sync', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        value: teacherClasses.contains(_selectedClass) ? _selectedClass : teacherClasses.first,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Class',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: teacherClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedClass = v;
                              _updateWeeklyTeacherSubjectsAndClass();
                              _activeEditingSubjectKey = '';
                            });
                            _loadWeeklySchedule();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        value: (_weeklySubjectFilter == 'All Subjects' || _availableSubjects.contains(_weeklySubjectFilter))
                            ? _weeklySubjectFilter
                            : 'All Subjects',
                        decoration: const InputDecoration(
                          labelText: 'My Subject',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        items: ['All Subjects', ..._availableSubjects].map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _weeklySubjectFilter = v;
                              _activeEditingSubjectKey = '';
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Admin Mode: Full flexible switcher
                Row(
                  children: [
                    const Text('Filter By: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['Class', 'Teacher', 'Subject'].map((mode) {
                            final isSel = _weeklyFilterMode == mode;
                            String icon = mode == 'Class' ? '🏫 ' : (mode == 'Teacher' ? '👨‍🏫 ' : '📚 ');
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text('$icon$mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppTheme.navyBlue)),
                                selected: isSel,
                                selectedColor: AppTheme.navyBlue,
                                backgroundColor: Colors.grey.shade100,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _weeklyFilterMode = mode;
                                      _activeEditingSubjectKey = '';
                                      if (mode == 'Class') {
                                        _availableSubjects = _getSubjectsForClass(_selectedClass);
                                      } else if (mode == 'Teacher') {
                                        _updateWeeklyTeacherSubjectsAndClass();
                                      } else if (mode == 'Subject') {
                                        _weeklySubjectFilter = _selectedWeeklySubject;
                                      }
                                    });
                                    _loadWeeklySchedule();
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveWeeklySchedule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navyBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.save, color: Colors.white, size: 16),
                      label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Row 2: Selectors according to filter mode
                if (_weeklyFilterMode == 'Class') ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          value: _classes.contains(_selectedClass) ? _selectedClass : _classes.first,
                          decoration: const InputDecoration(
                            labelText: 'Select Class',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedClass = v;
                                _availableSubjects = _getSubjectsForClass(v);
                                _activeEditingSubjectKey = '';
                              });
                              _loadWeeklySchedule();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          value: (_weeklySubjectFilter == 'All Subjects' || _availableSubjects.contains(_weeklySubjectFilter))
                              ? _weeklySubjectFilter
                              : 'All Subjects',
                          decoration: const InputDecoration(
                            labelText: 'Filter Subject',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: ['All Subjects', ..._availableSubjects].map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _weeklySubjectFilter = v;
                                _activeEditingSubjectKey = '';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ] else if (_weeklyFilterMode == 'Teacher') ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          value: _allTeachers.any((t) => t.name == _selectedWeeklyTeacher)
                              ? _selectedWeeklyTeacher
                              : (_allTeachers.isNotEmpty ? _allTeachers.first.name : 'Sir Haroon'),
                          decoration: const InputDecoration(
                            labelText: 'Select Teacher',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: _allTeachers
                              .map((t) => DropdownMenuItem(
                                    value: t.name,
                                    child: Text(_getTeacherDisplayName(t.name).split(" (")[0], overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedWeeklyTeacher = v;
                                _updateWeeklyTeacherSubjectsAndClass();
                                _activeEditingSubjectKey = '';
                              });
                              _loadWeeklySchedule();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: teacherClasses.contains(_selectedClass) ? _selectedClass : teacherClasses.first,
                          decoration: const InputDecoration(
                            labelText: 'Class',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: teacherClasses
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedClass = v;
                                _activeEditingSubjectKey = '';
                              });
                              _loadWeeklySchedule();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: (_weeklySubjectFilter == 'All Subjects' || _availableSubjects.contains(_weeklySubjectFilter))
                              ? _weeklySubjectFilter
                              : 'All Subjects',
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          items: ['All Subjects', ..._availableSubjects].map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _weeklySubjectFilter = v;
                                _activeEditingSubjectKey = '';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Subject mode
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          value: _allSubjectsList.contains(_selectedWeeklySubject) ? _selectedWeeklySubject : _allSubjectsList.first,
                          decoration: const InputDecoration(
                            labelText: 'Select Subject',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: _allSubjectsList.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedWeeklySubject = v;
                                _weeklySubjectFilter = v;
                                _activeEditingSubjectKey = '';
                              });
                              _loadWeeklySchedule();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          value: _classes.contains(_selectedClass) ? _selectedClass : _classes.first,
                          decoration: const InputDecoration(
                            labelText: 'For Class',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedClass = v;
                                _activeEditingSubjectKey = '';
                              });
                              _loadWeeklySchedule();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              if (_weeklySubjectFilter != 'All Subjects' && _weeklyFilterMode != 'Subject') ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() => _weeklySubjectFilter = 'All Subjects'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.navyBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Showing only: $_weeklySubjectFilter', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navyBlue)),
                        const SizedBox(width: 6),
                        const Icon(Icons.close, size: 14, color: AppTheme.navyBlue),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // List of days with sleek horizontal subject bars
        Expanded(
          child: ScrollConfiguration(
            behavior: const NoScrollbarBehavior(),
            child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _days.length,
            itemBuilder: (context, dIdx) {
              final day = _days[dIdx];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.navyBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              day,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyBlue, fontSize: 14),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            subjectsToShow.length == 1
                                ? 'Subject: ${subjectsToShow.first}'
                                : '${subjectsToShow.length} Subject Topics',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      // Horizontal subject bars with on-click reveal of mic and text editing
                      ...subjectsToShow.map((sub) {
                        final key = '${day}_$sub';
                        final currentTopic = _weeklySchedule[day]?[sub] ?? 'Standard SNC Lesson';
                        final isEditing = _activeEditingSubjectKey == key;

                        if (!_subjectControllers.containsKey(key)) {
                          _subjectControllers[key] = TextEditingController(text: currentTopic);
                        }

                        if (!isEditing) {
                          // Unselected: Clean horizontal bar. No mic and no lang toggle visible!
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _activeEditingSubjectKey = key;
                                _subjectControllers[key]!.text = _weeklySchedule[day]?[sub] ?? currentTopic;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _getSubjectColor(sub).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(_getSubjectIcon(sub), size: 16, color: _getSubjectColor(sub)),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      sub,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _getSubjectColor(sub)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      currentTopic,
                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.edit_note_rounded, size: 18, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          );
                        }

                        // Selected: Active editing container showing input, mic button, and language switch toggle
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.navyBlue, width: 1.5),
                            boxShadow: [
                              BoxShadow(color: AppTheme.navyBlue.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _getSubjectColor(sub).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(_getSubjectIcon(sub), size: 16, color: _getSubjectColor(sub)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(sub, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _getSubjectColor(sub))),
                                  const Spacer(),
                                  // Language toggle for STT dictation
                                  InkWell(
                                    onTap: () => setState(() => _subjectDictationLang = _subjectDictationLang == 'Urdu' ? 'English' : 'Urdu'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.navyBlue.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _subjectDictationLang == 'Urdu' ? '🇵🇰 اردو' : '🇬🇧 Eng',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Microphone dictation icon
                                  IconButton(
                                    icon: Icon(_isListening && _activeEditingSubjectKey == key ? Icons.mic : Icons.mic_none),
                                    color: _isListening && _activeEditingSubjectKey == key ? Colors.red : AppTheme.navyBlue,
                                    iconSize: 22,
                                    tooltip: 'Speak into topic ($_subjectDictationLang)',
                                    onPressed: () => _toggleSubjectDictation(day, sub),
                                  ),
                                  const SizedBox(width: 2),
                                  // Done / Collapse icon
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.green),
                                    iconSize: 22,
                                    tooltip: 'Done',
                                    onPressed: () {
                                      setState(() {
                                        _weeklySchedule[day]?[sub] = _subjectControllers[key]?.text ?? currentTopic;
                                        _activeEditingSubjectKey = '';
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _subjectControllers[key],
                                autofocus: true,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  hintText: _subjectDictationLang == 'Urdu' ? 'سبق کا عنوان بولیں یا درج کریں...' : 'Enter or speak topic...',
                                ),
                                onChanged: (val) {
                                  _weeklySchedule[day]?[sub] = val;
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
  }
}
