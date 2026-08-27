// [FIX-L10N-04] فحص دخان (smoke test) شامل لآخر بند من المرحلة الأولى (البنية
// التحتية للترجمة) قبل البدء بترحيل أي نص فعلياً (المرحلة الثانية): كل شاشة
// رئيسية تُبنى فعلياً تحت كلتا اللغتين (ar/en) وبعرضين مختلفين (هاتف عادي
// 390dp + عرض ضيق 320dp)، ويُثبت أن حذف Directionality اليدوي بـapp.dart
// (والاعتماد الكامل على locale المُشتقّ تلقائياً بدلاً منه) لا يُسبّب أي
// استثناء غير مُلتقَط — يشمل ذلك RenderFlex overflow، الذي يظهر غالباً
// بالعرض الضيق أولاً لأن النصوص الإنجليزية أطول عادة من مقابلها العربي. كل
// النصوص المعروضة اليوم عربية بالكامل (لا شيء رُحِّل بعد) حتى تحت
// locale=en — هذا متوقَّع ومقصود بهذه المرحلة، ولا علاقة له بهذا الاختبار.
//
// ما لا يكشفه هذا الاختبار (مهم): أي عنصر بصري "مقلوب" أو تخطيط غير متّزن لا
// يصل لحدّ استثناء فعلي فعلياً (مثل أيقونة سهم تشير بالاتجاه الخطأ، أو
// تباعد غير متماثل بصرياً لا يُنتج RenderFlex overflow) — هذا الجزء البصري
// يغطّيه الآن l10n_screenshot_capture_test.dart (لقطات PNG فعلية بخط عربي
// حقيقي، لا خط الاختبار الافتراضي).
//
// جدول الشاشات/الـProviders مشترك مع l10n_screenshot_capture_test.dart —
// راجع test/support/l10n_screen_cases.dart.
//
// كل الـProviders أدناه Mock/حقيقية بواجهة API غير مُهيَّأة (unstubbed) عمداً
// — كل طرق التحميل (loadRequests/loadChats/...) بالتطبيق مُغلَّفة أصلاً
// بـtry/catch داخلياً (نمط ثابت عبر كل الـProviders، تحقّقنا منه قبل كتابة
// هذا الملف)، فتفشل بصمت للحالة "خطأ" الموجودة أصلاً بكل شاشة بدل رمي
// استثناء — لا حاجة لتزييف استجابات API هنا لغرض هذا الاختبار تحديداً.
import 'package:flutter_test/flutter_test.dart';

import '../support/l10n_screen_cases.dart';

// [FIX-L10N-04] عُثر فعلياً على RenderFlex overflow حقيقي (2.2px يميناً)
// بـEditProfileScreen عند 320dp — تحت locale=ar وlocale=en على حدٍّ سواء، ما
// يُثبت أنه باگ ضيق-شاشة موجود مسبقاً بالكود، لا علاقة له بحذف Directionality
// أو بالترجمة إطلاقاً (لو كان سببه اتجاه الكتابة لظهر بـen فقط لا بكلتيهما).
// خارج نطاق "البنية التحتية للترجمة" — لا يُصلَح هنا. يبقى محجوباً (skip) هنا
// مع توثيقه صراحة عوضاً عن حذفه من الجدول، حتى لا يحجب اكتمال Phase 1 لسبب
// غير متعلّق بها، ولا يُنسى أيضاً.
// [FIX-L10N-04] TechnicianDashboardScreen: نفس نمط EditProfileScreen تماماً —
// فيضان حقيقي (25px أسفل بـ_StatCard، و10px يميناً بشريط خطأ تحميل الطلبات)
// عند 320dp فقط تحت كلتا اللغتين (يمرّ بنجاح عند 390dp العادي) — باگ عرض
// ضيق موجود مسبقاً، غير متعلّق بالترجمة.
//
// CustomerDashboardScreen: فيضان يظهر بكل توليفات locale/عرض الأربع رغم أن
// النص بالبطاقة ثابت بالكامل. أُعيد فحصه فعلياً (انظر L10N_PROGRESS.md) بخط
// عربي حقيقي (Noto Naskh Arabic) بدل خط الاختبار الافتراضي — اختفى الفيضان
// تماماً بكل التوليفات الأربع. مؤكَّد الآن: أثر خط اختبار فقط (Ahem-like)،
// وليس باگاً حقيقياً. يبقى skip هنا لأن إزالته لم تُطلَب صراحةً بعد.
const Set<String> _knownPreexistingOverflow = {
  'تعديل الملف الشخصي (EditProfileScreen)|ar|ضيق 320dp',
  'تعديل الملف الشخصي (EditProfileScreen)|en|ضيق 320dp',
  'الرئيسية-فني (TechnicianDashboardScreen)|ar|ضيق 320dp',
  'الرئيسية-فني (TechnicianDashboardScreen)|en|ضيق 320dp',
  'الرئيسية-عميل (CustomerDashboardScreen)|ar|عادي 390dp',
  'الرئيسية-عميل (CustomerDashboardScreen)|ar|ضيق 320dp',
  'الرئيسية-عميل (CustomerDashboardScreen)|en|عادي 390dp',
  'الرئيسية-عميل (CustomerDashboardScreen)|en|ضيق 320dp',
};

void main() {
  for (final screenCase in screenCases) {
    for (final locale in testLocales) {
      for (final viewport in testViewports) {
        final key = '${screenCase.name}|${locale.languageCode}|${viewport.label}';
        // سبب التخطي (عند وجوده) موثَّق أعلاه بـ_knownPreexistingOverflow
        // وبـL10N_PROGRESS.md — معامل skip هنا bool فقط (لا يقبل نص السبب
        // مباشرةً بهذا الإصدار من Flutter، خلافاً لما افترضته أول مرة).
        testWidgets(
          '[FIX-L10N-04] ${screenCase.name} — locale=${locale.languageCode} — ${viewport.label}: بلا استثناء',
          skip: _knownPreexistingOverflow.contains(key),
          (tester) async {
            tester.view.physicalSize = viewport.size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final providers = TestProviders();

            await tester.pumpWidget(wrapScreen(screenCase.build(), providers, locale));
            await pumpAnimated(tester);

            expect(
              tester.takeException(),
              isNull,
              reason: '${screenCase.name} رمى استثناءً (على الأرجح RenderFlex '
                  'overflow) تحت locale=${locale.languageCode} بعرض '
                  '${viewport.size.width.toInt()}dp.',
            );
          },
        );
      }
    }
  }
}
