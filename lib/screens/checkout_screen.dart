// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_theme.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const CheckoutScreen({super.key, required this.product});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isLoading = false;
  bool _isProUser = false;
  double _partPrice = 0.0;
  double _consumerFee = 0.0;
  double _totalAmount = 0.0;
  String _selectedPaymentMethod = 'Credit Card';

  @override
  void initState() {
    super.initState();
    _calculatePricing();
  }

  Future<void> _calculatePricing() async {
    _partPrice =
        double.tryParse(widget.product['price']?.toString() ?? '0') ?? 0.0;

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final res = await Supabase.instance.client
          .from('customers')
          .select('subscription_plan, subscription_expires_at')
          .eq('id', user.id)
          .maybeSingle();

      if (res != null) {
        final plan = res['subscription_plan']?.toString() ?? 'free';
        final expiryStr = res['subscription_expires_at']?.toString();
        if (plan == 'pro' &&
            expiryStr != null &&
            DateTime.now().isBefore(DateTime.parse(expiryStr))) {
          _isProUser = true;
        }
      }
    }

    // إذا كان المستهلك مجانياً يدفع عمولة 2%، وإذا كان برو فعليها إعفاء (0%)
    _consumerFee = _isProUser ? 0.0 : (_partPrice * 0.02);
    _totalAmount = _partPrice + _consumerFee;

    setState(() {});
  }

  Future<void> _processCheckout() async {
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
          'Authorization': 'Bearer $anonKey'
        },
        body: utf8.encode(jsonEncode({
          'user_id': user.id,
          'amount': _totalAmount.toString(),
          'payment_method': _selectedPaymentMethod,
          'product_id': widget.product['id'],
          'seller_id': widget.product['user_id'],
          'plan_name': 'Buy Part: ${widget.product['title']}',
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
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('إتمام عملية الشراء (Checkout)',
              style: TextStyle(color: Colors.white, fontSize: 15)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.product['title'] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('سعر القطعة الأساسي:',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text('$_partPrice د.أ',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            _isProUser
                                ? 'عمولة المنصة (باقة البرو معفى):'
                                : 'عمولة المنصة (2%):',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        Text('$_consumerFee د.أ',
                            style: const TextStyle(
                                color: AppTheme.primaryLight,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الإجمالي النهائي للدفع:',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        Text('$_totalAmount د.أ',
                            style: const TextStyle(
                                color: AppTheme.success,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('اختر وسيلة الدفع:',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildPaymentRadio(
                  'بطاقة الائتمان (Visa / Mastercard)', 'Credit Card', false),
              _buildPaymentRadio(
                  'Apple Pay (غير متاح حالياً)', 'Apple Pay', true),
              _buildPaymentRadio(
                  'Google Pay (غير متاح حالياً)', 'Google Pay', true),
              _buildPaymentRadio('CliQ كليك (معطل مؤقتاً)', 'CliQ', true),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: _isLoading ? null : _processCheckout,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('ادفع الآن ($_totalAmount د.أ)',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentRadio(String title, String value, bool isDisabled) {
    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: RadioListTile<String>(
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        value: value,
        groupValue: _selectedPaymentMethod,
        activeColor: AppTheme.primary,
        onChanged: isDisabled
            ? null
            : (val) => setState(() => _selectedPaymentMethod = val!),
      ),
    );
  }
}
