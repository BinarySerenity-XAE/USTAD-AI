// lib/screens/teacher/roleplay_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../widgets/network_banner.dart';

class RoleplayScreen extends StatefulWidget {
  const RoleplayScreen({super.key});

  @override
  State<RoleplayScreen> createState() => _RoleplayScreenState();
}

class _RoleplayScreenState extends State<RoleplayScreen> {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  final TextEditingController _questionInputCtrl = TextEditingController();

  String _selectedScenario = '';
  String _selectedClass = 'Class 5';
  String _subject = 'History';
  String _script = '';
  String _character = '';
  String _voiceGender = 'male'; // 'male' | 'female'
  String _voiceLanguage = 'ur_PK'; // 'ur_PK' | 'en_US'

  bool _isGenerating = false;
  bool _isResponding = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _isListening = false;
  bool _sessionStarted = false;

  String _currentSpeechText = '';
  int _lastWordOffset = 0;

  final List<Map<String, dynamic>> _scenarios = [
    {
      'title': 'Allama Iqbal',
      'subject': 'History',
      'emoji': '📜',
      'desc': 'The great poet-philosopher of Pakistan',
      'gender': 'male',
    },
    {
      'title': 'Quaid-e-Azam Muhammad Ali Jinnah',
      'subject': 'History',
      'emoji': '🏛️',
      'desc': 'Founder of Pakistan, Unity, Faith, Discipline',
      'gender': 'male',
    },
    {
      'title': 'Fatima Jinnah',
      'subject': 'History',
      'emoji': '🪷',
      'desc': 'Madar-e-Millat, leader and dental surgeon',
      'gender': 'female',
    },
    {
      'title': 'Sir Isaac Newton',
      'subject': 'Science',
      'emoji': '⚡',
      'desc': 'Laws of motion & universal gravitation',
      'gender': 'male',
    },
    {
      'title': 'Marie Curie',
      'subject': 'Science',
      'emoji': '🔬',
      'desc': 'Radioactivity & first double Nobel laureate',
      'gender': 'female',
    },
    {
      'title': 'Al-Khwarizmi',
      'subject': 'Mathematics',
      'emoji': '📐',
      'desc': 'Father of Algebra and Algorithms',
      'gender': 'male',
    },
    {
      'title': 'A Water Molecule (H2O)',
      'subject': 'Chemistry',
      'emoji': '💧',
      'desc': 'Living concept: molecular bonds & water cycle',
      'gender': 'female',
    },
    {
      'title': 'A Robot from 2050',
      'subject': 'Technology',
      'emoji': '🤖',
      'desc': 'Future AI assistant explaining space & robotics',
      'gender': 'male',
    },
  ];

  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isTeacher && auth.currentUser?.assignedClass != null) {
      _selectedClass = auth.currentUser!.assignedClass!;
    }
    _initTts();
    _initStt();
    _loadCustomCharacters();
  }

  Future<void> _loadCustomCharacters() async {
    try {
      final saved = await DatabaseHelper.instance.getCustomCharacters();
      for (final char in saved) {
        final existing = _scenarios.any((s) => s['title'] == char['name']);
        if (!existing) {
          _scenarios.insert(0, {
            'id': char['id'],
            'title': char['name'],
            'subject': char['subject'],
            'emoji': char['avatar_emoji'] ?? '🌟',
            'desc': char['title'] ?? 'Custom Persona',
            'gender': char['voice_gender'] ?? 'male',
            'is_custom': true,
          });
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading custom characters: $e');
    }
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
    try {
      final isUrdu = _voiceLanguage == 'ur_PK';
      await _tts.setLanguage(isUrdu ? 'ur-PK' : 'en-US');

      // Natural speech cadence
      final rate = isUrdu ? 0.38 : 0.44;
      await _tts.setSpeechRate(rate);
      await _tts.setVolume(1.0);

      // Male vs Female pitch - strong distinction to ensure gender change is audible
      final pitch = _voiceGender == 'female' ? 1.30 : 0.75;
      await _tts.setPitch(pitch);
    } catch (e) {
      debugPrint('Error configuring TTS: $e');
    }
  }

  Future<void> _initStt() async {
    await _stt.initialize();
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    _questionInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    if (_selectedScenario.isEmpty) return;
    setState(() {
      _isGenerating = true;
      _messages.clear();
      _questionInputCtrl.clear();
    });

    final result = await ApiService.instance.generateRoleplay(
      scenario: _selectedScenario,
      className: _selectedClass,
      subject: _subject,
    );

    _script = result['script'] ?? 'Hello class! I am ready to answer your questions.';
    _character = result['character'] ?? _selectedScenario;

    _messages.add({'role': 'character', 'text': _script, 'name': _character});

    setState(() {
      _isGenerating = false;
      _sessionStarted = true;
    });
    await _speak(_script);
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

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stt.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _stt.listen(
        localeId: _voiceLanguage,
        onResult: (r) {
          setState(() {
            _questionInputCtrl.text = r.recognizedWords;
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

  Future<void> _sendQuestion() async {
    final text = _questionInputCtrl.text.trim();
    if (text.isEmpty) return;

    if (_isListening) {
      await _stt.stop();
      setState(() => _isListening = false);
    }

    _messages.add({'role': 'student', 'text': text, 'name': 'Student'});
    _questionInputCtrl.clear();
    setState(() => _isResponding = true);

    final result = await ApiService.instance.getRoleplayResponse(
      scenario: _selectedScenario,
      studentQuestion: text,
      character: _character,
    );

    final response = result['response'] ?? 'That is a great question!';
    _messages.add({'role': 'character', 'text': response, 'name': _character});
    setState(() => _isResponding = false);
    await _speak(response);
  }

  void _showAddCustomCharacterDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '🌟');
    String customSub = _subject;
    String customGender = _voiceGender;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            '✨ Add Custom Character',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Character / Concept Name',
                    hintText: 'e.g. Dr. Abdul Qadeer Khan',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Role / Description',
                    hintText: 'e.g. Nuclear Physicist & National Hero',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: TextField(
                        controller: emojiCtrl,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22),
                        decoration: InputDecoration(
                          labelText: 'Emoji',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: customSub,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: ['History', 'Science', 'Mathematics', 'Chemistry', 'Physics', 'Technology', 'General']
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setDlgState(() => customSub = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Voice Gender:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Male 👨', style: TextStyle(fontSize: 13)),
                      selected: customGender == 'male',
                      onSelected: (sel) {
                        if (sel) setDlgState(() => customGender = 'male');
                      },
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Female 👩', style: TextStyle(fontSize: 13)),
                      selected: customGender == 'female',
                      onSelected: (sel) {
                        if (sel) setDlgState(() => customGender = 'female');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final charName = nameCtrl.text.trim();
                final charDesc = descCtrl.text.trim().isEmpty ? 'Custom Roleplay Persona' : descCtrl.text.trim();
                final charEmoji = emojiCtrl.text.trim().isEmpty ? '🌟' : emojiCtrl.text.trim();

                // Persist to SQLite
                final id = await DatabaseHelper.instance.insertCustomCharacter({
                  'name': charName,
                  'title': charDesc,
                  'subject': customSub,
                  'initial_greeting': 'Hello class!',
                  'system_prompt': '',
                  'voice_gender': customGender,
                  'voice_language': _voiceLanguage,
                  'avatar_emoji': charEmoji,
                });

                final newChar = {
                  'id': id,
                  'title': charName,
                  'subject': customSub,
                  'emoji': charEmoji,
                  'desc': charDesc,
                  'gender': customGender,
                  'is_custom': true,
                };
                setState(() {
                  _scenarios.insert(0, newChar);
                  _selectedScenario = newChar['title'] as String;
                  _subject = customSub;
                  _voiceGender = customGender;
                });
                _configureTts();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add & Save Persona'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('AI Roleplay'),
        leading: const BackButton(),
        actions: [
          const AiModeBadge(),
          if (_sessionStarted)
            TextButton(
              onPressed: () => setState(() {
                _stopAudio();
                _sessionStarted = false;
                _selectedScenario = '';
                _messages.clear();
              }),
              child: const Text('New Session', style: TextStyle(color: AppTheme.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          const NetworkBanner(),
          Expanded(child: _sessionStarted ? _buildSession() : _buildSetup()),
        ],
      ),
    );
  }

  Widget _buildSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🎭', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Whole-Class AI Roleplay', style: AppTheme.headingSmall.copyWith(color: AppTheme.white)),
                      Text(
                        'Single-phone broadcast to Bluetooth speaker — students ask questions!',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.white.withOpacity(0.88)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Class & Subject Pickers
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (ctx) {
                    final auth = ctx.watch<AuthProvider>();
                    final isTeacher = auth.isTeacher;
                    final teacherClass = auth.currentUser?.assignedClass;
                    final classes = (isTeacher && teacherClass != null)
                        ? [teacherClass]
                        : ['Class 4', 'Class 5', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10'];
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
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (isTeacher && teacherClass != null)
                          ? null
                          : (v) => setState(() => _selectedClass = v!),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _subject,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Subject', isDense: true),
                  items: ['History', 'Science', 'Chemistry', 'Physics', 'Technology', 'Mathematics', 'English', 'General']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() => _subject = v!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Voice Settings: Gender & Language
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.cardShadowList,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🎙️ Voice Settings', style: AppTheme.labelMedium),
                    Text('Custom Tuning', style: AppTheme.bodySmall.copyWith(color: AppTheme.navyBlue, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Voice Gender', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            segments: const [
                              ButtonSegment(value: 'male', label: Text('Male 👨', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 'female', label: Text('Female 👩', style: TextStyle(fontSize: 11))),
                            ],
                            selected: {_voiceGender},
                            onSelectionChanged: (s) {
                              setState(() => _voiceGender = s.first);
                              _configureTts();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Voice Language', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            segments: const [
                              ButtonSegment(value: 'ur_PK', label: Text('🇵🇰 اردو', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 'en_US', label: Text('🇬🇧 Eng', style: TextStyle(fontSize: 11))),
                            ],
                            selected: {_voiceLanguage},
                            onSelectionChanged: (s) {
                              setState(() => _voiceLanguage = s.first);
                              _configureTts();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Character Heading + Add Custom Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('Choose Character', style: AppTheme.headingSmall, overflow: TextOverflow.ellipsis)),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _showAddCustomCharacterDialog,
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('+ Custom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Scenarios Grid (Optimized aspect ratio to prevent overflow)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: _scenarios.map((s) {
              final selected = _selectedScenario == s['title'];
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedScenario = s['title'] as String;
                  _subject = s['subject'] as String;
                  if (s['gender'] != null) {
                    _voiceGender = s['gender'] as String;
                    _configureTts();
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.navyBlue : AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppTheme.navyBlue : AppTheme.borderColor,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected ? AppTheme.buttonShadowList : AppTheme.cardShadowList,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s['emoji'] as String, style: const TextStyle(fontSize: 22)),
                          if (selected)
                            const Icon(Icons.check_circle, color: Colors.white, size: 16),
                        ],
                      ),
                      Text(
                        s['title'] as String,
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: selected ? AppTheme.white : AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        s['desc'] as String,
                        style: AppTheme.bodySmall.copyWith(
                          fontSize: 9.5,
                          color: selected ? AppTheme.white.withOpacity(0.85) : AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: (_selectedScenario.isEmpty || _isGenerating) ? null : _startSession,
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_isGenerating ? 'Starting Session...' : '🎭 Start Roleplay Session'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSession() {
    return Column(
      children: [
        // Character header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.navyBlue,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _scenarios.firstWhere((s) => s['title'] == _selectedScenario, orElse: () => {'emoji': '🎭'})['emoji'] as String,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _character.isNotEmpty ? _character : _selectedScenario,
                      style: AppTheme.headingSmall.copyWith(color: AppTheme.white, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$_selectedClass • $_subject • ${_voiceGender.toUpperCase()} ${_voiceLanguage == "ur_PK" ? "URDU" : "ENG"}',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.white.withOpacity(0.75), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Audio Player Controls Bar (Play, Pause, Resume, Stop)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0F172A),
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
                  _isSpeaking
                      ? 'Speaking aloud...'
                      : (_isPaused ? 'Audio Paused (Tap Resume)' : 'Audio Ready'),
                  style: TextStyle(
                    color: _isSpeaking ? AppTheme.accentGold : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Pause Button
              if (_isSpeaking)
                IconButton(
                  icon: const Icon(Icons.pause_rounded, color: Colors.white),
                  tooltip: 'Pause Audio',
                  onPressed: _pauseAudio,
                ),
              // Resume / Play Button
              if (_isPaused || (!_isSpeaking && _currentSpeechText.isNotEmpty))
                IconButton(
                  icon: const Icon(Icons.play_arrow_rounded, color: AppTheme.accentGold),
                  tooltip: 'Resume Audio',
                  onPressed: _resumeAudio,
                ),
              // Stop Button
              if (_isSpeaking || _isPaused)
                IconButton(
                  icon: const Icon(Icons.stop_rounded, color: AppTheme.errorRed),
                  tooltip: 'Stop Audio',
                  onPressed: _stopAudio,
                ),
            ],
          ),
        ),

        // Chat messages
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length + (_isResponding ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _messages.length) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final msg = _messages[i];
              final isChar = msg['role'] == 'character';
              return Align(
                alignment: isChar ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isChar ? AppTheme.navyBlue : AppTheme.lightBlue,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isChar ? 4 : 16),
                      bottomRight: Radius.circular(isChar ? 16 : 4),
                    ),
                    boxShadow: AppTheme.cardShadowList,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            msg['name']!,
                            style: AppTheme.bodySmall.copyWith(
                              color: isChar ? AppTheme.accentGold : AppTheme.navyBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isChar)
                            InkWell(
                              onTap: () => _speak(msg['text']!),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(Icons.volume_up_rounded, color: AppTheme.accentGold, size: 18),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        msg['text']!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: isChar ? AppTheme.white : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Input Area with Live Speech Input + Edit Box
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: AppTheme.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Language indicator chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isListening ? '🔴 Recording question...' : 'Ask character a question:',
                      style: TextStyle(
                        fontSize: 11,
                        color: _isListening ? AppTheme.errorRed : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _voiceLanguage = _voiceLanguage == 'ur_PK' ? 'en_US' : 'ur_PK';
                        });
                        _configureTts();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.lightBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _voiceLanguage == 'ur_PK' ? '🇵🇰 Input: اردو' : '🇬🇧 Input: English',
                          style: const TextStyle(fontSize: 10, color: AppTheme.navyBlue, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Mic button
                    GestureDetector(
                      onTap: _toggleListening,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isListening ? AppTheme.errorRed : AppTheme.navyBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Editable question box
                    Expanded(
                      child: TextField(
                        controller: _questionInputCtrl,
                        decoration: InputDecoration(
                          hintText: _voiceLanguage == 'ur_PK'
                              ? 'طلبہ کا سوال یہاں لکھیں یا بولیں...'
                              : 'Type or speak question...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppTheme.borderColor),
                          ),
                          suffixIcon: _questionInputCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => setState(() => _questionInputCtrl.clear()),
                                )
                              : null,
                        ),
                        maxLines: 2,
                        minLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send Button
                    IconButton.filled(
                      onPressed: _isResponding ? null : _sendQuestion,
                      style: IconButton.styleFrom(backgroundColor: AppTheme.navyBlue),
                      icon: _isResponding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
