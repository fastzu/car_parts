// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_theme.dart';

class ProviderMembershipScreen extends StatefulWidget {
  final bool isArabic;

  const ProviderMembershipScreen({super.key, required this.isArabic});

  @override
  State<ProviderMembershipScreen> createState() =>
      _ProviderMembershipScreenState();
}

class _ProviderMembershipScreenState extends State<ProviderMembershipScreen> {
  bool _isLoading = true;
  String _currentPlan = 'free';
  String _selectedPaymentMethod = 'Credit Card';

  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'free',
      'titleAr': 'الباقة المجانية',
      'titleEn': 'Free Plan',
      'price': '0',
      'durationAr': 'مجاناً',
      'commission': '15%',
      'featuresAr': [
        'الحد الأقصى 5 منشورات فقط',
        'نسبة عمولة المنصة على المبيعات والخدمات: 15%',
        'ظهور اعتيادي في نتائج البحث',
      ],
    },
    {
      'id': '1_month',
      'titleAr': 'اشتراك شهر واحد',
      'titleEn': '1 Month Plan',
      'price': '1.95',
      'durationAr': 'شهرياً',
      'commission': '10%',
      'featuresAr': [
        'نسبة عمولة مخفضة: 10% فقط',
        'شارة "تاجر / مزود موثوق" بجانب اسمك',
        'عدد منشورات غير محدود',
      ],
    },
    {
      'id': '3_months',
      'titleAr': 'اشتراك 3 أشهر',
      'titleEn': '3 Months Plan',
      'price': '3.95',
      'durationAr': 'كل 3 أشهر',
      'commission': '6.5%',
      'featuresAr': [
        'نسبة عمولة مخفضة: 6.5% فقط',
        'شارة "تاجر / مزود موثوق"',
        'ظهور أعلى وأولوية في نتائج البحث والصفحة الرئيسية',
        'عدد منشورات غير محدود',
      ],
    },
    {
      'id': '6_months',
      'titleAr': 'اشتراك 6 أشهر',
      'titleEn': '6 Months Plan',
      'price': '9.95',
      'durationAr': 'كل 6 أشهر',
      'commission': '2.5%',
      'featuresAr': [
        'نسبة عمولة منخفضة جداً: 2.5% فقط',
        'شارة "تاجر / مزود موثوق"',
        'ظهور أعلى وأولوية في نتائج البحث والصفحة الرئيسية',
        'عدد منشورات غير محدود',
      ],
    },
    {
      'id': '12_months',
      'titleAr': 'اشتراك 12 شهر (الباقة السنوية)',
      'titleEn': '12 Months Plan',
      'price': '24.95',
      'durationAr': 'سنوياً',
      'commission': '0% (بدون عمولة)',
      'featuresAr': [
        'بدون عمولة نهائياً (0%) على جميع مبيعاتك وخدماتك',
        'شارة "تاجر / مزود موثوق"',
        'ظهور أعلى وأولوية قصوى في البحث والصفحة الرئيسية',
        'إعلان مجاني واحد (1) في الصفحة الرئيسية كل شهر',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentPlan();
  }

  Future<void> _fetchCurrentPlan() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('customers')
          .select('subscription_plan')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _currentPlan = res?['subscription_plan']?.toString() ?? 'free';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPaymentDialog(Map<String, dynamic> plan) {
    _selectedPaymentMethod = 'Credit Card';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void handleMethodSelect(String val, bool isDisabled, String name) {
            if (isDisabled) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$name غير متاح حالياً، سيتم تفعيله قريباً'),
                  backgroundColor: Colors.orange.shade800,
                ),
              );
              return;
            }
            setDialogState(() => _selectedPaymentMethod = val);
          }

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'اشتراك: ${plan['titleAr']} (${plan['price']} د.أ)',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اختر وسيلة الدفع المتاحة:',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  _buildPaymentOption(
                    title: 'بطاقة الائتمان (Credit Card)',
                    subtitle: 'Visa / Mastercard',
                    icon: Icons.credit_card,
                    iconColor: Colors.blueAccent,
                    value: 'Credit Card',
                    groupValue: _selectedPaymentMethod,
                    isDisabled: false,
                    onTap: () =>
                        handleMethodSelect('Credit Card', false, 'Credit Card'),
                  ),
                  const SizedBox(height: 8),
                  _buildPaymentOption(
                    title: 'Apple Pay',
                    subtitle: 'غير متاح حالياً (قريباً)',
                    icon: Icons.apple,
                    iconColor: Colors.grey,
                    value: 'Apple Pay',
                    groupValue: _selectedPaymentMethod,
                    isDisabled: true,
                    onTap: () =>
                        handleMethodSelect('Apple Pay', true, 'Apple Pay'),
                  ),
                  const SizedBox(height: 8),
                  _buildPaymentOption(
                    title: 'Google Pay',
                    subtitle: 'غير متاح حالياً (قريباً)',
                    icon: Icons.g_mobiledata,
                    iconColor: Colors.grey,
                    value: 'Google Pay',
                    groupValue: _selectedPaymentMethod,
                    isDisabled: true,
                    onTap: () =>
                        handleMethodSelect('Google Pay', true, 'Google Pay'),
                  ),
                  const SizedBox(height: 8),
                  _buildPaymentOption(
                    title: 'CliQ (كليك)',
                    subtitle: 'معطل مؤقتاً للتفعيل التلقائي',
                    icon: Icons.flash_on,
                    iconColor: Colors.grey,
                    value: 'CliQ',
                    groupValue: _selectedPaymentMethod,
                    isDisabled: true,
                    onTap: () => handleMethodSelect('CliQ', true, 'CliQ'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: () {
                  Navigator.pop(context);
                  _processPaymentViaAPI(plan);
                },
                child: const Text('ادفع الآن',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String groupValue,
    required bool isDisabled,
    required VoidCallback onTap,
  }) {
    final bool isSelected = value == groupValue && !isDisabled;
    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.border,
                width: isSelected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 10)),
                  ],
                ),
              ),
              Icon(
                isDisabled
                    ? Icons.lock_outline
                    : (isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off),
                color: isSelected ? AppTheme.primary : Colors.grey,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPaymentViaAPI(Map<String, dynamic> plan) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
          'https://nsdymdqrlvbhvurwptvq.supabase.co/functions/v1/create-payment');

      const String anonKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5zZHltZHFybHZiaHZ1cndwdHZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzNTQzOTcsImV4cCI6MjEwODkzMDM5N30.IVrWoj0WcapQn9cQS4NYlqKtZI8c4VCq3dPg3BwF0zY';

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
        },
        body: utf8.encode(jsonEncode({
          'user_id': user.id,
          'amount': plan['price'],
          'payment_method': _selectedPaymentMethod,
          'plan_name': 'Provider Plan: ${plan['id']}',
        })),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['redirect_url'] != null) {
          final Uri bankUrl = Uri.parse(resData['redirect_url']);
          if (await canLaunchUrl(bankUrl)) {
            await launchUrl(bankUrl, mode: LaunchMode.externalApplication);
          }
        }
      } else {
        throw 'خطأ في معالجة الدفع';
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text(
            'باقات التجار والورش والونشات',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _plans.length,
                itemBuilder: (context, index) {
                  final plan = _plans[index];
                  final bool isCurrent = _currentPlan == plan['id'];
                  final bool isFree = plan['id'] == 'free';
                  final List<String> features =
                      List<String>.from(plan['featuresAr']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent
                            ? AppTheme.success
                            : (plan['id'] == '12_months'
                                ? Colors.amber
                                : AppTheme.border),
                        width: isCurrent || plan['id'] == '12_months' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                plan['titleAr'],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isFree
                                    ? AppTheme.primary
                                    : Colors.amber.shade800,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isFree
                                    ? 'مجاناً'
                                    : '${plan['price']} د.أ / ${plan['durationAr']}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'نسبة العمولة: ${plan['commission']}',
                            style: const TextStyle(
                                color: AppTheme.primaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...features.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: AppTheme.success, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(f,
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12)),
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCurrent
                                  ? AppTheme.success
                                  : (isFree
                                      ? AppTheme.border
                                      : AppTheme.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: isCurrent || isFree
                                ? null
                                : () => _showPaymentDialog(plan),
                            child: Text(
                              isCurrent
                                  ? 'باقتك الحالية ✅'
                                  : (isFree
                                      ? 'الباقة الافتراضية'
                                      : 'اشترك الآن (${plan['price']} د.أ)'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
