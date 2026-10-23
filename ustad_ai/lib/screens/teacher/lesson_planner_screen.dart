// lib/screens/teacher/lesson_planner_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/network_banner.dart';
import '../../utils/pdf_fonts.dart';

class LessonPlannerScreen extends StatefulWidget {
  final String? initialClass;

  const LessonPlannerScreen({super.key, this.initialClass});

  @override
  State<LessonPlannerScreen> createState() => _LessonPlannerScreenState();
}

class _LessonPlannerScreenState extends State<LessonPlannerScreen> {
  late String _selectedClass;
  String _selectedSubject = 'General Science';
  final _topicController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _lessonPlan;

  // Image & Speech
  File? _textbookImage;
  final ImagePicker _picker = ImagePicker();
  final SpeechToText _stt = SpeechToText();
  bool _isListening = false;
  String _voiceLanguage = 'ur_PK'; // 'ur_PK' | 'en_US'

  final List<String> _classes = [
    'Nursery', 'KG', 'Class 1', 'Class 2', 'Class 3', 'Class 4',
    'Class 5', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10'
  ];

  final List<String> _subjects = [
    'General Science',
    'Mathematics',
    'English',
    'Urdu',
    'Islamiyat',
    'Social Studies',
    'Computer Science',
    'Physics',
    'Chemistry',
    'Biology'
  ];

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.initialClass ?? 'Class 5';
    _topicController.text = 'Photosynthesis and Plant Food';
  }

  @override
  void dispose() {
    _topicController.dispose();
    _stt.stop();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      await _stt.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _stt.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone not available')),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    final locale = _voiceLanguage == 'ur_PK' ? 'ur_PK' : 'en_US';
    try {
      await _stt.listen(
        localeId: locale,
        onResult: (r) {
          setState(() {
            _topicController.text = r.recognizedWords;
          });
          if (r.finalResult) {
            setState(() => _isListening = false);
          }
        },
      );
    } catch (_) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _textbookImage = File(picked.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking textbook photo: $e')),
      );
    }
  }

  Future<void> _generatePlan() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty && _textbookImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a lesson topic or attach a textbook photo')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.instance.generateLessonPlan(
        className: _selectedClass,
        subject: _selectedSubject,
        topic: topic.isNotEmpty ? topic : 'Textbook Page Lesson',
      );
      setState(() => _lessonPlan = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating plan: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printWorksheetPdf() async {
    if (_lessonPlan == null) return;
    await PdfFonts.ensureLoaded();

    final pdf = pw.Document();
    final topic = _lessonPlan!['topic'] ?? 'Worksheet';
    final cls = _lessonPlan!['class_name'] ?? _selectedClass;
    final sub = _lessonPlan!['subject'] ?? _selectedSubject;
    final questions = (_lessonPlan!['worksheet_questions'] as List?) ?? [];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: PdfFonts.theme,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'SUBLIME GRAMMAR SCHOOL',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Single National Curriculum (SNC) Classroom Worksheet',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Divider(thickness: 1.5),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // Metadata Bar
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Student Name: _______________________', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Roll No: ______', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Date: ___________', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Class: $cls', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Subject: $sub', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Topic: $topic', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 12),

                // Worksheet Questions
                pw.Text('EXERCISES & ASSESSMENT QUESTIONS', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),

                ...questions.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final q = entry.value as Map<String, dynamic>;
                  final qText = q['question'] ?? '';
                  final options = (q['options'] as List?)?.cast<String>() ?? [];

                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Q$idx. $qText', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        if (options.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                            children: options.map((opt) => pw.Text('• $opt', style: const pw.TextStyle(fontSize: 10))).toList(),
                          ),
                        ],
                        pw.SizedBox(height: 8),
                        pw.Text('Answer: ____________________________________________________________________',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      ],
                    ),
                  );
                }),

                pw.Spacer(),
                pw.Center(
                  child: pw.Text(
                    'Sublime Grammar School — Empowering Teachers through Ustad-AI',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Worksheet_${cls}_${topic.replaceAll(' ', '_')}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('📑 1-Tap SNC Lesson Planner'),
        backgroundColor: AppTheme.navyBlue,
        actions: [
          const AiModeBadge(),
          if (_lessonPlan != null)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print Worksheet PDF',
              onPressed: _printWorksheetPdf,
            ),
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
                                    child: const Icon(Icons.menu_book, color: AppTheme.navyBlue),
                                  ),
                                  const SizedBox(width: 12),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Curriculum Planner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text('Aligned with Punjab SNC', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                              // Language toggle for mic
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightBlue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('اردو', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      selected: _voiceLanguage == 'ur_PK',
                                      selectedColor: AppTheme.navyBlue,
                                      labelStyle: TextStyle(color: _voiceLanguage == 'ur_PK' ? Colors.white : AppTheme.navyBlue),
                                      padding: EdgeInsets.zero,
                                      onSelected: (v) => setState(() => _voiceLanguage = 'ur_PK'),
                                    ),
                                    const SizedBox(width: 4),
                                    ChoiceChip(
                                      label: const Text('Eng', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      selected: _voiceLanguage == 'en_US',
                                      selectedColor: AppTheme.navyBlue,
                                      labelStyle: TextStyle(color: _voiceLanguage == 'en_US' ? Colors.white : AppTheme.navyBlue),
                                      padding: EdgeInsets.zero,
                                      onSelected: (v) => setState(() => _voiceLanguage = 'en_US'),
                                    ),
                                  ],
                                ),
                              ),
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
                          const SizedBox(height: 16),

                          // Topic input with Mic (EN/UR)
                          TextField(
                            controller: _topicController,
                            decoration: InputDecoration(
                              labelText: 'Curriculum Topic / عنوان',
                              hintText: 'e.g. Photosynthesis, Fractions, Word Problems',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lightbulb_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isListening ? Icons.mic : Icons.mic_none,
                                  color: _isListening ? Colors.red : AppTheme.navyBlue,
                                ),
                                tooltip: 'Speak Topic (${_voiceLanguage == 'ur_PK' ? 'اردو' : 'English'})',
                                onPressed: _toggleMic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Textbook Page / Topic Photo attachment
                          Row(
                            children: [
                              const Text('Textbook Page / Photo (اختیاری):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt, size: 16),
                                label: const Text('Camera', style: TextStyle(fontSize: 12)),
                              ),
                              TextButton.icon(
                                onPressed: () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library, size: 16),
                                label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          if (_textbookImage != null) ...[
                            const SizedBox(height: 6),
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(_textbookImage!, height: 120, width: double.infinity, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    radius: 14,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                      onPressed: () => setState(() => _textbookImage = null),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _generatePlan,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.navyBlue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.psychology, color: Colors.white),
                              label: Text(
                                _isLoading ? 'Consulting SNC AI Model...' : 'Generate SNC Lesson Plan & Worksheet',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_lessonPlan != null) ...[
                    const SizedBox(height: 20),

                    // SNC Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accentGold),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, color: AppTheme.accentGold, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _lessonPlan!['snc_alignment'] ?? 'SNC Verified Standard',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Objectives Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.flag_outlined, color: AppTheme.navyBlue),
                                SizedBox(width: 8),
                                Text('Student Learning Outcomes (SLOs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            const Divider(height: 18),
                            ...((_lessonPlan!['learning_objectives'] as List?) ?? []).map((slo) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('🎯 ', style: TextStyle(fontSize: 14)),
                                    Expanded(child: Text(slo, style: const TextStyle(fontSize: 13, height: 1.4))),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Lesson Flow
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.timer_outlined, color: AppTheme.navyBlue),
                                SizedBox(width: 8),
                                Text('40-Minute Lesson Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            const Divider(height: 18),
                            ...((_lessonPlan!['lesson_flow'] as List?) ?? []).map((step) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: AppTheme.lightBlue, borderRadius: BorderRadius.circular(6)),
                                      child: Text(
                                        step['time'] ?? '5 min',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.navyBlue),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(step['activity'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text(step['description'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Urdu Summary for Parents
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: AppTheme.navyBlue,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.family_restroom, color: AppTheme.accentGold, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'والدین کے لیے ڈائری کا خلاصہ (Urdu Parent Summary)',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _lessonPlan!['parent_summary_urdu'] ?? '',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontFamily: 'Noto Nastaliq Urdu',
                                fontSize: 14,
                                height: 1.8,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Print Worksheet Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _printWorksheetPdf,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade800,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.print, color: Colors.white),
                        label: const Text(
                          'Export & Print Worksheet (PDF)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
