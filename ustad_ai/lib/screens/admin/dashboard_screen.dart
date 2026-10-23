// lib/screens/admin/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/sync_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../database/db_helper.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/network_banner.dart';
import '../teacher/oral_exam_screen.dart';
import '../teacher/stem_hunt_screen.dart';
import '../teacher/roleplay_screen.dart';
import 'staff_attendance_screen.dart';
import 'student_management_screen.dart';
import 'fee_management_screen.dart';
import 'timetable_screen.dart';
import 'report_card_screen.dart';
import 'assembly_screen.dart';
import 'certificate_screen.dart';
import '../teacher/paper_grader_screen.dart';
import '../../widgets/ustad_bol_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _atRiskStudents = [];
  Map<String, int> _classCount = {};
  double _attendanceRate = 0;
  double _monthFeeCollected = 0;
  double _monthFeePending = 0;
  String _currentMonthName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final year = now.year;
      final month = now.month;
      _currentMonthName = DateFormat('MMMM').format(now);
      _atRiskStudents = await DatabaseHelper.instance.getAtRiskStudents();
      _classCount = await DatabaseHelper.instance.getClassWiseStudentCount();
      _attendanceRate = await DatabaseHelper.instance.getAttendanceRate();
      _monthFeeCollected = await DatabaseHelper.instance.getMonthlyFeeCollected(month, year);
      _monthFeePending = await DatabaseHelper.instance.getMonthlyFeePending(month, year);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _riskColor(Map<String, dynamic> s) {
    final absences = s['absence_count'] as int? ?? 0;
    final avg = s['avg_marks'] as double? ?? 100;
    if (absences >= 7 || avg < 35) return AppTheme.errorRed;
    if (absences >= 4 || avg < 50) return AppTheme.warningOrange;
    return AppTheme.accentGold;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final students = context.watch<StudentProvider>().students;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 140,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppTheme.navyBlue,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(gradient: AppTheme.navyGradient),
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Good ${_greeting()}, ${auth.user?.name.split(' ').first ?? 'Admin'} 👋',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.white.withOpacity(0.85),
                                    ),
                                  ),
                                  Text(
                                    'Dashboard Overview',
                                    style: AppTheme.headingSmall.copyWith(color: AppTheme.white),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.person_add_rounded, color: AppTheme.white, size: 24),
                                    tooltip: 'Add & Manage Students',
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const StudentManagementScreen()),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  IconButton(
                                    icon: const Icon(Icons.info_outline_rounded, color: AppTheme.white, size: 22),
                                    tooltip: 'Network & System Architecture',
                                    onPressed: () => showNetworkInfoDialog(context),
                                  ),
                                  const SizedBox(width: 2),
                                  IconButton(
                                    icon: const Icon(Icons.cloud_sync_rounded, color: AppTheme.accentGold, size: 24),
                                    tooltip: 'Sync School Data Online',
                                    onPressed: () async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('☁️ Syncing school data with cloud...'), duration: Duration(seconds: 2)),
                                      );
                                      final res = await SyncService.instance.syncBiDirectional();
                                      if (context.mounted) {
                                        if (res['status'] == 'success') {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('✅ Synced with school cloud successfully!'),
                                              backgroundColor: AppTheme.successGreen,
                                            ),
                                          );
                                          await context.read<StudentProvider>().loadStudents();
                                          await _loadData();
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('📱 Working offline: Changes saved locally on device. Will auto-sync when online cloud connects.'),
                                              backgroundColor: Colors.blueGrey,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 2),
                                  IconButton(
                                    icon: const Icon(Icons.how_to_reg_rounded, color: AppTheme.white, size: 24),
                                    tooltip: 'Staff & Student Attendance',
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const StaffAttendanceScreen()),
                                    ),
                                  ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () async {
                                await context.read<AuthProvider>().logout();
                                if (mounted) Navigator.pushReplacementNamed(context, '/login');
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.logout_rounded, color: AppTheme.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Builder(
                        builder: (context) {
                          final isWide = MediaQuery.of(context).size.width > 600;
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Stat Cards Grid (Responsive for Z Fold 6 & Tablets)
                                GridView.count(
                                  crossAxisCount: isWide ? 4 : 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: isWide ? 1.35 : 1.08,
                                  children: [
                                    StatCard(
                                      title: 'Total Students',
                                      value: '${students.length}',
                                      icon: Icons.people_alt_rounded,
                                      iconBgColor: AppTheme.lightBlue,
                                      iconColor: AppTheme.navyBlue,
                                      subtitle: 'Active enrollment',
                                    ),
                                    StatCard(
                                       title: 'Attendance Rate',
                                       value: '${_attendanceRate.toStringAsFixed(1)}%',
                                       icon: Icons.check_circle_rounded,
                                       iconBgColor: const Color(0xFFDCFCE7),
                                       iconColor: AppTheme.successGreen,
                                       subtitle: 'Staff & Class Attendance',
                                       onTap: () => Navigator.push(
                                         context,
                                         MaterialPageRoute(builder: (_) => const StaffAttendanceScreen(initialTab: 1)),
                                       ),
                                     ),
                                      StatCard(
                                        title: 'Fee Collected',
                                        value: 'Rs. ${NumberFormat("#,##0").format(_monthFeeCollected.toInt())}',
                                        icon: Icons.account_balance_wallet_rounded,
                                        iconBgColor: const Color(0xFFFEF3C7),
                                        iconColor: AppTheme.accentGold,
                                        subtitle: '$_currentMonthName ${DateTime.now().year} • Manage',
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const FeeManagementScreen()),
                                        ),
                                      ),
                                      StatCard(
                                        title: 'Pending Fees',
                                        value: 'Rs. ${NumberFormat("#,##0").format(_monthFeePending.toInt())}',
                                        icon: Icons.warning_amber_rounded,
                                        iconBgColor: const Color(0xFFFEE2E2),
                                        iconColor: AppTheme.errorRed,
                                        subtitle: '$_currentMonthName Dues • Manage',
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const FeeManagementScreen()),
                                        ),
                                      ),
                                   ],
                                 ),

                                 const SizedBox(height: 16),

                                 // Staff & Student Attendance Banner Card
                                 Container(
                                   padding: const EdgeInsets.all(14),
                                   decoration: BoxDecoration(
                                     color: const Color(0xFF0F172A),
                                     borderRadius: BorderRadius.circular(16),
                                     boxShadow: AppTheme.cardShadowList,
                                   ),
                                   child: Column(
                                     children: [
                                       InkWell(
                                         onTap: () => Navigator.push(
                                           context,
                                           MaterialPageRoute(builder: (_) => const StaffAttendanceScreen()),
                                         ),
                                         child: Row(
                                           children: [
                                             Container(
                                               padding: const EdgeInsets.all(8),
                                               decoration: BoxDecoration(
                                                 color: AppTheme.accentGold.withValues(alpha: 0.2),
                                                 borderRadius: BorderRadius.circular(10),
                                               ),
                                               child: const Icon(Icons.fact_check_rounded, color: AppTheme.accentGold, size: 22),
                                             ),
                                             const SizedBox(width: 12),
                                             Expanded(
                                               child: Column(
                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                 children: [
                                                   Text(
                                                     'Attendance Management',
                                                     style: AppTheme.labelMedium.copyWith(color: AppTheme.white, fontWeight: FontWeight.bold),
                                                   ),
                                                   Text(
                                                     'Daily roll call for 11 teachers & student classes',
                                                     style: AppTheme.bodySmall.copyWith(color: AppTheme.white.withValues(alpha: 0.7), fontSize: 11),
                                                   ),
                                                 ],
                                               ),
                                             ),
                                             const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.accentGold, size: 14),
                                           ],
                                         ),
                                       ),
                                       const SizedBox(height: 10),
                                       Row(
                                         children: [
                                           Expanded(
                                             child: InkWell(
                                               onTap: () => Navigator.push(
                                                 context,
                                                 MaterialPageRoute(builder: (_) => const StaffAttendanceScreen(initialTab: 0)),
                                               ),
                                               borderRadius: BorderRadius.circular(10),
                                               child: Container(
                                                 padding: const EdgeInsets.symmetric(vertical: 8),
                                                 decoration: BoxDecoration(
                                                   color: AppTheme.white.withValues(alpha: 0.1),
                                                   borderRadius: BorderRadius.circular(10),
                                                   border: Border.all(color: AppTheme.white.withValues(alpha: 0.2)),
                                                 ),
                                                 child: const Row(
                                                   mainAxisAlignment: MainAxisAlignment.center,
                                                   children: [
                                                     Icon(Icons.badge_rounded, size: 14, color: AppTheme.white),
                                                     SizedBox(width: 6),
                                                     Text('Teachers Staff', style: TextStyle(color: AppTheme.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                   ],
                                                 ),
                                               ),
                                             ),
                                           ),
                                           const SizedBox(width: 8),
                                           Expanded(
                                             child: InkWell(
                                               onTap: () => Navigator.push(
                                                 context,
                                                 MaterialPageRoute(builder: (_) => const StaffAttendanceScreen(initialTab: 1)),
                                               ),
                                               borderRadius: BorderRadius.circular(10),
                                               child: Container(
                                                 padding: const EdgeInsets.symmetric(vertical: 8),
                                                 decoration: BoxDecoration(
                                                   color: AppTheme.accentGold.withValues(alpha: 0.2),
                                                   borderRadius: BorderRadius.circular(10),
                                                   border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.5)),
                                                 ),
                                                 child: const Row(
                                                   mainAxisAlignment: MainAxisAlignment.center,
                                                   children: [
                                                     Icon(Icons.school_rounded, size: 14, color: AppTheme.accentGold),
                                                     SizedBox(width: 6),
                                                     Text('Students by Class', style: TextStyle(color: AppTheme.accentGold, fontSize: 12, fontWeight: FontWeight.bold)),
                                                   ],
                                                 ),
                                               ),
                                             ),
                                           ),
                                         ],
                                       ),
                                     ],
                                   ),
                                 ),

                                const SizedBox(height: 20),

                        // Classroom AI Hub
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('⚡ Classroom AI Hub', style: AppTheme.headingSmall),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.navyBlue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Single-Device Tech',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.navyBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _AiFeatureQuickCard(
                                title: 'Oral Exam',
                                subtitle: 'Voice AI',
                                icon: Icons.mic_rounded,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const OralExamScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _AiFeatureQuickCard(
                                title: 'STEM Hunt',
                                subtitle: 'Camera AI',
                                icon: Icons.camera_alt_rounded,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF047857), Color(0xFF10B981)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const StemHuntScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _AiFeatureQuickCard(
                                title: 'AI Roleplay',
                                subtitle: 'Speaker Audio',
                                icon: Icons.record_voice_over_rounded,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RoleplayScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _AiFeatureQuickCard(
                                title: 'AI Timetable',
                                subtitle: 'Term Plan',
                                icon: Icons.calendar_month_rounded,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const TimetableScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _AiFeatureQuickCard(
                                title: 'Report Cards',
                                subtitle: 'Urdu PDF',
                                icon: Icons.assignment_turned_in_rounded,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ReportCardScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _AiFeatureQuickCard(
                                title: 'Morning Talk',
                                subtitle: 'Chit-Chat & Hadith',
                                icon: Icons.forum_rounded,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFBE185D), Color(0xFFF43F5E)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AssemblyScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _AiFeatureQuickCard(
                                title: '🎙️ Ustad Bol',
                                subtitle: 'Voice Control',
                                icon: Icons.mic_rounded,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1E1B4B), Color(0xFF3730A3)],
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
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _AiFeatureQuickCard(
                                title: 'Certificates',
                                subtitle: 'Merit PDF',
                                icon: Icons.military_tech_rounded,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CertificateScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _AiFeatureQuickCard(
                                title: 'Vision Grader',
                                subtitle: 'Math & Exam',
                                icon: Icons.document_scanner_rounded,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PaperGraderScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // At-Risk Students
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '⚠️ Students Needing Attention',
                                style: AppTheme.headingSmall.copyWith(fontSize: 15.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_atRiskStudents.length} students',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.errorRed,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_atRiskStudents.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppTheme.successGreen),
                                const SizedBox(width: 12),
                                Text('All students are on track! 🎉',
                                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.successGreen)),
                              ],
                            ),
                          )
                        else
                          ..._atRiskStudents.take(8).map((s) => _AtRiskCard(
                                student: s,
                                riskColor: _riskColor(s),
                              )),

                        const SizedBox(height: 24),

                        // Class Distribution Chart
                        if (_classCount.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('📊 Student Distribution by Class',
                                    style: AppTheme.headingSmall.copyWith(fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.successGreen.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Live DB',
                                    style: TextStyle(fontSize: 10, color: AppTheme.successGreen, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 245,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: AppTheme.cardShadowList,
                            ),
                            child: _ClassChart(classCount: _classCount),
                          ),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: FloatingActionButton(
          onPressed: _loadData,
          tooltip: 'Refresh',
          child: const Icon(Icons.refresh_rounded),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _AtRiskCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final Color riskColor;

  const _AtRiskCard({required this.student, required this.riskColor});

  @override
  Widget build(BuildContext context) {
    final absences = student['absence_count'] as int? ?? 0;
    final avg = student['avg_marks'] as double?;
    final unpaid = student['unpaid_fees'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: riskColor, width: 4)),
        boxShadow: AppTheme.cardShadowList,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                (student['name'] as String).substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: riskColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student['name'], style: AppTheme.labelMedium),
                Text(student['class_name'], style: AppTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (absences > 0)
                _RiskTag('${absences}x absent', AppTheme.warningOrange),
              if (avg != null && avg < 50)
                _RiskTag('${avg.toStringAsFixed(0)}% marks', AppTheme.errorRed),
              if (unpaid > 0)
                _RiskTag('${unpaid} fees due', AppTheme.accentGold),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskTag extends StatelessWidget {
  final String text;
  final Color color;
  const _RiskTag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ClassChart extends StatefulWidget {
  final Map<String, int> classCount;
  const _ClassChart({required this.classCount});

  @override
  State<_ClassChart> createState() => _ClassChartState();
}

class _ClassChartState extends State<_ClassChart> {
  int _viewMode = 0; // 0: Bar Chart, 1: Breakdown List

  @override
  Widget build(BuildContext context) {
    final entries = widget.classCount.entries.toList();
    if (entries.isEmpty) {
      return const Center(child: Text('No student records found'));
    }

    final totalStudents = entries.fold<int>(0, (sum, e) => sum + e.value);
    final maxCount = entries.fold<int>(1, (max, e) => e.value > max ? e.value : max);

    final colors = [
      const Color(0xFF1E3A8A), // Deep Navy
      const Color(0xFF0284C7), // Sky Blue
      const Color(0xFF0D9488), // Teal
      const Color(0xFF10B981), // Emerald
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF6366F1), // Indigo
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-header with total and toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.navyBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$totalStudents Students',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'in ${entries.length} classes',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Toggle view button
            GestureDetector(
              onTap: () => setState(() => _viewMode = _viewMode == 0 ? 1 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_viewMode == 0 ? Icons.format_list_bulleted_rounded : Icons.bar_chart_rounded,
                        size: 14, color: AppTheme.navyBlue),
                    const SizedBox(width: 4),
                    Text(
                      _viewMode == 0 ? 'List' : 'Chart',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.navyBlue),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Chart or List View
        Expanded(
          child: _viewMode == 0
              ? BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (maxCount + 0.8).toDouble(),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppTheme.navyBlue,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final c = entries[group.x.toInt()];
                          return BarTooltipItem(
                            '${c.key}\n${c.value} Students (${((c.value / totalStudents) * 100).toStringAsFixed(0)}%)',
                            const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ),
                    barGroups: List.generate(entries.length, (i) {
                      final c = entries[i];
                      final col = colors[i % colors.length];
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: c.value.toDouble(),
                            color: col,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: (maxCount + 0.8).toDouble(),
                              color: AppTheme.offWhite,
                            ),
                          ),
                        ],
                      );
                    }),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                            final name = entries[idx].key.replaceAll('Class ', 'C');
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 18,
                          interval: 1,
                          getTitlesWidget: (v, _) => Text(
                            v.toInt().toString(),
                            style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppTheme.borderColor.withOpacity(0.4),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                )
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final item = entries[i];
                    final pct = totalStudents > 0 ? (item.value / totalStudents) : 0.0;
                    final col = colors[i % colors.length];
                    return Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            item.key,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 8,
                              backgroundColor: AppTheme.offWhite,
                              valueColor: AlwaysStoppedAnimation<Color>(col),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.value} std (${(pct * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: col,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AiFeatureQuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _AiFeatureQuickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

