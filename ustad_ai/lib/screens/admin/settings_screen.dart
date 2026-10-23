// lib/screens/admin/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../models/teacher_model.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_text_field.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final auth = context.read<AuthProvider>();
      final isTeacher = auth.isTeacher;
      _tabCtrl = TabController(length: isTeacher ? 2 : 3, vsync: this);
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTeacher = auth.isTeacher;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.white,
          labelColor: AppTheme.white,
          unselectedLabelColor: AppTheme.white.withOpacity(0.6),
          tabs: [
            if (!isTeacher) const Tab(text: 'Teachers'),
            const Tab(text: 'Account'),
            const Tab(text: 'About'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          if (!isTeacher) const _TeachersTab(),
          const _AccountTab(),
          const _AboutTab(),
        ],
      ),
    );
  }
}

class _TeachersTab extends StatelessWidget {
  const _TeachersTab();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${settings.teachers.length} Teachers', style: AppTheme.headingSmall),
              ElevatedButton.icon(
                onPressed: () => _showAddTeacherDialog(context),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add Teacher'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 38)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: settings.teachers.length,
            itemBuilder: (_, i) => _TeacherCard(teacher: settings.teachers[i]),
          ),
        ),
      ],
    );
  }

  void _showAddTeacherDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddTeacherSheet(),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  final TeacherModel teacher;
  const _TeacherCard({required this.teacher});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadowList,
      ),
      child: ExpansionTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.navyGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              teacher.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ),
        title: Text(teacher.name, style: AppTheme.labelMedium),
        subtitle: Text(
          teacher.assignedClasses.isEmpty ? 'No classes assigned' : teacher.assignedClasses.join(', '),
          style: AppTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Allocate to Desired Classes:', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                      tooltip: 'Remove Teacher',
                      onPressed: () => _confirmDeleteTeacher(context, teacher),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: StudentModel.classes.map((cls) {
                    final assigned = teacher.assignedClasses.contains(cls);
                    return FilterChip(
                      label: Text(cls, style: AppTheme.bodySmall),
                      selected: assigned,
                      onSelected: (v) {
                        final classes = List<String>.from(teacher.assignedClasses);
                        if (v) {
                          classes.add(cls);
                        } else {
                          classes.remove(cls);
                        }
                        context.read<SettingsProvider>().updateTeacher(teacher.copyWith(assignedClasses: classes));
                      },
                      selectedColor: AppTheme.navyBlue,
                      checkmarkColor: AppTheme.white,
                      labelStyle: TextStyle(color: assigned ? AppTheme.white : AppTheme.textPrimary),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTeacher(BuildContext context, TeacherModel teacher) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${teacher.name}?'),
        content: const Text('Are you sure you want to remove this teacher? Their login account will also be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              if (teacher.id != null) {
                await context.read<SettingsProvider>().deleteTeacher(teacher.id!);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${teacher.name} removed successfully')),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _AddTeacherSheet extends StatefulWidget {
  const _AddTeacherSheet();

  @override
  State<_AddTeacherSheet> createState() => _AddTeacherSheetState();
}

class _AddTeacherSheetState extends State<_AddTeacherSheet> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final List<String> _selectedClasses = [];
  bool _saving = false;

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    setState(() => _saving = true);
    try {
      // Check if username already taken
      final existing = await DatabaseHelper.instance.getUserByUsername(_usernameCtrl.text.trim().toLowerCase());
      if (existing != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username already taken')));
        setState(() => _saving = false);
        return;
      }
      final hash = DatabaseHelper.instance.hashPassword(_passwordCtrl.text);
      final user = UserModel(
        name: _nameCtrl.text.trim(),
        username: _usernameCtrl.text.trim().toLowerCase(),
        passwordHash: hash,
        role: 'teacher',
        createdAt: DateTime.now(),
        assignedClass: _selectedClasses.isNotEmpty ? _selectedClasses.first : null,
      );
      final userId = await DatabaseHelper.instance.insertUser(user);
      await DatabaseHelper.instance.insertTeacher(TeacherModel(
        userId: userId,
        name: _nameCtrl.text.trim(),
        assignedClasses: _selectedClasses,
      ));
      await context.read<SettingsProvider>().reloadTeachers();
      setState(() => _saving = false);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Add New Teacher', style: AppTheme.headingSmall),
            const SizedBox(height: 16),
            CustomTextField(controller: _nameCtrl, label: 'Full Name', prefixIcon: Icons.person,
                textCapitalization: TextCapitalization.words),
            const SizedBox(height: 12),
            CustomTextField(controller: _usernameCtrl, label: 'Username (for login)', prefixIcon: Icons.account_circle),
            const SizedBox(height: 12),
            CustomTextField(controller: _passwordCtrl, label: 'Password', prefixIcon: Icons.lock, obscureText: true),
            const SizedBox(height: 16),
            Text('Allocate to Desired Classes:', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: StudentModel.classes.map((cls) {
                final selected = _selectedClasses.contains(cls);
                return FilterChip(
                  label: Text(cls, style: AppTheme.bodySmall),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedClasses.add(cls);
                      } else {
                        _selectedClasses.remove(cls);
                      }
                    });
                  },
                  selectedColor: AppTheme.navyBlue,
                  checkmarkColor: AppTheme.white,
                  labelStyle: TextStyle(color: selected ? AppTheme.white : AppTheme.textPrimary),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white))
                  : const Text('Add Teacher & Save Allocation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTab extends StatefulWidget {
  const _AccountTab();

  @override
  State<_AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<_AccountTab> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.navyGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      (auth.user?.name ?? 'A').substring(0, 1),
                      style: const TextStyle(fontSize: 28, color: AppTheme.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.user?.name ?? '', style: AppTheme.headingSmall.copyWith(color: AppTheme.white)),
                    Text('@${auth.user?.username ?? ''}',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.white.withOpacity(0.7))),
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        auth.user?.role.toUpperCase() ?? '',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.accentGold, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (auth.isTeacher && auth.currentUser?.assignedClass != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          '🔒 Designated Class: ${auth.currentUser!.assignedClass}',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text('Change Password', style: AppTheme.headingSmall),
          const SizedBox(height: 14),
          CustomTextField(controller: _currentCtrl, label: 'Current Password', prefixIcon: Icons.lock, obscureText: true),
          const SizedBox(height: 12),
          CustomTextField(controller: _newCtrl, label: 'New Password', prefixIcon: Icons.lock_open, obscureText: true),
          const SizedBox(height: 12),
          CustomTextField(controller: _confirmCtrl, label: 'Confirm New Password', prefixIcon: Icons.lock_outline, obscureText: true),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              if (_newCtrl.text != _confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match!')));
                return;
              }
              final user = auth.user!;
              final currentHash = DatabaseHelper.instance.hashPassword(_currentCtrl.text);
              if (currentHash != user.passwordHash) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Current password is incorrect!')));
                return;
              }
              await DatabaseHelper.instance.updateUserPassword(
                  user.id!, DatabaseHelper.instance.hashPassword(_newCtrl.text));
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Password changed successfully!')));
              _currentCtrl.clear();
              _newCtrl.clear();
              _confirmCtrl.clear();
            },
            child: const Text('Update Password'),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              await auth.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
              side: const BorderSide(color: AppTheme.errorRed),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: AppTheme.navyGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('🎓', style: TextStyle(fontSize: 50)),
                const SizedBox(height: 12),
                Text('Ustad-AI', style: AppTheme.headingLarge.copyWith(color: AppTheme.white, fontSize: 28)),
                const SizedBox(height: 6),
                Text('Sublime Grammar School', style: AppTheme.bodyMedium.copyWith(color: AppTheme.white.withOpacity(0.8))),
                const SizedBox(height: 6),
                Text('Version 1.0.0', style: AppTheme.bodySmall.copyWith(color: AppTheme.white.withOpacity(0.6))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _InfoCard('🤖 AI Engine', 'Alibaba Cloud Qwen-Max + Qwen-VL'),
          _InfoCard('🎤 Voice Recognition', 'Google Speech-to-Text (on-device)'),
          _InfoCard('🔊 Text-to-Speech', 'Flutter TTS (on-device)'),
          _InfoCard('💾 Database', 'SQLite (local, secure)'),
          _InfoCard('👔 Chairman', 'Ms. Sadia Babar'),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadowList,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
          Text(value, style: AppTheme.bodySmall),
        ],
      ),
    );
  }
}
