// lib/screens/admin/certificate_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../theme/app_theme.dart';
import '../../providers/student_provider.dart';
import '../../models/student_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/whatsapp_service.dart';
import '../../widgets/network_banner.dart';
import '../../utils/pdf_fonts.dart';

class CertificateScreen extends StatefulWidget {
  final StudentModel? initialStudent;

  const CertificateScreen({super.key, this.initialStudent});

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  StudentModel? _selectedStudent;
  String _selectedAchievement = 'Academic Excellence';
  String _selectedEvent = 'Annual Academic Session 2026';
  bool _isLoading = false;
  Map<String, dynamic>? _certificateData;

  // Custom achievement & occasion controllers + STT
  final TextEditingController _customAchievementCtrl = TextEditingController();
  final TextEditingController _customEventCtrl = TextEditingController();
  final SpeechToText _stt = SpeechToText();
  bool _isListeningAchievement = false;
  bool _isListeningEvent = false;
  String _voiceLanguage = 'ur_PK'; // 'ur_PK' or 'en_US'
  String _citationLanguage = 'Bilingual'; // 'Bilingual', 'English', 'Urdu'

  final List<String> _achievements = [
    'Academic Excellence',
    'Class 1st Position',
    'Science & Innovation Star',
    'Exemplary Moral Character',
    'Best Calligraphy & Handwriting',
    'Quran Recitation Distinction',
    '100% Full Attendance Award',
    'Sports & Fitness Champion',
    'Custom Achievement...',
  ];

  final List<String> _events = [
    'Annual Academic Session 2026',
    'Mid-Term Examination 2026',
    'Science & STEM Exhibition',
    'Sports Gala 2026',
    'Iqbal Day Commemoration',
    'Custom Occasion...',
  ];

  @override
  void initState() {
    super.initState();
    final students = context.read<StudentProvider>().students;
    _selectedStudent = widget.initialStudent ?? (students.isNotEmpty ? students.first : null);
    if (_selectedStudent != null && AuthService.instance.isAdmin) {
      _generateCertificate();
    }
  }

  @override
  void dispose() {
    _customAchievementCtrl.dispose();
    _customEventCtrl.dispose();
    _stt.stop();
    super.dispose();
  }

