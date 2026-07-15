import 'package:flutter/material.dart';

/// نظام الألوان المركزي للتطبيق.
///
/// [FIX-THEME-01] لدعم "الوايت مود" (خلفية بيضاء احترافية موحّدة لكل
/// الشاشات) مع زر تبديل حي من الإعدادات، تحوّلت الحقول هنا من `static const`
/// إلى `static` عادية (قابلة لإعادة التعيين وقت التشغيل) — بنفس الأسماء
/// وبنفس نقاط الاستخدام بالضبط بباقي الكود، فلا شيء تغيّر بتصميم أو منطق أي
/// شاشة. عند تبديل الوضع عبر ThemeController تُستدعى [applyDark] أو
/// [applyLight] فتتحدّث كل القيم دفعة واحدة، ثم تُعاد قراءتها تلقائياً بكل
/// مكان يستخدم AppColors.xxx.
class AppColors {
  AppColors._();

  static bool isLight = false;

  // ==== الوضع الداكن (الأصلي، كما هو تماماً) ====
  static Color background = const Color(0xFF0A0E29);
  static Color background2 = const Color(0xFF111A45);

  static Color surface = const Color(0xF2141D45);
  static Color card = const Color(0xE6192352);
  static Color card2 = const Color(0xE61F2B63);

  // الهوية: تركواز + بنفسجي + أزرق سماوي — تبقى نفسها بالوضعين حفاظاً على
  // هوية العلامة التجارية.
  static Color primary = const Color(0xFF7B5CFF); // بنفسجي
  static Color secondary = const Color(0xFF22D3EE); // تركواز
  static Color accent = const Color(0xFF38BDF8); // أزرق سماوي

  static Color success = const Color(0xFF10D9A0);
  static Color warning = const Color(0xFFFBBF24);
  static Color danger = const Color(0xFFFB5C6B);

  static Color textPrimary = const Color(0xFFF4F7FF);
  static Color textSecondary = const Color(0xFFB9C4E0);
  static Color textMuted = const Color(0xFF7E8AB4);

  static Color border = const Color(0xFF2E3A77);
  static const Color transparent = Colors.transparent;

  // تدرّج الأزرار: بنفسجي ← تركواز (الهوية البريميوم) — ثابت بالوضعين.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [
      Color(0xFF7B5CFF),
      Color(0xFF22D3EE),
    ],
  );

  // تدرّج بديل سماوي ← بنفسجي — ثابت بالوضعين.
  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF38BDF8),
      Color(0xFF7B5CFF),
    ],
  );

  static LinearGradient backgroundGradient = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0C1234),
      Color(0xFF080B22),
    ],
  );

  static LinearGradient cardGradient = const LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF1E2A63),
      Color(0xFF141D45),
    ],
  );

  /// يعيد كل الألوان لنفس القيم الأصلية بالضبط (الوضع الداكن الحالي).
  static void applyDark() {
    isLight = false;
    background = const Color(0xFF0A0E29);
    background2 = const Color(0xFF111A45);
    surface = const Color(0xF2141D45);
    card = const Color(0xE6192352);
    card2 = const Color(0xE61F2B63);
    success = const Color(0xFF10D9A0);
    warning = const Color(0xFFFBBF24);
    danger = const Color(0xFFFB5C6B);
    textPrimary = const Color(0xFFF4F7FF);
    textSecondary = const Color(0xFFB9C4E0);
    textMuted = const Color(0xFF7E8AB4);
    border = const Color(0xFF2E3A77);
    backgroundGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF0C1234),
        Color(0xFF080B22),
      ],
    );
    cardGradient = const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Color(0xFF1E2A63),
        Color(0xFF141D45),
      ],
    );
  }

  /// وضع "الوايت مود": خلفية بيضاء نظيفة واحترافية (بأسلوب تطبيقات الطلبات
  /// الكبرى) مع نصوص داكنة عالية التباين وكروت بيضاء بحدود فاتحة بدل التوهّج
  /// الزجاجي الداكن. ألوان الهوية (primary/secondary/accent) والتدرّجات
  /// البنفسجي/التركوازي على الأزرار تبقى كما هي بالضبط.
  static void applyLight() {
    isLight = true;
    background = const Color(0xFFFFFFFF);
    background2 = const Color(0xFFF7F8FC);
    surface = const Color(0xFFF6F7FB);
    card = const Color(0xFFFFFFFF);
    card2 = const Color(0xFFEFF1F8);
    success = const Color(0xFF0FA982);
    warning = const Color(0xFFB9840F);
    danger = const Color(0xFFE0323F);
    textPrimary = const Color(0xFF15182E);
    textSecondary = const Color(0xFF565F80);
    textMuted = const Color(0xFF8C95B3);
    border = const Color(0xFFE4E7F2);
    backgroundGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFFFFFF),
        Color(0xFFFAFBFF),
      ],
    );
    cardGradient = const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Color(0xFFFFFFFF),
        Color(0xFFF8F9FD),
      ],
    );
  }
}
