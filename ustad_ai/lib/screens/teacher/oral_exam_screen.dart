// lib/screens/teacher/oral_exam_screen.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/student_model.dart';
import '../../models/marks_model.dart';
import '../../services/api_service.dart';
import '../../database/db_helper.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/network_banner.dart';

class OralExamScreen extends StatefulWidget {
  const OralExamScreen({super.key});

  @override
  State<OralExamScreen> createState() => _OralExamScreenState();
}

class _OralExamScreenState extends State<OralExamScreen>
    with SingleTickerProviderStateMixin {
  // State
  String _selectedClass = 'Class 5';
  StudentModel? _selectedStudent;
  List<StudentModel> _students = [];
  final TextEditingController _questionCtrl = TextEditingController();
  final TextEditingController _answerCtrl = TextEditingController();
  String _subject = 'General Science';
  String _voiceLang = 'ur_PK'; // 'ur_PK' | 'en_US'

  // Speech & TTS
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isListeningQuestion = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  String _currentSpeechText = '';
  int _lastWordOffset = 0;

  // AI Result
  Map<String, dynamic>? _result;
  bool _isGrading = false;

  // Animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final List<String> _sampleQuestions = [
    'Explain the process of photosynthesis.',
    'What are the primary states of matter?',
    'What did Quaid-e-Azam stand for?',
    'How do plants absorb water from the soil?',
    'پودے اپنی خوراک کیسے بناتے ہیں؟',
    'پاکستان کے قیام کے اہم مقاصد کیا تھے؟',
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isTeacher && auth.currentUser?.assignedClass != null) {
      _selectedClass = auth.currentUser!.assignedClass!;
    }
    _initSpeech();
    _initTts();
    _loadStudents();

    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() {
              _isListening = false;
              _isListeningQuestion = false;
            });
          }
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _isListeningQuestion = false;
          });
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _initTts() async {
    await _configureTts();
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
          _lastWordOffset = 0;
        });
      }
    });
    _tts.setProgressHandler((String text, int startOffset, int endOffset, String word) {
      _lastWordOffset = startOffset;
    });
  }

  Future<void> _configureTts() async {
    final isUrdu = _voiceLang == 'ur_PK';
    await _tts.setLanguage(isUrdu ? 'ur-PK' : 'en-US');
    await _tts.setSpeechRate(isUrdu ? 0.38 : 0.44);
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.95);
  }

  Future<void> _speak(String text) async {
    _currentSpeechText = text;
    _lastWordOffset = 0;
    await _configureTts();
    setState(() {
      _isSpeaking = true;
      _isPaused = false;
    });
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _pauseAudio() async {
    if (_isSpeaking && !_isPaused) {
      await _tts.stop();
      setState(() {
        _isSpeaking = false;
        _isPaused = true;
      });
    }
  }

  Future<void> _resumeAudio() async {
    if (_isPaused && _currentSpeechText.isNotEmpty) {
      final resumeText = _lastWordOffset < _currentSpeechText.length
          ? _currentSpeechText.substring(_lastWordOffset)
          : _currentSpeechText;
      await _configureTts();
      setState(() {
        _isSpeaking = true;
        _isPaused = false;
      });
      await _tts.speak(resumeText);
    } else if (!_isSpeaking && _currentSpeechText.isNotEmpty) {
      await _speak(_currentSpeechText);
    }
  }

  Future<void> _stopAudio() async {
    await _tts.stop();
    setState(() {
      _isSpeaking = false;
      _isPaused = false;
      _lastWordOffset = 0;
    });
  }

  Future<void> _loadStudents() async {
    final students = await DatabaseHelper.instance.getStudentsByClass(_selectedClass);
    setState(() {
      _students = students;
      _selectedStudent = students.isNotEmpty ? students.first : null;
    });
  }

  Future<void> _toggleListeningQuestion() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone not available. Please grant mic permission.')),
      );
      return;
    }
    if (_isListeningQuestion) {
      await _speech.stop();
      setState(() => _isListeningQuestion = false);
    } else {
      if (_isListening) {
        await _speech.stop();
        setState(() => _isListening = false);
      }
      setState(() {
        _isListeningQuestion = true;
      });
      await _speech.listen(
        localeId: _voiceLang,
        onResult: (r) {
          setState(() {
            _questionCtrl.text = r.recognizedWords;
          });
          if (r.finalResult) {
            setState(() => _isListeningQuestion = false);
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 15),
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
        ),
      );
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone not available. Please grant mic permission.')),
      );
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() {
        _isListening = true;
        _result = null;
      });
      await _speech.listen(
        localeId: _voiceLang,
        onResult: (r) {
          setState(() {
            _answerCtrl.text = r.recognizedWords;
          });
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 15),
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
        ),
      );
    }
  }

  Future<void> _gradeAnswer() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student')));
      return;
    }
    final answer = _answerCtrl.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please record or type the student answer')));
      return;
    }

    setState(() => _isGrading = true);

    final qText = _questionCtrl.text.trim().isNotEmpty
        ? _questionCtrl.text.trim()
        : 'Oral evaluation in $_subject';

    final result = await ApiService.instance.gradeOralAnswer(
      studentName: _selectedStudent!.name,
      question: qText,
      answerText: answer,
      subject: _subject,
      className: _selectedClass,
    );

    // Save result to local SQLite
    await DatabaseHelper.instance.insertOralExamResult(OralExamResult(
      studentId: _selectedStudent!.id!,
      studentName: _selectedStudent!.name,
      question: qText,
      answerText: answer,
      score: (result['score'] as num?)?.toDouble() ?? 5.0,
      feedback: result['feedback'] ?? '',
      feedbackUrdu: result['feedback_urdu'] ?? '',
    ));

    setState(() {
      _result = result;
      _isGrading = false;
    });

    // Automatically speak the feedback in the selected language
    final fb = (result['feedback_urdu'] != null && result['feedback_urdu'].toString().isNotEmpty)
        ? result['feedback_urdu']
        : result['feedback'];
    if (fb != null) {
      await _speak(fb.toString());
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Voice Oral Exam'),
        leading: const BackButton(),
        actions: const [
          AiModeBadge(),
        ],
      ),
      body: Column(
        children: [
          const NetworkBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Student & Subject Selector Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadowList,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (ctx) {
                            final auth = ctx.watch<AuthProvider>();
                            final isTeacher = auth.isTeacher;
                            final teacherClass = auth.currentUser?.assignedClass;
                            final classes = (isTeacher && teacherClass != null) ? [teacherClass] : StudentModel.classes;
                            return DropdownButtonFormField<String>(
                              value: _selectedClass,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: isTeacher ? 'Assigned Class' : 'Class',
                                isDense: true,
                                helperText: isTeacher ? '🔒 Designated Class' : null,
                                helperStyle: const TextStyle(color: AppTheme.navyBlue, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              items: classes
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppTheme.bodyMedium, overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (isTeacher && teacherClass != null)
                                  ? null
                                  : (c) {
                                      setState(() => _selectedClass = c!);
                                      _loadStudents();
                                    },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _subject,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Subject', isDense: true),
                          items: ['General Science', 'English', 'Urdu', 'Islamiyat', 'Social Studies', 'Mathematics']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: AppTheme.bodyMedium, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (s) => setState(() => _subject = s!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StudentModel>(
                    value: _selectedStudent,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Student for Desk Exam',
                      prefixIcon: Icon(Icons.person, color: AppTheme.navyBlue, size: 20),
                    ),
                    items: _students
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text('${s.name} (Roll #${s.rollNumber ?? "N/A"})', style: AppTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (s) => setState(() => _selectedStudent = s),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Voice Language Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.cardShadowList,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Voice Input & Audio Language', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_voiceLang == 'ur_PK' ? 'اردو زبانی امتحان' : 'English Oral Exam',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.navyBlue)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<String>(
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: const [
                      ButtonSegment(value: 'ur_PK', label: Text('🇵🇰 اردو', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: 'en_US', label: Text('🇬🇧 Eng', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {_voiceLang},
                    onSelectionChanged: (s) {
                      setState(() => _voiceLang = s.first);
                      _configureTts();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Question Input with Editable Field & Presets
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.white,
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
                          Text('Question to Ask', style: AppTheme.labelMedium),
                          if (_isListeningQuestion) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fiber_manual_record, color: AppTheme.errorRed, size: 10),
                                  SizedBox(width: 4),
                                  Text('Listening...', style: TextStyle(fontSize: 10, color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isListeningQuestion ? Icons.mic : Icons.mic_none_rounded,
                              color: _isListeningQuestion ? AppTheme.errorRed : AppTheme.navyBlue,
                              size: 22,
                            ),
                            tooltip: _isListeningQuestion ? 'Stop Listening' : 'Speak Question with Mic',
                            onPressed: _toggleListeningQuestion,
                          ),
                          if (_questionCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.volume_up_rounded, color: AppTheme.navyBlue, size: 20),
                              tooltip: 'Speak Question Aloud',
                              onPressed: () => _speak(_questionCtrl.text),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _questionCtrl,
                    decoration: InputDecoration(
                      hintText: _voiceLang == 'ur_PK'
                          ? 'یہاں سوال بولیں یا لکھیں...'
                          : 'Speak or enter oral question...',
                      filled: true,
                      fillColor: AppTheme.offWhite,
                      prefixIcon: const Icon(Icons.help_outline, color: AppTheme.navyBlue, size: 20),
                      isDense: true,
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                  const SizedBox(height: 10),
                  const Text('Quick Preset Questions:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _sampleQuestions.map((q) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(
                              q,
                              style: TextStyle(
                                fontSize: 11,
                                color: _questionCtrl.text == q ? AppTheme.white : AppTheme.navyBlue,
                              ),
                            ),
                            backgroundColor: _questionCtrl.text == q ? AppTheme.navyBlue : AppTheme.lightBlue,
                            onPressed: () => setState(() => _questionCtrl.text = q),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // MIC RECORDING BUTTON
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _toggleListening,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Transform.scale(
                        scale: _isListening ? _pulseAnim.value : 1.0,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _isListening
                                ? const LinearGradient(colors: [AppTheme.errorRed, Color(0xFFDC2626)])
                                : AppTheme.navyGradient,
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening ? AppTheme.errorRed : AppTheme.navyBlue).withOpacity(0.35),
                                blurRadius: 18,
                                spreadRadius: _isListening ? 6 : 0,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                            color: AppTheme.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isListening
                        ? '🔴 Listening in ${_voiceLang == "ur_PK" ? "اردو" : "English"}... Tap to stop'
                        : 'Tap Mic to Record Student Answer',
                    style: AppTheme.bodyMedium.copyWith(
                      color: _isListening ? AppTheme.errorRed : AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Student speaks into teacher smartphone at desk',
                    style: AppTheme.bodySmall.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Editable Answer Area (Student Speech-to-Text)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadowList,
                border: Border.all(color: AppTheme.navyBlue.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note_rounded, color: AppTheme.navyBlue, size: 20),
                          const SizedBox(width: 6),
                          Text('Student Answer (Review & Edit)', style: AppTheme.labelMedium),
                        ],
                      ),
                      if (_answerCtrl.text.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _answerCtrl.clear()),
                          child: const Text('Clear', style: TextStyle(fontSize: 11, color: AppTheme.errorRed)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Voice transcription appears below. You can edit or refine any word before submitting to AI.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _answerCtrl,
                    decoration: InputDecoration(
                      hintText: _voiceLang == 'ur_PK'
                          ? 'طالب علم کا زبانی جواب یہاں آئے گا یا خود ٹائپ کریں...'
                          : 'Spoken answer will appear here, or type manually...',
                      filled: true,
                      fillColor: AppTheme.offWhite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderColor)),
                      isDense: true,
                    ),
                    maxLines: 3,
                    minLines: 2,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Grade with AI Button
            ElevatedButton.icon(
              onPressed: _isGrading ? null : _gradeAnswer,
              icon: _isGrading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isGrading ? 'AI Evaluating Spoken Answer...' : '⚡ Grade with Alibaba Cloud Qwen'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            ),

            // Audio Player Bar (Play, Pause, Resume, Stop)
            if (_isSpeaking || _isPaused || _currentSpeechText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSpeaking
                          ? Icons.graphic_eq_rounded
                          : (_isPaused ? Icons.pause_circle_filled : Icons.volume_mute_rounded),
                      color: _isSpeaking ? AppTheme.accentGold : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isSpeaking ? 'Playing audio feedback...' : (_isPaused ? 'Audio Paused' : 'Audio Complete'),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_isSpeaking)
                      IconButton(
                        icon: const Icon(Icons.pause_rounded, color: Colors.white),
                        tooltip: 'Pause',
                        onPressed: _pauseAudio,
                      ),
                    if (_isPaused || (!_isSpeaking && _currentSpeechText.isNotEmpty))
                      IconButton(
                        icon: const Icon(Icons.play_arrow_rounded, color: AppTheme.accentGold),
                        tooltip: 'Resume',
                        onPressed: _resumeAudio,
                      ),
                    if (_isSpeaking || _isPaused)
                      IconButton(
                        icon: const Icon(Icons.stop_rounded, color: AppTheme.errorRed),
                        tooltip: 'Stop',
                        onPressed: _stopAudio,
                      ),
                  ],
                ),
              ),
            ],

            // Result card
            if (_result != null) ...[
              const SizedBox(height: 20),
              _ResultCard(
                result: _result!,
                studentName: _selectedStudent?.name ?? '',
                onSpeakFeedback: (text) => _speak(text),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  ],
),
);
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final String studentName;
  final void Function(String text) onSpeakFeedback;

  const _ResultCard({
    required this.result,
    required this.studentName,
    required this.onSpeakFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final score = (result['score'] as num?)?.toDouble() ?? 5.0;
    final feedback = result['feedback']?.toString() ?? '';
    final feedbackUrdu = result['feedback_urdu']?.toString() ?? '';

    Color scoreColor = AppTheme.successGreen;
    if (score < 4) {
      scoreColor = AppTheme.errorRed;
    } else if (score < 7) {
      scoreColor = AppTheme.warningOrange;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadowList,
        border: Border.all(color: scoreColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Oral Evaluation', style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary)),
                    Text(
                      studentName,
                      style: AppTheme.headingSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor, width: 3),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        score.toStringAsFixed(1),
                        style: TextStyle(color: scoreColor, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text('/10', style: TextStyle(color: scoreColor.withOpacity(0.7), fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('📝 Feedback (English)', style: AppTheme.labelMedium),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: AppTheme.navyBlue, size: 20),
                tooltip: 'Play English Feedback',
                onPressed: () => onSpeakFeedback(feedback),
              ),
            ],
          ),
          Text(feedback, style: AppTheme.bodyMedium),

          if (feedbackUrdu.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('تاثرات (اردو)', style: AppTheme.labelMedium),
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, color: AppTheme.navyBlue, size: 20),
                  tooltip: 'Play Urdu Feedback',
                  onPressed: () => onSpeakFeedback(feedbackUrdu),
                ),
              ],
            ),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(feedbackUrdu, style: AppTheme.urduStyle, textAlign: TextAlign.right),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
