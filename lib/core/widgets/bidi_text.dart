import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

/// نص يشتق اتجاهه من محتواه الفعلي (`Bidi.estimateDirectionOfText`) بدل
/// الاتجاه المحيط (`Directionality.of(context)`) — بديل مباشر لـ`Text` بنفس
/// المعاملات الفعلية المستخدَمة بمواقع هذا المشروع (`style`، `textAlign`،
/// `maxLines`، `overflow`، `softWrap`).
///
/// لماذا: نص عربي (مثل وصف طلب، رسالة دردشة) يبقى بواجهة أصبح اتجاهها
/// المحيط LTR (`locale=en`) — أو العكس تماماً: فني يكتب "OK"/"done" برسالة
/// داخل واجهة عربية RTL — يحتاج اتجاهه الداخلي (تشكيل الحروف/التفاف
/// الترقيم اللاحق) مشتقّاً من محتواه هو، لا من لغة الواجهة الحالية. راجع
/// L10N_PROGRESS.md §3 ("Arabic content renders on the wrong side...").
///
/// عند محتوى محايد الاتجاه (فارغ/فراغات فقط/ترقيم فقط، حيث
/// `estimateDirectionOfText` يرجع `UNKNOWN`)، يُستخدَم الاتجاه المحيط بدل
/// فرض أي اتجاه — لا معنى لاتجاه "مكتشَف" من نص لا يحوي أي حرف قوي الاتجاه
/// أصلاً.
///
/// **يؤثّر فقط على اتجاه *هذا النص تحديداً* — لا على موضعه بالتخطيط الأب.**
/// موضع فقاعة الدردشة مثلاً (`Align(alignment: isMe ? ... )` بـ
/// `chat_bubble.dart`) يبقى كما هو تماماً بغضّ النظر عن لغة محتوى الرسالة —
/// `Text.textDirection` معامل تشكيل/رسم داخلي للفقرة نفسها فقط، لا ينتشر
/// لأي عنصر تخطيط أب أو شقيق (مضمون معماريًا بفلَتّر، ومُتحقَّق منه أيضاً
/// بـ`test/widgets/bidi_text_test.dart`).
///
/// **`textAlign`:** إن مُرِّر `TextAlign.start`/`.end` (الحالة الوحيدة
/// المُستخدَمة فعلياً بهذا المشروع اليوم، بـ`_InfoTile` بـ`settings_screen.dart`)
/// يُحلّ لقيمة `.left`/`.right` مطلقة حسب **الاتجاه المحيط** (لا اتجاه
/// المحتوى المكتشَف) قبل التمرير لـ`Text` الداخلي. بدون هذا، عنصر يعرض قيمة
/// بنهاية صف (`textAlign: TextAlign.end` تحت `locale=en`، أي "يمين" أصلاً)
/// كان سينتقل فجأة لليسار فور اكتشاف محتوى عربي RTL بهذه القيمة — نفس
/// "التأثير الجانبي على المحاذاة" الذي طُلِب تفاديه تحديداً. القيم المطلقة
/// (`.left`/`.right`/`.center`/`.justify`) أو `null` تُمرَّر كما هي بلا أي
/// تحويل.
class BidiText extends StatelessWidget {
  final String? text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const BidiText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  @override
  Widget build(BuildContext context) {
    final ambient = Directionality.of(context);
    final content = text ?? '';

    final TextDirection direction;
    switch (intl.Bidi.estimateDirectionOfText(content)) {
      case intl.TextDirection.RTL:
        direction = TextDirection.rtl;
      case intl.TextDirection.LTR:
        direction = TextDirection.ltr;
      default:
        // UNKNOWN — لا إشارة اتجاه قوية بالمحتوى (فارغ/فراغات/ترقيم فقط)،
        // فلا داعٍ لفرض أي اتجاه غير الاتجاه المحيط أصلاً.
        direction = ambient;
    }

    var resolvedAlign = textAlign;
    if (textAlign == TextAlign.start) {
      resolvedAlign =
          ambient == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    } else if (textAlign == TextAlign.end) {
      resolvedAlign =
          ambient == TextDirection.rtl ? TextAlign.left : TextAlign.right;
    }

    return Text(
      content,
      textDirection: direction,
      style: style,
      textAlign: resolvedAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
