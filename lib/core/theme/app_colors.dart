import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // خلفية أغمق ميلان للأزرق الليلي البنفسجي (بريميوم، أقل كآبة من الأسود)
  static const Color background = Color(0xFF0A0E29);
  static const Color background2 = Color(0xFF111A45);

  static const Color surface = Color(0xF2141D45);
  static const Color card = Color(0xE6192352);
  static const Color card2 = Color(0xE61F2B63);

  // الهوية: تركواز + بنفسجي + أزرق سماوي
  static const Color primary = Color(0xFF7B5CFF);      // بنفسجي
  static const Color secondary = Color(0xFF22D3EE);    // تركواز
  static const Color accent = Color(0xFF38BDF8);       // أزرق سماوي

  static const Color success = Color(0xFF10D9A0);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFFB5C6B);

  static const Color textPrimary = Color(0xFFF4F7FF);
  static const Color textSecondary = Color(0xFFB9C4E0);
  static const Color textMuted = Color(0xFF7E8AB4);

  static const Color border = Color(0xFF2E3A77);
  static const Color transparent = Colors.transparent;

  // تدرّج الأزرار: بنفسجي ← تركواز (الهوية البريميوم)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [
      Color(0xFF7B5CFF),
      Color(0xFF22D3EE),
    ],
  );

  // تدرّج بديل سماوي ← بنفسجي
  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF38BDF8),
      Color(0xFF7B5CFF),
    ],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0C1234),
      Color(0xFF080B22),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF1E2A63),
      Color(0xFF141D45),
    ],
  );
}