  Future<void> _toggleMicForField({required bool isAchievement}) async {
    final currentlyListening = isAchievement ? _isListeningAchievement : _isListeningEvent;
    if (currentlyListening) {
      await _stt.stop();
      setState(() {
        _isListeningAchievement = false;
        _isListeningEvent = false;
      });
      return;
    }

    final available = await _stt.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone not available on this device')),
        );
      }
      return;
    }

    setState(() {
      if (isAchievement) {
        _isListeningAchievement = true;
        _isListeningEvent = false;
      } else {
        _isListeningEvent = true;
        _isListeningAchievement = false;
      }
    });

    final targetCtrl = isAchievement ? _customAchievementCtrl : _customEventCtrl;
    try {
      await _stt.listen(
        localeId: _voiceLanguage,
        onResult: (r) {
          setState(() {
            targetCtrl.text = r.recognizedWords;
          });
          if (r.finalResult) {
            setState(() {
              _isListeningAchievement = false;
              _isListeningEvent = false;
            });
          }
        },
      );
    } catch (_) {
      setState(() {
        _isListeningAchievement = false;
        _isListeningEvent = false;
      });
    }
  }

  Future<void> _generateCertificate() async {
    if (_selectedStudent == null) return;
    setState(() => _isLoading = true);

    final achievement = (_selectedAchievement == 'Custom Achievement...' && _customAchievementCtrl.text.trim().isNotEmpty)
        ? _customAchievementCtrl.text.trim()
        : _selectedAchievement;
    final event = (_selectedEvent == 'Custom Occasion...' && _customEventCtrl.text.trim().isNotEmpty)
        ? _customEventCtrl.text.trim()
        : _selectedEvent;

    try {
      final res = await ApiService.instance.generateCertificate(
        studentName: _selectedStudent!.name,
        className: _selectedStudent!.className,
        achievementType: achievement,
        termOrEvent: event,
      );
      setState(() => _certificateData = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating certificate: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printCertificatePdf() async {
    if (_certificateData == null || _selectedStudent == null) return;
    await PdfFonts.ensureLoaded();
    final pdf = pw.Document();

    final sName = _selectedStudent!.name;
    final cName = _selectedStudent!.className;
    final fatherName = _selectedStudent!.fatherName;
    final title = _certificateData!['title'] ?? 'CERTIFICATE OF MERIT';
    final citeEn = _certificateData!['citation_english'] ?? '';
    final citeUr = _certificateData!['citation_urdu'] ?? '';
    final presentedBy = _certificateData!['presented_by'] ?? 'Sadia Babar, Principal';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: PdfFonts.theme,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.amber800, width: 4),
            ),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.5),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'SUBLIME GRAMMAR SCHOOL',
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Recognized & Registered Educational Institution | Lahore, Pakistan',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: const pw.BoxDecoration(color: PdfColors.amber800),
                    child: pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'This is proudly presented to',
                    style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    sName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                  pw.Text(
                    'Son/Daughter of $fatherName | $cName',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
                  ),
                  pw.SizedBox(height: 14),
                  // Citation English (if selected)
                  if (_citationLanguage == 'English' || _citationLanguage == 'Bilingual') ...[
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                      child: pw.Text(
                        citeEn,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                  ],
                  // Citation Urdu (if selected - using Noto Naskh Arabic & RTL)
                  if (_citationLanguage == 'Urdu' || _citationLanguage == 'Bilingual') ...[
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                      child: pw.Text(
                        citeUr,
                        textAlign: pw.TextAlign.center,
                        textDirection: pw.TextDirection.rtl,
                        style: pw.TextStyle(
                          font: PdfFonts.arabicFont,
                          fontSize: 12,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 20),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        children: [
                          pw.Container(width: 140, height: 1, color: PdfColors.black),
                          pw.SizedBox(height: 4),
                          pw.Text('Class Teacher', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: PdfColors.amber800, width: 2),
                        ),
                        child: pw.Text('SEAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
                      ),
                      pw.Column(
                        children: [
                          pw.Container(width: 140, height: 1, color: PdfColors.black),
                          pw.SizedBox(height: 4),
                          pw.Text(presentedBy, style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Certificate_${_selectedStudent!.name.replaceAll(' ', '_')}.pdf',
    );
  }

  Future<void> _shareOnWhatsApp() async {
    if (_certificateData == null || _selectedStudent == null) return;
    final parentPhone = _selectedStudent!.whatsappNumber ?? _selectedStudent!.phone;
    final achievement = (_selectedAchievement == 'Custom Achievement...' && _customAchievementCtrl.text.trim().isNotEmpty)
        ? _customAchievementCtrl.text.trim()
        : _selectedAchievement;

    final msg = '''محترم والدین، السلام علیکم!
انتہائی مسرت کے ساتھ مطلع کیا جاتا ہے کہ سبلائم گرامر اسکول نے آپ کے لائق فرزند / صاحبزادی ${_selectedStudent!.name} (جماعت ${_selectedStudent!.className}) کو "$achievement" کی شاندار کامیابی پر اعزازی سند (Certificate of Merit) سے نوازا ہے۔

🏆 توصیفی کلمات:
"${_certificateData!['citation_urdu']}"

ہم آپ کو اور آپ کے خاندان کو دلی مبارکباد پیش کرتے ہیں۔
شکریہ، 
سعدیہ بابر، پرنسپل، سبلائم گرامر اسکول''';

    await WhatsAppService.showShareDialog(
      context: context,
      title: 'Share Certificate - ${_selectedStudent!.name}',
      subtitle: 'Class: ${_selectedStudent!.className} • Achievement: $achievement',
      message: msg,
      initialPhone: parentPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Role guard: Only admin / principal can access Certificate Generator
    if (!AuthService.instance.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('🏆 Achievement Certificate'),
          backgroundColor: AppTheme.navyBlue,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings, size: 72, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.navyBlue),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Achievement Certificate Generation is only available to Admin and Principal accounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyBlue),
                  child: const Text('Return to Home', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final students = context.watch<StudentProvider>().students;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('🏆 Achievement Certificate Generator'),
        backgroundColor: AppTheme.navyBlue,
        actions: [
          if (_certificateData != null) ...[
            IconButton(
              icon: const Icon(Icons.share, color: Colors.greenAccent),
              tooltip: 'Share on WhatsApp',
              onPressed: _shareOnWhatsApp,
            ),
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              tooltip: 'Print Certificate PDF',
              onPressed: _printCertificatePdf,
            ),
          ],
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
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.military_tech, color: AppTheme.navyBlue),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('AI Merit Citation Generator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Creates official English & Urdu certificates', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<StudentModel>(
                            value: _selectedStudent,
                            decoration: const InputDecoration(labelText: 'Select Student', border: OutlineInputBorder()),
                            items: students.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.className})'))).toList(),
                            onChanged: (v) {
                              setState(() => _selectedStudent = v);
                              _generateCertificate();
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedAchievement,
                                  decoration: const InputDecoration(labelText: 'Achievement', border: OutlineInputBorder()),
                                  items: _achievements.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (v) {
                                    setState(() => _selectedAchievement = v!);
                                    if (v != 'Custom Achievement...') {
                                      _generateCertificate();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedEvent,
                                  decoration: const InputDecoration(labelText: 'Occasion', border: OutlineInputBorder()),
                                  items: _events.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (v) {
                                    setState(() => _selectedEvent = v!);
                                    if (v != 'Custom Occasion...') {
                                      _generateCertificate();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),

                          // Custom Achievement input with mic & EN/UR toggle
                          if (_selectedAchievement == 'Custom Achievement...') ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _customAchievementCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Type or Speak Custom Achievement...',
                                      hintText: 'e.g. Best Robotics Project 2026',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              _isListeningAchievement ? Icons.stop : Icons.mic,
                                              color: _isListeningAchievement ? Colors.red : AppTheme.navyBlue,
                                            ),
                                            tooltip: 'Speak custom achievement',
                                            onPressed: () => _toggleMicForField(isAchievement: true),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: Text(
                                              _voiceLanguage == 'ur_PK' ? '🇵🇰 UR' : '🇬🇧 EN',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
                                            ),
                                            onSelected: (val) => setState(() => _voiceLanguage = val),
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(value: 'ur_PK', child: Text('Urdu (اردو)')),
                                              PopupMenuItem(value: 'en_US', child: Text('English')),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    onSubmitted: (_) => _generateCertificate(),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Custom Occasion input with mic & EN/UR toggle
                          if (_selectedEvent == 'Custom Occasion...') ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _customEventCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Type or Speak Custom Occasion...',
                                      hintText: 'e.g. Spring Science Fair 2026',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              _isListeningEvent ? Icons.stop : Icons.mic,
                                              color: _isListeningEvent ? Colors.red : AppTheme.navyBlue,
                                            ),
                                            tooltip: 'Speak custom occasion',
                                            onPressed: () => _toggleMicForField(isAchievement: false),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: Text(
                                              _voiceLanguage == 'ur_PK' ? '🇵🇰 UR' : '🇬🇧 EN',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
                                            ),
                                            onSelected: (val) => setState(() => _voiceLanguage = val),
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(value: 'ur_PK', child: Text('Urdu (اردو)')),
                                              PopupMenuItem(value: 'en_US', child: Text('English')),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    onSubmitted: (_) => _generateCertificate(),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),
                          // Certificate Citation Language Selection
                          Row(
                            children: [
                              const Text('Main Citation Language: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyBlue)),
                              const SizedBox(width: 8),
                              Wrap(
                                spacing: 6,
                                children: ['Bilingual', 'English', 'Urdu'].map((lang) {
                                  final isSel = _citationLanguage == lang;
                                  return ChoiceChip(
                                    label: Text(
                                      lang == 'Bilingual' ? 'Bilingual (Both)' : (lang == 'English' ? 'English Only' : 'اردو (Urdu Only)'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSel ? Colors.white : AppTheme.navyBlue,
                                      ),
                                    ),
                                    selected: isSel,
                                    selectedColor: AppTheme.navyBlue,
                                    backgroundColor: Colors.grey.shade100,
                                    onSelected: (sel) {
                                      if (sel) setState(() => _citationLanguage = lang);
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _generateCertificate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.navyBlue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: _isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.auto_awesome, color: Colors.white),
                              label: Text(
                                _isLoading ? 'Writing Prestigious Citation...' : 'Regenerate Citation with Qwen-Max',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Certificate Preview Card
                  if (_certificateData != null && _selectedStudent != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.accentGold, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.workspace_premium, color: AppTheme.accentGold, size: 48),
                          const SizedBox(height: 8),
                          const Text(
                            'SUBLIME GRAMMAR SCHOOL',
                            style: TextStyle(
                              color: AppTheme.navyBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Text(
                            'Excellence in Islamic & Modern Education',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _certificateData!['title'] ?? 'CERTIFICATE OF MERIT',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyBlue, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('This prestigious certificate is proudly presented to:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Text(
                            _selectedStudent!.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navyBlue,
                            ),
                          ),
                          Text('Son/Daughter of ${_selectedStudent!.fatherName} • ${_selectedStudent!.className}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          const Divider(height: 28),

                          // English Citation preview
                          if (_citationLanguage == 'English' || _citationLanguage == 'Bilingual') ...[
                            Text(
                              _certificateData!['citation_english'] ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Urdu Citation preview
                          if (_citationLanguage == 'Urdu' || _citationLanguage == 'Bilingual') ...[
                            Text(
                              _certificateData!['citation_urdu'] ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Noto Nastaliq Urdu',
                                fontSize: 14,
                                height: 1.8,
                                color: AppTheme.navyBlue,
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Sadia Babar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('Principal', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _printCertificatePdf,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentGold,
                                  foregroundColor: AppTheme.navyBlue,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.print, size: 16),
                                label: const Text('Print PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
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
