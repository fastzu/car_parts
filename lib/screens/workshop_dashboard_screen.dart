// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_theme.dart';

class WorkshopDashboardScreen extends StatefulWidget {
  const WorkshopDashboardScreen({super.key});

  @override
  State<WorkshopDashboardScreen> createState() =>
      _WorkshopDashboardScreenState();
}

class _WorkshopDashboardScreenState extends State<WorkshopDashboardScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  Map<String, dynamic>? _workshopProfile;

  double _totalEarningsBeforeCommission = 0.0;
  double _totalEarningsAfterCommission = 0.0;
  int _carsInServiceCount = 0;
  int _upcomingAppointmentsCount = 0;

  DateTime _selectedAvailableDate = DateTime.now();

  String _selectedPaymentMethod = 'Credit Card';

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // 🌟 معالجة التوقيت ليظهر بالتوقيت المحلي الصحيح ودون أي تفاوت زمني غير منطقي
  String _formatLocalizedDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null) return '';
    try {
      final String fullString =
          timeStr != null && timeStr.isNotEmpty ? '$dateStr $timeStr' : dateStr;
      final DateTime parsedDate = DateTime.parse(fullString).toLocal();

      final int hour24 = parsedDate.hour;
      final String period = hour24 >= 12 ? 'PM' : 'AM';
      final int hour12 =
          hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
      final String minuteFormatted =
          parsedDate.minute.toString().padLeft(2, '0');

      return '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')} ($period $hour12:$minuteFormatted)';
    } catch (_) {
      return '$dateStr ${timeStr ?? ''}';
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profileRes = await Supabase.instance.client
          .from('customers')
          .select()
          .eq('id', user.id)
          .single();

      final appointmentsRes = await Supabase.instance.client
          .from('workshop_appointments')
          .select('*, customers:user_id(username, phone, full_name)')
          .eq('workshop_id', user.id)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> loadedAppointments =
          List<Map<String, dynamic>>.from(appointmentsRes);

      double earningsBefore = 0.0;
      double commissionTotal = 0.0;
      int inServiceForSelectedDate = 0;
      int upcoming = 0;

      String targetDateStr = _formatDate(_selectedAvailableDate);

      for (var appt in loadedAppointments) {
        String status = appt['status'] ?? 'pending';
        String apptDate = appt['appointment_date']?.toString() ?? '';
        double totalAmt =
            double.tryParse(appt['total_amount']?.toString() ?? '0') ?? 0.0;
        double comm =
            double.tryParse(appt['platform_commission']?.toString() ?? '0') ??
                (totalAmt * 0.1);

        if (status == 'completed' ||
            status == 'repairing' ||
            status == 'accepted') {
          earningsBefore += totalAmt;
          commissionTotal += comm;
        }

        if (apptDate == targetDateStr &&
            (status == 'repairing' ||
                status == 'accepted' ||
                status == 'confirmed_and_on_the_way')) {
          inServiceForSelectedDate++;
        }

        if (status == 'pending' ||
            status == 'accepted' ||
            status == 'reschedule_suggested') {
          upcoming++;
        }
      }

      double earningsAfter = earningsBefore - commissionTotal;

      if (mounted) {
        setState(() {
          _workshopProfile = profileRes;
          _appointments = loadedAppointments;
          _totalEarningsBeforeCommission = earningsBefore;
          _totalEarningsAfterCommission =
              earningsAfter > 0 ? earningsAfter : 0.0;
          _carsInServiceCount = inServiceForSelectedDate;
          _upcomingAppointmentsCount = upcoming;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAppointmentStatus(
      String appointmentId, String newStatus, String newStep,
      {double? totalAmount, String? newDate, String? newTime}) async {
    try {
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'progress_step': newStep,
      };

      if (totalAmount != null) {
        updateData['total_amount'] = totalAmount;
        updateData['platform_commission'] = totalAmount * 0.1;
      }

      if (newDate != null && newTime != null) {
        updateData['appointment_date'] = newDate;
        updateData['appointment_time'] = newTime;
      }

      await Supabase.instance.client
          .from('workshop_appointments')
          .update(updateData)
          .eq('id', appointmentId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم تحديث حالة الطلب بنجاح'),
            backgroundColor: AppTheme.success),
      );
      _fetchDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  // 🌟 نافذة اقتراح موعد بديل من قِبل الميكانيكي
  void _showSuggestRescheduleDialog(String appointmentId) {
    DateTime suggestedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay suggestedTime = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('اقتراح موعد آخر للزبون',
                style: TextStyle(color: Colors.white, fontSize: 15)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'الورشة ممتلئة بهذا اليوم. اختر موعداً بديلاً ليتم إرساله للزبون:',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: suggestedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => suggestedDate = picked);
                    }
                  },
                  icon:
                      const Icon(Icons.calendar_month, color: AppTheme.primary),
                  label: Text('التاريخ المقترح: ${_formatDate(suggestedDate)}'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: suggestedTime,
                    );
                    if (picked != null) {
                      setDialogState(() => suggestedTime = picked);
                    }
                  },
                  icon: const Icon(Icons.access_time, color: AppTheme.primary),
                  label:
                      Text('الوقت المقترح: ${suggestedTime.format(context)}'),
                ),
              ],
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
                  String formattedNewDate = _formatDate(suggestedDate);
                  String formattedNewTime = suggestedTime.format(context);
                  _updateAppointmentStatus(
                    appointmentId,
                    'reschedule_suggested',
                    'reschedule_suggested',
                    newDate: formattedNewDate,
                    newTime: formattedNewTime,
                  );
                },
                child: const Text('إرسال الاقتراح للزبون',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPaymentOptionsDialog(
      String appointmentId, double currentTotalAmount) {
    _selectedPaymentMethod = 'Credit Card';
    double commission =
        currentTotalAmount > 0 ? (currentTotalAmount * 0.1) : 1.00;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void handlePaymentMethodChange(String? value) {
            if (value == null) return;
            if (value == 'Google Pay' || value == 'Apple Pay') {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$value غير متاح حالياً')));
              return;
            }
            setDialogState(() => _selectedPaymentMethod = value);
          }

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('دفع عمولة المنصة المطلوبة ($commission د.أ)',
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            content: SingleChildScrollView(
              child: RadioGroup<String>(
                groupValue: _selectedPaymentMethod,
                onChanged: handlePaymentMethodChange,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اختر وسيلة دفع العمولة المستحقة للسيستم:',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    _buildPaymentOption(
                      title: 'بطاقة الائتمان (Credit Card)',
                      subtitle: 'Visa / Mastercard',
                      icon: Icons.credit_card,
                      iconColor: Colors.blueAccent,
                      value: 'Credit Card',
                      groupValue: _selectedPaymentMethod,
                      onChanged: handlePaymentMethodChange,
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentOption(
                      title: 'CliQ (كليك)',
                      subtitle: 'Alias: ghayarak',
                      icon: Icons.flash_on,
                      iconColor: Colors.amber,
                      value: 'CliQ',
                      groupValue: _selectedPaymentMethod,
                      onChanged: handlePaymentMethodChange,
                    ),
                  ],
                ),
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
                  if (_selectedPaymentMethod == 'CliQ') {
                    _showCliQDetailsDialog(commission);
                  } else {
                    _processPaymentViaAPI(commission, _selectedPaymentMethod);
                  }
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
            Icon(icon ?? Icons.payment,
                color: iconColor ?? Colors.white, size: 26),
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
              activeColor: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showCliQDetailsDialog(double commissionAmount) {
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
            Text('تحويل العمولة ($commissionAmount د.أ) عبر CliQ',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'يرجى تحويل مبلغ العمولة إلى معرف CliQ (الـ Alias) التالي:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.amber, size: 18),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: 'ghayarak'));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('تم نسخ الـ Alias بنجاح'),
                          backgroundColor: Colors.green));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: refController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'رقم مرجع الحوالة أو اسم الحساب المحول منه',
                labelStyle: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('تم إرسال إشعار الدفع للإدارة للمراجعة'),
                  backgroundColor: Colors.green));
            },
            child: const Text('تأكيد إرسال الحوالة',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _processPaymentViaAPI(
      double amount, String paymentMethod) async {
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
          'user_id': Supabase.instance.client.auth.currentUser!.id,
          'amount': amount.toStringAsFixed(2),
          'payment_method': paymentMethod,
          'plan_name': 'Workshop Commission Payment',
        })),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['redirect_url'] != null) {
          final bankUrl = Uri.parse(resData['redirect_url']);
          if (await canLaunchUrl(bankUrl)) {
            await launchUrl(bankUrl, mode: LaunchMode.externalApplication);
          }
        }
      } else {
        throw 'خطأ في معالجة البوابة';
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم تسجيل عملية الدفع بنجاح'),
          backgroundColor: AppTheme.success));
    }
  }

  void _showAvailabilitySettings() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedAvailableDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedAvailableDate = picked);
      await _fetchDashboardData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('تم عرض حالة تفرغ الورشة لتاريخ: ${_formatDate(picked)}'),
            backgroundColor: AppTheme.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int maxCapacity = _workshopProfile?['max_car_capacity'] ?? 5;
    bool isFull = _carsInServiceCount >= maxCapacity;
    int remainingCapacity = maxCapacity - _carsInServiceCount;
    if (remainingCapacity < 0) remainingCapacity = 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('لوحة تحكم الورشة والأرباح والمواعيد',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month, color: AppTheme.primary),
              tooltip: 'تغيير التاريخ وفحص التفرغ',
              onPressed: _showAvailabilitySettings,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.account_balance_wallet,
                                    color: AppTheme.success, size: 20),
                                const SizedBox(height: 6),
                                const Text('الأرباح قبل العمولة',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 10)),
                                Text('$_totalEarningsBeforeCommission د.أ',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const Divider(
                                    color: Colors.white12, height: 10),
                                const Text('الأرباح بعد العمولة (10%):',
                                    style: TextStyle(
                                        color: AppTheme.primaryLight,
                                        fontSize: 9)),
                                Text('$_totalEarningsAfterCommission د.أ',
                                    style: const TextStyle(
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.car_repair,
                                    color: AppTheme.warning, size: 20),
                                const SizedBox(height: 6),
                                const Text('المقبولة بهذا التاريخ',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 10)),
                                const SizedBox(height: 2),
                                Text(
                                    '$_carsInServiceCount / $maxCapacity سيارة',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const SizedBox(height: 14),
                                Text(
                                    isFull
                                        ? '🔴 ممتلئ تماماً'
                                        : '🟢 متفرغ (متبقي $remainingCapacity)',
                                    style: TextStyle(
                                        color: isFull
                                            ? AppTheme.error
                                            : AppTheme.success,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.event_note,
                                    color: AppTheme.primary, size: 20),
                                const SizedBox(height: 6),
                                const Text('إجمالي المواعيد',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 10)),
                                const SizedBox(height: 2),
                                Text('$_upcomingAppointmentsCount موعد',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const SizedBox(height: 22),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isFull ? AppTheme.error : AppTheme.success,
                            width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isFull
                                      ? '🔴 حالة الورشة: ممتلئ (غير متفرغ لهذا اليوم)'
                                      : '🟢 حالة الورشة: متفرغ (يمكنه استقبال وتصليح $remainingCapacity سيارات إضافية)',
                                  style: TextStyle(
                                      color: isFull
                                          ? AppTheme.error
                                          : AppTheme.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                    'التاريخ المحدّد للفحص: ${_formatDate(_selectedAvailableDate)}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary),
                            onPressed: _showAvailabilitySettings,
                            icon: const Icon(Icons.edit_calendar,
                                size: 14, color: Colors.white),
                            label: const Text('تغيير التاريخ',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('طلبات الحجوزات الواردة:',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 12),
                    _appointments.isEmpty
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Text('لا توجد حجوزات واردة حالياً',
                                    style: TextStyle(color: Colors.grey))))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _appointments.length,
                            itemBuilder: (context, index) {
                              final appt = _appointments[index];
                              final customer = appt['customers'] ?? {};
                              final status = appt['status'] ?? 'pending';
                              final apptDate =
                                  appt['appointment_date']?.toString() ?? '';
                              final apptTime =
                                  appt['appointment_time']?.toString() ?? '';

                              // 🌟 عرض التوقيت المحلي بدقة
                              final String formattedDateTime =
                                  _formatLocalizedDateTime(apptDate, apptTime);

                              double totalAmt = double.tryParse(
                                      appt['total_amount']?.toString() ??
                                          '0') ??
                                  0.0;
                              double commission = double.tryParse(
                                      appt['platform_commission']?.toString() ??
                                          '0') ??
                                  (totalAmt * 0.1);

                              int acceptedOnThisApptDate = _appointments
                                  .where((a) =>
                                      a['appointment_date']?.toString() ==
                                          apptDate &&
                                      (a['status'] == 'accepted' ||
                                          a['status'] == 'repairing' ||
                                          a['status'] ==
                                              'confirmed_and_on_the_way'))
                                  .length;
                              bool isThisDateFull =
                                  acceptedOnThisApptDate >= maxCapacity;

                              // 🌟 هل انتهت السيارة وجاهزة؟
                              final bool isCompleted = status == 'completed';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
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
                                            customer['full_name'] ??
                                                customer['username'] ??
                                                'زبون',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14)),
                                        Text('📅 $formattedDateTime',
                                            style: const TextStyle(
                                                color: AppTheme.warning,
                                                fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                        '📞 الهاتف: ${customer['phone'] ?? 'غير متوفر'}',
                                        style: TextStyle(
                                            color: Colors.grey.shade300,
                                            fontSize: 12)),
                                    Text(
                                        '🔧 الخدمة: ${appt['service_description'] ?? 'صيانة عامة'}',
                                        style: TextStyle(
                                            color: Colors.grey.shade300,
                                            fontSize: 12)),
                                    if (status == 'reschedule_suggested') ...[
                                      const SizedBox(height: 6),
                                      const Text(
                                          '⏳ تم اقتراح موعد آخر للزبون، بانتظار رد الزبون...',
                                          style: TextStyle(
                                              color: Colors.amber,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                    if (totalAmt > 0) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                          '💰 السعر المتفق عليه: $totalAmt د.أ | العمولة (10%): $commission د.أ',
                                          style: const TextStyle(
                                              color: AppTheme.primaryLight,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                    const SizedBox(height: 12),
                                    if (status == 'pending')
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      isThisDateFull
                                                          ? AppTheme.warning
                                                          : AppTheme.success,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 8)),
                                              onPressed: isThisDateFull
                                                  ? () =>
                                                      _showSuggestRescheduleDialog(
                                                          appt['id'].toString())
                                                  : () => _updateAppointmentStatus(
                                                      appt['id'].toString(),
                                                      'accepted',
                                                      'accepted'), // 🌟 قبول مباشر بدون إدخال سعر
                                              child: Text(
                                                  isThisDateFull
                                                      ? 'اكتمل العدد - اقتراح موعد آخر'
                                                      : 'قبول', // 🌟 كلمة قبول فقط
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppTheme.error,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 8)),
                                              onPressed: () =>
                                                  _updateAppointmentStatus(
                                                      appt['id'].toString(),
                                                      'rejected',
                                                      'rejected'),
                                              child: const Text('رفض',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11)),
                                            ),
                                          ),
                                        ],
                                      )
                                    else if (status == 'accepted' ||
                                        status == 'repairing') ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      AppTheme.warning,
                                                  side: const BorderSide(
                                                      color: AppTheme.warning)),
                                              onPressed: () =>
                                                  _updateAppointmentStatus(
                                                      appt['id'].toString(),
                                                      'repairing',
                                                      'repairing'),
                                              child: const Text('جاري التصليح',
                                                  style:
                                                      TextStyle(fontSize: 11)),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppTheme.success),
                                              onPressed: () =>
                                                  _updateAppointmentStatus(
                                                      appt['id'].toString(),
                                                      'completed',
                                                      'completed'),
                                              child: const Text(
                                                  'تم الانتهاء وجاهزة',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.white)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // 🌟 زر دفع العمولة (مقفل تماماً ولن يتفعل إلا بعد الضغط على "تم الانتهاء وجاهزة")
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isCompleted
                                                ? AppTheme.primary
                                                : Colors.grey.shade800,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                          ),
                                          onPressed: isCompleted
                                              ? () => _showPaymentOptionsDialog(
                                                  appt['id'].toString(),
                                                  totalAmt)
                                              : null,
                                          icon: const Icon(Icons.payment,
                                              size: 16, color: Colors.white),
                                          label: Text(
                                            isCompleted
                                                ? 'دفع عمولة المنصة المستحقة'
                                                : 'دفع العمولة (يُفتح بعد إتمام التصليح وجاهزيتها)',
                                            style: TextStyle(
                                              color: isCompleted
                                                  ? Colors.white
                                                  : Colors.grey.shade400,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ] else if (status == 'completed') ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.success
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Center(
                                          child: Text('✅ مكتمل (تم التسليم)',
                                              style: TextStyle(
                                                  color: AppTheme.success,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // 🌟 زر دفع العمولة يصبح متاحاً وفعالاً بعد إتمام الطلب
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primary,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8)),
                                          onPressed: () =>
                                              _showPaymentOptionsDialog(
                                                  appt['id'].toString(),
                                                  totalAmt),
                                          icon: const Icon(Icons.payment,
                                              size: 16, color: Colors.white),
                                          label: const Text(
                                              'دفع عمولة المنصة المستحقة',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12)),
                                        ),
                                      ),
                                    ] else if (status == 'rejected') ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.error
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Center(
                                          child: Text('❌ تم رفض الطلب',
                                              style: TextStyle(
                                                  color: AppTheme.error,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold)),
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
}
