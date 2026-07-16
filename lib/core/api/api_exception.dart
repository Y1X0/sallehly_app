class ApiException implements Exception {
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