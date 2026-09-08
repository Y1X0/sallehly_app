class AppConfig {
  AppConfig._();

  // [L10N-02] لا يوجد أي موقع استخدام فعلي لهذا الثابت بالكود حالياً (تحقّق
  // شامل: بلا أي استدعاء) — تُرِك كنص عربي ثابت بدل تحويله لمفتاح ARB يتطلب
  // BuildContext بلا أي داعٍ عملي، طالما لا توجد شاشة تعرضه فعلياً.
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

  // [FEAT-GOOGLESIGNIN-01] "Web client ID" (OAuth 2.0) من Firebase Console:
  // Authentication → Sign-in method → Google → Web SDK configuration. يُنشأ
  // تلقائياً عند تفعيل Google كمزوّد تسجيل دخول — ليس سرّاً (يظهر بكل طلب
  // تسجيل دخول)، لكنه إلزامي التمرير هنا (google_sign_in v7 يرفض المتابعة
  // بأندرويد بلا serverClientId صريح). فارغ افتراضياً حتى يُمرَّر فعلياً:
  //   flutter build appbundle --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxxx.apps.googleusercontent.com
  // بلا هذه القيمة، زر "تسجيل الدخول بجوجل" يبقى معطَّلاً بصمت (راجع
  // login_screen.dart) بدل رمي خطأ مبهم وقت الضغط عليه.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
}
