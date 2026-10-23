// lib/widgets/ustad_bol_sheet.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../providers/student_provider.dart';
import '../providers/auth_provider.dart';
import '../models/student_model.dart';

// Destination screens
import '../screens/teacher/homework_screen.dart';
import '../screens/teacher/attendance_screen.dart';
import '../screens/teacher/lesson_planner_screen.dart';
import '../screens/teacher/paper_grader_screen.dart';
import '../screens/teacher/oral_exam_screen.dart';
import '../screens/teacher/roleplay_screen.dart';
import '../screens/teacher/stem_hunt_screen.dart';
import '../screens/teacher/class_marks_screen.dart';
import '../screens/admin/timetable_screen.dart';
import '../screens/admin/report_card_screen.dart';
import '../screens/admin/assembly_screen.dart';
import '../screens/admin/certificate_screen.dart';
import '../screens/admin/parent_comms_screen.dart';
import '../screens/admin/marks_admin_screen.dart';
import '../screens/admin/fee_management_screen.dart';
import '../screens/admin/student_management_screen.dart';
import '../screens/admin/staff_attendance_screen.dart';
import '../screens/admin/settings_screen.dart';

class UstadBolSheet extends StatefulWidget {
  final String? activeClass;

  const UstadBolSheet({super.key, this.activeClass});

  @override
  State<UstadBolSheet> createState() => _UstadBolSheetState();
}

class _UstadBolSheetState extends State<UstadBolSheet> with TickerProviderStateMixin {
  late TabController _tabController;

  // Speech & TTS
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isProcessing = false;
  String _spokenText = '';
  String _aiFeedbackUrdu = '';
  String _aiFeedbackEnglish = '';
  String _assistantLanguage = 'ur_PK'; // 'ur_PK' or 'en_US'

  // Animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Voice Note Tab State
  StudentModel? _selectedStudent;
  bool _isListeningNote = false;
  String _noteTranscript = '';
  Map<String, dynamic>? _formalizedNote;
  String _noteWhatsAppLanguage = 'Urdu'; // 'Urdu' or 'English'

  List<String> get _currentQuickCommandsUrdu {
    final auth = context.read<AuthProvider>();
    if (auth.isAdmin) {
      return [
        'ماسٹر ٹائم ٹیبل دیکھو',
        'سالانہ امتحانی رپورٹ کارڈ',
        'طلباء کے اعزازی سرٹیفکیٹ',
        'امتحانی نمبرات اور رزلٹ',
        'فیس مینجمنٹ اور بقایا جات',
        'طلباء کا ریکارڈ اور داخلے',
        'اساتذہ و عملہ کی حاضری',
        'صبح کی اسمبلی اور حدیث',
        'والدین سے رابطہ اور پیغامات',
      ];
    }
    if (auth.user?.role == 'parent') {
      return [
        'بچے کا ٹائم ٹیبل',
        'امتحانی رپورٹ کارڈ',
        'فیس کا چالان اور ریکارڈ',
        'روزانہ کی حاضری',
        'ہوم ورک اور ڈائری',
        'اعزازی سرٹیفکیٹ',
      ];
    }
    return [
      'کلاس حاضری لگاؤ',
      'پانچویں جماعت کا ہوم ورک',
      'امتحانی نمبر درج کرو',
      'پیپر اور ریاضی چیک کرو',
      'یکساں نصاب کا لیسن پلان',
      'میرا تدریسی ٹائم ٹیبل',
      'زبانی امتحان شروع کرو',
      'قائد اعظم سے مکالمہ',
      'صبح کی کلاس گفتگو اور حدیث',
    ];
  }

