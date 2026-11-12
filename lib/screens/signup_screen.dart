// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'workshop_setup_screen.dart';
import '../app_theme.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();

  String _selectedCountry = 'الأردن (Jordan)';
  String _selectedCountryCode = '+962';

  String _selectedAccountType = 'user';
  bool _hasTowing = false;

  final List<Map<String, String>> _countryCodesList = [
    {'code': '+962', 'name': '+962 (الأردن)'},
    {'code': '+966', 'name': '+966 (السعودية)'},
    {'code': '+971', 'name': '+971 (الإمارات)'},
    {'code': '+20', 'name': '+20 (مصر)'},
    {'code': '+965', 'name': '+965 (الكويت)'},
    {'code': '+974', 'name': '+974 (قطر)'},
    {'code': '+973', 'name': '+973 (البحرين)'},
    {'code': '+968', 'name': '+968 (عمان)'},
    {'code': '+964', 'name': '+964 (العراق)'},
    {'code': '+961', 'name': '+961 (لبنان)'},
    {'code': '+970', 'name': '+970 (فلسطين)'},
    {'code': '+963', 'name': '+963 (سوريا)'},
    {'code': '+213', 'name': '+213 (الجزائر)'},
    {'code': '+212', 'name': '+212 (المغرب)'},
    {'code': '+216', 'name': '+216 (تونس)'},
    {'code': '+249', 'name': '+249 (السودان)'},
    {'code': '+967', 'name': '+967 (اليمن)'},
    {'code': '+1', 'name': '+1 (أمريكا/كندا)'},
    {'code': '+44', 'name': '+44 (بريطانيا)'},
    {'code': '+90', 'name': '+90 (تركيا)'},
    {'code': '+49', 'name': '+49 (ألمانيا)'},
    {'code': '+33', 'name': '+33 (فرنسا)'},
    {'code': '+39', 'name': '+39 (إيطاليا)'},
    {'code': '+34', 'name': '+34 (إسبانيا)'},
    {'code': '+61', 'name': '+61 (أستراليا)'},
    {'code': '+55', 'name': '+55 (البرازيل)'},
    {'code': '+91', 'name': '+91 (الهند)'},
    {'code': '+86', 'name': '+86 (الصين)'},
    {'code': '+81', 'name': '+81 (اليابان)'},
    {'code': '+82', 'name': '+82 (كوريا الجنوبية)'},
    {'code': '+7', 'name': '+7 (روسيا)'},
    {'code': '+92', 'name': '+92 (باكستان)'},
    {'code': '+880', 'name': '+880 (بنغلاديش)'},
    {'code': '+62', 'name': '+62 (إندونيسيا)'},
    {'code': '+60', 'name': '+60 (ماليزيا)'},
    {'code': '+65', 'name': '+65 (سنغافورة)'},
    {'code': '+98', 'name': '+98 (إيران)'},
    {'code': '+93', 'name': '+93 (أفغانستان)'},
    {'code': '+00', 'name': '+00 (دولة أخرى)'},
  ];

  final List<String> _worldCountries = [
    'الأردن (Jordan)',
    'المملكة العربية السعودية (Saudi Arabia)',
    'الإمارات العربية المتحدة (UAE)',
    'مصر (Egypt)',
    'الكويت (Kuwait)',
    'قطر (Qatar)',
    'البحرين (Bahrain)',
    'عمان (Oman)',
    'العراق (Iraq)',
    'لبنان (Lebanon)',
    'فلسطين (Palestine)',
    'سوريا (Syria)',
    'الجزائر (Algeria)',
    'المغرب (Morocco)',
    'تونس (Tunisia)',
    'السودان (Sudan)',
    'اليمن (Yemen)',
    'الولايات المتحدة (USA)',
    'المملكة المتحدة (UK)',
    'تركيا (Turkey)',
    'ألمانيا (Germany)',
    'فرنسا (France)',
    'إيطاليا (Italy)',
    'إسبانيا (Spain)',
    'كندا (Canada)',
    'أستراليا (Australia)',
    'البرازيل (Brazil)',
    'الهند (India)',
    'الصين (China)',
    'اليابان (Japan)',
    'كوريا الجنوبية (South Korea)',
    'روسيا (Russia)',
    'باكستان (Pakistan)',
    'بنغلاديش (Bangladesh)',
    'إندونيسيا (Indonesia)',
    'ماليزيا (Malaysia)',
    'سنغافورة (Singapore)',
    'إيران (Iran)',
    'أفغانستان (Afghanistan)',
    'دولة أخرى (Other)'
  ];

  bool _isLoading = false;
  final bool _isArabic = true;
  String? _errorMessage;

  void _proceedToNextStep() {
    setState(() => _errorMessage = null);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final username = _usernameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final fullName = _fullNameController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        username.isEmpty ||
        rawPhone.isEmpty ||
        fullName.isEmpty) {
      setState(() => _errorMessage = 'يرجى تعبئة جميع الحقول المطلوبة');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'كلمات المرور غير متطابقة');
      return;
    }

    if (password.length < 6) {
      setState(
          () => _errorMessage = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    final cleanPhoneDigits =
        rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone;
    final fullPhone = '$_selectedCountryCode$cleanPhoneDigits';

    if (_selectedAccountType == 'mechanic') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkshopSetupScreen(
            email: email,
            password: password,
            username: username,
            fullPhone: fullPhone,
            fullName: fullName,
            country: _selectedCountry,
            role: _selectedAccountType,
            hasTowing: _hasTowing,
          ),
        ),
      );
    } else {
      _executeStandardSignup(email, password, username, fullPhone, fullName);
    }
  }

  Future<void> _executeStandardSignup(String email, String password,
      String username, String fullPhone, String fullName) async {
    setState(() => _isLoading = true);
    try {
      // تحديد العمولة الافتراضية: 2% للمستهلك العادي، 15% للتاجر أو الونش
      final double defaultCommission =
          _selectedAccountType == 'user' ? 0.02 : 0.15;

      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'username': username,
          'phone': fullPhone,
          'country': _selectedCountry,
          'role': _selectedAccountType,
          'has_towing': _selectedAccountType == 'towing',
        },
      );

      if (res.user != null) {
        final userData = {
          'id': res.user!.id,
          'email': email,
          'username': username,
          'phone': fullPhone,
          'full_name': fullName,
          'country': _selectedCountry,
          'role': _selectedAccountType,
          'has_towing': _selectedAccountType == 'towing',
          'subscription_plan': 'free',
          'commission_rate': defaultCommission,
          'max_posts_limit': 5,
        };

        try {
          await Supabase.instance.client.from('customers').upsert(userData);
        } catch (_) {}
        try {
          await Supabase.instance.client.from('profiles').upsert({
            'id': res.user!.id,
            'email': email,
            'username': username,
            'phone': fullPhone,
            'full_name': fullName,
            'country': _selectedCountry,
            'role': _selectedAccountType,
            'has_towing': _selectedAccountType == 'towing',
          });
        } catch (_) {}

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'خطأ في التسجيل: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _fullNameController.dispose();
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
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isArabic ? 'إنشاء حساب جديد' : 'Create Account',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isArabic ? 'اختر نوع الحساب:' : 'Select Account Type:',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    child:
                                        _buildRoleButton('user', 'حساب عادي')),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: _buildRoleButton(
                                        'merchant', 'تاجر عادي')),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                    child: _buildRoleButton(
                                        'mechanic', 'ميكانيكي / ورشة')),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: _buildRoleButton(
                                        'towing', 'صاحب ونش طوارئ')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_selectedAccountType == 'mechanic') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'هل تملك ونش سحب تابع لك؟',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          RadioGroup<bool>(
                            groupValue: _hasTowing,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _hasTowing = value);
                              }
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Radio<bool>(
                                        value: true,
                                        activeColor: AppTheme.primary,
                                      ),
                                      const Text('نعم',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Radio<bool>(
                                        value: false,
                                        activeColor: AppTheme.primary,
                                      ),
                                      const Text('لا',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _fullNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _isArabic ? 'الاسم الكامل' : 'Full Name',
                      prefixIcon:
                          const Icon(Icons.person, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText:
                          _isArabic ? 'اسم المستخدم (Username)' : 'Username',
                      prefixIcon: const Icon(Icons.alternate_email,
                          color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCountry,
                        isExpanded: true,
                        dropdownColor: AppTheme.surface,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        items: _worldCountries.map((String country) {
                          return DropdownMenuItem<String>(
                            value: country,
                            child: Text(country,
                                style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (newValue) =>
                            setState(() => _selectedCountry = newValue!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        height: 56,
                        width: 125,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCountryCode,
                            isExpanded: true,
                            dropdownColor: AppTheme.surface,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            items: _countryCodesList
                                .map((Map<String, String> item) {
                              return DropdownMenuItem<String>(
                                value: item['code'],
                                child: Text(
                                  item['name']!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (newCode) =>
                                setState(() => _selectedCountryCode = newCode!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: _isArabic
                                ? 'رقم الهاتف (بدون الصفر)'
                                : 'Phone Number',
                            prefixIcon: const Icon(Icons.phone,
                                color: AppTheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _isArabic ? 'البريد الإلكتروني' : 'Email',
                      prefixIcon:
                          const Icon(Icons.email, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _isArabic ? 'كلمة المرور' : 'Password',
                      prefixIcon:
                          const Icon(Icons.lock, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText:
                          _isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppTheme.primary),
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
                      onPressed: _isLoading ? null : _proceedToNextStep,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _selectedAccountType == 'mechanic'
                                  ? 'التالي: تحديد موقع الورشة'
                                  : 'سجل الآن',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                        _isArabic
                            ? 'لديك حساب بالفعل؟ تسجيل الدخول'
                            : 'Already have an account? Login',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(String roleValue, String label) {
    final bool isSelected = _selectedAccountType == roleValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedAccountType = roleValue),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade400,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
