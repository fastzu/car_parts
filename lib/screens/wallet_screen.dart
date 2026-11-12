// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isLoading = true;
  double _walletBalance = 0.0;
  double _pendingDebt = 0.0;
  String _commissionRate = '15%';
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  Future<void> _fetchWalletData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final customerRes = await Supabase.instance.client
          .from('customers')
          .select('wallet_balance, pending_commission_debt, commission_rate')
          .eq('id', user.id)
          .maybeSingle();

      if (customerRes != null) {
        _walletBalance =
            double.tryParse(customerRes['wallet_balance']?.toString() ?? '0') ??
                0.0;
        _pendingDebt = double.tryParse(
                customerRes['pending_commission_debt']?.toString() ?? '0') ??
            0.0;
        final rate = double.tryParse(
                customerRes['commission_rate']?.toString() ?? '0.15') ??
            0.15;
        _commissionRate = '${(rate * 100).toStringAsFixed(1)}%';
      }

      final txRes = await Supabase.instance.client
          .from('wallet_transactions')
          .select()
          .eq('provider_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        final parsedList =
            txRes is List ? txRes as List<dynamic> : const <dynamic>[];
        setState(() {
          _transactions = parsedList
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching wallet data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 سداد ذمم عمولات الكاش المتراكمة عبر CliQ الشركة
  void _showCliQPaymentDialog() {
    final TextEditingController refController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.flash_on, color: Colors.amber, size: 26),
            SizedBox(width: 8),
            Text('سداد عمولات المنصة عبر CliQ',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الذمم المستحقة عليك للمنصة: $_pendingDebt دينار\nيرجى تحويل المبلغ إلى معرف CliQ (الـ Alias) التالي:',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ghayarak',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Icon(Icons.copy, color: Colors.amber, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: refController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'رقم مرجع الحوالة أو اسم الحساب',
                labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                filled: true,
                fillColor: AppTheme.background,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () async {
              if (refController.text.trim().isEmpty) return;
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) return;

              await Supabase.instance.client.from('cliq_requests').insert({
                'user_id': user.id,
                'user_email': user.email,
                'transaction_ref': refController.text.trim(),
                'status': 'pending_commission_settlement',
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'تم إرسال طلب السداد للإدارة للمراجعة وتصفية الذمم'),
                    backgroundColor: AppTheme.success),
              );
            },
            child: const Text('إرسال للمراجعة',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('محفظتي المالية والأرباح',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : RefreshIndicator(
                onRefresh: _fetchWalletData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // بطاقة الأرصدة والملخص المالي
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [AppTheme.surface, AppTheme.background]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primary, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إجمالي الأرباح الصافية المتاحة',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text('$_walletBalance د.أ',
                              style: const TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold)),
                          const Divider(color: Colors.white24, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ذمم عمولات الكاش:',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('$_pendingDebt د.أ',
                                      style: const TextStyle(
                                          color: AppTheme.error,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('نسبة العمولة الحالية:',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(_commissionRate,
                                      style: const TextStyle(
                                          color: AppTheme.primaryLight,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          if (_pendingDebt > 0) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                icon: const Icon(Icons.flash_on,
                                    color: Colors.black),
                                label: const Text(
                                    'تسوية وسداد العمولات المستحقة (CliQ)',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold)),
                                onPressed: _showCliQPaymentDialog,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('سجل المعاملات المالية',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _transactions.isEmpty
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(30),
                                child: Text('لا توجد معاملات مسجلة بعد',
                                    style: TextStyle(color: Colors.grey))))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final tx = _transactions[index];
                              double gross = double.tryParse(
                                      tx['gross_amount']?.toString() ?? '0') ??
                                  0.0;
                              double commission = double.tryParse(
                                      tx['commission_amount']?.toString() ??
                                          '0') ??
                                  0.0;
                              double net = double.tryParse(
                                      tx['net_amount']?.toString() ?? '0') ??
                                  0.0;
                              String method = tx['payment_method'] ?? '';
                              String type = tx['transaction_type'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            type.contains('cash')
                                                ? 'دفع نقدي (Cash)'
                                                : 'دفع إلكتروني (Visa)',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        Text('+$net د.أ (صافي)',
                                            style: const TextStyle(
                                                color: AppTheme.success,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('المبلغ قبل العمولة: $gross د.أ',
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11)),
                                        Text('العمولة: -$commission د.أ',
                                            style: const TextStyle(
                                                color: AppTheme.error,
                                                fontSize: 11)),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}
