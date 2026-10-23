import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../theme/app_theme.dart';
import '../../providers/student_provider.dart';
import '../../models/student_model.dart';
import '../../services/api_service.dart';
import '../../services/whatsapp_service.dart';

class ParentCommsScreen extends StatefulWidget {
  const ParentCommsScreen({super.key});

  @override
  State<ParentCommsScreen> createState() => _ParentCommsScreenState();
}

class _ParentCommsScreenState extends State<ParentCommsScreen> {
  StudentModel? _selectedStudent;
  String _messageType = 'attendance';
  String _generatedMessage = '';
  bool _isGenerating = false;
  final _customCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Speech Recognition
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _voiceLocale = 'ur_PK'; // 'ur_PK' | 'en_US'

  final List<Map<String, dynamic>> _messageTypes = [
    {'type': 'attendance', 'label': 'Attendance Warning', 'icon': '📋', 'color': AppTheme.warningOrange},
    {'type': 'fees', 'label': 'Fee Reminder', 'icon': '💰', 'color': AppTheme.errorRed},
    {'type': 'marks', 'label': 'Exam Results', 'icon': '📊', 'color': AppTheme.navyBlue},
    {'type': 'general', 'label': 'General Notice', 'icon': '📢', 'color': AppTheme.successGreen},
    {'type': 'custom', 'label': 'Custom Notice', 'icon': '✍️', 'color': Color(0xFF7C3AED)},
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (e) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }
    if (mounted) setState(() {});
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
      setState(() => _isListening = true);
      await _speech.listen(
        localeId: _voiceLocale,
        onResult: (result) {
          setState(() {
            _customCtrl.text = result.recognizedWords;
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

  @override
  void dispose() {
    _speech.stop();
    _customCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateMessage() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student first')));
      return;
    }
    setState(() { _isGenerating = true; _generatedMessage = ''; });

    try {
      final result = await ApiService.instance.generateParentMessage(
        studentName: _selectedStudent!.name,
        className: _selectedStudent!.className,
        messageType: _messageType,
        context: {
          'father_name': _selectedStudent!.fatherName,
          'custom_note': _customCtrl.text,
          'school_name': 'Sublime Grammar School',
        },
      );
      setState(() => _generatedMessage = result['urdu_message'] ?? '');
    } catch (e) {
      setState(() => _generatedMessage = '⚠️ Backend not available. Check your connection.');
    }

    setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentProvider>().students;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Parent Communication')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppTheme.navyGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Text('🤖', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Urdu Message Generator',
                            style: AppTheme.headingSmall.copyWith(color: AppTheme.white)),
                        const SizedBox(height: 4),
                        Text('Powered by Qwen-Max — Culturally respectful Urdu messages',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.white.withOpacity(0.8))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Student selector
            Text('Select Student', style: AppTheme.labelMedium),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.cardShadowList,
              ),
              child: DropdownButtonFormField<StudentModel>(
                value: _selectedStudent,
                decoration: const InputDecoration(
                  hintText: 'Choose a student...',
                  prefixIcon: Icon(Icons.person_search, color: AppTheme.navyBlue),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                isExpanded: true,
                items: students.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text('${s.name} — ${s.className}', style: AppTheme.bodyMedium),
                )).toList(),
                onChanged: (s) => setState(() {
                  _selectedStudent = s;
                  if (s != null) {
                    _phoneCtrl.text = s.whatsappNumber ?? s.phone ?? '';
                  }
                }),
              ),
            ),

            const SizedBox(height: 20),

            // Message type
            Text('Message Type', style: AppTheme.labelMedium),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: _messageTypes.map((mt) {
                final selected = _messageType == mt['type'];
                return GestureDetector(
                  onTap: () => setState(() => _messageType = mt['type']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? (mt['color'] as Color).withOpacity(0.15) : AppTheme.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? mt['color'] as Color : AppTheme.borderColor,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(mt['icon'], style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(mt['label'],
                              style: AppTheme.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: selected ? mt['color'] as Color : AppTheme.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Custom note or message with Mic / Voice option
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _messageType == 'custom' ? 'Custom Notice / Message' : 'Additional Note (optional)',
                          style: AppTheme.labelMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isListening) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record, color: AppTheme.errorRed, size: 8),
                              SizedBox(width: 4),
                              Text('Listening...',
                                  style: TextStyle(fontSize: 10, color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Single language switcher next to note label
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _voiceLocale = _voiceLocale == 'ur_PK' ? 'en_US' : 'ur_PK';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _voiceLocale == 'ur_PK' ? '🇵🇰 اردو' : '🇬🇧 Eng',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _customCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: _messageType == 'custom'
                    ? (_voiceLocale == 'ur_PK' ? 'یہاں اپنا پیغام بولیں یا لکھیں...' : 'Speak or type your custom notice...')
                    : 'e.g. "Please come to school on Monday at 9 AM"',
                filled: true,
                fillColor: AppTheme.white,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isListening ? Icons.stop_circle : Icons.mic,
                    color: _isListening ? AppTheme.errorRed : AppTheme.navyBlue,
                  ),
                  tooltip: 'Voice Input',
                  onPressed: _toggleListening,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.navyBlue, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Generate button
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateMessage,
              icon: _isGenerating
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white)))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isGenerating ? 'Generating Urdu Message...' : '✨ Generate Urdu Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navyBlue,
                minimumSize: const Size(double.infinity, 52),
              ),
            ),

            // Generated message
            if (_generatedMessage.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppTheme.cardShadowList,
                  border: Border.all(color: AppTheme.navyBlue.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Generated Message', style: AppTheme.labelMedium),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              tooltip: 'Copy',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _generatedMessage));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Message copied!')));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 20),
                              tooltip: 'Edit',
                              onPressed: () => _showEditDialog(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Urdu text (right-to-left)
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.offWhite,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _generatedMessage,
                          style: AppTheme.urduStyle,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Recipient Phone Input (Pre-filled from student, editable for testing)
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: InputDecoration(
                        labelText: 'Recipient WhatsApp Number',
                        hintText: 'e.g. 03001234567',
                        helperText: 'Pre-filled from student. You can edit to your number for testing!',
                        prefixIcon: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF25D366)),
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.offWhite,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 14),

                    // WhatsApp button
                    ElevatedButton.icon(
                      onPressed: () async {
                        final phone = _phoneCtrl.text.trim();
                        if (phone.isEmpty) {
                          _showPhoneDialog();
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 12),
                                Text('Opening WhatsApp...'),
                              ],
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        final success = await WhatsAppService.sendMessage(
                          phone: phone,
                          message: _generatedMessage,
                        );
                        if (!success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open WhatsApp. Please check if WhatsApp is installed.'),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.chat_rounded, size: 20),
                      label: const Text('Send via WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showEditDialog() {
    final ctrl = TextEditingController(text: _generatedMessage);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Message', style: AppTheme.headingSmall),
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: TextField(
            controller: ctrl,
            maxLines: 8,
            style: AppTheme.urduStyle,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            setState(() => _generatedMessage = ctrl.text);
            Navigator.pop(context);
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  void _showPhoneDialog() {
    WhatsAppService.showShareDialog(
      context: context,
      title: 'Send Notice via WhatsApp',
      message: _generatedMessage,
      initialPhone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
    );
  }
}
