import 'package:flutter/material.dart';

/// نظام الألوان الموحد للتطبيق — تصميم عصري بألوان عميقة وهادئة
class AppColors {
  AppColors._();

  // ─── الألوان الأساسية ───
  static const Color primary = Color(0xFF1D4ED8); // أزرق عميق
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color secondary = Color(0xFF0D9488); // تركواز
  static const Color secondaryLight = Color(0xFF14B8A6);

  // ─── الألوان الوظيفية ───
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFF22C55E);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0284C7);
  static const Color violet = Color(0xFF7C3AED);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color slate = Color(0xFF475569);

  // ─── الخلفيات والأسطح ───
  static const Color background = Color(0xFFF1F5F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF8FAFC);

  // ─── النصوص ───
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // ─── الحدود ───
  static const Color border = Color(0xFFE2E8F0);

  // ─── التدرجات ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF0D9488)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF134E4A)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF16A34A), Color(0xFF4ADE80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFB91C1C), Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient violetGradient = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient inkGradient = LinearGradient(
    colors: [Color(0xFF334155), Color(0xFF94A3B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ظل ناعم موحد للبطاقات
  static List<BoxShadow> softShadow({
    Color color = const Color(0x140F172A),
    double blur = 14,
    double y = 4,
  }) {
    return [BoxShadow(color: color, blurRadius: blur, offset: Offset(0, y))];
  }
}
