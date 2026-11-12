// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_theme.dart';

class MembershipScreen extends StatefulWidget {
  final bool isArabic;

  const MembershipScreen({super.key, required this.isArabic});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  bool _isLoading = true;
  bool _isProSubscribed = false;
  String _selectedPaymentMethod = 'Credit Card';
  DateTime? _proExpiryDate;

  @override
  void initState() {
    super.initState();
    _checkUserSubscription();
  }

  Future<void> _checkUserSubscription() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final customerRes = await Supabase.instance.client
          .from('customers')
          .select('subscription_plan, subscription_expires_at')
          .eq('id', user.id)
          .maybeSingle();

      if (customerRes != null && mounted) {
        final plan = customerRes['subscription_plan']?.toString() ?? 'free';
        final expiryStr = customerRes['subscription_expires_at']?.toString();

        bool isPro = false;
        if (plan == 'pro' && expiryStr != null) {
          final expiryDate = DateTime.parse(expiryStr);
          if (DateTime.now().isBefore(expiryDate)) {
            isPro = true;
            _proExpiryDate = expiryDate;
          }
        }

        setState(() {
          _isProSubscribed = isPro;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error checking subscription: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPaymentDialog() {
    _selectedPaymentMethod = 'Credit Card';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void handleMethodSelect(String val, bool isDisabled, String name) {
            if (isDisabled) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(widget.isArabic
                      ? '$name غير متاح حالياً، سيتم تفعيله قريباً'
                      : '$name is currently unavailable'),
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
            title: Row(
              children: [
                const Icon(Icons.payment, color: AppTheme.primary, size: 28),
                const SizedBox(width: 10),
                Text(
                  widget.isArabic
                      ? 'إتمام الدفع (1.95 د.أ)'
                      : 'Complete Payment (1.95 JOD)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isArabic
                        ? 'اختر وسيلة الدفع للاشتراك في باقة البرو (شهر واحد):'
                        : 'Choose payment method for Pro Package (1 Month):',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentOption(
                    title: widget.isArabic ? 'بطاقة الائتمان' : 'Credit Card',
                    subtitle: 'Visa / Mastercard',
                    icon: Icons.credit_card,
                    iconColor: Colors.blueAccent,
                    value: 'Credit Card',
                    groupValue: _selectedPaymentMethod,
                    isDisabled: false,
                    onTap: () =>
                        handleMethodSelect('Credit Card', false, 'Credit Card'),
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentOption(
                    title: 'Apple Pay',
                    subtitle: widget.isArabic
                        ? 'غير متاح حالياً (قريباً)'
                        : 'Currently Unavailable',
                    icon: Icons.apple,
                    iconColor: Colors.grey,
                    value: 'Apple Pay',
                    groupValue: _selectedPaymentMethod,
                    isDisabled: true,
                    onTap: () =>
                        handleMethodSelect('Apple Pay', true, 'Apple Pay'),
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentOption(
                    title: 'Google Pay',
                    subtitle: widget.isArabic
                        ? 'غير متاح حالياً (قريباً)'
                        : 'Currently Unavailable',
                    icon: Icons.g_mobiledata,
                    iconColor: Colors.grey,
                    value: 'Google Pay',
                    groupValue: _selectedPaymentMethod,
                    isDisabled: true,
                    onTap: () =>
                        handleMethodSelect('Google Pay', true, 'Google Pay'),
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentOption(
                    title: 'CliQ (كليك)',
                    subtitle: widget.isArabic
                        ? 'معطل مؤقتاً للتفعيل التلقائي'
                        : 'Temporarily Disabled',
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
                child: Text(widget.isArabic ? 'إلغاء' : 'Cancel',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: () {
                  Navigator.pop(context);
                  _processPaymentViaAPI(_selectedPaymentMethod);
                },
                child: Text(widget.isArabic ? 'ادفع الآن' : 'Pay Now',
                    style: const TextStyle(color: Colors.white)),
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
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
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
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPaymentViaAPI(String paymentMethod) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
          'https://nsdymdqrlvbhvurwptvq.supabase.co/functions/v1/create-payment');

      const String anonKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5zZHltZHFybHZiaHZ1cndwdHZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzNTQzOTcsImV4cCI6MjEwODkzMDM5N30.IVrWoj0WcapQn9cQS4NYlqKtZI8c4VCq3dPg3BwF0zY';

      final Map<String, dynamic> requestBody = {
        'user_id': user.id,
        'amount': '1.95',
        'payment_method': paymentMethod,
        'plan_name': 'Consumer Pro Plan (1 Month)',
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
        },
        body: utf8.encode(jsonEncode(requestBody)),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['redirect_url'] != null) {
          final Uri bankUrl = Uri.parse(resData['redirect_url']);
          if (await canLaunchUrl(bankUrl)) {
            await launchUrl(bankUrl, mode: LaunchMode.externalApplication);
          } else {
            throw 'تعذر فتح صفحة الدفع الخاصة بالبنك';
          }
        } else {
          throw resData['error'] ?? 'لم يتم استرجاع رابط الدفع';
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['error'] ?? 'خطأ في الخادم (${response.statusCode})';
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في الاتصال: $e'), backgroundColor: Colors.red),
        );
      }
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
          title: Text(
            widget.isArabic
                ? 'عضوية المستهلك والاشتراكات'
                : 'Consumer Membership',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // الباقة المجانية للمستهلك
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: !_isProSubscribed
                            ? AppTheme.success
                            : AppTheme.border,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.isArabic
                                  ? 'العضوية المجانية'
                                  : 'Free Membership',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('0 د.أ',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.isArabic
                              ? '• تصفح جميع القطع والورش المعتمدة\n• يدفع المستهلك عمولة خدمة 2% فقط عند شراء القطع أو الخدمات\n• تواصل مباشر مع التجار والورش'
                              : '• Browse all parts and workshops\n• 2% service fee on purchases or services\n• Direct chat with sellers',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.border,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: null,
                            child: Text(
                              _isProSubscribed
                                  ? (widget.isArabic
                                      ? 'أنت مشترك حالياً في البرو حتى ${_proExpiryDate != null ? "${_proExpiryDate!.year}/${_proExpiryDate!.month}/${_proExpiryDate!.day}" : ""}'
                                      : 'Active Pro Plan')
                                  : (widget.isArabic
                                      ? 'أنت على الباقة المجانية الحالية'
                                      : 'Current Plan'),
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // باقة البرو للمستهلك
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isProSubscribed
                            ? AppTheme.success
                            : AppTheme.primary,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.isArabic
                                  ? 'باقة البرو (Pro)'
                                  : 'Pro Membership',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade800,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('1.95 د.أ / شهر',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.isArabic
                              ? '• معفى تماماً من العمولة (0%) عند شراء القطع أو طلب أي خدمة\n• خصومات حصرية على جميع القطع وخدمات الصيانة\n• أولوية في الدعم الفني'
                              : '• 0% commission on all parts and services\n• Exclusive discounts on all parts and repairs\n• Priority support',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isProSubscribed
                                  ? AppTheme.success
                                  : AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed:
                                _isProSubscribed ? null : _showPaymentDialog,
                            child: Text(
                              _isProSubscribed
                                  ? (widget.isArabic
                                      ? 'مُفعّلة حالياً ✅'
                                      : 'Active ✅')
                                  : (widget.isArabic
                                      ? 'اشترك الآن (1.95 د.أ / شهر)'
                                      : 'Subscribe Now (1.95 JOD)'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
