// lib/screens/teacher/teacher_home.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/student_provider.dart';
import 'ai_tools_screen.dart';
import 'attendance_screen.dart';
import 'class_marks_screen.dart';
import '../admin/settings_screen.dart';
import '../../widgets/ustad_bol_sheet.dart';
import '../../widgets/network_banner.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents();
    });
  }

  List<Widget> get _pages => [
        const AiToolsScreen(),
        const AttendanceScreen(),
        const ClassMarksScreen(),
        const SettingsScreen(),
      ];

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.auto_awesome_rounded, label: 'AI Tools'),
    _NavItem(icon: Icons.calendar_today_rounded, label: 'Attendance'),
    _NavItem(icon: Icons.bar_chart_rounded, label: 'Marks'),
    _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const NetworkBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const UstadBolSheet(),
          );
        },
        backgroundColor: AppTheme.navyBlue,
        elevation: 6,
        icon: const Icon(Icons.mic, color: AppTheme.accentGold, size: 24),
        label: const Text(
          '🎙️ استاد بول',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          boxShadow: [
            BoxShadow(color: AppTheme.cardShadow, blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final selected = _currentIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.navyBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, color: selected ? AppTheme.white : AppTheme.textLight, size: 20),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(item.label,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                    color: selected ? AppTheme.white : AppTheme.textLight)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}