  List<String> get _currentQuickCommandsEnglish {
    final auth = context.read<AuthProvider>();
    if (auth.isAdmin) {
      return [
        'Master Timetable',
        'Terminal Report Card',
        'Merit Certificates',
        'Exam Marks & Results',
        'Fee Management & Dues',
        'Student Records & Admissions',
        'Staff Attendance',
        'Morning Assembly & Hadith',
        'Parent Comms WhatsApp',
      ];
    }
    if (auth.user?.role == 'parent') {
      return [
        'Class Timetable',
        'Report Card',
        'Fee Status',
        'Daily Attendance',
        'Homework Diary',
        'Merit Certificate',
      ];
    }
    return [
      'Mark Attendance',
      'Class 5 Homework',
      'Enter Class Marks',
      'Grade Papers & Math',
      'SNC Lesson Plan',
      'My Teaching Timetable',
      'Voice Oral Exam',
      'Quaid-e-Azam Roleplay',
      'Class Morning Talk',
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _initSpeech();
    _initTts();

    final students = context.read<StudentProvider>().students;
    if (students.isNotEmpty) {
      _selectedStudent = students.first;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseCtrl.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _speechAvailable = false;
        if (mounted) setState(() {});
        return;
      }
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
                _isListeningNote = false;
              });
              if (_tabController.index == 0 && _spokenText.trim().isNotEmpty && !_isProcessing) {
                _executeCommand(_spokenText);
              } else if (_tabController.index == 1 && _noteTranscript.trim().isNotEmpty && !_isProcessing) {
                _processNote();
              }
            }
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _isListeningNote = false;
            });
          }
        },
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage(_assistantLanguage == 'ur_PK' ? 'ur-PK' : 'en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  Future<void> _speakReply() async {
    try {
      await _tts.stop();
      // User requirement: Voice TTS output should speak strictly "JI USTAD Ji" and nothing more
      if (_assistantLanguage == 'en_US') {
        await _tts.setLanguage('en-US');
        await _tts.speak('Ji Ustad Ji!');
      } else {
        await _tts.setLanguage('ur-PK');
        await _tts.speak('جی استاد جی!');
      }
    } catch (_) {}
  }

  Future<void> _startListeningCommand() async {
    if (_isProcessing) return;
    if (!_speechAvailable) {
      await _initSpeech();
    }
    if (!_speechAvailable) {
      setState(() {
        _aiFeedbackUrdu = 'مائیکروفون کی اجازت درکار ہے۔ برائے مہربانی سیٹنگز میں اجازت دیں۔';
        _aiFeedbackEnglish = 'Microphone permission required. Please enable it in Settings.';
      });
      return;
    }
    setState(() {
      _isListening = true;
      _spokenText = '';
      _aiFeedbackUrdu = '';
      _aiFeedbackEnglish = '';
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _spokenText = result.recognizedWords;
            });
            if (result.finalResult && _spokenText.trim().isNotEmpty && !_isProcessing) {
              _executeCommand(_spokenText);
            }
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          cancelOnError: false,
          partialResults: true,
          localeId: _assistantLanguage,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    setState(() {
      _isListening = false;
      _isListeningNote = false;
    });
    if (_spokenText.trim().isNotEmpty && !_isProcessing) {
      _executeCommand(_spokenText);
    }
  }

  Future<void> _executeCommand(String query) async {
    if (query.trim().isEmpty || _isProcessing) return;

    try {
      await _speech.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _isListening = false;
      _isProcessing = true;
      _spokenText = query;
    });

    final auth = context.read<AuthProvider>();
    final currentRole = auth.isAdmin
        ? 'admin'
        : (auth.isTeacher
            ? 'teacher'
            : (auth.user?.role == 'parent' ? 'parent' : (auth.user?.role ?? 'teacher')));

    try {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: query,
        currentRole: currentRole,
        activeClass: widget.activeClass ?? 'Class 5',
      );

      final replyUrdu = res['spoken_reply_urdu'] ?? 'جی استاد جی! آپ کیا کھولنا چاہتے ہیں؟';
      final replyEn = res['spoken_reply_english'] ?? 'Ji Ustad Ji! What would you like to open?';
      final route = res['target_route'] ?? 'none';

      // 1. Guard Admin from Teacher-Only routes (specifically Homework!)
      if (auth.isAdmin && route == 'homework') {
        const restrictedUrdu = 'معذرت ایڈمن صاحب! ہوم ورک کا سیکشن صرف اساتذہ کے لیے ہے۔';
        const restrictedEn = 'Access Restricted: Homework management is only accessible in Teacher mode.';
        setState(() {
          _aiFeedbackUrdu = restrictedUrdu;
          _aiFeedbackEnglish = restrictedEn;
          _isProcessing = false;
        });
        _speakReply();
        return;
      }

      // 2. Guard Teacher from Admin-Only routes
      if (auth.isTeacher &&
          (route == 'certificate' ||
              route == 'report_card' ||
              route == 'fee' ||
              route == 'fee_management' ||
              route == 'students' ||
              route == 'student_management' ||
              route == 'staff_attendance' ||
              route == 'admin')) {
        const restrictedUrdu = 'معذرت استاد جی! یہ اختیارات صرف ایڈمن اور پرنسپل کے لیے مخصوص ہیں۔';
        const restrictedEn = 'Access Restricted: This feature is only accessible by School Admin & Principal.';
        setState(() {
          _aiFeedbackUrdu = restrictedUrdu;
          _aiFeedbackEnglish = restrictedEn;
          _isProcessing = false;
        });
        _speakReply();
        return;
      }

      // 3. Guard Parent from staff/admin operations
      if (auth.user?.role == 'parent' &&
          (route == 'staff_attendance' ||
              route == 'paper_grader' ||
              route == 'lesson_plan' ||
              route == 'students' ||
              route == 'student_management' ||
              route == 'settings')) {
        const restrictedUrdu = 'معذرت! یہ اختیارات صرف اسکول انتظامیہ اور اساتذہ کے لیے ہیں۔';
        const restrictedEn = 'Access Restricted: This feature is only accessible by School Staff & Administration.';
        setState(() {
          _aiFeedbackUrdu = restrictedUrdu;
          _aiFeedbackEnglish = restrictedEn;
          _isProcessing = false;
        });
        _speakReply();
        return;
      }

      // 4. If unrecognized or none, stay on sheet and politely prompt
      if (route == 'none' || route.isEmpty) {
        setState(() {
          _aiFeedbackUrdu = replyUrdu;
          _aiFeedbackEnglish = replyEn;
          _isProcessing = false;
        });
        _speakReply();
        return;
      }

      // 5. Valid command confirmed
      setState(() {
        _aiFeedbackUrdu = replyUrdu;
        _aiFeedbackEnglish = replyEn;
      });

      _speakReply();

      // Brief delay for user to hear "Ji Ustad Ji!", then navigate
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      Navigator.pop(context); // close bottom sheet
      _navigateToRoute(route);
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiFeedbackUrdu = 'جی استاد جی! آپ کیا کھولنا چاہتے ہیں؟ برائے مہربانی نیچے دیے گئے آپشنز میں سے منتخب کریں۔';
          _aiFeedbackEnglish = 'Ji Ustad Ji! What would you like to open? Please select from available commands below.';
          _isProcessing = false;
        });
        _speakReply();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _navigateToRoute(String route) {
    if (route == 'none' || route.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final isTeacher = auth.isTeacher;

    if (isAdmin && route == 'homework') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Homework section is for teachers only.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (isTeacher &&
        (route == 'certificate' ||
            route == 'report_card' ||
            route == 'fee' ||
            route == 'fee_management' ||
            route == 'students' ||
            route == 'student_management' ||
            route == 'staff_attendance' ||
            route == 'admin')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Access Restricted: This feature is only accessible by School Admin & Principal.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Widget target;
    switch (route) {
      case 'homework':
        target = const HomeworkScreen();
        break;
      case 'attendance':
        target = const AttendanceScreen();
        break;
      case 'staff_attendance':
        target = const StaffAttendanceScreen();
        break;
      case 'marks':
      case 'class_marks':
      case 'marks_admin':
        target = isAdmin ? const MarksAdminScreen() : const ClassMarksScreen();
        break;
      case 'lesson_plan':
        target = const LessonPlannerScreen();
        break;
      case 'paper_grader':
        target = const PaperGraderScreen();
        break;
      case 'oral_exam':
        target = const OralExamScreen();
        break;
      case 'roleplay':
        target = const RoleplayScreen();
        break;
      case 'stem_hunt':
        target = const StemHuntScreen();
        break;
      case 'timetable':
        target = isTeacher
            ? TimetableScreen(
                initialClass: auth.user?.assignedClass ?? widget.activeClass ?? 'Class 5',
                initialTab: 0,
              )
            : const TimetableScreen();
        break;
      case 'report_card':
        target = const ReportCardScreen();
        break;
      case 'assembly':
        target = const AssemblyScreen();
        break;
      case 'certificate':
        target = const CertificateScreen();
        break;
      case 'fee':
      case 'fee_management':
        target = const FeeManagementScreen();
        break;
      case 'students':
      case 'student_management':
        target = const StudentManagementScreen();
        break;
      case 'parent_comms':
        target = const ParentCommsScreen();
        break;
      case 'settings':
        target = const SettingsScreen();
        break;
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => target));
  }

  // ── Voice-to-Admin Note Logic ─────────────────────────────────────────────

  Future<void> _startListeningNote() async {
    if (_isProcessing) return;
    if (!_speechAvailable) {
      await _initSpeech();
    }
    if (!_speechAvailable) return;

    setState(() {
      _isListeningNote = true;
      _noteTranscript = '';
      _formalizedNote = null;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _noteTranscript = result.recognizedWords;
            });
            if (result.finalResult && _noteTranscript.trim().isNotEmpty && !_isProcessing) {
              _processNote();
            }
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          cancelOnError: false,
          partialResults: true,
          localeId: _assistantLanguage,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _isListeningNote = false);
    }
  }

  Future<void> _processNote() async {
    if (_noteTranscript.trim().isEmpty || _selectedStudent == null) return;
    setState(() => _isProcessing = true);

    try {
      final res = await ApiService.instance.processVoiceNote(
        studentName: _selectedStudent!.name,
        className: _selectedStudent!.className,
        transcript: _noteTranscript,
      );
      setState(() => _formalizedNote = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error filing note: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _shareNoteOnWhatsApp() async {
    if (_formalizedNote == null || _selectedStudent == null) return;
    final parentPhone = _selectedStudent!.whatsappNumber ?? _selectedStudent!.phone;
    final String msg;

    if (_noteWhatsAppLanguage == 'English') {
      msg = '''Dear Respected Parents, Assalam-o-Alaikum!
Official Student Observation Note regarding ${_selectedStudent!.name} (Class ${_selectedStudent!.className}) from Sublime Grammar School:

📋 Official Record:
"${_formalizedNote!['formalized_english_note']}"

Recommended Action: ${_formalizedNote!['recommended_action'] ?? 'Regular follow-up with teacher.'}

Thank you,
Sublime Grammar School Administration''';
    } else {
      msg = '''محترم والدین، السلام علیکم!
سبلائم گرامر اسکول کے استاد کی طرف سے ${_selectedStudent!.name} (جماعت ${_selectedStudent!.className}) کے متعلق زبانی مشاہداتی رپورٹ:

📋 اندراج:
${_formalizedNote!['formalized_urdu_note']}

📌 انگریزی ریکارڈ:
"${_formalizedNote!['formalized_english_note']}"

توجہ و رہنمائی: ${_formalizedNote!['recommended_action']}

شکریہ،
انتظامیہ سبلائم گرامر اسکول''';
    }

    await WhatsAppService.showShareDialog(
      context: context,
      title: 'Forward Note - ${_selectedStudent!.name}',
      subtitle: 'Class: ${_selectedStudent!.className} • Language: $_noteWhatsAppLanguage',
      message: msg,
      initialPhone: parentPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppTheme.offWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AppTheme.navyBlue,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: AppTheme.accentGold, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎙️ استاد بول — Ustad Bol',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      Text(
                        'Hands-Free Voice Commander & Voice-to-Admin Notes',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: AppTheme.navyBlue,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accentGold,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(icon: Icon(Icons.record_voice_over, size: 18), text: 'Voice Commands'),
                Tab(icon: Icon(Icons.note_alt, size: 18), text: 'Voice-to-Admin Note'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVoiceCommanderTab(),
                _buildVoiceNoteTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Voice Commands ────────────────────────────────────────────────

  Widget _buildVoiceCommanderTab() {
    final commands = _assistantLanguage == 'ur_PK' ? _currentQuickCommandsUrdu : _currentQuickCommandsEnglish;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Language selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('🇵🇰 اردو (Urdu)'),
                selected: _assistantLanguage == 'ur_PK',
                selectedColor: AppTheme.navyBlue,
                labelStyle: TextStyle(
                  color: _assistantLanguage == 'ur_PK' ? Colors.white : AppTheme.navyBlue,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _assistantLanguage = 'ur_PK');
                    _initTts();
                  }
                },
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text('🇬🇧 English'),
                selected: _assistantLanguage == 'en_US',
                selectedColor: AppTheme.navyBlue,
                labelStyle: TextStyle(
                  color: _assistantLanguage == 'en_US' ? Colors.white : AppTheme.navyBlue,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _assistantLanguage = 'en_US');
                    _initTts();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _assistantLanguage == 'ur_PK'
                ? 'کلاس اور اسکول چلائیں ہاتھ لگائے بغیر!'
                : 'Operate school & class completely hands-free!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _assistantLanguage == 'ur_PK' ? 'Noto Nastaliq Urdu' : null,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.navyBlue,
              height: 1.8,
            ),
          ),
          Text(
            _assistantLanguage == 'ur_PK'
                ? 'اردو یا انگریزی میں بولیں، مطلوبہ ٹول فوراً کھل جائے گا'
                : 'Speak commands in English or Urdu to open features instantly',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Pulsing Mic Button
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListeningCommand,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isListening ? _pulseAnim.value : 1.0,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? Colors.red : AppTheme.navyBlue,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? Colors.red : AppTheme.navyBlue).withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: _isListening ? 6 : 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isListening
                ? (_assistantLanguage == 'ur_PK' ? 'سن رہا ہوں... فرمائیے!' : 'Listening... Speak now!')
                : (_isProcessing ? 'Qwen-Max Processing...' : (_assistantLanguage == 'ur_PK' ? 'مائیک پر ٹیپ کریں اور بولیں' : 'Tap Mic to Speak')),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _isListening ? Colors.red : AppTheme.navyBlue,
              fontSize: 14,
            ),
          ),

          // Spoken Text Box
          if (_spokenText.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recognized Speech:', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_spokenText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],

          // AI Spoken Feedback Display
          if (_aiFeedbackUrdu.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentGold),
              ),
              child: Column(
                children: [
                  Text(
                    _aiFeedbackUrdu,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Noto Nastaliq Urdu',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navyBlue,
                      height: 1.8,
                    ),
                  ),
                  Text(
                    _aiFeedbackEnglish,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _assistantLanguage == 'ur_PK' ? '💡 یا فوری وائس کمانڈ منتخب کریں:' : '💡 Or Tap a Quick Voice Command:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 10),

          // Suggestion Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: commands.map((cmd) {
              return ActionChip(
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade300),
                label: Text(cmd, style: const TextStyle(fontSize: 12, color: AppTheme.navyBlue, fontWeight: FontWeight.w600)),
                avatar: const Icon(Icons.arrow_forward, size: 14, color: AppTheme.accentGold),
                onPressed: () => _executeCommand(cmd),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Voice-to-Admin Note ───────────────────────────────────────────

  Widget _buildVoiceNoteTab() {
    final auth = context.watch<AuthProvider>();
    final allStudents = context.watch<StudentProvider>().students;
    // Strict restriction: only show students tied with that teacher if teacher is logged in
    final students = (auth.isTeacher && auth.user?.assignedClass != null)
        ? allStudents.where((s) => s.className.toLowerCase() == auth.user!.assignedClass!.toLowerCase()).toList()
        : allStudents;

    if (_selectedStudent == null || !students.contains(_selectedStudent)) {
      if (students.isNotEmpty) {
        _selectedStudent = students.first;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🗣️ Voice-to-Admin Note Filing',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.navyBlue),
          ),
          Text(
            auth.isTeacher && auth.user?.assignedClass != null
                ? 'Showing students for your assigned class: ${auth.user!.assignedClass}'
                : 'Record a 30-sec observation — AI transcribes, formalizes in Urdu & English, and files it.',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<StudentModel>(
            value: _selectedStudent,
            decoration: InputDecoration(
              labelText: auth.isTeacher ? 'Select Assigned Student (${auth.user?.assignedClass})' : 'Select Student',
              border: const OutlineInputBorder(),
            ),
            items: students.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.className})'))).toList(),
            onChanged: (v) => setState(() => _selectedStudent = v),
          ),
          const SizedBox(height: 18),

          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isListeningNote ? _stopListening : _startListeningNote,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListeningNote ? Colors.red : AppTheme.accentGold,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListeningNote ? Colors.red : AppTheme.accentGold).withValues(alpha: 0.35),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListeningNote ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isListeningNote
                      ? (_assistantLanguage == 'ur_PK' ? 'ریکارڈ ہو رہا ہے... فرمائیں!' : 'Recording... Speak now!')
                      : (_assistantLanguage == 'ur_PK' ? 'بولنے کے لیے ٹیپ کریں' : 'Tap to Record Spoken Note'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isListeningNote ? Colors.red : AppTheme.navyBlue,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          if (_noteTranscript.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Spoken Transcript:', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_noteTranscript, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  if (_formalizedNote == null)
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processNote,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyBlue),
                      icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                      label: const Text('Formalize with AI', style: TextStyle(color: Colors.white)),
                    ),
                ],
              ),
            ),
          ],

          if (_formalizedNote != null) ...[
            const SizedBox(height: 18),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Official Dossier Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Text(
                            _formalizedNote!['category'] ?? 'Academic',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    const Text('English Academic Record:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(_formalizedNote!['formalized_english_note'] ?? '', style: const TextStyle(fontSize: 13, height: 1.3)),
                    const SizedBox(height: 12),
                    const Text('Urdu Official Record:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      _formalizedNote!['formalized_urdu_note'] ?? '',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'Noto Nastaliq Urdu',
                        fontSize: 14,
                        height: 1.8,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Recommended Action: ${_formalizedNote!['recommended_action'] ?? ''}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.black87)),
                    const SizedBox(height: 16),

                    // WhatsApp Message Language Selector
                    Row(
                      children: [
                        const Text('WhatsApp Language: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyBlue)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('🇵🇰 اردو (Urdu)', style: TextStyle(fontSize: 11)),
                          selected: _noteWhatsAppLanguage == 'Urdu',
                          selectedColor: AppTheme.navyBlue,
                          labelStyle: TextStyle(
                            color: _noteWhatsAppLanguage == 'Urdu' ? Colors.white : AppTheme.navyBlue,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (sel) {
                            if (sel) setState(() => _noteWhatsAppLanguage = 'Urdu');
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('🇬🇧 English', style: TextStyle(fontSize: 11)),
                          selected: _noteWhatsAppLanguage == 'English',
                          selectedColor: AppTheme.navyBlue,
                          labelStyle: TextStyle(
                            color: _noteWhatsAppLanguage == 'English' ? Colors.white : AppTheme.navyBlue,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (sel) {
                            if (sel) setState(() => _noteWhatsAppLanguage = 'English');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _shareNoteOnWhatsApp,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                        icon: const Icon(Icons.share, color: Colors.white, size: 18),
                        label: Text('Forward to Parent via WhatsApp ($_noteWhatsAppLanguage)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
