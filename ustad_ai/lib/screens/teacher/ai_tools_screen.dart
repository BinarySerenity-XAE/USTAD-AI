// lib/screens/teacher/ai_tools_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/network_banner.dart';
import 'package:provider/provider.dart';
import 'oral_exam_screen.dart';
import 'stem_hunt_screen.dart';
import 'roleplay_screen.dart';
import 'paper_grader_screen.dart';
import 'lesson_planner_screen.dart';
import 'homework_screen.dart';
import '../admin/timetable_screen.dart';
import '../admin/assembly_screen.dart';
import 'class_marks_screen.dart';
import '../../widgets/ustad_bol_sheet.dart';

class AiToolsScreen extends StatelessWidget {
  const AiToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 140,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppTheme.navyBlue,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, color: AppTheme.white, size: 22),
                      tooltip: 'Network & System Architecture',
                      onPressed: () => showNetworkInfoDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: AppTheme.white),
                      onPressed: () async {
                        await context.read<AuthProvider>().logout();
                        if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
                  ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.navyGradient),
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${auth.user?.name ?? 'Teacher'} 👋',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.white.withOpacity(0.85)),
                    ),
                    Text('AI Classroom Tools', style: AppTheme.headingSmall.copyWith(color: AppTheme.white)),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero tools
                  Text('🤖 AI-Powered Tools', style: AppTheme.headingSmall),
                  const SizedBox(height: 6),
                  Text('Transform your classroom with AI', style: AppTheme.bodySmall),
                  const SizedBox(height: 16),

                  _ToolCard(
                    emoji: '🎤',
                    title: 'Voice Oral Exam',
                    subtitle: 'Students answer aloud — AI grades instantly with Urdu feedback',
                    tag: 'STEM + All Subjects',
                    tagColor: AppTheme.navyBlue,
                    gradient: AppTheme.navyGradient,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OralExamScreen())),
                  ),

                  const SizedBox(height: 14),

                  _ToolCard(
                    emoji: '🔍',
                    title: 'STEM Scavenger Hunt',
                    subtitle: 'Students bring objects to the camera — AI identifies and evaluates',
                    tag: 'Camera + Vision AI',
                    tagColor: const Color(0xFF7C3AED),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StemHuntScreen())),
                  ),

                  const SizedBox(height: 14),

                  _ToolCard(
                    emoji: '🎭',
                    title: 'Whole-Class AI Roleplay',
                    subtitle: 'AI becomes a historical figure or scientist — interactive class dialogue',
                    tag: 'Bluetooth Speaker Ready',
                    tagColor: const Color(0xFF059669),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleplayScreen())),
                  ),

                  const SizedBox(height: 14),

                  _ToolCard(
                    emoji: '📝',
                    title: 'AI Handwritten Paper Grader',
                    subtitle: 'Snap photo of student paper or math derivation — Qwen3-VL grades instantly',
                    tag: 'Qwen3-VL Vision',
                    tagColor: const Color(0xFFD97706),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFB45309)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaperGraderScreen())),
                  ),

                  const SizedBox(height: 14),

                  _ToolCard(
                    emoji: '📑',
                    title: '1-Tap SNC Lesson Planner',
                    subtitle: 'Aligned with Punjab SNC — 40-min lesson flow & printable worksheet PDF',
                    tag: 'Punjab SNC Standard',
                    tagColor: const Color(0xFF2563EB),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LessonPlannerScreen())),
                  ),

                  const SizedBox(height: 14),

                  _ToolCard(
                    emoji: '📚',
                    title: 'Homework & 1-Tap Check',
                    subtitle: 'Assign tasks, 1-tap morning notebook inspection & WhatsApp reminders',
                    tag: 'Offline Register + WhatsApp',
                    tagColor: const Color(0xFF0F382C),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F382C), Color(0xFF16503E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeworkScreen())),
                  ),

                  const SizedBox(height: 14),

                  _ToolCard(
                    emoji: '🧮',
                    title: 'Vision Math Auto-Grader',
                    subtitle: 'Step-by-step handwriting math verification with arithmetic error detection',
                    tag: 'Qwen2.5-Math Vision',
                    tagColor: const Color(0xFF0284C7),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaperGraderScreen(initialTabIndex: 1))),
                  ),

                  const SizedBox(height: 14),

                  _ToolCard(
                    emoji: '🎙️',
                    title: 'Ustad Bol Voice Assistant',
                    subtitle: 'Speak in Urdu or English to navigate hands-free or record 30-sec admin notes',
                    tag: 'Hands-Free Urdu & English',
                    tagColor: AppTheme.navyBlue,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const UstadBolSheet(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  _ToolCard(
                    emoji: '🌅',
                    title: 'Class Morning Talk & Hadith',
                    subtitle: 'Classroom entry chit-chat icebreaker, Hadith & spark of the day — unique to your class every day',
                    tag: 'Daily Classroom Warm-Up',
                    tagColor: const Color(0xFFB45309),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB45309), Color(0xFF78350F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssemblyScreen())),
                  ),

                  const SizedBox(height: 14),

                  _ToolCard(
                    emoji: '📊',
                    title: 'Student Marks & Exam Grading',
                    subtitle: 'Enter exam marks, class test scores, monthly assessments & view student rankings',
                    tag: 'Gradebook & Exams',
                    tagColor: const Color(0xFF0F382C),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F382C), Color(0xFF16503E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassMarksScreen())),
                  ),

                  const SizedBox(height: 16),

                  // Horizontal Buttons for Timetable & Weekly Schedule
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TimetableScreen(
                                initialClass: auth.user?.assignedClass ?? 'Class 5',
                                initialTab: 0,
                              ),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F382C), Color(0xFF16503E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppTheme.cardShadowList,
                            ),
                            child: const Column(
                              children: [
                                Text('📅', style: TextStyle(fontSize: 26)),
                                SizedBox(height: 8),
                                Text(
                                  'Class Timetable',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Period Matrix',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TimetableScreen(
                                initialClass: auth.user?.assignedClass ?? 'Class 5',
                                initialTab: 1,
                              ),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E293B), Color(0xFF334155)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppTheme.cardShadowList,
                            ),
                            child: const Column(
                              children: [
                                Text('📓', style: TextStyle(fontSize: 26)),
                                SizedBox(height: 8),
                                Text(
                                  'Weekly Schedule',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  '7-Day SNC Diary',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String tag;
  final Color tagColor;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ToolCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient).colors.first.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(tag,
                        style: const TextStyle(fontSize: 10, color: AppTheme.white, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 6),
                  Text(title, style: AppTheme.headingSmall.copyWith(color: AppTheme.white, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.white.withOpacity(0.8)),
                      maxLines: 2),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.white, size: 18),
          ],
        ),
      ),
    );
  }
}
