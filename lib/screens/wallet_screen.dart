// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
  final String _commissionRate = '15.0%';
  List<Map<String, dynamic>> _transactions = [];
  String _selectedPaymentMethod = 'Credit Card';

  @override
  void initState() {
    super.initState();
    _fetchWalletDataFromTable();
  }

  // جلب البيانات بالكامل من جدول wallet_transactions حصراً (بدون جدول customers)
  Future<void> _fetchWalletDataFromTable() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final txRes = await Supabase.instance.client
          .from('wallet_transactions')
          .select()
          .eq('provider_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        final parsedList = txRes as List<dynamic>;

        final List<Map<String, dynamic>> allTx = parsedList
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

        double calculatedDebt = 0.0;
        double calculatedBalance = 0.0;

        for (final tx in allTx) {
          final bool isPaid = tx['is_paid'] == true || tx['status'] == 'paid';
          final double gross =
              double.tryParse(tx['gross_amount']?.toString() ?? '0') ?? 0.0;
          final double net =
              double.tryParse(tx['net_amount']?.toString() ?? '0') ?? 0.0;
          final String type = tx['transaction_type'] ?? '';

          if (!isPaid && (type == 'commission_debt' || type == 'debt')) {
            calculatedDebt += gross;
          } else if (isPaid ||
              type == 'commission_settlement' ||
              type == 'earning') {
            calculatedBalance += net;
          }
        }

        setState(() {
          _walletBalance = calculatedBalance;
          _pendingDebt = calculatedDebt;
          _transactions = allTx; // تحتوي على الكل لتظهر في الـ History
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching wallet data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPaymentOptionsDialog() {
    _selectedPaymentMethod = 'Credit Card';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void handlePaymentMethodChange(String? value) {
            if (value == null) return;
            setDialogState(() => _selectedPaymentMethod = value);
          }

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('سداد الذمم المستحقة ($_pendingDebt د.أ)',
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'اختر وسيلة سداد الذمم لتنتقل المعاملة إلى السجل (History):',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    title: 'بطاقة الائتمان (Credit Card)',
                    subtitle: 'Visa / Mastercard',
                    icon: Icons.credit_card,
                    value: 'Credit Card',
                    groupValue: _selectedPaymentMethod,
                    onChanged: handlePaymentMethodChange,
                  ),
                  const SizedBox(height: 8),
                  _buildPaymentOption(
                    title: 'CliQ (كليك)',
                    subtitle: 'Alias: ghayarak',
                    icon: Icons.flash_on,
                    value: 'CliQ',
                    groupValue: _selectedPaymentMethod,
                    onChanged: handlePaymentMethodChange,
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: () {
                  Navigator.pop(context);
                  if (_selectedPaymentMethod == 'CliQ') {
                    _showCliQDetailsDialog(_pendingDebt);
                  } else {
                    _processDebtPayment(_pendingDebt, 'Credit Card');
                  }
                },
                child: const Text('تأكيد السداد',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
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
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final bool isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppTheme.primary : Colors.white, size: 26),
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
            Radio<String>(
              value: value,
              groupValue: groupValue,
              activeColor: AppTheme.primary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  void _showCliQDetailsDialog(double amount) {
    final TextEditingController refController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تسوية الذمم عبر CliQ',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('قم بالتحويل إلى معرف CliQ: ghayarak',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: refController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'رقم مرجع الحوالة (Reference ID)',
                labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
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
              Navigator.pop(context);
              await _processDebtPayment(amount, 'CliQ');
            },
            child: const Text('تأكيد وإرسال',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // تحديث حالة الذمم إلى مدفوعة (is_paid = true) لتظهر في الـ History
  Future<void> _processDebtPayment(double amount, String method) async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // تحديث السجلات غير المدفوعة وجعلها مدفوعة في wallet_transactions
      await Supabase.instance.client
          .from('wallet_transactions')
          .update({'is_paid': true, 'status': 'paid'})
          .eq('provider_id', user.id)
          .eq('is_paid', false);

      // إضافة معاملة جديدة توثق عملية السداد الناجحة لتظهر في التاريخ
      await Supabase.instance.client.from('wallet_transactions').insert({
        'provider_id': user.id,
        'gross_amount': amount,
        'commission_amount': 0.0,
        'net_amount': amount,
        'payment_method': method,
        'transaction_type': 'commission_settlement',
        'is_paid': true,
        'status': 'completed',
      });

      await _fetchWalletDataFromTable();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'تم تسوية وسداد الذمم بنجاح ونقلها إلى سجل التاريخ (History)'),
            backgroundColor: AppTheme.success),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطأ أثناء الدفع: $e'),
            backgroundColor: AppTheme.error),
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
          title: const Text('محفظتي المالية والذمم',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : RefreshIndicator(
                onRefresh: _fetchWalletDataFromTable,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
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
                                  const Text('الذمم المستحقة غير المدفوعة:',
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
                                  const Text('نسبة العمولة:',
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
                                    'تسوية وسداد الذمم المستحقة (Credit Card / CliQ)',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold)),
                                onPressed: _showPaymentOptionsDialog,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('سجل المعاملات والتاريخ (History)',
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
                              double net = double.tryParse(
                                      tx['net_amount']?.toString() ?? '0') ??
                                  0.0;
                              String method = tx['payment_method'] ?? 'نقدى';
                              String type = tx['transaction_type'] ?? '';
                              bool isPaid = tx['is_paid'] == true ||
                                  tx['status'] == 'paid' ||
                                  tx['status'] == 'completed';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: isPaid
                                          ? AppTheme.success
                                          : AppTheme.error,
                                      width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            type == 'commission_settlement'
                                                ? 'تسوية ذمم ($method)'
                                                : 'معاملة مالية ($method)',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        Text(
                                            isPaid
                                                ? 'مدفوع (Paid)'
                                                : 'غير مدفوع (Pending)',
                                            style: TextStyle(
                                                color: isPaid
                                                    ? AppTheme.success
                                                    : AppTheme.error,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('المبلغ: $gross د.أ',
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11)),
                                        Text('الصافي: $net د.أ',
                                            style: const TextStyle(
                                                color: AppTheme.primaryLight,
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
