// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_theme.dart';

class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() =>
      _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _myAcceptedRequests = [];
  final bool _isArabic = true;

  double _totalCollectedBefore = 0.0;
  double _totalCommissionPaid = 0.0;
  double _totalCommissionUnpaid = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchMyAcceptedRequests();
  }

  Future<void> _fetchMyAcceptedRequests() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('mechanic_requests')
          .select()
          .eq('mechanic_id', user.id)
          .order('created_at', ascending: false);

      final List<dynamic> data = List<dynamic>.from(res);

      double collected = 0.0;
      double paidComm = 0.0;
      double unpaidComm = 0.0;

      for (var req in data) {
        if (req['status'] == 'completed') {
          double totalAmt = _toDouble(req['total_amount']);
          double commAmt = _toDouble(req['commission_amount']);
          String payStatus = req['payment_status'] ?? 'unpaid';

          collected += totalAmt;
          if (payStatus == 'paid') {
            paidComm += commAmt;
          } else {
            unpaidComm += commAmt;
          }
        }
      }

      if (mounted) {
        setState(() {
          _myAcceptedRequests = data;
          _totalCollectedBefore = collected;
          _totalCommissionPaid = paidComm;
          _totalCommissionUnpaid = unpaidComm;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching dashboard requests: $e');
    }
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is int) return val.toDouble();
    if (val is double) return val;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  void _showPaymentDialog(String requestId, double commissionAmount) {
    String selectedPaymentMethod = 'Credit Card';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.payment, color: AppTheme.primary, size: 28),
                const SizedBox(width: 10),
                Text(
                  _isArabic
                      ? 'إتمام دفع العمولة (${commissionAmount.toStringAsFixed(2)} د.أ)'
                      : 'Complete Commission (${commissionAmount.toStringAsFixed(2)} JOD)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isArabic
                      ? 'اختر وسيلة الدفع لتسديد عمولة المنصة (6.5%):'
                      : 'Choose payment method for platform commission:',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _buildPaymentOption(
                  title: _isArabic
                      ? 'بطاقة الائتمان (PayTaps)'
                      : 'Credit Card (PayTaps)',
                  subtitle: 'Visa / Mastercard',
                  icon: Icons.credit_card,
                  iconColor: Colors.blueAccent,
                  value: 'Credit Card',
                  groupValue: selectedPaymentMethod,
                  onChanged: (val) =>
                      setDialogState(() => selectedPaymentMethod = val!),
                ),
                const SizedBox(height: 10),
                _buildPaymentOption(
                  title: 'CliQ (كليك)',
                  subtitle: 'Alias: ghayarak',
                  icon: Icons.flash_on,
                  iconColor: Colors.amber,
                  value: 'CliQ',
                  groupValue: selectedPaymentMethod,
                  onChanged: (val) =>
                      setDialogState(() => selectedPaymentMethod = val!),
                ),
                const SizedBox(height: 10),
                Opacity(
                  opacity: 0.5,
                  child: _buildPaymentOption(
                    title: 'Google Pay (قريباً)',
                    subtitle: _isArabic
                        ? 'بانتظار توفر السجل التجاري'
                        : 'Pending commercial register',
                    icon: Icons.g_mobiledata,
                    iconColor: Colors.grey,
                    value: 'Google Pay',
                    groupValue: selectedPaymentMethod,
                    onChanged: (val) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'هذه الخدمة ستتوفر قريباً بعد إتمام السجل التجاري')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Opacity(
                  opacity: 0.5,
                  child: _buildPaymentOption(
                    title: 'Apple Pay (قريباً)',
                    subtitle: _isArabic
                        ? 'بانتظار توفر السجل التجاري'
                        : 'Pending commercial register',
                    icon: Icons.apple,
                    iconColor: Colors.grey,
                    value: 'Apple Pay',
                    groupValue: selectedPaymentMethod,
                    onChanged: (val) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'هذه الخدمة ستتوفر قريباً بعد إتمام السجل التجاري')),
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_isArabic ? 'إلغاء' : 'Cancel',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (selectedPaymentMethod == 'CliQ') {
                    _showCliQDetailsDialog(requestId, commissionAmount);
                  } else if (selectedPaymentMethod == 'Apple Pay' ||
                      selectedPaymentMethod == 'Google Pay') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'عذراً، هذه الطريقة غير مفعلة حالياً لحين توفر السجل التجاري')),
                    );
                  } else {
                    _processPaymentViaAPI(
                        requestId, commissionAmount, selectedPaymentMethod);
                  }
                },
                child: Text(_isArabic ? 'متابعة' : 'Proceed'),
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
    IconData? icon,
    Color? iconColor,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final bool isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
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
            if (icon != null)
              Icon(icon, color: iconColor ?? Colors.white, size: 30),
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
            Radio<String>(
                value: value,
                groupValue: groupValue,
                activeColor: AppTheme.primary,
                onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  void _showCliQDetailsDialog(String requestId, double commissionAmount) {
    final TextEditingController refController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.amber, size: 28),
            const SizedBox(width: 10),
            Text(
              _isArabic
                  ? 'التحويل عبر CliQ للعمولة'
                  : 'CliQ Transfer for Commission',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isArabic
                  ? 'يرجى تحويل مبلغ ${commissionAmount.toStringAsFixed(2)} د.أ إلى معرف CliQ (الـ Alias) التالي:'
                  : 'Please transfer commission to CliQ Alias:',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ghayarak',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.amber, size: 20),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: 'ghayarak'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('تم نسخ الـ Alias بنجاح'),
                            backgroundColor: Colors.green),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: refController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: _isArabic
                    ? 'رقم مرجع الحوالة أو اسم الحساب'
                    : 'Transaction Ref / Account Name',
                labelStyle: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
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
            child: Text(_isArabic ? 'إلغاء' : 'Cancel',
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (refController.text.trim().isEmpty) return;
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) return;

              await Supabase.instance.client.from('cliq_requests').insert({
                'user_id': user.id,
                'user_email': user.email,
                'transaction_ref': 'عمولة صيانة - ${refController.text.trim()}',
                'status': 'pending',
              });

              await Supabase.instance.client.from('mechanic_requests').update({
                'payment_status': 'paid',
              }).eq('id', requestId);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('تم إرسال طلب الكليك للإدارة بنجاح'),
                      backgroundColor: Colors.green),
                );
                _fetchMyAcceptedRequests();
              }
            },
            child: Text(_isArabic ? 'إرسال للمراجعة' : 'Submit',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _processPaymentViaAPI(
      String requestId, double amount, String paymentMethod) async {
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
        'amount': amount.toStringAsFixed(2),
        'payment_method': paymentMethod,
        'plan_name': 'Mechanic Commission',
        'merchant_id': '185206',
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
          final String redirectUrl = resData['redirect_url'];
          final Uri bankUrl = Uri.parse(redirectUrl);

          if (await canLaunchUrl(bankUrl)) {
            await launchUrl(bankUrl, mode: LaunchMode.externalApplication);
          } else {
            throw 'تعذر فتح صفحة الدفع الخاصة بالبنك';
          }
        } else {
          await Supabase.instance.client.from('mechanic_requests').update({
            'payment_status': 'paid',
          }).eq('id', requestId);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('تمت عملية الدفع بنجاح وتسديد العمولة!'),
                  backgroundColor: AppTheme.success),
            );
            _fetchMyAcceptedRequests();
          }
        }
      } else {
        throw 'خطأ في الاتصال بخدمة الدفع';
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _completeRepairAndCalculateCommission(
      String requestId, double totalAmount) async {
    try {
      double commission = totalAmount * 0.065;

      await Supabase.instance.client.from('mechanic_requests').update({
        'status': 'completed',
        'total_amount': totalAmount,
        'commission_amount': commission,
        'payment_status': 'pending_payment',
      }).eq('id', requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isArabic
                ? 'تم تسجيل الفاتورة. عمولة المنصة (6.5%): ${commission.toStringAsFixed(2)} د.أ'
                : 'Commission calculated: ${commission.toStringAsFixed(2)}'),
            backgroundColor: AppTheme.success,
          ),
        );
        _fetchMyAcceptedRequests();
      }
    } catch (e) {
      debugPrint('Error completing repair: $e');
    }
  }

  void _showAmountInputDialog(String requestId) {
    final TextEditingController amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isArabic
                    ? 'إدخال إجمالي مبلغ الفاتورة المدفوع من الزبون'
                    : 'Enter Total Paid Amount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: _isArabic ? 'المبلغ (بالدينار)' : 'Amount',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final val =
                        double.tryParse(amountController.text.trim()) ?? 0;
                    if (val > 0) {
                      Navigator.pop(context);
                      _completeRepairAndCalculateCommission(requestId, val);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(_isArabic
                                ? 'الرجاء إدخال مبلغ صحيح'
                                : 'Please enter valid amount')),
                      );
                    }
                  },
                  child: Text(
                    _isArabic
                        ? 'حفظ وحساب العمولة (6.5%)'
                        : 'Save & Calculate Commission',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalNetAfterCommission =
        _totalCollectedBefore - (_totalCommissionPaid + _totalCommissionUnpaid);

    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: Text(
            _isArabic
                ? 'لوحة تحكم الصيانة والأرباح'
                : 'Mechanic Financial Dashboard',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard(
                          title: _isArabic
                              ? 'المبلغ من الزبون (قبل)'
                              : 'Total Collected',
                          value:
                              '${_totalCollectedBefore.toStringAsFixed(2)} د.أ',
                          icon: Icons.account_balance_wallet_rounded,
                          color: AppTheme.primary,
                        ),
                        _buildStatCard(
                          title: _isArabic
                              ? 'صافي المبلغ (بعد العمولة)'
                              : 'Net Amount',
                          value:
                              '${totalNetAfterCommission.toStringAsFixed(2)} د.أ',
                          icon: Icons.savings_rounded,
                          color: AppTheme.success,
                        ),
                        _buildStatCard(
                          title: _isArabic
                              ? 'العمولات المدفوعة'
                              : 'Paid Commissions',
                          value:
                              '${_totalCommissionPaid.toStringAsFixed(2)} د.أ',
                          icon: Icons.task_alt_rounded,
                          color: Colors.blueAccent,
                        ),
                        _buildStatCard(
                          title: _isArabic
                              ? 'العمولات غير المدفوعة'
                              : 'Unpaid Commissions',
                          value:
                              '${_totalCommissionUnpaid.toStringAsFixed(2)} د.أ',
                          icon: Icons.warning_amber_rounded,
                          color: AppTheme.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isArabic
                                ? 'توزيع الأرباح والعمولات'
                                : 'Revenue & Commission Breakdown',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 180,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: _totalCollectedBefore == 0
                                    ? 10
                                    : _totalCollectedBefore * 1.2,
                                barTouchData: BarTouchData(enabled: true),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        const style = TextStyle(
                                            color: Colors.grey, fontSize: 11);
                                        switch (value.toInt()) {
                                          case 0:
                                            return const Text('المحصل',
                                                style: style);
                                          case 1:
                                            return const Text('المدفوعة',
                                                style: style);
                                          case 2:
                                            return const Text('المعلقة',
                                                style: style);
                                          default:
                                            return const Text('', style: style);
                                        }
                                      },
                                    ),
                                  ),
                                  leftTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barGroups: [
                                  BarChartGroupData(x: 0, barRods: [
                                    BarChartRodData(
                                        toY: _totalCollectedBefore,
                                        color: AppTheme.primary,
                                        width: 22,
                                        borderRadius: BorderRadius.circular(6))
                                  ]),
                                  BarChartGroupData(x: 1, barRods: [
                                    BarChartRodData(
                                        toY: _totalCommissionPaid,
                                        color: Colors.blueAccent,
                                        width: 22,
                                        borderRadius: BorderRadius.circular(6))
                                  ]),
                                  BarChartGroupData(x: 2, barRods: [
                                    BarChartRodData(
                                        toY: _totalCommissionUnpaid,
                                        color: AppTheme.warning,
                                        width: 22,
                                        borderRadius: BorderRadius.circular(6))
                                  ]),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isArabic
                          ? 'سجل وحجوزات الصيانة'
                          : 'Repair Orders & History',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    _myAcceptedRequests.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                _isArabic
                                    ? 'لا توجد حجوزات مسجلة حالياً'
                                    : 'No repairs recorded',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 14),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _myAcceptedRequests.length,
                            itemBuilder: (context, index) {
                              final req = _myAcceptedRequests[index];
                              final requestId = req['id'].toString();
                              final String orderCode =
                                  'GHY-${requestId.substring(0, 6).toUpperCase()}';

                              final serviceType =
                                  req['service_type'] ?? 'خدمة طارئة';
                              final status = req['status'] ?? 'accepted';
                              final paymentStatus =
                                  req['payment_status'] ?? 'unpaid';
                              double commissionAmount =
                                  _toDouble(req['commission_amount']);

                              final carDetails =
                                  req['car_details'] ?? 'غير متوفر';
                              final description = req['description'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: AppTheme.primary
                                                    .withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            orderCode,
                                            style: const TextStyle(
                                                color: AppTheme.primaryLight,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                          ),
                                        ),
                                        Text(
                                          carDetails,
                                          style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      serviceType,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      description,
                                      style: TextStyle(
                                          color: Colors.grey.shade300,
                                          fontSize: 13),
                                    ),
                                    const Divider(
                                        color: Colors.white12, height: 24),
                                    if (status == 'accepted') ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.engineering,
                                              color: AppTheme.warning,
                                              size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isArabic
                                                ? 'السيارة قيد العمل / الصيانة'
                                                : 'Repair in progress',
                                            style: const TextStyle(
                                                color: AppTheme.warning,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.success,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                          onPressed: () =>
                                              _showAmountInputDialog(requestId),
                                          icon: const Icon(Icons.check_circle,
                                              size: 16, color: Colors.white),
                                          label: Text(
                                            _isArabic
                                                ? 'تم الانتهاء من تصليح سيارة العميل'
                                                : 'Repair Completed',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ] else if (status == 'completed') ...[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _isArabic
                                                ? 'عمولة المنصة المطلوبة (6.5%):'
                                                : 'Platform Commission:',
                                            style: TextStyle(
                                                color: Colors.grey.shade400,
                                                fontSize: 12),
                                          ),
                                          Text(
                                            '${commissionAmount.toStringAsFixed(2)} د.أ',
                                            style: const TextStyle(
                                                color: AppTheme.warning,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (paymentStatus == 'paid')
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.success
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _isArabic
                                                  ? 'تم تسديد عمولة المنصة بنجاح'
                                                  : 'Commission Paid',
                                              style: const TextStyle(
                                                  color: AppTheme.success,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12),
                                            ),
                                          ),
                                        )
                                      else
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primary,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                            ),
                                            onPressed: () => _showPaymentDialog(
                                                requestId, commissionAmount),
                                            icon: const Icon(Icons.payment,
                                                size: 16, color: Colors.white),
                                            label: Text(
                                              _isArabic
                                                  ? 'ادفع الآن (عمولة المنصة)'
                                                  : 'Pay Commission Now',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                    ],
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

  Widget _buildStatCard(
      {required String title,
      required String value,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
