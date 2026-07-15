class AppConfig {
  AppConfig._();

  static const String appName = 'صلّحلي';

  // [FIX-ENV-01] عنوان الخادم كان ثابتاً على الإنتاج دائماً، حتى في نسخ
  // Debug المحلية — أي اختبار على جهاز مطوّر كان يضرب بيانات حقيقية (طلبات،
  // رصيد، دفعات) بدون قصد.
  //
  // الآن يمكن تجاوزه وقت البناء فقط عند الحاجة، عبر:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  //   (استخدم 10.0.2.2 لمحاكي أندرويد للوصول لسيرفر يعمل محلياً على جهازك)
  //
  // بدون تمرير --dart-define إطلاقاً، القيمة الافتراضية تبقى هي الإنتاج
  // تماماً كما كانت قبل هذا التعديل — أي أمر بناء أو CI موجود حالياً (لا يمرر
  // --dart-define) يبقى بنفس السلوك 100% بدون أي تغيير.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sallehly.com',
  );

  static const String apiUrl = '$baseUrl/api';
}
