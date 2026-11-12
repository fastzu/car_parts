import 'package:flutter/material.dart';

class AppTheme {
  // الهوية البصرية الجديدة (الفحمي + البرتقالي)
  static const Color background =
      Color(0xFF1A1D21); // الفحمي الداكن جداً (الخلفية)
  static const Color surface =
      Color(0xFF262A30); // الفحمي الفاتح (للكروت والقوائم)
  static const Color primary =
      Color(0xFFFF7A00); // البرتقالي الصناعي (لأزرار والعناصر المهمة)
  static const Color primaryLight = Color(0xFFFF9933); // برتقالي فاتح

  // ألوان النصوص والثانوية
  static const Color textPrimary = Colors.white; // النصوص الأساسية
  static const Color textSecondary =
      Color(0xFF9CA3AF); // النصوص الثانوية (رمادي فاتح)
  static const Color border = Color(0xFF374151); // لون الحدود

  // ألوان الحالات
  static const Color success = Color(0xFF10B981); // أخضر للنجاح
  static const Color error = Color(0xFFEF4444); // أحمر للخطأ
  static const Color warning = Color(0xFFF59E0B); // أصفر للتحذير

  // إعدادات الـ Theme العام
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      fontFamily: 'Tajawal',
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryLight,
        surface: surface,
        error: error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
            color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 2)),
        labelStyle: const TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
