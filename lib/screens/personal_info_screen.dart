import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';

class PersonalInfoScreen extends StatefulWidget {
  final bool isArabic;
  const PersonalInfoScreen({super.key, required this.isArabic});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _supabase = Supabase.instance.client;

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();

  String _selectedCountry = 'الأردن (Jordan)';
  bool _isLoading = true;

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
    'إصدارات أخرى / دولة أجنبية'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _emailController.text = user.email ?? '';

        final data = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data != null) {
          setState(() {
            _fullNameController.text = data['full_name'] ?? '';
            _usernameController.text = data['username'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _ageController.text = data['age']?.toString() ?? '';

            if (data['country'] != null &&
                _worldCountries.contains(data['country'])) {
              _selectedCountry = data['country'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final updates = {
          'id': user.id,
          'full_name': _fullNameController.text.trim(),
          'username': _usernameController.text.trim(),
          'email': user.email,
          'phone': _phoneController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 0,
          'country': _selectedCountry,
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _supabase.from('profiles').upsert(updates);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.isArabic
                  ? 'تم حفظ التعديلات بنجاح'
                  : 'Changes saved successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: Text(widget.isArabic ? 'المعلومات الشخصية' : 'Personal Info',
              style: const TextStyle(color: Colors.white, fontSize: 18)),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                        widget.isArabic ? 'الاسم الكامل' : 'Full Name',
                        _fullNameController,
                        Icons.person),
                    const SizedBox(height: 16),
                    _buildTextField(
                        widget.isArabic
                            ? 'اسم المستخدم (Username)'
                            : 'Username',
                        _usernameController,
                        Icons.alternate_email),
                    const SizedBox(height: 16),
                    _buildTextField(
                        widget.isArabic ? 'البريد الإلكتروني' : 'Email',
                        _emailController,
                        Icons.email,
                        readOnly: true),
                    const SizedBox(height: 16),
                    _buildTextField(
                        widget.isArabic ? 'رقم الهاتف' : 'Phone Number',
                        _phoneController,
                        Icons.phone,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildTextField(widget.isArabic ? 'العمر' : 'Age',
                        _ageController, Icons.cake,
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    Text(widget.isArabic ? 'البلد' : 'Country',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCountry,
                          dropdownColor: AppTheme.surface,
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          items: _worldCountries.map((String country) {
                            return DropdownMenuItem<String>(
                                value: country, child: Text(country));
                          }).toList(),
                          onChanged: (newValue) =>
                              setState(() => _selectedCountry = newValue!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _updateUserData,
                        child: Text(
                            widget.isArabic ? 'حفظ التعديلات' : 'Save Changes',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon,
      {TextInputType keyboardType = TextInputType.text,
      bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: TextStyle(
              color: readOnly ? AppTheme.textSecondary : Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.primaryLight, size: 20),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
