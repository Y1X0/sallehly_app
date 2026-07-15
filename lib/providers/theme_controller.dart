import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';

/// [FIX-THEME-01] يتحكّم بوضع الألوان (داكن/فاتح "وايت مود") لكل التطبيق،
/// ويحفظ اختيار المستخدم محلياً حتى يبقى نفس الوضع بعد إغلاق التطبيق وفتحه.
///
/// عند تبديل الوضع، يستدعي AppColors.applyLight()/applyDark() (اللتان تعيدان
/// تعيين كل قيم الألوان المستخدمة بكل شاشات التطبيق)، ثم يُصدر إشعاراً
/// (notifyListeners) يلتقطه app.dart لإعادة بناء التطبيق، فتنعكس الألوان
/// الجديدة فوراً على كل الصفحات دفعة واحدة.
class ThemeController extends ChangeNotifier {
  static const String _prefsKey = 'sallehly_light_mode';

  bool _isLight = false;
  bool get isLight => _isLight;

  /// يحمّل التفضيل المحفوظ (إن وجد) عند إقلاع التطبيق.
  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_prefsKey) ?? false;
    _isLight = saved;
    if (saved) {
      AppColors.applyLight();
    } else {
      AppColors.applyDark();
    }
    notifyListeners();
  }

  Future<void> setLight(bool value) async {
    if (_isLight == value) return;
    _isLight = value;

    if (value) {
      AppColors.applyLight();
    } else {
      AppColors.applyDark();
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  Future<void> toggle() => setLight(!_isLight);
}
