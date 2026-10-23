// lib/widgets/network_banner.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';

class NetworkBanner extends StatefulWidget {
  const NetworkBanner({super.key});

  @override
  State<NetworkBanner> createState() => _NetworkBannerState();
}

class _NetworkBannerState extends State<NetworkBanner> {
  bool _isOffline = false;
  bool _justReconnected = false;
  Timer? _reconnectTimer;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.isEmpty ||
          (results.length == 1 && results.first == ConnectivityResult.none);
      if (mounted) {
        if (_isOffline && !offline) {
          // Transitioned from Offline -> Online
          _reconnectTimer?.cancel();
          setState(() {
            _isOffline = false;
            _justReconnected = true;
          });
          _reconnectTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => _justReconnected = false);
          });
        } else if (_isOffline != offline) {
          setState(() {
            _isOffline = offline;
            _justReconnected = false;
          });
        }
      }
    });
  }

  Future<void> _checkInitial() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final offline = results.isEmpty ||
          (results.length == 1 && results.first == ConnectivityResult.none);
      if (mounted) setState(() => _isOffline = offline);
    } catch (_) {}
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline && !_justReconnected) return const SizedBox.shrink();

    final isReconnected = _justReconnected && !_isOffline;
    final bgColor = isReconnected
        ? AppTheme.successGreen.withValues(alpha: 0.16)
        : AppTheme.warningOrange.withValues(alpha: 0.16);
    final borderColor = isReconnected
        ? AppTheme.successGreen.withValues(alpha: 0.45)
        : AppTheme.warningOrange.withValues(alpha: 0.45);
    final iconColor = isReconnected ? AppTheme.successGreen : AppTheme.warningOrange;

    return Material(
      color: bgColor,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: InkWell(
            onTap: () => showNetworkInfoDialog(context),
          child: Row(
            children: [
              Icon(
                isReconnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isReconnected
                          ? '🌐 Back Online: Live Cloud AI & Services Active'
                          : '⚡ Offline Mode Active: Local SQLite Operating',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.navyBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                    Text(
                      isReconnected
                          ? 'Alibaba Cloud Qwen AI ready. Tap to view feature status.'
                          : '100% of school records, attendance & marks work offline. Tap for info.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.navyBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppTheme.navyBlue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

/// A compact status badge to display in AI screen app bars
class AiModeBadge extends StatelessWidget {
  const AiModeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final results = snapshot.data;
        final isOffline = results != null &&
            (results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none));

        return InkWell(
          onTap: () => showNetworkInfoDialog(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOffline
                  ? AppTheme.warningOrange.withValues(alpha: 0.2)
                  : AppTheme.successGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOffline ? AppTheme.warningOrange : AppTheme.successGreen,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isOffline ? AppTheme.warningOrange : AppTheme.successGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isOffline ? '⚡ Offline AI' : '🌐 Cloud AI',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Comprehensive, crystal-clear network and feature status bottom sheet
void showNetworkInfoDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _NetworkInfoSheet(),
  );
}

class _NetworkInfoSheet extends StatefulWidget {
  @override
  State<_NetworkInfoSheet> createState() => _NetworkInfoSheetState();
}

class _NetworkInfoSheetState extends State<_NetworkInfoSheet> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        setState(() {
          _isOffline = results.isEmpty ||
              (results.length == 1 && results.first == ConnectivityResult.none);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isOffline
                      ? AppTheme.warningOrange.withValues(alpha: 0.15)
                      : AppTheme.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                  color: _isOffline ? AppTheme.warningOrange : AppTheme.successGreen,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ustad-AI Connectivity & Features', style: AppTheme.headingSmall),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isOffline ? AppTheme.warningOrange : AppTheme.successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isOffline
                              ? 'Status: OFFLINE (Local SQLite Mode)'
                              : 'Status: ONLINE (Cloud Qwen AI Active)',
                          style: AppTheme.bodySmall.copyWith(
                            color: _isOffline ? AppTheme.warningOrange : AppTheme.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Role-Aware Scrollable Feature Breakdown (Clean & No Supabase)
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Builder(
                builder: (context) {
                  final auth = Provider.of<AuthProvider?>(context, listen: false);
                  final role = auth?.user?.role ?? '';
                  final isTeacher = role == 'teacher';
                  final isAdmin = role == 'admin' || role == 'principal';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 100% Offline Section
                      _buildSectionHeader(
                        title: '✅ 100% OFFLINE CAPABLE (Zero Internet Required)',
                        subtitle: 'Operates directly on-device using local SQLite database.',
                        headerColor: AppTheme.successGreen,
                      ),
                      const SizedBox(height: 10),

                      if (isAdmin) ...[
                        _buildFeatureRow(
                          icon: Icons.people_alt_rounded,
                          title: 'Student Admissions & Profiles',
                          status: 'Active Offline',
                          desc: 'Add, view, and search student enrollment records locally.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Basic Fee Ledger & Collection',
                          status: 'Active Offline',
                          desc: 'Record monthly tuition fee payments and check outstanding balances.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.how_to_reg_rounded,
                          title: 'Student & Staff Attendance',
                          status: 'Active Offline',
                          desc: 'Mark daily attendance and calculate monthly percentage rates.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.calendar_month_rounded,
                          title: 'Master Class Timetables',
                          status: 'Active Offline',
                          desc: 'Full matrix of classes, periods, and assigned subject teachers.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.description_rounded,
                          title: 'Terminal Report Card Generator',
                          status: 'Active Offline',
                          desc: 'Calculate total marks, percentage, and printable report dossiers.',
                        ),
                      ] else if (isTeacher) ...[
                        _buildFeatureRow(
                          icon: Icons.how_to_reg_rounded,
                          title: 'Class Roll Call Attendance',
                          status: 'Active Offline',
                          desc: 'Mark daily attendance for your assigned class section in seconds.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.calendar_month_rounded,
                          title: 'My Teaching Timetable',
                          status: 'Active Offline',
                          desc: 'View your scheduled teaching periods and assigned classrooms.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.menu_book_rounded,
                          title: '7-Day SNC Teaching Diary',
                          status: 'Active Offline',
                          desc: 'Track and plan weekly textbook units and student learning outcomes.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.mic_rounded,
                          title: 'Voice Notes & Attendance Command',
                          status: 'Active Offline',
                          desc: 'Hands-free voice recognition for classroom operations.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.theater_comedy_rounded,
                          title: 'Curriculum AI Roleplay (Offline)',
                          status: 'Fallback Scripts',
                          desc: 'Interactive historical character dialogues in natural Urdu.',
                        ),
                      ] else ...[
                        // Parent Mode
                        _buildFeatureRow(
                          icon: Icons.how_to_reg_rounded,
                          title: 'Child Attendance Rate',
                          status: 'Active Offline',
                          desc: 'Review your children\'s monthly attendance percentages and absences.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.bar_chart_rounded,
                          title: 'Academic Performance Dossier',
                          status: 'Active Offline',
                          desc: 'Inspect Term 1, Term 2, Term 3, and monthly test progressions.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.menu_book_rounded,
                          title: '7-Day SNC Homework Diary',
                          status: 'Active Offline',
                          desc: 'Access daily class lessons, textbook topics, and assignments.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Tuition Fee Status',
                          status: 'Active Offline',
                          desc: 'Check current month tuition payment status and outstanding dues.',
                        ),
                      ],

                      const SizedBox(height: 20),

                      // 2. Online Only Section
                      _buildSectionHeader(
                        title: '🌐 REQUIRES ACTIVE INTERNET (Online Only)',
                        subtitle: 'Uses live cloud neural networks & external networks.',
                        headerColor: AppTheme.navyBlue,
                      ),
                      const SizedBox(height: 10),

                      if (isTeacher || isAdmin) ...[
                        _buildFeatureRow(
                          icon: Icons.document_scanner_rounded,
                          title: 'Vision AI Paper Grader (Qwen3-VL)',
                          status: 'Requires Internet',
                          desc: 'Camera OCR handwriting extraction & step-by-step paper grading.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.auto_awesome_rounded,
                          title: 'Alibaba Cloud Qwen AI Engine',
                          status: 'Requires Internet',
                          desc: 'Dynamic lesson plan synthesis and advanced reasoning.',
                        ),
                        _buildFeatureRow(
                          icon: Icons.send_rounded,
                          title: 'WhatsApp Message Dispatch',
                          status: 'Requires Internet',
                          desc: 'Sending instant Urdu notifications and fee updates to parents.',
                        ),
                      ] else ...[
                        _buildFeatureRow(
                          icon: Icons.send_rounded,
                          title: 'WhatsApp Alerts & Sync',
                          status: 'Requires Internet',
                          desc: 'Receiving direct school updates and notifications via WhatsApp.',
                        ),
                      ],

                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              backgroundColor: AppTheme.navyBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required Color headerColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.labelMedium.copyWith(
            color: headerColor,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String status,
    required String desc,
  }) {
    final isOfflineFeature = status.contains('Offline') || status.contains('Fallback') || status.contains('Framework');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.offWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isOfflineFeature
                  ? AppTheme.successGreen.withValues(alpha: 0.12)
                  : AppTheme.navyBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isOfflineFeature ? AppTheme.successGreen : AppTheme.navyBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navyBlue,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOfflineFeature
                            ? AppTheme.successGreen.withValues(alpha: 0.12)
                            : AppTheme.accentGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isOfflineFeature ? AppTheme.successGreen : AppTheme.navyBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
