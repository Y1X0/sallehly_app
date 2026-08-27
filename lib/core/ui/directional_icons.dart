import 'package:flutter/material.dart';

/// [FIX-L10N-02] أيقونات ملاحة (رجوع/تقدّم) مُدركة لاتجاه النص — يجب أن
/// تنعكس بصرياً بين العربية (RTL) والإنجليزية (LTR)، تماماً كما يفعل زر
/// الرجوع الافتراضي بفلَتّر نفسه (`BackButtonIcon`) داخلياً. هذا مقصور على
/// أيقونات الملاحة فقط — أيقونات الوسائط/التشغيل/الوقت (تشغيل صوت، ساعة،
/// ...) لا تُعاكَس أبداً بغضّ النظر عن الاتجاه، ولا علاقة لها بهذا الملف.
///
/// راجع L10N_PROGRESS.md §3 لقائمة الحالات التسع المرشَّحة لاستخدام هذا
/// الملف. **لم يُطبَّق بعد على أي شاشة** — تطبيقه مؤجَّل عمداً للمرحلة
/// الثانية (Phase 2)، بنفس توقيت استخراج نصوص كل ملف من تلك الملفات تحديداً
/// (بدل تعديلها الآن بمعزل عن ذلك)، تماشياً مع خطة "إصلاح مشاكل RTL/LTR ضمن
/// نفس الملف عند ترحيله" الأصلية. تطبيق هذه الدوال على شاشة عربية حالياً
/// سيُغيّر اتجاه سهم "رجوع" فعلياً (من الإشارة يساراً إلى الإشارة يميناً)
/// لمطابقة عرف RTL الصحيح — تغيير بصري مقصود عند تطبيقه، وليس أثراً جانبياً.
class DirectionalIcons {
  const DirectionalIcons._();

  static bool isRtl(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl;

  /// زر "رجوع" (العودة للشاشة السابقة) — طراز Material المدوّر.
  static IconData back(BuildContext context) =>
      isRtl(context) ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded;

  /// زر "رجوع" — طراز iOS المدوّر الحديث (arrow_..._ios_new_rounded).
  static IconData backIosStyle(BuildContext context) => isRtl(context)
      ? Icons.arrow_forward_ios_new_rounded
      : Icons.arrow_back_ios_new_rounded;

  /// سهم "الانتقال للتفاصيل" ضمن صف قائمة (بطاقة طلب، عنصر إعدادات، ...) —
  /// طراز iOS. عكس اتجاه back تماماً: يشير نحو المحتوى وليس للخلف.
  static IconData forwardIosStyle(BuildContext context) => isRtl(context)
      ? Icons.arrow_back_ios_new_rounded
      : Icons.arrow_forward_ios_rounded;

  /// شيفرون بسيط لنفس غرض forwardIosStyle، لأي استخدام مشابه لاحقاً.
  static IconData chevronForward(BuildContext context) =>
      isRtl(context) ? Icons.chevron_left_rounded : Icons.chevron_right_rounded;
}
