// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import '../app_theme.dart';

class BookWorkshopScreen extends StatefulWidget {
  const BookWorkshopScreen({super.key});

  @override
  State<BookWorkshopScreen> createState() => _BookWorkshopScreenState();
}

class _BookWorkshopScreenState extends State<BookWorkshopScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _workshopsList = [];
  Map<String, dynamic>? _selectedWorkshopForBooking;

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  int _selectedWorkshopCapacity = 5;
  int _selectedWorkshopBookedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchWorkshops();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchWorkshops() async {
    setState(() => _isLoading = true);
    try {
      final workshopsRes = await Supabase.instance.client
          .from('customers')
          .select(
              'id, username, phone, workshop_address, workshop_latitude, workshop_longitude, max_car_capacity, workshop_image_url, opening_hours, google_maps_url')
          .not('workshop_latitude', 'is', null);

      if (mounted) {
        setState(() {
          _workshopsList = List<Map<String, dynamic>>.from(
            (workshopsRes as List).map(
              (workshop) => Map<String, dynamic>.from(workshop as Map),
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching workshops: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkCapacityAndDate(String workshopId, String dateStr) async {
    try {
      final selectedWorkshop =
          _workshopsList.firstWhere((w) => w['id'].toString() == workshopId);
      int maxCapacity = int.tryParse(
              selectedWorkshop['max_car_capacity']?.toString() ?? '5') ??
          5;

      // جلب الحجوزات المقبولة أو قيد الصيانة لهذا اليوم
      final acceptedBookings = await Supabase.instance.client
          .from('workshop_appointments')
          .select('id, appointment_time')
          .eq('workshop_id', workshopId)
          .eq('appointment_date', dateStr)
          .inFilter('status', ['accepted', 'repairing']);

      setState(() {
        _selectedWorkshopCapacity = maxCapacity;
        _selectedWorkshopBookedCount = acceptedBookings.length;
      });
    } catch (e) {
      debugPrint('Error checking capacity: $e');
    }
  }

  Future<void> _selectCustomDate(
      BuildContext context, String workshopId) async {
    DateTime today = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      String formattedDate =
          "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";

      setState(() {
        _dateController.text = formattedDate;
        _timeController.clear(); // مسح الوقت عند تغيير التاريخ لإعادة التحقق
      });

      await _checkCapacityAndDate(workshopId, formattedDate);
    }
  }

  Future<void> _selectCustomTime(
      BuildContext context, String workshopId) async {
    if (_dateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء اختيار تاريخ الحجز أولاً'),
            backgroundColor: AppTheme.warning),
      );
      return;
    }

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      String timeStr = pickedTime.format(context);

      // جلب الحجوزات الموجودة في نفس اليوم للتحقق من فارق الساعة
      final existingBookings = await Supabase.instance.client
          .from('workshop_appointments')
          .select('appointment_time, status')
          .eq('workshop_id', workshopId)
          .eq('appointment_date', _dateController.text.trim())
          .inFilter('status', ['accepted', 'repairing', 'pending']);

      // تحويل الوقت المختار لدقائق من منتصف الليل للمقارنة بدقة
      int pickedMinutes = pickedTime.hour * 60 + pickedTime.minute;

      bool hasTimeConflict = false;
      for (var booking in existingBookings) {
        String? existingTimeStr = booking['appointment_time']?.toString();
        if (existingTimeStr != null) {
          // محاولة تحليل صيغة الوقت (يدعم الصيغ مثل 10:30 ص أو 14:30)
          int? existingMinutes = _parseTimeStringToMinutes(existingTimeStr);
          if (existingMinutes != null) {
            // التحقق أن الفارق الزمني أقل من 60 دقيقة (ساعة كاملة)
            if ((pickedMinutes - existingMinutes).abs() < 60) {
              hasTimeConflict = true;
              break;
            }
          }
        }
      }

      if (hasTimeConflict) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'عذراً، يجب أن يكون هناك فارق ساعة على الأقل بين المواعيد المحجوزة في هذا اليوم!'),
              backgroundColor: AppTheme.error),
        );
        return;
      }

      setState(() {
        _timeController.text = timeStr;
      });
    }
  }

  // مساعد لتحويل نص الوقت إلى دقائق للمقارنة
  int? _parseTimeStringToMinutes(String timeStr) {
    try {
      // إزالة المسافات الزائدة
      timeStr = timeStr.trim();
      bool isPM = timeStr.contains('م') || timeStr.toLowerCase().contains('pm');
      bool isAM = timeStr.contains('ص') || timeStr.toLowerCase().contains('am');

      // استخراج الأرقام فقط (الساعات والدقائق)
      String cleanTime = timeStr.replaceAll(RegExp(r'[^0-9:]'), '');
      List<String> parts = cleanTime.split(':');
      if (parts.length < 2) return null;

      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return hour * 60 + minute;
    } catch (e) {
      return null;
    }
  }

  Future<void> _bookAppointment(String workshopId) async {
    if (_dateController.text.trim().isEmpty ||
        _timeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء اختيار تاريخ ووقت الحجز من التقويم أولاً'),
            backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'يرجى تسجيل الدخول أولاً';

      final selectedWorkshop =
          _workshopsList.firstWhere((w) => w['id'].toString() == workshopId);
      int maxCapacity = int.tryParse(
              selectedWorkshop['max_car_capacity']?.toString() ?? '5') ??
          5;

      // التحقق النهائي من سعة الورشة المقبولة لهذا اليوم
      final acceptedBookings = await Supabase.instance.client
          .from('workshop_appointments')
          .select('id')
          .eq('workshop_id', workshopId)
          .eq('appointment_date', _dateController.text.trim())
          .inFilter('status', ['accepted', 'repairing']);

      if (acceptedBookings.length >= maxCapacity) {
        throw 'عذراً، وصلت الورشة للحد الأقصى من الطلبات المقبولة ($maxCapacity سيارات) في هذا التاريخ ولا يمكن استقبال حجوزات جديدة!';
      }

      // إدراج الحجز الجديد
      await Supabase.instance.client.from('workshop_appointments').insert({
        'user_id': user.id,
        'workshop_id': workshopId,
        'appointment_date': _dateController.text.trim(),
        'appointment_time': _timeController.text.trim(),
        'service_description': _descController.text.trim(),
        'status': 'pending',
        'progress_step': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إرسال طلب الحجز للورشة بنجاح!'),
              backgroundColor: AppTheme.success),
        );
        setState(() {
          _selectedWorkshopForBooking = null;
          _dateController.clear();
          _timeController.clear();
          _descController.clear();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int remainingCapacity =
        _selectedWorkshopCapacity - _selectedWorkshopBookedCount;
    if (remainingCapacity < 0) remainingCapacity = 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('حجز موعد في ورشة معتمدة',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : _workshopsList.isEmpty
                ? const Center(
                    child: Text('لا توجد ورشات معتمدة متاحة حالياً',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _workshopsList.length,
                    itemBuilder: (context, index) {
                      final workshop = _workshopsList[index];
                      final workshopId = workshop['id'].toString();
                      final isSelectedForBooking =
                          _selectedWorkshopForBooking?['id'].toString() ==
                              workshopId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelectedForBooking
                                ? AppTheme.primary
                                : AppTheme.border,
                            width: isSelectedForBooking ? 2 : 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.network(
                              workshop['workshop_image_url'] ??
                                  'https://images.unsplash.com/photo-1486006920555-c77dce18193b?auto=format&fit=crop&w=600&q=80',
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                height: 160,
                                color: Colors.grey.shade800,
                                child: const Center(
                                    child: Icon(Icons.car_repair,
                                        size: 40, color: Colors.white54)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workshop['username'] ?? 'ورشة معتمدة',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '📍 العنوان: ${workshop['workshop_address'] ?? 'غير متوفر'}',
                                    style: TextStyle(
                                        color: Colors.grey.shade300,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '⏰ ساعات العمل: ${workshop['opening_hours'] ?? '08:00 ص - 08:00 م'}',
                                    style: const TextStyle(
                                        color: AppTheme.warning,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '📞 هاتف الورشة: ${workshop['phone'] ?? 'غير متوفر'}',
                                    style: const TextStyle(
                                        color: AppTheme.primaryLight,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                isSelectedForBooking
                                                    ? AppTheme.success
                                                    : AppTheme.primary,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                          ),
                                          onPressed: () async {
                                            setState(() {
                                              if (isSelectedForBooking) {
                                                _selectedWorkshopForBooking =
                                                    null;
                                              } else {
                                                _selectedWorkshopForBooking =
                                                    workshop;
                                              }
                                              _dateController.clear();
                                              _timeController.clear();
                                              _descController.clear();
                                            });
                                            if (!isSelectedForBooking) {
                                              // جلب السعة الافتراضية عند فتح حقول الحجز
                                              int maxCap = int.tryParse(
                                                      workshop['max_car_capacity']
                                                              ?.toString() ??
                                                          '5') ??
                                                  5;
                                              setState(() {
                                                _selectedWorkshopCapacity =
                                                    maxCap;
                                                _selectedWorkshopBookedCount =
                                                    0;
                                              });
                                            }
                                          },
                                          icon: Icon(
                                              isSelectedForBooking
                                                  ? Icons.check
                                                  : Icons.calendar_month,
                                              size: 16,
                                              color: Colors.white),
                                          label: Text(
                                            isSelectedForBooking
                                                ? 'إلغاء اختيار الحجز'
                                                : 'اختر للحجز',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.primary,
                                            side: const BorderSide(
                                                color: AppTheme.primary),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ChatScreen(
                                                  receiverId: workshopId,
                                                  receiverName:
                                                      workshop['username'] ??
                                                          'الورشة',
                                                ),
                                              ),
                                            );
                                          },
                                          icon:
                                              const Icon(Icons.chat, size: 16),
                                          label: const Text('دردشة',
                                              style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isSelectedForBooking) ...[
                                    const Divider(
                                        color: Colors.white24, height: 24),

                                    // 🌟 عرض عدد السيارات المتبقية في هذا اليوم للزبون
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: remainingCapacity > 0
                                            ? AppTheme.success
                                                .withValues(alpha: 0.15)
                                            : AppTheme.error
                                                .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: remainingCapacity > 0
                                                ? AppTheme.success
                                                : AppTheme.error),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            remainingCapacity > 0
                                                ? Icons.car_repair
                                                : Icons.error_outline,
                                            color: remainingCapacity > 0
                                                ? AppTheme.success
                                                : AppTheme.error,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _dateController.text.isEmpty
                                                ? 'اختر تاريخ الحجز لمعرفة السيارات المتاحة'
                                                : remainingCapacity > 0
                                                    ? '🟢 متبقي $remainingCapacity سيارات متاحة للحجز بهذا اليوم'
                                                    : '🔴 عذراً، الورشة ممتلئة بالكامل لهذا اليوم',
                                            style: TextStyle(
                                              color: remainingCapacity > 0
                                                  ? AppTheme.success
                                                  : AppTheme.error,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    const Text('أدخل تفاصيل وموعد الحجز:',
                                        style: TextStyle(
                                            color: AppTheme.primaryLight,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(height: 12),
                                    GestureDetector(
                                      onTap: () => _selectCustomDate(
                                          context, workshopId),
                                      child: AbsorbPointer(
                                        child: TextField(
                                          controller: _dateController,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: InputDecoration(
                                            labelText:
                                                'تاريخ الحجز (من التقويم - Calendar)',
                                            labelStyle: const TextStyle(
                                                color: Colors.grey),
                                            filled: true,
                                            fillColor: AppTheme.background,
                                            suffixIcon: const Icon(
                                                Icons.calendar_month,
                                                color: AppTheme.primary),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide.none),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: () => _selectCustomTime(
                                          context, workshopId),
                                      child: AbsorbPointer(
                                        child: TextField(
                                          controller: _timeController,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: InputDecoration(
                                            labelText:
                                                'وقت الحجز (يجب أن يكون بين المواعيد فارق ساعة)',
                                            labelStyle: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11),
                                            filled: true,
                                            fillColor: AppTheme.background,
                                            suffixIcon: const Icon(
                                                Icons.access_time_filled,
                                                color: AppTheme.primary),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide.none),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: _descController,
                                      maxLines: 2,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText:
                                            'تفاصيل الصيانة المطلوبة (غيار زيت، فحص...)',
                                        labelStyle:
                                            const TextStyle(color: Colors.grey),
                                        filled: true,
                                        fillColor: AppTheme.background,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide.none),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                remainingCapacity > 0
                                                    ? AppTheme.success
                                                    : Colors.grey.shade700,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12)),
                                        onPressed: remainingCapacity > 0
                                            ? () => _bookAppointment(workshopId)
                                            : () {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'عذراً، لا يمكن الحجز لأن الورشة ممتلئة في هذا التاريخ'),
                                                    backgroundColor:
                                                        AppTheme.error,
                                                  ),
                                                );
                                              },
                                        child: Text(
                                            remainingCapacity > 0
                                                ? 'تأكيد وإرسال الحجز النهائي'
                                                : 'الورشة ممتلئة في هذا التاريخ',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ],
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
