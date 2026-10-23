// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../config/app_config.dart';
import '../database/db_helper.dart';
import '../widgets/network_banner.dart';
import 'parent/parent_portal_screen.dart';
import '../widgets/whatsapp_agent_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _parentPasswordCtrl = TextEditingController();
  String _selectedRole = 'Admin / Principal';
  bool _obscurePassword = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<String> _roles = ['Admin / Principal', 'Teacher', 'Parent Portal'];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _parentPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_selectedRole == 'Parent Portal') {
      final phone = _parentPhoneCtrl.text.trim();
      final password = _parentPasswordCtrl.text.trim();
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter mobile phone number')),
        );
        return;
      }
      if (password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter parent portal password')),
        );
        return;
      }
      final isValid = await DatabaseHelper.instance.verifyParentPassword(phone, password);
      if (!isValid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid parent password (default: parent123)'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ParentPortalScreen(parentPhone: phone)),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pushReplacementNamed(
        context,
        auth.isAdmin ? '/admin' : '/teacher',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Login failed'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _selectedRole == 'Parent Portal'
          ? const WhatsAppAgentButton()
          : null,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.lightGradient),
        child: SafeArea(
          child: Column(
            children: [
              const NetworkBanner(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    // Header
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppTheme.navyGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.navyBlue.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🎓', style: TextStyle(fontSize: 36)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Ustad-AI',
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.navyBlue,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),

                    Text(
                      'AI Operating System • Sublime Grammar School',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Card
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: AppTheme.cardShadowList,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Role Selector
                            Text('Login As', style: AppTheme.labelMedium),
                            const SizedBox(height: 10),
                            Row(
                              children: _roles.map((role) {
                                final selected = _selectedRole == role;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedRole = role),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: selected ? AppTheme.navyBlue : AppTheme.lightBlue,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              role == 'Admin / Principal'
                                                  ? '🏫'
                                                  : (role == 'Teacher' ? '👩‍🏫' : '👨‍👩‍👧'),
                                              style: const TextStyle(fontSize: 20),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              role,
                                              textAlign: TextAlign.center,
                                              style: AppTheme.bodySmall.copyWith(
                                                color: selected ? AppTheme.white : AppTheme.navyBlue,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            if (AppConfig.isDemoMode) ...[
                              const SizedBox(height: 12),
                              // 1-Tap Quick Demo Logins
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedRole = 'Admin / Principal';
                                          _usernameCtrl.text = 'sadia';
                                          _passwordCtrl.text = 'principal123';
                                        });
                                        _login();
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.lightBlue,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppTheme.navyBlue.withValues(alpha: 0.2)),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Text('⚡', style: TextStyle(fontSize: 13)),
                                              const SizedBox(width: 3),
                                              Text(
                                                'Chairman',
                                                style: AppTheme.bodySmall.copyWith(
                                                  color: AppTheme.navyBlue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedRole = 'Teacher';
                                          _usernameCtrl.text = 'munza';
                                          _passwordCtrl.text = 'teacher123';
                                        });
                                        _login();
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.lightBlue,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppTheme.navyBlue.withValues(alpha: 0.2)),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Text('⚡', style: TextStyle(fontSize: 13)),
                                              const SizedBox(width: 3),
                                              Text(
                                                'Teacher',
                                                style: AppTheme.bodySmall.copyWith(
                                                  color: AppTheme.navyBlue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedRole = 'Parent Portal';
                                          _parentPhoneCtrl.clear();
                                          _parentPasswordCtrl.clear();
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentGold.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppTheme.accentGold),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Text('⚡', style: TextStyle(fontSize: 13)),
                                              const SizedBox(width: 3),
                                              Text(
                                                'Parent',
                                                style: AppTheme.bodySmall.copyWith(
                                                  color: AppTheme.navyBlue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Form Fields
                            if (_selectedRole == 'Parent Portal') ...[
                              CustomTextField(
                                controller: _parentPhoneCtrl,
                                label: 'Parent Mobile Number',
                                hint: 'e.g. 03001234567',
                                prefixIcon: Icons.phone_android_rounded,
                                keyboardType: TextInputType.phone,
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Please enter mobile number' : null,
                              ),
                              const SizedBox(height: 14),
                              CustomTextField(
                                controller: _parentPasswordCtrl,
                                label: 'Parent Password',
                                hint: 'Default: parent123',
                                prefixIcon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Please enter password' : null,
                              ),
                            ] else ...[
                              // Username
                              CustomTextField(
                                controller: _usernameCtrl,
                                label: 'Username',
                                hint: _selectedRole == 'Admin / Principal'
                                    ? 'ansab, moiz, or sadia'
                                    : 'e.g. munza, maham',
                                prefixIcon: Icons.person_outline,
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Please enter username' : null,
                              ),

                              const SizedBox(height: 16),

                              // Password
                              CustomTextField(
                                controller: _passwordCtrl,
                                label: 'Password',
                                hint: 'Default: admin123 / teacher123',
                                prefixIcon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Please enter password' : null,
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Login Button
                            auth.isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : ElevatedButton(
                                    onPressed: _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.navyBlue,
                                      minimumSize: const Size(double.infinity, 54),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _selectedRole == 'Parent Portal'
                                              ? Icons.family_restroom
                                              : Icons.login_rounded,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _selectedRole == 'Parent Portal'
                                              ? 'Access Parent Portal'
                                              : 'Sign In',
                                          style: AppTheme.bodyLarge.copyWith(
                                            color: AppTheme.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
),
);
  }
}
