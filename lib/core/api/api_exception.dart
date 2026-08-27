class ApiException implements Exception {
  // TODO(l10n): يعرض هذا النص كما يرسله الخادم حرفياً (عربي فقط حالياً) في
  // كل مكان يُعرض فيه للمستخدم (SnackBar/Text عبر ~40+ موقعاً بالتطبيق) —
  // لا تُترجم أو تُزوَّر ترجمته بالواجهة. دعم إنجليزي حقيقي هنا يتطلب تغييراً
  // بالخادم نفسه (رمز خطأ لغوي محايد كـ`code` أدناه، أو دعم Accept-Language)
  // وليس بهذا المشروع وحده. راجع L10N_PROGRESS.md §5.
  final String message;
  final int? statusCode;

  /// [FIX-OFFERQUOTA-01] رمز خطأ صريح من السيرفر (مثل 'INSUFFICIENT_BALANCE')
  /// عند توفّره — يسمح للواجهة بالتفريق بين حالات خطأ محدَّدة تحتاج تصرفاً
  /// خاصاً (مثل توجيه المستخدم لشاشة الشحن) بدل الاعتماد على نص الرسالة أو
  /// رمز الحالة HTTP وحده.
  final String? code;

  ApiException(
      this.message, {
        this.statusCode,
        this.code,
      });

  @override
  String toString() {
    return message;
  }
}