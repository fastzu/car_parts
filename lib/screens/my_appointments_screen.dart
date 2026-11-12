// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_theme.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _myAppointments = [];

  @override
  void initState() {
    super.initState();
    _fetchMyAppointments();
  }

  Future<void> _fetchMyAppointments() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('workshop_appointments')
          .select(
              '*, workshop:workshop_id(id, username, phone, workshop_address)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _myAppointments = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching my appointments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respondToReschedule(String appointmentId, bool accept,
      String suggestedDate, String suggestedTime) async {
    try {
      String newStatus = accept ? 'accepted' : 'rejected';
      String newProgress = accept ? 'accepted' : 'rejected';

      Map<String, dynamic> updateData = {
        'status': newStatus,
        'progress_step': newProgress,
      };

      if (accept) {
        updateData['appointment_date'] = suggestedDate;
        updateData['appointment_time'] = suggestedTime;
      }

      await Supabase.instance.client
          .from('workshop_appointments')
          .update(updateData)
          .eq('id', appointmentId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'تم قبول الموعد الجديد بنجاح!'
              : 'تم رفض الموعد المقترح وإلغاء الطلب'),
          backgroundColor: accept ? AppTheme.success : AppTheme.error,
        ),
      );

      _fetchMyAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  // 🌟 معالجة دفع تكلفة الصيانة (كاش أو فيزا)
  void _showPaymentDialog(Map<String, dynamic> appt) {
    double totalAmt =
        double.tryParse(appt['total_amount']?.toString() ?? '0') ?? 0.0;
    String appointmentId = appt['id'].toString();
    String workshopId = appt['workshop_id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'دفع فاتورة صيانة ($totalAmt د.أ)',
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر طريقة الدفع لتسوية تكلفة الصيانة:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.credit_card, color: Colors.white),
              label: const Text('دفع إلكتروني عبر الفيزا (Credit Card)',
                  style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.pop(context);
                _processServicePaymentViaAPI(
                    appointmentId, workshopId, totalAmt, 'visa');
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.money, color: Colors.white),
              label: const Text('الدفع نقداً (Cash) للميكانيكي',
                  style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.pop(context);
                _processCashPayment(appointmentId, workshopId, totalAmt);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _processCashPayment(
      String appointmentId, String workshopId, double amount) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // تحديث حالة الموعد والدفع إلى مدفوع كاش
      await Supabase.instance.client.from('workshop_appointments').update({
        'payment_method': 'cash',
        'payment_status': 'paid',
        'status': 'completed'
      }).eq('id', appointmentId);

      // جلب نسبة عمولة الورشة لحساب ذمم الكاش (Netting)
      final workshopData = await Supabase.instance.client
          .from('customers')
          .select('commission_rate, pending_commission_debt, wallet_balance')
          .eq('id', workshopId)
          .maybeSingle();

      if (workshopData != null) {
        double commissionRate = double.tryParse(
                workshopData['commission_rate']?.toString() ?? '0.15') ??
            0.15;
        double currentDebt = double.tryParse(
                workshopData['pending_commission_debt']?.toString() ?? '0') ??
            0.0;
        double currentWallet = double.tryParse(
                workshopData['wallet_balance']?.toString() ?? '0') ??
            0.0;

        double commissionAmount = amount * commissionRate;
        double netAmount = amount - commissionAmount;

        // في الكاش: الورشة قبضت المبلغ كاملاً، إذن عمولة المنصة تصبح ديناً (ذمة) عليها
        double newDebt = currentDebt + commissionAmount;
        double newWallet = currentWallet +
            netAmount; // يسجل في المحفظة كإجمالي صيانة مطروحاً منه العمولة

        await Supabase.instance.client.from('customers').update({
          'pending_commission_debt': newDebt,
          'wallet_balance': newWallet,
        }).eq('id', workshopId);

        // تسجيل المعاملة في سجل المعاملات المالية
        await Supabase.instance.client.from('wallet_transactions').insert({
          'provider_id': workshopId,
          'customer_id': user.id,
          'reference_id': appointmentId,
          'transaction_type': 'workshop_service_cash',
          'payment_method': 'cash',
          'gross_amount': amount,
          'commission_rate': commissionRate,
          'commission_amount': commissionAmount,
          'net_amount': netAmount,
          'status': 'pending_debt',
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم تأكيد الدفع النقدي وتسجيل العملية بنجاح!'),
            backgroundColor: AppTheme.success),
      );
      _fetchMyAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _processServicePaymentViaAPI(String appointmentId,
      String workshopId, double amount, String method) async {
    // توجيه لبوابة الدفع عبر الـ API مع تمرير تفاصيل الموعد
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
          'amount': amount.toString(),
          'payment_method': method,
          'reference_id': appointmentId,
          'workshop_id': workshopId,
          'plan_name': 'Workshop Maintenance Service',
        })),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['redirect_url'] != null) {
          final Uri bankUrl = Uri.parse(resData['redirect_url']);
          if (await canLaunchUrl(bankUrl)) {
            await launchUrl(bankUrl, mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطأ في الاتصال: $e'),
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
          title: const Text('مواعيدي وحجوزات الصيانة',
              style: TextStyle(color: Colors.white, fontSize: 15)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : _myAppointments.isEmpty
                ? const Center(
                    child: Text('لا توجد لديك أي مواعيد حجز حالياً',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _myAppointments.length,
                    itemBuilder: (context, index) {
                      final appt = _myAppointments[index];
                      final workshop = appt['workshop'] ?? {};
                      final status = appt['status'] ?? 'pending';
                      final paymentStatus = appt['payment_status'] ?? 'unpaid';
                      final date = appt['appointment_date'] ?? '';
                      final time = appt['appointment_time'] ?? '';
                      final serviceDesc =
                          appt['service_description'] ?? 'صيانة عامة';
                      double totalAmt = double.tryParse(
                              appt['total_amount']?.toString() ?? '0') ??
                          0.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(workshop['username'] ?? 'ورشة معتمدة',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: _getStatusColor(status)),
                                  ),
                                  child: Text(_getStatusText(status),
                                      style: TextStyle(
                                          color: _getStatusColor(status),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                                '📍 العنوان: ${workshop['workshop_address'] ?? 'غير متوفر'}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            Text(
                                '📞 هاتف الورشة: ${workshop['phone'] ?? 'غير متوفر'}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            const Divider(color: Colors.white24, height: 16),
                            Text('🔧 الخدمة: $serviceDesc',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('📅 موعد الحجز: $date ($time)',
                                style: const TextStyle(
                                    color: AppTheme.warning,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            if (totalAmt > 0) ...[
                              const SizedBox(height: 6),
                              Text(
                                  '💰 المبلغ المطلوب من الورشة: $totalAmt دينار',
                                  style: const TextStyle(
                                      color: AppTheme.primaryLight,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              if (paymentStatus != 'paid')
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary),
                                    onPressed: () => _showPaymentDialog(appt),
                                    child: const Text(
                                        'دفع تكلفة الصيانة (اختر كاش أو فيزا)',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 12)),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: AppTheme.success
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Text('✅ تم دفع الفاتورة بنجاح',
                                      style: TextStyle(
                                          color: AppTheme.success,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11),
                                      textAlign: TextAlign.center),
                                ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return AppTheme.success;
      case 'repairing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'accepted':
        return 'مقبول';
      case 'repairing':
        return 'جاري التصليح';
      case 'completed':
        return 'مكتمل';
      default:
        return status;
    }
  }
}
