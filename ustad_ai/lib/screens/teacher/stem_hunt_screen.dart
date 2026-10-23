// lib/screens/teacher/stem_hunt_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/student_model.dart';
import '../../database/db_helper.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/network_banner.dart';

class StemHuntScreen extends StatefulWidget {
  const StemHuntScreen({super.key});

  @override
  State<StemHuntScreen> createState() => _StemHuntScreenState();
}

class _StemHuntScreenState extends State<StemHuntScreen> {
  String _selectedClass = 'Class 1';
  StudentModel? _selectedStudent;
  List<StudentModel> _students = [];
  final _objectCtrl = TextEditingController();
  File? _capturedImage;
  Map<String, dynamic>? _result;
  bool _isAnalyzing = false;
  final _picker = ImagePicker();

  final List<String> _suggestedObjects = [
    '🌿 Leaf', '🧲 Magnet', '🧪 Cylinder', '⚽ Sphere',
    '📐 Triangle', '💎 Crystal', '🌡️ Thermometer', '🔭 Lens',
    '🪨 Rock', '🌱 Seed', '🦋 Insect', '🔬 Slide',
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isTeacher && auth.currentUser?.assignedClass != null) {
      _selectedClass = auth.currentUser!.assignedClass!;
    }
    _loadStudents();
  }

  @override
  void dispose() {
    _objectCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final students = await DatabaseHelper.instance.getStudentsByClass(_selectedClass);
    setState(() { _students = students; _selectedStudent = null; });
  }

  Future<void> _captureImage() async {
    final img = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (img != null) {
      setState(() { _capturedImage = File(img.path); _result = null; });
    }
  }

  Future<void> _pickFromGallery() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (img != null) {
      setState(() { _capturedImage = File(img.path); _result = null; });
    }
  }

  Future<void> _analyze() async {
    if (_capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please capture an image first')));
      return;
    }
    if (_objectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please specify the expected object')));
      return;
    }
    setState(() { _isAnalyzing = true; _result = null; });

    // Convert image to base64
    final bytes = await _capturedImage!.readAsBytes();
    final base64Image = base64Encode(bytes);

    final result = await ApiService.instance.analyzeStemImage(
      imageBase64: base64Image,
      expectedObject: _objectCtrl.text.trim(),
      className: _selectedClass,
    );

    setState(() { _result = result; _isAnalyzing = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('STEM Scavenger Hunt'),
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
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('🔍', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Vision Challenge', style: AppTheme.headingSmall.copyWith(color: AppTheme.white)),
                        Text('Student brings object to camera — AI identifies it!',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.white.withOpacity(0.8))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Class & Student
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(14), boxShadow: AppTheme.cardShadowList),
              child: Column(
                children: [
                  Builder(
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
                        items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (isTeacher && teacherClass != null)
                            ? null
                            : (v) {
                                setState(() => _selectedClass = v!);
                                _loadStudents();
                              },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<StudentModel>(
                    value: _selectedStudent,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Student', isDense: true,
                        prefixIcon: Icon(Icons.person, color: AppTheme.navyBlue, size: 18)),
                    items: _students.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                    onChanged: (s) => setState(() => _selectedStudent = s),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Expected Object
            Text('What should they find?', style: AppTheme.labelMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _objectCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. A cylinder-shaped object',
                prefixIcon: const Icon(Icons.search, color: AppTheme.navyBlue, size: 20),
                filled: true, fillColor: AppTheme.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.navyBlue, width: 2)),
              ),
            ),
            const SizedBox(height: 10),
            // Quick suggest chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedObjects.map((obj) => ActionChip(
                label: Text(obj, style: const TextStyle(fontSize: 12)),
                onPressed: () => _objectCtrl.text = obj.replaceAll(RegExp(r'^[^\w]+'), '').trim(),
                backgroundColor: AppTheme.lightBlue,
              )).toList(),
            ),

            const SizedBox(height: 20),

            // Camera section
            Text('📸 Capture Object', style: AppTheme.labelMedium),
            const SizedBox(height: 10),

            GestureDetector(
              onTap: _captureImage,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: _capturedImage == null ? AppTheme.lightBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.navyBlue.withOpacity(0.3),
                    style: _capturedImage == null ? BorderStyle.solid : BorderStyle.none,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: _capturedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_rounded, size: 52, color: AppTheme.navyBlue),
                          const SizedBox(height: 10),
                          Text('Tap to open camera', style: AppTheme.bodyMedium.copyWith(color: AppTheme.navyBlue)),
                          Text('Point at student\'s object', style: AppTheme.bodySmall),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_capturedImage!, fit: BoxFit.cover),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: _captureImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppTheme.navyBlue, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.camera_alt_rounded, color: AppTheme.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _captureImage,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Analyze button
            ElevatedButton.icon(
              onPressed: (_capturedImage == null || _isAnalyzing) ? null : _analyze,
              icon: _isAnalyzing
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white)))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isAnalyzing ? 'AI Analyzing...' : '🔍 Analyze with Qwen-VL'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            ),

            // Result
            if (_result != null) ...[
              const SizedBox(height: 20),
              _StemResultCard(result: _result!, expectedObject: _objectCtrl.text),
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

class _StemResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final String expectedObject;
  const _StemResultCard({required this.result, required this.expectedObject});

  @override
  Widget build(BuildContext context) {
    final isMatch = result['is_match'] as bool? ?? false;
    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    final hint = result['hint'] ?? '';
    final hintUrdu = result['hint_urdu'] ?? '';
    final detectedObject = result['detected_object'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isMatch ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isMatch ? AppTheme.successGreen : AppTheme.errorRed, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isMatch ? '✅' : '❌', style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMatch ? 'Correct! Great find! 🎉' : 'Incorrect Match! ❌',
                      style: AppTheme.headingSmall.copyWith(
                          color: isMatch ? AppTheme.successGreen : AppTheme.errorRed,
                          fontWeight: FontWeight.bold),
                    ),
                    if (detectedObject != null && detectedObject.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'AI Detected: $detectedObject',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isMatch ? AppTheme.successGreen : AppTheme.errorRed,
                        ),
                      ),
                    ],
                    Text(
                      'Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text('💬 $hint', style: AppTheme.bodyMedium),
          ],
          if (hintUrdu.isNotEmpty) ...[
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(hintUrdu, style: AppTheme.urduStyle.copyWith(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }
}
