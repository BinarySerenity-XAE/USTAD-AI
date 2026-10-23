// lib/screens/teacher/paper_grader_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/network_banner.dart';

class PaperGraderScreen extends StatefulWidget {
  final String? initialClass;
  final int initialTabIndex;

  const PaperGraderScreen({
    super.key,
    this.initialClass,
    this.initialTabIndex = 0,
  });

  @override
  State<PaperGraderScreen> createState() => _PaperGraderScreenState();
}

class _PaperGraderScreenState extends State<PaperGraderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Speech To Text
  final SpeechToText _stt = SpeechToText();
  bool _sttInitialized = false;
  String _activeListeningField = ''; // 'paper_q', 'paper_a', 'math_p', 'math_s'
  String _voiceLanguage = 'ur_PK'; // 'ur_PK' | 'en_US'

  // General Paper Grader state
  late String _selectedClass;
  String _selectedSubject = 'General Science';
  final _questionController = TextEditingController();
  final _answerKeyController = TextEditingController();
  File? _selectedImage;
  String? _base64Image;
  bool _isLoadingPaper = false;
  Map<String, dynamic>? _paperResult;
  // Verification mode: false = Provide/Upload Answer Key, true = Verify Directly with AI
  bool _directAiPaper = false;
  File? _answerKeyImage;
  String? _answerKeyBase64;

  // Math Auto-Grader state
  late String _mathClass;
  final _mathProblemController = TextEditingController();
  final _mathExpectedController = TextEditingController();
  File? _mathImage;
  String? _mathBase64;
  bool _isLoadingMath = false;
  Map<String, dynamic>? _mathResult;
  // Verification mode: false = Provide Expected Solution, true = Verify Directly with AI
  bool _directAiMath = false;
  File? _mathSolutionImage;
  String? _mathSolutionBase64;

  final ImagePicker _picker = ImagePicker();

  final List<String> _classes = [
    'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5',
    'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10'
  ];

  final List<String> _subjects = [
    'General Science',
    'Mathematics',
    'English',
    'Urdu',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'Islamiyat'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _selectedClass = widget.initialClass ?? 'Class 5';
    _mathClass = widget.initialClass ?? 'Class 5';

    _questionController.text = 'Define Photosynthesis and write its formula.';
    _answerKeyController.text = 'Process by which plants use sunlight to synthesize nutrients from CO2 and water. 6CO2 + 6H2O -> C6H12O6 + 6O2';

    _mathProblemController.text = 'Solve for x: 3x + 12 = 27';
    _mathExpectedController.text = '3x = 15, x = 5';

    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _sttInitialized = await _stt.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionController.dispose();
    _answerKeyController.dispose();
    _mathProblemController.dispose();
    _mathExpectedController.dispose();
    _stt.stop();
    super.dispose();
  }

  Future<void> _toggleMic(String fieldKey, TextEditingController controller) async {
    if (_activeListeningField == fieldKey) {
      await _stt.stop();
      setState(() => _activeListeningField = '');
      return;
    }

    if (!_sttInitialized) {
      await _initSpeech();
    }

    setState(() => _activeListeningField = fieldKey);
    final locale = _voiceLanguage == 'ur_PK' ? 'ur_PK' : 'en_US';

    try {
      await _stt.listen(
        localeId: locale,
        onResult: (result) {
          setState(() {
            controller.text = result.recognizedWords;
          });
          if (result.finalResult) {
            setState(() => _activeListeningField = '');
          }
        },
      );
    } catch (_) {
      setState(() => _activeListeningField = '');
    }
  }

  Future<void> _pickImageForPaper(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await File(picked.path).readAsBytes();
        setState(() {
          _selectedImage = File(picked.path);
          _base64Image = base64Encode(bytes);
          _paperResult = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting student paper photo: $e')),
      );
    }
  }

  Future<void> _pickAnswerKeyImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await File(picked.path).readAsBytes();
        setState(() {
          _answerKeyImage = File(picked.path);
          _answerKeyBase64 = base64Encode(bytes);
          _paperResult = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking key photo: $e')),
      );
    }
  }

  void _clearAnswerKeyImage() {
    setState(() {
      _answerKeyImage = null;
      _answerKeyBase64 = null;
    });
  }

  Future<void> _pickImageForMath(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await File(picked.path).readAsBytes();
        setState(() {
          _mathImage = File(picked.path);
          _mathBase64 = base64Encode(bytes);
          _mathResult = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting math photo: $e')),
      );
    }
  }

  Future<void> _pickMathSolutionImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await File(picked.path).readAsBytes();
        setState(() {
          _mathSolutionImage = File(picked.path);
          _mathSolutionBase64 = base64Encode(bytes);
          _mathResult = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking solution photo: $e')),
      );
    }
  }

  void _clearMathSolutionImage() {
    setState(() {
      _mathSolutionImage = null;
      _mathSolutionBase64 = null;
    });
  }

  Future<void> _gradePaper() async {
    if (_base64Image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture or select a photo of the student paper first.')),
      );
      return;
    }

    setState(() => _isLoadingPaper = true);
    try {
      final expectedKey = _directAiPaper ? null : _answerKeyController.text.trim();
      final keyImage = _directAiPaper ? null : _answerKeyBase64;
      final res = await ApiService.instance.gradeHandwrittenPaper(
        imageBase64: _base64Image!,
        className: _selectedClass,
        subject: _selectedSubject,
        questionOrTopic: _questionController.text.trim(),
        expectedAnswerKey: expectedKey,
        answerKeyImageBase64: keyImage,
        directAi: _directAiPaper,
        maxScore: 10.0,
      );
      setState(() => _paperResult = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paper grading failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingPaper = false);
    }
  }

  Future<void> _gradeMath() async {
    if (_mathBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture or select a photo of the handwritten math calculation.')),
      );
      return;
    }

    setState(() => _isLoadingMath = true);
    try {
      final expectedSol = _directAiMath ? null : _mathExpectedController.text.trim();
      final solImage = _directAiMath ? null : _mathSolutionBase64;
      final res = await ApiService.instance.gradeMathProblem(
        imageBase64: _mathBase64!,
        className: _mathClass,
        mathProblem: _mathProblemController.text.trim(),
        expectedSolution: expectedSol,
        solutionImageBase64: solImage,
        directAi: _directAiMath,
      );
      setState(() => _mathResult = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Math grading failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingMath = false);
    }
  }

  Widget _buildLanguageToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language, size: 14, color: AppTheme.navyBlue),
          const SizedBox(width: 6),
          const Text('Voice Lang:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navyBlue)),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('اردو 🇵🇰', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            selected: _voiceLanguage == 'ur_PK',
            selectedColor: AppTheme.navyBlue,
            labelStyle: TextStyle(color: _voiceLanguage == 'ur_PK' ? Colors.white : AppTheme.navyBlue),
            padding: EdgeInsets.zero,
            onSelected: (v) => setState(() => _voiceLanguage = 'ur_PK'),
          ),
          const SizedBox(width: 4),
          ChoiceChip(
            label: const Text('Eng 🇬🇧', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            selected: _voiceLanguage == 'en_US',
            selectedColor: AppTheme.navyBlue,
            labelStyle: TextStyle(color: _voiceLanguage == 'en_US' ? Colors.white : AppTheme.navyBlue),
            padding: EdgeInsets.zero,
            onSelected: (v) => setState(() => _voiceLanguage = 'en_US'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('📝 AI Vision Grader'),
        backgroundColor: AppTheme.navyBlue,
        actions: const [
          AiModeBadge(),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentGold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.description), text: 'Exam & Homework'),
            Tab(icon: Icon(Icons.calculate), text: '🧮 Math Step-by-Step'),
          ],
        ),
      ),
      body: Column(
        children: [
          const NetworkBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPaperGraderTab(),
                _buildMathGraderTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: General Paper Grader ──────────────────────────────────────────

  Widget _buildPaperGraderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.navyBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.document_scanner, color: AppTheme.navyBlue),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Qwen3-VL Vision Grader', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Examines student handwriting & checks facts', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      _buildLanguageToggle(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedClass,
                          decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                          items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _selectedClass = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedSubject,
                          decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                          items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => _selectedSubject = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Question input with Mic (EN/UR)
                  TextField(
                    controller: _questionController,
                    decoration: InputDecoration(
                      labelText: 'Question / Topic',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.help_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _activeListeningField == 'paper_q' ? Icons.mic : Icons.mic_none,
                          color: _activeListeningField == 'paper_q' ? Colors.red : AppTheme.navyBlue,
                        ),
                        tooltip: 'Speak Question (${_voiceLanguage == 'ur_PK' ? 'اردو' : 'English'})',
                        onPressed: () => _toggleMic('paper_q', _questionController),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Verification Mode Selector: Upload Answer Key vs Verify Directly with AI
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBlue.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.navyBlue.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Verification Method:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyBlue)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('📋 Provide / Upload Answer Key', style: TextStyle(fontSize: 11)),
                                selected: !_directAiPaper,
                                selectedColor: AppTheme.navyBlue,
                                labelStyle: TextStyle(color: !_directAiPaper ? Colors.white : AppTheme.navyBlue, fontWeight: FontWeight.bold),
                                onSelected: (val) {
                                  if (val) setState(() => _directAiPaper = false);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('🤖 Verify Directly with AI', style: TextStyle(fontSize: 11)),
                                selected: _directAiPaper,
                                selectedColor: AppTheme.navyBlue,
                                labelStyle: TextStyle(color: _directAiPaper ? Colors.white : AppTheme.navyBlue, fontWeight: FontWeight.bold),
                                onSelected: (val) {
                                  if (val) setState(() => _directAiPaper = true);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (!_directAiPaper) ...[
                    // Answer Key input with Mic (EN/UR)
                    TextField(
                      controller: _answerKeyController,
                      maxLines: 2,
                      minLines: 1,
                      decoration: InputDecoration(
                        labelText: 'Expected Answer Key / Model Solution (Text or Speech)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _activeListeningField == 'paper_a' ? Icons.mic : Icons.mic_none,
                            color: _activeListeningField == 'paper_a' ? Colors.red : AppTheme.navyBlue,
                          ),
                          tooltip: 'Speak Answer Key (${_voiceLanguage == 'ur_PK' ? 'اردو' : 'English'})',
                          onPressed: () => _toggleMic('paper_a', _answerKeyController),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_answerKeyImage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.offWhite,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.accentGold),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_answerKeyImage!, width: 48, height: 48, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Attached Answer Key Photo (جواب کلید کی تصویر)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyBlue)),
                                  Text(
                                    _answerKeyImage!.path.split(Platform.pathSeparator).last,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red, size: 20),
                              tooltip: 'Remove Key Photo',
                              onPressed: _clearAnswerKeyImage,
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickAnswerKeyImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt, size: 16),
                              label: const Text('Capture Key Photo', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickAnswerKeyImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library, size: 16),
                              label: const Text('Key from Gallery', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AI Direct Verification Active: Qwen3-VL solves the question itself and scores accuracy directly from curriculum standards.',
                              style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Student Paper Photo Capture
                  const Text('Student Handwriting Photo (طالب علم کی کاپی کی تصویر):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  if (_selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Image.file(_selectedImage!, height: 180, width: double.infinity, fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                onPressed: () => setState(() {
                                  _selectedImage = null;
                                  _base64Image = null;
                                  _paperResult = null;
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImageForPaper(ImageSource.camera),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImageForPaper(ImageSource.gallery),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingPaper ? null : _gradePaper,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navyBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isLoadingPaper
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.auto_awesome, color: Colors.white),
                      label: Text(
                        _isLoadingPaper ? 'Reading Handwriting & Evaluating...' : 'Grade Paper with Vision AI',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_paperResult != null) ...[
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Assessment Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            '${_paperResult!['score']} / ${_paperResult!['max_score']}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text('Transcribed Student Handwriting:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        _paperResult!['extracted_handwriting'] ?? '',
                        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Teacher Pedagogical Feedback:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      _paperResult!['feedback_english'] ?? '',
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _paperResult!['feedback_urdu'] ?? '',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'Noto Nastaliq Urdu',
                        fontSize: 15,
                        height: 1.9,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_paperResult!['strengths'] != null) ...[
                      const Text('✅ Strengths:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                      const SizedBox(height: 4),
                      ...((_paperResult!['strengths'] as List?) ?? []).map((st) => Text('• $st', style: const TextStyle(fontSize: 13))),
                      const SizedBox(height: 12),
                    ],
                    if (_paperResult!['improvements'] != null) ...[
                      const Text('💡 Suggested Next Steps:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                      const SizedBox(height: 4),
                      ...((_paperResult!['improvements'] as List?) ?? []).map((im) => Text('• $im', style: const TextStyle(fontSize: 13))),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Math Step-by-Step Auto-Grader ──────────────────────────────────

  Widget _buildMathGraderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.calculate, color: AppTheme.navyBlue),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('🧮 Math Step-by-Step Auto-Grader', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Verifies derivations line-by-line', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      _buildLanguageToggle(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _mathClass,
                    decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                    items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _mathClass = v!),
                  ),
                  const SizedBox(height: 14),

                  // Math Problem input with Mic (EN/UR)
                  TextField(
                    controller: _mathProblemController,
                    decoration: InputDecoration(
                      labelText: 'Math Problem / Equation',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.functions),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _activeListeningField == 'math_p' ? Icons.mic : Icons.mic_none,
                          color: _activeListeningField == 'math_p' ? Colors.red : AppTheme.navyBlue,
                        ),
                        tooltip: 'Speak Problem (${_voiceLanguage == 'ur_PK' ? 'اردو' : 'English'})',
                        onPressed: () => _toggleMic('math_p', _mathProblemController),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Math Verification Mode: Provide Steps vs Direct AI
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBlue.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.navyBlue.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Math Verification Method:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyBlue)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('📐 Provide / Upload Expected Steps', style: TextStyle(fontSize: 11)),
                                selected: !_directAiMath,
                                selectedColor: AppTheme.navyBlue,
                                labelStyle: TextStyle(color: !_directAiMath ? Colors.white : AppTheme.navyBlue, fontWeight: FontWeight.bold),
                                onSelected: (val) {
                                  if (val) setState(() => _directAiMath = false);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('🤖 Verify Directly with AI', style: TextStyle(fontSize: 11)),
                                selected: _directAiMath,
                                selectedColor: AppTheme.navyBlue,
                                labelStyle: TextStyle(color: _directAiMath ? Colors.white : AppTheme.navyBlue, fontWeight: FontWeight.bold),
                                onSelected: (val) {
                                  if (val) setState(() => _directAiMath = true);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (!_directAiMath) ...[
                    // Expected Solution input with Mic (EN/UR)
                    TextField(
                      controller: _mathExpectedController,
                      maxLines: 2,
                      minLines: 1,
                      decoration: InputDecoration(
                        labelText: 'Expected Solution / Steps (Text or Speech)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _activeListeningField == 'math_s' ? Icons.mic : Icons.mic_none,
                            color: _activeListeningField == 'math_s' ? Colors.red : AppTheme.navyBlue,
                          ),
                          tooltip: 'Speak Steps (${_voiceLanguage == 'ur_PK' ? 'اردو' : 'English'})',
                          onPressed: () => _toggleMic('math_s', _mathExpectedController),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Solution Photo Attachment
                    if (_mathSolutionImage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.offWhite,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.accentGold),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_mathSolutionImage!, width: 48, height: 48, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Attached Solution Photo (حل شدہ تصویر)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyBlue)),
                                  Text(
                                    _mathSolutionImage!.path.split(Platform.pathSeparator).last,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red, size: 20),
                              tooltip: 'Remove Solution Photo',
                              onPressed: _clearMathSolutionImage,
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickMathSolutionImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt, size: 16),
                              label: const Text('Capture Solution', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickMathSolutionImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library, size: 16),
                              label: const Text('Solution from Gallery', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AI Direct Math Solve Active: Qwen2.5-Math derives the solution automatically and audits student calculations line-by-line.',
                              style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Math Notebook Photo Capture
                  const Text('Student Math Calculation Photo (ریاضی حل شدہ کاپی کی تصویر):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  if (_mathImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Image.file(_mathImage!, height: 180, width: double.infinity, fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                onPressed: () => setState(() {
                                  _mathImage = null;
                                  _mathBase64 = null;
                                  _mathResult = null;
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImageForMath(ImageSource.camera),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Capture Work'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImageForMath(ImageSource.gallery),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Notebook Gallery'),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingMath ? null : _gradeMath,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navyBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isLoadingMath
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.auto_awesome, color: Colors.white),
                      label: Text(
                        _isLoadingMath ? 'Solving & Auditing Calculations...' : 'Verify Math with AI',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_mathResult != null) ...[
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Math Derivation Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: (_mathResult!['is_correct'] == true) ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: (_mathResult!['is_correct'] == true) ? Colors.green : Colors.red),
                          ),
                          child: Text(
                            (_mathResult!['is_correct'] == true) ? '✅ Correct' : '⚠️ Error in Steps',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (_mathResult!['is_correct'] == true) ? Colors.green.shade900 : Colors.red.shade900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text('Extracted Mathematical Equations:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        _mathResult!['extracted_math'] ?? '',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Line-by-Line Verification:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 6),
                    ...((_mathResult!['step_by_step_check'] as List?) ?? []).map(
                      (step) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(step, style: const TextStyle(fontSize: 14))),
                          ],
                        ),
                      ),
                    ),

                    if (_mathResult!['identified_mistake'] != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Identified Mistake: ${_mathResult!['identified_mistake']}',
                                style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text('Teacher Pedagogical Guidance (Urdu):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Text(
                      _mathResult!['teacher_tip_urdu'] ?? '',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'Noto Nastaliq Urdu',
                        fontSize: 15,
                        height: 1.9,
                        color: AppTheme.navyBlue,
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
