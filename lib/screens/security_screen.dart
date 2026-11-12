import 'package:flutter/material.dart';

class SecurityScreen extends StatefulWidget {
  final bool isArabic;
  const SecurityScreen({super.key, required this.isArabic});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _twoFactorEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
              widget.isArabic ? 'الحماية والباسورد' : 'Security & Password',
              style: const TextStyle(color: Colors.white, fontSize: 18)),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // حل مشكلة ListTile بتغليفها بـ Material صريح
            Material(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.lock_reset,
                    color: Color(0xFF34D399), size: 28),
                title: Text(
                    widget.isArabic ? 'تغيير كلمة المرور' : 'Change Password',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(
                    widget.isArabic
                        ? 'تحديث كلمة المرور عبر Supabase'
                        : 'Update password via Supabase',
                    style:
                        TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios,
                    color: Colors.grey, size: 16),
                onTap: () {
                  // يمكنك هنا فتح شاشة تغيير كلمة المرور أو الحوار الخاص بها
                },
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.mark_email_unread_outlined,
                    color: Color(0xFF60A5FA), size: 28),
                title: Text(
                    widget.isArabic
                        ? 'تغيير البريد الإلكتروني'
                        : 'Change Email',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(
                    widget.isArabic
                        ? 'إرسال رابط تأكيد للبريد الجديد'
                        : 'Send verification link',
                    style:
                        TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios,
                    color: Colors.grey, size: 16),
                onTap: () {
                  // يمكنك هنا إضافة منطق تغيير البريد
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security,
                          color: Color(0xFFFBBF24), size: 28),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              widget.isArabic
                                  ? 'التحقق الثنائي (2FA)'
                                  : 'Two-Factor Auth',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                              widget.isArabic
                                  ? 'حماية إضافية لحسابك'
                                  : 'Extra security via Supabase',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: _twoFactorEnabled,
                    activeThumbColor: const Color(0xFF3B82F6),
                    onChanged: (val) => setState(() => _twoFactorEnabled = val),
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
