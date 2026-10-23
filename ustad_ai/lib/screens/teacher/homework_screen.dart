// lib/screens/teacher/homework_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../models/homework_model.dart';
import '../../models/student_model.dart';
import '../../database/db_helper.dart';
import '../../services/api_service.dart';
import '../../services/whatsapp_service.dart';
import '../../widgets/network_banner.dart';

class HomeworkScreen extends StatefulWidget {
  final String? designatedClass;

  const HomeworkScreen({super.key, this.designatedClass});

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedClass;
  String _selectedSubject = 'Mathematics';
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));

  // Images for Task and Detailed Instructions
  File? _taskImage;
  File? _instructionsImage;
  final ImagePicker _picker = ImagePicker();

  // Speech Recognition
  final SpeechToText _stt = SpeechToText();
  bool _isListeningTask = false;
  bool _isListeningDesc = false;
  String _voiceLanguage = 'ur_PK'; // 'ur_PK' | 'en_US'

  // Student Targeting for assignment
  StudentModel? _targetStudent; // null = All students in class

  List<HomeworkModel> _homeworkList = [];
  HomeworkModel? _activeAssignment;
  Map<int, bool> _studentCompletionMap = {};
  bool _isLoading = false;

  final List<String> _defaultSubjects = [
    'Mathematics',
    'General Science',
    'English',
    'Urdu',
    'Islamiyat',
    'Computer Science',
    'Social Studies',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final auth = context.read<AuthProvider>();
    _selectedClass = widget.designatedClass ?? auth.user?.assignedClass ?? 'Class 5';
    _loadHomework();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _stt.stop();
    super.dispose();
  }

  Future<void> _toggleMic(bool isTask) async {
    final currentlyListening = isTask ? _isListeningTask : _isListeningDesc;
    if (currentlyListening) {
      await _stt.stop();
      setState(() {
        _isListeningTask = false;
        _isListeningDesc = false;
      });
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

    setState(() {
      _isListeningTask = isTask;
      _isListeningDesc = !isTask;
    });

    final locale = _voiceLanguage == 'ur_PK' ? 'ur_PK' : 'en_US';
    try {
      await _stt.listen(
        localeId: locale,
        onResult: (r) {
          setState(() {
            if (isTask) {
              _titleController.text = r.recognizedWords;
            } else {
              _descController.text = r.recognizedWords;
            }
          });
          if (r.finalResult) {
            setState(() {
              _isListeningTask = false;
              _isListeningDesc = false;
            });
          }
        },
      );
    } catch (_) {
      setState(() {
        _isListeningTask = false;
        _isListeningDesc = false;
      });
    }
  }

  Future<void> _pickImage(bool isTask) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          if (isTask) {
            _taskImage = File(picked.path);
          } else {
            _instructionsImage = File(picked.path);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _loadHomework() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getHomeworkByClass(_selectedClass);
    setState(() {
      _homeworkList = list;
      if (list.isNotEmpty && _activeAssignment == null) {
        _activeAssignment = list.first;
      }
      _isLoading = false;
    });
    if (_activeAssignment != null) {
      await _loadChecksForAssignment(_activeAssignment!);
    }
  }

  Future<void> _loadChecksForAssignment(HomeworkModel hw) async {
    final students = context.read<StudentProvider>().students.where((s) => s.className == _selectedClass).toList();
    final checks = await DatabaseHelper.instance.getHomeworkChecks(hw.id!);
    final map = <int, bool>{};

    for (final s in students) {
      final existing = checks.where((c) => c.studentId == s.id).toList();
      map[s.id!] = existing.isNotEmpty ? existing.first.isCompleted : true; // default all checked
    }

    setState(() {
      _activeAssignment = hw;
      _studentCompletionMap = map;
    });
  }

  Future<void> _saveNewHomework() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter homework topic or details')),
      );
      return;
    }

    final hw = HomeworkModel(
      className: _selectedClass,
      subjectName: _selectedSubject,
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty ? _titleController.text.trim() : _descController.text.trim(),
      dueDate: _dueDate,
      imagePath: _taskImage?.path,
      instructionsImagePath: _instructionsImage?.path,
      targetStudentId: _targetStudent?.id,
    );

    await DatabaseHelper.instance.insertHomework(hw);
    _titleController.clear();
    _descController.clear();
    setState(() {
      _taskImage = null;
      _instructionsImage = null;
      _targetStudent = null;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Homework created & images saved successfully!')),
    );

    await _loadHomework();
    _tabController.animateTo(1); // Switch to check register
  }

  Future<void> _broadcastWhatsApp(HomeworkModel hw, {StudentModel? specificStudent}) async {
    final dateStr = '${hw.dueDate.day}/${hw.dueDate.month}/${hw.dueDate.year}';
    final students = context.read<StudentProvider>().students.where((s) => s.className == _selectedClass).toList();

    if (specificStudent != null) {
      final phone = specificStudent.whatsappNumber ?? specificStudent.phone;
      final urduText =
          'محترم والدین، السلام علیکم!\nسبلائم گرامر اسکول کی جانب سے مطلع کیا جاتا ہے کہ آپ کے بچے ${specificStudent.name} (جماعت ${_selectedClass}) کے لیے ${hw.subjectName} کا ہوم ورک تفویض کیا گیا ہے:\n\n'
          '📌 عنوان: ${hw.title}\n'
          '📝 تفصیل: ${hw.description}\n'
          '📅 آخری تاریخ: $dateStr\n\n'
          'برائے مہربانی بچے کی کاپی چیک فرما لیں۔\nشکریہ، انتظامیہ سبلائم گرامر اسکول';

      await WhatsAppService.showShareDialog(
        context: context,
        title: 'Share Homework - ${specificStudent.name}',
        subtitle: 'Class: $_selectedClass • Subject: ${hw.subjectName}',
        message: urduText,
        initialPhone: phone,
      );
      return;
    }

    final urduText =
        'محترم والدین، السلام علیکم!\nسبلائم گرامر اسکول کی جانب سے مطلع کیا جاتا ہے کہ جماعت ${_selectedClass} کے لیے ${hw.subjectName} کا ہوم ورک دیا گیا ہے:\n\n'
        '📌 عنوان: ${hw.title}\n'
        '📝 تفصیل: ${hw.description}\n'
        '📅 آخری تاریخ: $dateStr\n\n'
        'برائے مہربانی بچے کی کاپی چیک فرما لیں۔\nشکریہ، انتظامیہ سبلائم گرامر اسکول';

    await WhatsAppService.showShareDialog(
      context: context,
      title: 'Broadcast Homework ($_selectedClass)',
      subtitle: 'Subject: ${hw.subjectName} (${students.length} students)',
      message: urduText,
      students: students,
    );
  }

  void _showStudentShareDialog(HomeworkModel hw) {
    _broadcastWhatsApp(hw);
  }

  Future<void> _saveCheckmarks() async {
    if (_activeAssignment == null) return;
    final students = context.read<StudentProvider>().students.where((s) => s.className == _selectedClass).toList();

    for (final s in students) {
      final isDone = _studentCompletionMap[s.id] ?? true;
      final check = HomeworkCheckModel(
        homeworkId: _activeAssignment!.id!,
        studentId: s.id!,
        studentName: s.name,
        isCompleted: isDone,
      );
      await DatabaseHelper.instance.saveHomeworkCheck(check);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Homework inspection saved to local register!')),
    );
  }

  Future<void> _remindIncompleteParents() async {
    if (_activeAssignment == null) return;
    final students = context.read<StudentProvider>().students.where((s) => s.className == _selectedClass).toList();
    final incomplete = students.where((s) => (_studentCompletionMap[s.id] ?? true) == false).toList();

    if (incomplete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 All students completed their homework! No reminders needed.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.red),
            SizedBox(width: 8),
            Text('Select Student to Remind', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${incomplete.length} student(s) did not complete homework. Tap student to dispatch reminder:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: incomplete.length,
                  itemBuilder: (_, i) {
                    final target = incomplete[i];
                    final phone = target.whatsappNumber ?? target.phone;
                    return ListTile(
                      dense: true,
                      leading: const CircleAvatar(radius: 14, backgroundColor: Colors.redAccent, child: Icon(Icons.close, color: Colors.white, size: 16)),
                      title: Text(target.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(phone != null && phone.isNotEmpty ? 'WhatsApp: $phone' : 'No phone saved', style: const TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.send, color: Colors.red, size: 18),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _sendReminderToStudent(target);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Future<void> _sendReminderToStudent(StudentModel target) async {
    if (_activeAssignment == null) return;
    final dateStr = '${_activeAssignment!.dueDate.day}/${_activeAssignment!.dueDate.month}';
    final urduMsg = await ApiService.instance.generateHomeworkReminder(
      studentName: target.name,
      className: _selectedClass,
      subject: _activeAssignment!.subjectName,
      homeworkTitle: _activeAssignment!.title,
      dueDate: dateStr,
      isOverdue: true,
    );

    final phone = target.whatsappNumber ?? target.phone;
    await WhatsAppService.showShareDialog(
      context: context,
      title: 'Homework Reminder - ${target.name}',
      subtitle: 'Class: $_selectedClass • Due: $dateStr',
      message: urduMsg,
      initialPhone: phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentProvider>().students.where((s) => s.className == _selectedClass).toList();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text('Homework Register — $_selectedClass'),
        backgroundColor: AppTheme.navyBlue,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentGold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.edit_note, color: Colors.white),
              child: Text(
                'Assign Homework',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            Tab(
              icon: Icon(Icons.checklist_rtl, color: Colors.white),
              child: Text(
                '1-Tap Check Register',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
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
                // Tab 1: Create Homework
                SingleChildScrollView(
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
                                  Text(
                                    'Assign New Homework / ہوم ورک اندراج',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.navyBlue,
                                        ),
                                  ),
                                  // Voice Language Toggle
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                      value: _selectedSubject,
                                      decoration: const InputDecoration(
                                        labelText: 'Subject / مضمون',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.book),
                                      ),
                                      items: _defaultSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                      onChanged: (v) => setState(() => _selectedSubject = v!),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<StudentModel?>(
                                      value: _targetStudent,
                                      decoration: const InputDecoration(
                                        labelText: 'Target Student',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.person_pin),
                                      ),
                                      items: [
                                        const DropdownMenuItem<StudentModel?>(
                                          value: null,
                                          child: Text('All Students (Entire Class)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        ...students.map((s) => DropdownMenuItem<StudentModel?>(
                                              value: s,
                                              child: Text(s.name, style: const TextStyle(fontSize: 12)),
                                            )),
                                      ],
                                      onChanged: (v) => setState(() => _targetStudent = v),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Homework Task field with Mic (EN/UR) and Photo attachment
                              TextField(
                                controller: _titleController,
                                decoration: InputDecoration(
                                  labelText: 'Homework Task / عنوان',
                                  hintText: 'e.g., Ex 3.2 Q 1 to 5 on copies',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.assignment),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.navyBlue, size: 20),
                                        tooltip: 'Attach Task Image',
                                        onPressed: () => _pickImage(true),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _isListeningTask ? Icons.mic : Icons.mic_none,
                                          color: _isListeningTask ? Colors.red : AppTheme.navyBlue,
                                        ),
                                        tooltip: 'Voice Input Task (${_voiceLanguage == 'ur_PK' ? 'اردو' : 'English'})',
                                        onPressed: () => _toggleMic(true),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_taskImage != null) ...[
                                const SizedBox(height: 6),
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(_taskImage!, height: 80, width: double.infinity, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.black54,
                                        radius: 12,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.close, color: Colors.white, size: 14),
                                          onPressed: () => setState(() => _taskImage = null),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),

                              // Detailed Instructions field with Mic (EN/UR) and Photo attachment
                              TextField(
                                controller: _descController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Detailed Instructions / تفصیل',
                                  hintText: 'Read chapter 4 and write words meanings in Urdu copy.',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.notes),
                                  suffixIcon: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.navyBlue, size: 20),
                                        tooltip: 'Attach Instructions Image',
                                        onPressed: () => _pickImage(false),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _isListeningDesc ? Icons.mic : Icons.mic_none,
                                          color: _isListeningDesc ? Colors.red : AppTheme.navyBlue,
                                        ),
                                        tooltip: 'Voice Input Instructions (${_voiceLanguage == 'ur_PK' ? 'اردو' : 'English'})',
                                        onPressed: () => _toggleMic(false),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_instructionsImage != null) ...[
                                const SizedBox(height: 6),
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(_instructionsImage!, height: 80, width: double.infinity, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.black54,
                                        radius: 12,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.close, color: Colors.white, size: 14),
                                          onPressed: () => setState(() => _instructionsImage = null),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: AppTheme.navyBlue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Due Date: ${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _dueDate,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 30)),
                                      );
                                      if (picked != null) setState(() => _dueDate = picked);
                                    },
                                    child: const Text('Change Date'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _saveNewHomework,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.navyBlue,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.save, color: Colors.white),
                                  label: const Text(
                                    'Save Assignment & Open Checklist',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Recent Class Assignments / حالیہ ڈائری',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_homeworkList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No homework assigned yet for this class.', style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ..._homeworkList.map((hw) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.navyBlue.withValues(alpha: 0.1),
                                  child: const Icon(Icons.menu_book, color: AppTheme.navyBlue),
                                ),
                                title: Text('${hw.subjectName}: ${hw.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Due: ${hw.dueDate.day}/${hw.dueDate.month} • ${hw.description}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.share, color: Colors.green),
                                  tooltip: 'Share via WhatsApp (Select Student)',
                                  onPressed: () => _showStudentShareDialog(hw),
                                ),
                              ),
                            )),
                    ],
                  ),
                ),

                // Tab 2: 1-Tap Check Register
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _activeAssignment == null
                        ? const Center(child: Text('No active assignment to check. Assign homework first.'))
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Assignment Summary Bar
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: AppTheme.cardShadowList,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_activeAssignment!.subjectName}: ${_activeAssignment!.title}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            Text(
                                              'Due: ${_activeAssignment!.dueDate.day}/${_activeAssignment!.dueDate.month} • Class: $_selectedClass',
                                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share, color: Colors.green),
                                        tooltip: 'Dispatch WhatsApp to Students',
                                        onPressed: () => _showStudentShareDialog(_activeAssignment!),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Checklist List
                                Expanded(
                                  child: Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    child: ListView.separated(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: students.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, idx) {
                                        final s = students[idx];
                                        final isDone = _studentCompletionMap[s.id] ?? true;
                                        return CheckboxListTile(
                                          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('Roll: ${s.rollNumber ?? "${idx + 1}"} • Phone: ${s.whatsappNumber ?? s.phone ?? "-"}'),
                                          value: isDone,
                                          activeColor: Colors.green,
                                          secondary: CircleAvatar(
                                            backgroundColor: isDone ? Colors.green.shade50 : Colors.red.shade50,
                                            child: Icon(
                                              isDone ? Icons.check : Icons.close,
                                              color: isDone ? Colors.green : Colors.red,
                                              size: 20,
                                            ),
                                          ),
                                          onChanged: (val) {
                                            setState(() {
                                              _studentCompletionMap[s.id!] = val ?? false;
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Bottom Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _remindIncompleteParents,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          side: const BorderSide(color: Colors.red),
                                        ),
                                        icon: const Icon(Icons.notifications_active, color: Colors.red),
                                        label: const Text('Remind Defaulters', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _saveCheckmarks,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.navyBlue,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        icon: const Icon(Icons.save, color: Colors.white),
                                        label: const Text('Save Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
