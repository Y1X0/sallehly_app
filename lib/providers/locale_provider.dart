import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/current_locale.dart';

/// [FIX-L10N-01] يتحكّم بلغة واجهة التطبيق (عربي/إنجليزي)، ويحفظ اختيار
/// المستخدم محلياً حتى تبقى نفس اللغة بعد إغلاق التطبيق وفتحه من جديد.
///
/// نفس نمط ThemeController بالضبط (راجع lib/providers/theme_controller.dart):
/// ChangeNotifier + SharedPreferences بمفتاح ثابت واحد، مع loadSaved() تُستدعى
/// عند الإقلاع وsetter يُصدر إشعاراً فورياً ثم يحفظ بالخلفية.
class LocaleProvider extends ChangeNotifier {
  static const String _prefsKey = 'sallehly_locale';

  /// العربية دائماً هي اللغة الافتراضية والاحتياطية (fallback) — قبل تحميل أي
  /// تفضيل محفوظ، وأيضاً إن كانت القيمة المحفوظة غير معروفة/تالفة.
  static const Locale fallbackLocale = Locale('ar');
  static const Locale englishLocale = Locale('en');

  Locale _locale = fallbackLocale;
  Locale get locale => _locale;
  bool get isEnglish => _locale.languageCode == englishLocale.languageCode;

  /// يحمّل التفضيل المحفوظ (إن وجد) عند إقلاع التطبيق.
  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    _locale = saved == englishLocale.languageCode ? englishLocale : fallbackLocale;
    // [FIX-ERRCODE-01] راجع core/i18n/current_locale.dart — يجب أن تبقى
    // مطابقة لـ_locale دائماً، بما فيها هذا المسار الابتدائي (لا فقط
    // setLocale أدناه)، وإلا يستخدم resolveApiErrorCode لغة قديمة/افتراضية.
    currentAppLocale = _locale;
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    if (_locale == value) return;
    _locale = value;
    currentAppLocale = _locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, value.languageCode);
  }

  Future<void> toggle() => setLocale(isEnglish ? fallbackLocale : englishLocale);
}
