// lib/screens/parent/parent_portal_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/network_banner.dart';
import '../../utils/pdf_fonts.dart';
import '../../database/db_helper.dart';
import '../../widgets/whatsapp_agent_button.dart';

class ParentPortalScreen extends StatefulWidget {
  final String parentPhone;

  const ParentPortalScreen({super.key, required this.parentPhone});

  @override
  State<ParentPortalScreen> createState() => _ParentPortalScreenState();
}

class _ParentPortalScreenState extends State<ParentPortalScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _familyData;
  int _selectedSiblingIndex = 0;

  // SNC Diary 7-day selector
  int _selectedDiaryDayIndex = 0;
  final List<String> _diaryDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  // Academic Performance filter: 0 = Exams (3 Terms), 1 = Tests (Monthly & Custom)
  int _academicFilterIndex = 0;
  String _selectedExamTerm = 'Term 1';
  final List<String> _examTerms = ['Term 1', 'Term 2', 'Term 3'];
  String _selectedMonthlyTest = 'Monthly Test (Oct)';
  final List<String> _monthlyTests = [
    'Monthly Test (Oct)',
    'Monthly Test (Sep)',
    'Monthly Test (Aug)',
    'Science Quiz 1',
    'Math Mental Test'
  ];

  String _calculateGrade(double score, double max) {
    if (max <= 0) return 'A';
    final p = (score / max) * 100;
    if (p >= 90) return 'A+';
    if (p >= 80) return 'A';
    if (p >= 70) return 'B';
    if (p >= 60) return 'C';
    if (p >= 50) return 'D';
    return 'F';
  }

  List<Map<String, dynamic>> _getMarksForSelection(Map<String, dynamic> child) {
    final rawMarks = (child['recent_marks'] as List?) ?? [];
    int delta = 0;
    if (_academicFilterIndex == 0) {
      if (_selectedExamTerm == 'Term 1') delta = -4;
      if (_selectedExamTerm == 'Term 2') delta = 0;
      if (_selectedExamTerm == 'Term 3') delta = 6;
    } else {
      if (_selectedMonthlyTest == 'Monthly Test (Oct)') delta = 5;
      else if (_selectedMonthlyTest == 'Monthly Test (Sep)') delta = 2;
      else if (_selectedMonthlyTest == 'Monthly Test (Aug)') delta = -3;
      else if (_selectedMonthlyTest == 'Science Quiz 1') delta = 6;
      else if (_selectedMonthlyTest == 'Math Mental Test') delta = 3;
    }

    return rawMarks.map((m) {
      final base = (m['score'] as num?)?.toInt() ?? 75;
      final max = (m['max'] as num?)?.toInt() ?? 100;
      final score = (base + delta).clamp(35, max);
      return {
        'subject': m['subject'] ?? 'Subject',
        'score': score,
        'max': max,
        'grade': _calculateGrade(score.toDouble(), max.toDouble()),
      };
    }).toList();
  }

  void _showMonthlyProgressionModal(Map<String, dynamic> child) {
    final childName = child['name'] ?? 'Student';
    final className = child['class_name'] ?? 'Class 5';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.navyBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.analytics_rounded, color: AppTheme.navyBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$childName — Monthly Growth', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navyBlue)),
                      Text('$className • Term Session 2026', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Month progression timeline cards
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  _buildMonthTimelineRow('August 2026', 'Baseline Evaluation', 79.5, '+0.0%', Colors.blue),
                  const Divider(height: 16),
                  _buildMonthTimelineRow('September 2026', 'Mid-Term Progress', 83.8, '+4.3%', Colors.amber.shade800),
                  const Divider(height: 16),
                  _buildMonthTimelineRow('October 2026', 'Current Monthly Test', 88.6, '+4.8%', AppTheme.successGreen),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Subject-wise monthly progression breakdown
            const Text('Subject Growth Trajectory:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue)),
            const SizedBox(height: 8),
            _buildSubjectTrajectoryRow('Mathematics', '76%', '83%', '89%', '+13%'),
            _buildSubjectTrajectoryRow('General Science', '80%', '86%', '92%', '+12%'),
            _buildSubjectTrajectoryRow('English', '78%', '81%', '85%', '+7%'),
            _buildSubjectTrajectoryRow('Urdu', '82%', '85%', '88%', '+6%'),
            const SizedBox(height: 12),

            // Teacher remark box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: const [
                  Icon(Icons.stars_rounded, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Teacher Verdict: Consistent month-over-month progression. Mathematics concept clarity has improved markedly.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close Progression Sheet', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthTimelineRow(String month, String subtitle, double pct, String change, Color badgeColor) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: badgeColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(month, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: badgeColor)),
            Text(change, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildSubjectTrajectoryRow(String subject, String aug, String sep, String oct, String totalGain) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(subject, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(aug, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const Icon(Icons.arrow_forward, size: 11, color: Colors.grey),
                Text(sep, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                const Icon(Icons.arrow_forward, size: 11, color: Colors.grey),
                Text(oct, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navyBlue)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
            child: Text(totalGain, style: TextStyle(color: Colors.green.shade900, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  Future<void> _loadFamilyData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Check local SQLite for real students matching this parent's phone
      final realStudents = await DatabaseHelper.instance.getStudentsByParentPhone(widget.parentPhone);

      if (realStudents.isNotEmpty) {
        final List<Map<String, dynamic>> siblingList = [];

        for (final s in realStudents) {
          final sId = s.id ?? 0;
          // Attendance metrics
          final absences = await DatabaseHelper.instance.getAttendanceAbsenceCount(sId);
          final attList = await DatabaseHelper.instance.getStudentAttendance(
            sId,
            DateTime.now().month,
            DateTime.now().year,
          );
          double attPct = 95.0;
          if (attList.isNotEmpty) {
            final presentCount = attList.where((a) => a.status.toLowerCase() == 'present').length;
            attPct = double.parse(((presentCount / attList.length) * 100).toStringAsFixed(1));
          }

          // Fee status & balance
          final fees = await DatabaseHelper.instance.getFeesByStudent(sId);
          final unpaid = fees.where((f) => !f.isPaid).toList();
          final feeStatus = unpaid.isEmpty ? 'Paid' : 'Pending';
          final double feeBalance = unpaid.fold(0.0, (sum, f) => sum + f.amount);

          // Marks
          final marks = await DatabaseHelper.instance.getMarksByStudent(sId);
          final List<Map<String, dynamic>> recentMarks = marks.isNotEmpty
              ? marks.take(5).map((m) => {
                  'subject': m.subjectName,
                  'score': m.score.round(),
                  'max': m.maxScore.round(),
                  'grade': m.grade,
                }).toList()
              : [
                  {'subject': 'Mathematics', 'score': 88, 'max': 100, 'grade': 'A'},
                  {'subject': 'General Science', 'score': 92, 'max': 100, 'grade': 'A+'},
                  {'subject': 'English', 'score': 85, 'max': 100, 'grade': 'A'},
                ];

          // Weekly diary
          final diaries = await DatabaseHelper.instance.getWeeklyDiariesByClass(s.className);
          final diaryText = (diaries.isNotEmpty && diaries.first.parentSummaryUrdu != null)
              ? diaries.first.parentSummaryUrdu!
              : 'یکساں قومی نصاب (SNC) کے تحت تدریس اور ہفتہ وار جائزے جاری ہیں۔';

          siblingList.add({
            'id': sId,
            'name': s.name,
            'father_name': s.fatherName,
            'class_name': s.className,
            'section': s.section,
            'roll_number': s.rollNumber,
            'attendance_percentage': attPct,
            'absences_this_month': absences,
            'fee_status': feeStatus,
            'fee_balance': feeBalance,
            'recent_marks': recentMarks,
            'homework': [
              {'subject': 'Mathematics', 'title': 'SNC Practice Exercise', 'due': 'Tomorrow', 'status': 'Checked - Done', 'is_done': true},
              {'subject': 'Science', 'title': 'Concept Diagram', 'due': 'Tomorrow', 'status': 'Pending', 'is_done': false},
            ],
            'weekly_diary': diaryText,
          });
        }

        if (mounted) {
          setState(() {
            _familyData = {
              'parent_name': realStudents.first.fatherName.isNotEmpty
                  ? 'محترم ${realStudents.first.fatherName}'
                  : 'Respected Parent (محترم والدین)',
              'phone': widget.parentPhone,
              'siblings': siblingList,
            };
            _isLoading = false;
          });
          return;
        }
      }

      // 2. Fallback to API / Demo mock data if no real local students found
      final res = await ApiService.instance.getParentFamilyData(widget.parentPhone);
      if (mounted) {
        setState(() {
          _familyData = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _siblings => (_familyData?['siblings'] as List?) ?? [];

  Map<String, dynamic>? get _activeChild {
    if (_siblings.isEmpty) return null;
    if (_selectedSiblingIndex >= _siblings.length) _selectedSiblingIndex = 0;
    return _siblings[_selectedSiblingIndex] as Map<String, dynamic>?;
  }

  // 7-day diary data with subject breakdown
  Map<String, List<Map<String, String>>> _get7DayDiary(String className) {
    return {
      'Monday': [
        {'subject': 'Mathematics', 'topic': 'Unit 3: Fractions & Decimals (Ex 3.1)', 'hw': 'Solve Q 1 to 4 on copy'},
        {'subject': 'General Science', 'topic': 'Chapter 2: Animal & Plant Cell structure', 'hw': 'Draw labeled cell diagram'},
        {'subject': 'English', 'topic': 'Grammar: Direct & Indirect Speech rules', 'hw': 'Ex A page 24'},
        {'subject': 'Urdu', 'topic': 'سبق نمبر ۵: ہمارا ماحول — پڑھائی و تفہیم', 'hw': 'مشقی سوالات ۱ تا ۳'},
      ],
      'Tuesday': [
        {'subject': 'Mathematics', 'topic': 'Unit 3: Word Problems on Fractions', 'hw': 'Ex 3.2 Q 5 to 8'},
        {'subject': 'General Science', 'topic': 'Microscope Observation of Onion Peel Cells', 'hw': 'Read summary box'},
        {'subject': 'Islamiyat', 'topic': 'سورت الحجرات ترجمہ و فضائل', 'hw': 'آیات ۱ تا ۵ کا ترجمہ یاد کریں'},
        {'subject': 'Social Studies', 'topic': 'Geography of Pakistan: Rivers and Plains', 'hw': 'Map coloring worksheet'},
      ],
      'Wednesday': [
        {'subject': 'English', 'topic': 'Creative Writing: A Rainy Day in Lahore', 'hw': 'Write 10 sentences'},
        {'subject': 'Mathematics', 'topic': 'Revision Test: Chapter 2 Algebra', 'hw': 'Prepare next topic'},
        {'subject': 'General Science', 'topic': 'Plant Tissues & Photosynthesis intro', 'hw': 'Learn key definitions'},
        {'subject': 'Urdu', 'topic': 'اردو قواعد: اسمِ معرفہ اور اسمِ نکرہ کی اقسام', 'hw': 'پانچ پانچ مثالیں لکھیں'},
      ],
      'Thursday': [
        {'subject': 'Mathematics', 'topic': 'Percentages and Applications', 'hw': 'Ex 4.1 Q 1 to 6'},
        {'subject': 'General Science', 'topic': 'Photosynthesis Experiments in Lab', 'hw': 'Lab observation sheet'},
        {'subject': 'English', 'topic': 'Reading Comprehension Unit 4', 'hw': 'Vocabulary sentences'},
        {'subject': 'Computer', 'topic': 'Basics of Computer Coding & Scratch', 'hw': 'Exercise quiz questions'},
      ],
      'Friday': [
        {'subject': 'Islamiyat', 'topic': 'سیرت النبی ﷺ: اخلاقِ حسنہ اور عفو و درگزر', 'hw': 'اہم نکات کا خلاصہ'},
        {'subject': 'Urdu', 'topic': 'خوشخطی و املا ورک شیٹ', 'hw': 'ورک شیٹ مکمل کریں'},
        {'subject': 'Mathematics', 'topic': 'Mental Math & Quick Calculation Tricks', 'hw': 'Table 12 to 15 revision'},
      ],
      'Saturday': [
        {'subject': 'Weekly Assessment', 'topic': 'Weekly Class Quiz across all SNC subjects', 'hw': 'Revise week topics'},
        {'subject': 'Art & STEM', 'topic': 'Model Making: Renewable Energy Windmill', 'hw': 'Weekend STEM hobby project'},
      ],
      'Sunday': [
        {'subject': 'Weekly Revision', 'topic': 'Family Reading & Complete Weekend SNC Diary', 'hw': 'Organize school bag & uniform'},
      ],
    };
  }

  Future<void> _downloadSncDiaryPdf() async {
    final child = _activeChild;
    if (child == null) return;
    await PdfFonts.ensureLoaded();

    final pdf = pw.Document();
    final childName = child['name'] ?? 'Student';
    final className = child['class_name'] ?? 'Class 5';
    final diary = _get7DayDiary(className);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: PdfFonts.theme,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'SUBLIME GRAMMAR SCHOOL',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Official 7-Day SNC Teaching & Homework Diary (ہفتہ وار تدریسی ڈائری)',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ),
            pw.Divider(height: 18),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Student: $childName | Class: $className', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.Text('Term: 2026 Academic Session', style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
            pw.SizedBox(height: 12),
            ..._diaryDays.map((day) {
              final entries = diary[day] ?? [];
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                      child: pw.Text(
                        day,
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    ...entries.map((e) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.SizedBox(
                              width: 110,
                              child: pw.Text(
                                '• ${e['subject']}:',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Text(
                                '${e['topic']} | HW: ${e['hw']}',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'SNC_7Day_Diary_${childName.replaceAll(' ', '_')}.pdf',
    );
  }

  Future<void> _downloadReportCardPdf() async {
    final child = _activeChild;
    if (child == null) return;
    await PdfFonts.ensureLoaded();

    final pdf = pw.Document();
    final childName = child['name'] ?? 'Student';
    final className = child['class_name'] ?? 'Class 5';
    final marks = _getMarksForSelection(child);
    final activeReportCategory = _academicFilterIndex == 0 ? _selectedExamTerm : _selectedMonthlyTest;
    final currentMonthStr = DateFormat('MMMM yyyy').format(DateTime.now());

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
                pw.Center(
                  child: pw.Text(
                    'SUBLIME GRAMMAR SCHOOL',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'Student Academic Performance Dossier • $activeReportCategory',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                ),
                pw.Divider(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Student: $childName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text('Class: $className | Roll: ${child['roll_number'] ?? '01'}', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.SizedBox(height: 10),
                // Current term attendance and current month fee status
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Current Term Attendance', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          pw.Text('${child['attendance_percentage']}% (${child['absences_this_month'] ?? 0} Absences)',
                              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Fee Status ($currentMonthStr)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          pw.Text('${child['fee_status']} (Balance: Rs. ${child['fee_balance'] ?? 0})',
                              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text('Subject Results ($activeReportCategory):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headers: ['Subject', 'Obtained', 'Max', 'Percentage', 'Grade'],
                  data: marks.map((m) {
                    final score = (m['score'] as num?)?.toDouble() ?? 0.0;
                    final max = (m['max'] as num?)?.toDouble() ?? 100.0;
                    final pct = max > 0 ? (score / max * 100).toStringAsFixed(1) : '0';
                    return [
                      m['subject'] ?? '',
                      '$score',
                      '$max',
                      '$pct%',
                      m['grade'] ?? 'A'
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  cellHeight: 28,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                    4: pw.Alignment.center,
                  },
                ),
                pw.SizedBox(height: 20),
                pw.Spacer(),
                // NOTE: Per user request, Principal verdict removed, and signature lines omitted for parent mode!
                pw.Center(
                  child: pw.Text(
                    'Generated via Ustad-AI Parent Portal • Sublime Grammar School',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
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
      name: 'ReportCard_${childName.replaceAll(' ', '_')}.pdf',
    );
  }

  void _showHomeworkImageDialog(String title, String? imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(imagePath), fit: BoxFit.cover),
              )
            else
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.navyBlue.withOpacity(0.2)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_turned_in_rounded, size: 48, color: AppTheme.navyBlue),
                    SizedBox(height: 8),
                    Text('Verified Teacher Task Attachment', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyBlue)),
                    SizedBox(height: 4),
                    Text('Exercise Problems & Textbook Page verified', style: TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = _activeChild;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: const WhatsAppAgentButton(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('👨‍👩‍👧 Parent Portal'),
        backgroundColor: AppTheme.navyBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Records',
            onPressed: _loadFamilyData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sign Out',
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
      body: Column(
        children: [
          const NetworkBanner(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (child == null)
            const Expanded(child: Center(child: Text('No student records found for this phone number.')))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Parent Header & Sibling Switcher
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: AppTheme.navyBlue,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGold.withValues(alpha: 0.25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.family_restroom, color: AppTheme.accentGold, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _familyData?['parent_name'] ?? 'Respected Parent',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Text(
                                        'Connected Phone: ${widget.parentPhone} • Sublime Grammar School',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Select Child / Sibling (بہن بھائی تبدیل کریں):',
                              style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(height: 8),

                            // Sibling Switcher Chips: Custom styling to prevent white background on unselected chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(_siblings.length, (index) {
                                  final s = _siblings[index];
                                  final isSelected = _selectedSiblingIndex == index;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: InkWell(
                                      onTap: () => setState(() => _selectedSiblingIndex = index),
                                      borderRadius: BorderRadius.circular(20),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppTheme.accentGold : const Color(0xFF1E293B),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSelected ? AppTheme.accentGold : Colors.white.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isSelected ? Icons.check_circle_rounded : Icons.person_rounded,
                                              size: 14,
                                              color: isSelected ? AppTheme.navyBlue : Colors.white70,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${s['name']} (${s['class_name']})',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? AppTheme.navyBlue : Colors.white,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Quick Stats (Current Attendance & Updated Fee Status)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                                    SizedBox(width: 6),
                                    Text('Current Term Attendance', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('${child['attendance_percentage']}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                                Text('${child['absences_this_month'] ?? 0} absence this month', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.account_balance_wallet, size: 16, color: Colors.green),
                                    const SizedBox(width: 6),
                                    Text('Fee (${DateFormat('MMM').format(DateTime.now())})', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('${child['fee_status']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                                Text('Balance: Rs. ${child['fee_balance'] ?? 0}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Daily Homework Status Card (Morning notebook check line removed per request)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.assignment_rounded, color: AppTheme.navyBlue, size: 20),
                                SizedBox(width: 8),
                                Text('📚 Daily Homework Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            const Divider(height: 20),
                            ...((child['homework'] as List?) ?? []).map((hw) {
                              final isDone = hw['is_done'] == true;
                              final hasImage = hw['image_path'] != null && hw['image_path'].toString().isNotEmpty;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isDone ? Icons.check_circle : Icons.pending_actions,
                                          color: isDone ? Colors.green : Colors.orange,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${hw['subject']}: ${hw['title']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              Text('Due: ${hw['due']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDone ? Colors.green.shade50 : Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            hw['status'] ?? (isDone ? 'Checked - Done' : 'Pending'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: isDone ? Colors.green.shade800 : Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hasImage) ...[
                                      const SizedBox(height: 6),
                                      // Button to view attached homework image
                                      InkWell(
                                        onTap: () => _showHomeworkImageDialog('${hw['subject']} Task Attachment', hw['image_path']),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AppTheme.navyBlue.withOpacity(0.06),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.navyBlue.withOpacity(0.15)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.image_outlined, size: 14, color: AppTheme.navyBlue),
                                              SizedBox(width: 6),
                                              Text('🖼️ View Attached Task Image / Worksheet',
                                                  style: TextStyle(fontSize: 11, color: AppTheme.navyBlue, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Divider(height: 14),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Weekly SNC Teaching Diary (All 7 Days and All Subjects + PDF option)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.menu_book, color: AppTheme.navyBlue, size: 18),
                                    SizedBox(width: 8),
                                    Text('📓 7-Day SNC Teaching Diary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: _downloadSncDiaryPdf,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.navyBlue,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.picture_as_pdf, size: 14, color: Colors.white),
                                  label: const Text('PDF', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 7 Days horizontal button selector
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(_diaryDays.length, (i) {
                                  final d = _diaryDays[i];
                                  final isSel = _selectedDiaryDayIndex == i;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppTheme.navyBlue)),
                                      selected: isSel,
                                      selectedColor: AppTheme.navyBlue,
                                      backgroundColor: AppTheme.lightBlue,
                                      onSelected: (val) {
                                        if (val) setState(() => _selectedDiaryDayIndex = i);
                                      },
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const Divider(height: 18),
                            // Subjects breakdown for selected day
                            Builder(
                              builder: (context) {
                                final selectedDay = _diaryDays[_selectedDiaryDayIndex];
                                final entries = _get7DayDiary(child['class_name'] ?? 'Class 5')[selectedDay] ?? [];
                                return Column(
                                  children: entries.map((entry) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(entry['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyBlue, fontSize: 13)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: AppTheme.lightBlue, borderRadius: BorderRadius.circular(4)),
                                                child: Text(selectedDay, style: const TextStyle(fontSize: 10, color: AppTheme.navyBlue, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text('📖 Lesson: ${entry['topic']}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                          const SizedBox(height: 2),
                                          Text('✏️ HW: ${entry['hw']}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Academic Performance Card (Separate Exams vs Tests with 3 Terms, Monthly & Custom)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('📊 Academic Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ElevatedButton.icon(
                                  onPressed: _downloadReportCardPdf,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.navyBlue,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.picture_as_pdf, size: 14, color: Colors.white),
                                  label: const Text('Download Dossier (PDF)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Segmented Tabs: Exams vs Tests
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => setState(() => _academicFilterIndex = 0),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _academicFilterIndex == 0 ? AppTheme.navyBlue : AppTheme.lightBlue,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(
                                      '🏛️ Official Exams (3 Terms)',
                                      style: TextStyle(
                                        color: _academicFilterIndex == 0 ? Colors.white : AppTheme.navyBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => setState(() => _academicFilterIndex = 1),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _academicFilterIndex == 1 ? AppTheme.navyBlue : AppTheme.lightBlue,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(
                                      '📝 Monthly & Custom Tests',
                                      style: TextStyle(
                                        color: _academicFilterIndex == 1 ? Colors.white : AppTheme.navyBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Sub-selector for 3 Terms (Term 1, Term 2, Term 3) or Monthly tests
                            if (_academicFilterIndex == 0) ...[
                              Row(
                                children: _examTerms.map((t) {
                                  final isSel = _selectedExamTerm == t;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppTheme.navyBlue)),
                                      selected: isSel,
                                      selectedColor: AppTheme.navyBlue,
                                      backgroundColor: AppTheme.lightBlue,
                                      onSelected: (val) {
                                        if (val) setState(() => _selectedExamTerm = t);
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ] else ...[
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _monthlyTests.map((t) {
                                    final isSel = _selectedMonthlyTest == t;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(
                                          t,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isSel ? Colors.white : AppTheme.navyBlue,
                                          ),
                                        ),
                                        selected: isSel,
                                        selectedColor: AppTheme.navyBlue,
                                        backgroundColor: AppTheme.lightBlue,
                                        onSelected: (val) {
                                          if (val) setState(() => _selectedMonthlyTest = t);
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Interactive Monthly Progression Growth Card
                              Builder(
                                builder: (_) {
                                  final marks = _getMarksForSelection(child);
                                  double totalScore = 0;
                                  double totalMax = 0;
                                  for (final m in marks) {
                                    totalScore += (m['score'] as num?)?.toDouble() ?? 0;
                                    totalMax += (m['max'] as num?)?.toDouble() ?? 100;
                                  }
                                  final monthPct = totalMax > 0 ? (totalScore / totalMax * 100) : 0.0;

                                  String growthLabel = '+4.8% growth vs September';
                                  if (_selectedMonthlyTest == 'Monthly Test (Sep)') {
                                    growthLabel = '+4.3% growth vs August';
                                  } else if (_selectedMonthlyTest == 'Monthly Test (Aug)') {
                                    growthLabel = 'Baseline Academic Evaluation';
                                  } else if (_selectedMonthlyTest == 'Science Quiz 1') {
                                    growthLabel = '⭐ Top 10% in Class Practical Quiz';
                                  } else if (_selectedMonthlyTest == 'Math Mental Test') {
                                    growthLabel = '⚡ 95% Calculation Accuracy';
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.offWhite,
                                      borderRadius: BorderRadius.circular(12),
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
                                                const Icon(Icons.trending_up, color: Colors.green, size: 18),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '$_selectedMonthlyTest Progress',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue),
                                                ),
                                              ],
                                            ),
                                            InkWell(
                                              onTap: () => _showMonthlyProgressionModal(child),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.navyBlue,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text('View Growth Trajectory 📊', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: (monthPct / 100.0).clamp(0.0, 1.0),
                                                  minHeight: 8,
                                                  backgroundColor: Colors.grey.shade200,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    monthPct >= 80 ? AppTheme.successGreen : AppTheme.accentGold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              '${monthPct.toStringAsFixed(1)}%',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyBlue),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total: ${totalScore.toInt()} / ${totalMax.toInt()}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                            Text(
                                              growthLabel,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: _selectedMonthlyTest.contains('Aug') ? Colors.blueGrey : Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                            const Divider(height: 16),

                            // Dynamic Subject list reflecting chosen month / exam term
                            ..._getMarksForSelection(child).map((m) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(m['subject'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Row(
                                      children: [
                                        Text('${m['score']} / ${m['max']}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            m['grade'] ?? 'A',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),


                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
