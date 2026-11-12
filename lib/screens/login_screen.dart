// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // تأكد من استيراد مكتبة الـ svg
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'signup_screen.dart';
import '../app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final bool _isArabic = true;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() => _errorMessage = null);
    final input = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      setState(() => _errorMessage =
          'يرجى إدخال اسم المستخدم / الهاتف / البريد الإلكتروني وكلمة المرور');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String resolvedEmail = input;

      // 1. التحقق مما إذا كان المدخل رقم هاتف (يبدأ بـ 07 أو +962)
      if (input.startsWith('07') ||
          input.startsWith('+962') ||
          input.startsWith('962')) {
        String cleanPhone = input;
        if (cleanPhone.startsWith('07')) {
          cleanPhone = '+962${cleanPhone.substring(1)}';
        }

        final customerRes = await Supabase.instance.client
            .from('customers')
            .select('email')
            .or('phone.eq.$input,phone.eq.$cleanPhone')
            .maybeSingle();

        if (customerRes != null && customerRes['email'] != null) {
          resolvedEmail = customerRes['email'];
        } else {
          final profileRes = await Supabase.instance.client
              .from('profiles')
              .select('email')
              .or('phone.eq.$input,phone.eq.$cleanPhone')
              .maybeSingle();

          if (profileRes != null && profileRes['email'] != null) {
            resolvedEmail = profileRes['email'];
          } else {
            throw Exception('رقم الهاتف غير مسجل في النظام.');
          }
        }
      }
      // 2. التحقق مما إذا كان المدخل اسم مستخدم (لا يحتوي على @)
      else if (!input.contains('@')) {
        final customerRes = await Supabase.instance.client
            .from('customers')
            .select('email')
            .eq('username', input)
            .maybeSingle();

        if (customerRes != null && customerRes['email'] != null) {
          resolvedEmail = customerRes['email'];
        } else {
          final profileRes = await Supabase.instance.client
              .from('profiles')
              .select('email')
              .eq('username', input)
              .maybeSingle();

          if (profileRes != null && profileRes['email'] != null) {
            resolvedEmail = profileRes['email'];
          } else {
            throw Exception('اسم المستخدم غير مسجل في النظام.');
          }
        }
      }

      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: resolvedEmail,
        password: password,
      );

      if (res.user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('Invalid login credentials')) {
        msg = 'البيانات المدخلة أو كلمة المرور غير صحيحة.';
      }
      setState(() => _errorMessage = 'خطأ في تسجيل الدخول: $msg');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 👈 إضافة اللوجو الرسمي هنا في أعلى شاشة تسجيل الدخول
                  SizedBox(
                    height: 60,
                    child: SvgPicture.asset(
                      'assets/g-logo-v6-machined.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'مرحباً بك مجدداً في منصة غيارك',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _identifierController,
                    keyboardType: TextInputType.text,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'البريد أو اسم المستخدم أو الهاتف',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      prefixIcon:
                          Icon(Icons.person, color: AppTheme.primaryLight),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      prefixIcon:
                          Icon(Icons.lock, color: AppTheme.primaryLight),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        border: Border.all(color: AppTheme.error),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_errorMessage!,
                          style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('دخول',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignUpScreen()),
                      );
                    },
                    child: const Text(
                      'ليس لديك حساب؟ إنشاء حساب جديد',
                      style: TextStyle(
                          color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
