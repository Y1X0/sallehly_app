// اختبارات BidiText (lib/core/widgets/bidi_text.dart) — راجع L10N_PROGRESS.md
// §3 لسياق المشكلة (نص عربي/إنجليزي يبقى على الجهة الخطأ بعد قلب الاتجاه
// المحيط). التغطية المطلوبة صراحةً: فارغ، فراغات فقط، أرقام فقط، ترقيم فقط،
// null-ish، رمز تعبيري فقط، ونص إنجليزي حقيقي داخل واجهة عربية (فني يكتب
// "OK"/"done" برسالة) — بلا أي استثناء إطلاقاً، ورجوع للاتجاه المحيط عند
// محتوى محايد الاتجاه. يُثبت أيضاً أن BidiText لا يغيّر موضع/محاذاة العنصر
// الأب (مثل Align فقاعة الدردشة) ولا يكسر textAlign.start/.end القائم على
// الاتجاه المحيط (لا اتجاه المحتوى المكتشَف) بمواقع مثل _InfoTile.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/core/widgets/bidi_text.dart';

Widget _wrap(Widget child, TextDirection ambient) =>
    Directionality(textDirection: ambient, child: child);

Text _innerText(WidgetTester tester) => tester.widget<Text>(find.byType(Text));

void main() {
  group('BidiText — لا يرمي أي استثناء إطلاقاً', () {
    final cases = <String, String?>{
      'فارغ': '',
      'فراغات فقط': '   ',
      'أرقام فقط': '0791234567',
      'ترقيم فقط': '...',
      'رمز تعبيري فقط': '🔧',
      'null-ish (text: null)': null,
    };

    for (final entry in cases.entries) {
      testWidgets('لا يرمي — ${entry.key} (محيط rtl)', (tester) async {
        await tester.pumpWidget(_wrap(BidiText(entry.value), TextDirection.rtl));
        expect(tester.takeException(), isNull);
      });

      testWidgets('لا يرمي — ${entry.key} (محيط ltr)', (tester) async {
        await tester.pumpWidget(_wrap(BidiText(entry.value), TextDirection.ltr));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('BidiText — يشتق الاتجاه من المحتوى الفعلي', () {
    testWidgets('نص عربي حقيقي => rtl حتى مع محيط ltr', (tester) async {
      await tester.pumpWidget(_wrap(
        const BidiText('يوجد عطل متكرر في التمديدات الكهربائية ويحتاج فحصاً عاجلاً.'),
        TextDirection.ltr,
      ));
      expect(_innerText(tester).textDirection, TextDirection.rtl);
    });

    testWidgets('نص إنجليزي حقيقي => ltr حتى مع محيط rtl', (tester) async {
      await tester.pumpWidget(_wrap(
        const BidiText('Please fix my AC unit as soon as possible'),
        TextDirection.rtl,
      ));
      expect(_innerText(tester).textDirection, TextDirection.ltr);
    });

    // [الحالة المطلوبة تحديداً] فني يكتب رداً إنجليزياً قصيراً برسالة دردشة
    // داخل واجهة عربية بالكامل — نمط يومي حقيقي (OK / done / رقم هاتف).
    testWidgets('"OK" داخل واجهة عربية => ltr (رسالة دردشة قصيرة)', (tester) async {
      await tester.pumpWidget(_wrap(const BidiText('OK'), TextDirection.rtl));
      expect(_innerText(tester).textDirection, TextDirection.ltr);
    });

    testWidgets('"done" داخل واجهة عربية => ltr', (tester) async {
      await tester.pumpWidget(_wrap(const BidiText('done'), TextDirection.rtl));
      expect(_innerText(tester).textDirection, TextDirection.ltr);
    });

    testWidgets('"call me at 0791234567" داخل واجهة عربية => ltr', (tester) async {
      await tester.pumpWidget(_wrap(
        const BidiText('call me at 0791234567'),
        TextDirection.rtl,
      ));
      expect(_innerText(tester).textDirection, TextDirection.ltr);
    });

    testWidgets('أرقام فقط (بلا حروف) => ltr — تصنيف حقيقي، وليس UNKNOWN',
        (tester) async {
      // تأكَّد تجريبياً بخطوة المقارنة السابقة: estimateDirectionOfText يصنّف
      // الأرقام المجرَّدة كـLTR فعلياً، ليس UNKNOWN — يبقى الأمر بلا أي رمي
      // استثناء (مغطّى بالمجموعة الأولى)، وهنا نثبت التصنيف الفعلي أيضاً.
      await tester.pumpWidget(_wrap(const BidiText('0791234567'), TextDirection.rtl));
      expect(_innerText(tester).textDirection, TextDirection.ltr);
    });
  });

  group('BidiText — يرجع للاتجاه المحيط عند محتوى محايد (UNKNOWN)', () {
    testWidgets('فارغ + محيط rtl => rtl', (tester) async {
      await tester.pumpWidget(_wrap(const BidiText(''), TextDirection.rtl));
      expect(_innerText(tester).textDirection, TextDirection.rtl);
    });

    testWidgets('فارغ + محيط ltr => ltr', (tester) async {
      await tester.pumpWidget(_wrap(const BidiText(''), TextDirection.ltr));
      expect(_innerText(tester).textDirection, TextDirection.ltr);
    });

    testWidgets('فراغات فقط + محيط rtl => rtl', (tester) async {
      await tester.pumpWidget(_wrap(const BidiText('   '), TextDirection.rtl));
      expect(_innerText(tester).textDirection, TextDirection.rtl);
    });

    testWidgets('ترقيم فقط + محيط ltr => ltr', (tester) async {
      await tester.pumpWidget(_wrap(const BidiText('...'), TextDirection.ltr));
      expect(_innerText(tester).textDirection, TextDirection.ltr);
    });

    testWidgets('null-ish (يُعامَل كفارغ) + محيط rtl => rtl', (tester) async {
      await tester.pumpWidget(_wrap(const BidiText(null), TextDirection.rtl));
      expect(_innerText(tester).textDirection, TextDirection.rtl);
    });

    testWidgets('null-ish (يُعامَل كفارغ) + محيط ltr => ltr', (tester) async {
      await tester.pumpWidget(_wrap(const BidiText(null), TextDirection.ltr));
      expect(_innerText(tester).textDirection, TextDirection.ltr);
    });
  });

  group(
    'BidiText — لا يغيّر موضع/محاذاة العنصر الأب (نمط فقاعة الدردشة)',
    () {
      // [الحالة المطلوبة تحديداً] فقاعة دردشة تُحدَّد جهتها من المُرسِل
      // (isMe)، لا من لغة محتواها — يجب أن تبقى بمكانها بغضّ النظر عن كون
      // الرسالة عربية أو إنجليزية. راجع chat_bubble.dart:160-161 (نمط حقيقي:
      // Align(alignment: isMe ? Alignment.centerLeft : Alignment.centerRight)).
      testWidgets('محتوى إنجليزي بفقاعة "مُرسَلة" (يمين) + محيط عربي => الموضع يبقى يميناً',
          (tester) async {
        await tester.pumpWidget(_wrap(
          const Align(
            alignment: Alignment.centerRight,
            child: BidiText('OK'),
          ),
          TextDirection.rtl,
        ));

        expect(
          tester.widget<Align>(find.byType(Align)).alignment,
          Alignment.centerRight,
        );
        // اتجاه النص الداخلي تغيّر فعلاً (المحتوى إنجليزي)، بلا أي علاقة
        // بموضع الفقاعة نفسها.
        expect(_innerText(tester).textDirection, TextDirection.ltr);
      });

      testWidgets('محتوى عربي بفقاعة "مُستقبَلة" (يسار) + محيط إنجليزي => الموضع يبقى يساراً',
          (tester) async {
        await tester.pumpWidget(_wrap(
          const Align(
            alignment: Alignment.centerLeft,
            child: BidiText('رسالة عربية عادية بمحادثة'),
          ),
          TextDirection.ltr,
        ));

        expect(
          tester.widget<Align>(find.byType(Align)).alignment,
          Alignment.centerLeft,
        );
        expect(_innerText(tester).textDirection, TextDirection.rtl);
      });
    },
  );

  group(
    'BidiText — textAlign.start/.end يتبعان الاتجاه المحيط لا اتجاه المحتوى',
    () {
      // [الحالة المطلوبة تحديداً] settings_screen.dart’s _InfoTile يستخدم
      // textAlign: TextAlign.end لتثبيت القيمة بنهاية الصف — قيمة عربية
      // (city/area) هي RTL دائماً؛ يجب ألا يقفز موضعها المرئي فور تفعيل
      // BidiText، بل يبقى بالضبط كما كان بالكود القديم (Text عادي بلا
      // textDirection صريح، يتّبع المحيط فقط لحلّ .end/.start).
      testWidgets('end + محيط ltr + محتوى عربي RTL => يبقى "يمين" (كما كان)', (tester) async {
        await tester.pumpWidget(_wrap(
          const BidiText('مكتمل', textAlign: TextAlign.end),
          TextDirection.ltr,
        ));
        final text = _innerText(tester);
        expect(text.textDirection, TextDirection.rtl); // شكل الحروف عربي فعلاً
        expect(text.textAlign, TextAlign.right); // لكن المحاذاة = end المحيط (ltr) = يمين، بلا تغيير
      });

      testWidgets('end + محيط rtl + محتوى إنجليزي LTR => يبقى "يسار" (كما كان)', (tester) async {
        await tester.pumpWidget(_wrap(
          const BidiText('Amman', textAlign: TextAlign.end),
          TextDirection.rtl,
        ));
        final text = _innerText(tester);
        expect(text.textDirection, TextDirection.ltr);
        expect(text.textAlign, TextAlign.left); // end المحيط (rtl) = يسار، بلا تغيير
      });

      testWidgets('start + محيط ltr => يُحلّ إلى left', (tester) async {
        await tester.pumpWidget(_wrap(
          const BidiText('مكتمل', textAlign: TextAlign.start),
          TextDirection.ltr,
        ));
        expect(_innerText(tester).textAlign, TextAlign.left);
      });

      testWidgets('start + محيط rtl => يُحلّ إلى right', (tester) async {
        await tester.pumpWidget(_wrap(
          const BidiText('OK', textAlign: TextAlign.start),
          TextDirection.rtl,
        ));
        expect(_innerText(tester).textAlign, TextAlign.right);
      });

      testWidgets('محاذاة مطلقة (center) تُمرَّر كما هي بلا أي تحويل', (tester) async {
        await tester.pumpWidget(_wrap(
          const BidiText('نص', textAlign: TextAlign.center),
          TextDirection.rtl,
        ));
        expect(_innerText(tester).textAlign, TextAlign.center);
      });

      testWidgets('بلا textAlign إطلاقاً => null (نفس افتراضي Text)', (tester) async {
        await tester.pumpWidget(_wrap(const BidiText('نص'), TextDirection.rtl));
        expect(_innerText(tester).textAlign, isNull);
      });
    },
  );

  group('BidiText — يمرّر كل معاملات Text المستخدَمة فعلياً بمواقع هذا المشروع', () {
    testWidgets('style، maxLines، overflow، softWrap تصل لـText الداخلي كما هي',
        (tester) async {
      const style = TextStyle(fontSize: 20, color: Colors.red);
      await tester.pumpWidget(_wrap(
        const BidiText(
          'نص طويل يحتاج قصّاً عند تجاوز عدد الأسطر المسموح',
          style: style,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
        TextDirection.rtl,
      ));
      final text = _innerText(tester);
      expect(text.style, style);
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.softWrap, false);
    });
  });
}
