import 'package:flutter/material.dart';
import '../app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> notifications = [
      {
        'title': 'خصم خاص على قطع الغيار!',
        'body': 'احصل على خصم 15% على جميع بطاريات وزيوت السيارات هذا الأسبوع.',
        'time': 'منذ ساعة'
      },
      {
        'title': 'تحديث حالة الطلب',
        'body': 'الميكانيكي قبل طلبك وهو في طريقه إلى موقعك الحالي.',
        'time': 'منذ 3 ساعات'
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('الإشعارات والعروض الترويجية', style: TextStyle(color: Colors.white, fontSize: 15)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif = notifications[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(notif['title']!, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(notif['time']!, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(notif['body']!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}