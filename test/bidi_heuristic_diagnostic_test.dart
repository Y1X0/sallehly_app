// أداة تشخيصية مؤقتة (تُحذف بعد استخلاص النتيجة) — تقارن
// Bidi.detectRtlDirectionality مقابل Bidi.estimateDirectionOfText على أمثلة
// واقعية من محتوى هذا التطبيق (وصف طلب، تركيب مدينة-منطقة، نص يبدأ برقم/
// ترقيم/اسم تجاري لاتيني، إنجليزي حقيقي، فارغ/فراغات فقط...) قبل اختيار أيّ
// منهما فعلياً لـBidiText المقترح بـL10N_PROGRESS.md. لا يمسّ أي كود تطبيق.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;

void main() {
  test('[BIDI-DIAG] مقارنة detectRtlDirectionality مقابل estimateDirectionOfText', () {
    final cases = <String, String>{
      'وصف طلب عربي عادي (جملتان)':
          'يوجد عطل متكرر في التمديدات الكهربائية بالمطبخ ويحتاج فحصاً عاجلاً '
              'قبل نهاية اليوم، الرجاء التواصل بأقرب وقت ممكن.',
      'تركيب مدينة-منطقة': 'عمّان - جبل الحسين',
      'عربي يبدأ برقم': '5 قطع غيار تحتاج استبدال فوراً في المكيف',
      'عربي يبدأ برقم هاتف': '0791234567 هذا رقمي للتواصل السريع رجاءً',
      'عربي يبدأ بشرطة/ترقيم': '- شارع الجامعة، بجانب المسجد الكبير',
      'عربي يبدأ باسم تجاري لاتيني': 'Samsung الثلاجة تعطلت منذ يومين وتحتاج فحصاً',
      'إنجليزي حقيقي بالكامل': 'Please fix my AC unit as soon as possible',
      'مختلط: عربي ينتهي باسم تجاري لاتيني': 'أحتاج فني تكييف لصيانة جهاز LG بأقرب وقت',
      'مختلط: عربي ورمز طلب لاتيني بالمنتصف': 'الطلب رقم ORDER-123 أصبح جاهزاً للتسليم',
      'فارغ تماماً': '',
      'فراغات فقط': '   ',
      'أرقام فقط': '0791234567',
      'ترقيم فقط': '...',
      'حالة سلكية عربية قصيرة (status wire value)': 'مكتمل',
      'رسالة دردشة تبدأ برمز تعبيري': '🔧 وصلتك رسالة جديدة بخصوص الطلب',
    };

    String label(intl.TextDirection d) {
      if (d == intl.TextDirection.RTL) return 'RTL';
      if (d == intl.TextDirection.LTR) return 'LTR';
      return 'UNKNOWN';
    }

    // ignore: avoid_print
    print('[BIDI-DIAG] ============================================================');
    cases.forEach((caseLabel, text) {
      final detectRtl = intl.Bidi.detectRtlDirectionality(text);
      final estimate = intl.Bidi.estimateDirectionOfText(text);
      final detectAsEstimate =
          detectRtl ? intl.TextDirection.RTL : intl.TextDirection.LTR;
      final disagree = estimate != intl.TextDirection.UNKNOWN &&
          estimate != detectAsEstimate;
      // ignore: avoid_print
      print(
        '[BIDI-DIAG] $caseLabel\n'
        '  النص: "${text.isEmpty ? '<فارغ>' : text}"\n'
        '  detectRtlDirectionality => ${detectRtl ? 'RTL' : 'LTR'}\n'
        '  estimateDirectionOfText => ${label(estimate)}\n'
        '  ${disagree ? '⚠️  يختلفان' : 'متّفقان (أو estimate=UNKNOWN)'}',
      );
    });
    print('[BIDI-DIAG] ============================================================');
  });
}
