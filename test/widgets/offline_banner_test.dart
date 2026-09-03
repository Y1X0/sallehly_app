// [FIX-BANNER-01] كان `_OfflineBanner` (lib/app.dart) يُخفى بإزاحة ثابتة
// (top: -80) أصغر من ارتفاعها الفعلي المتغيّر (حسب شريط الحالة/حجم الخط لكل
// جهاز)، فيبقى جزء منها ظاهراً دائماً كخط أحمر رفيع أعلى الشاشة حتى في حالة
// "مخفي". الحل: AnimatedSlide بإزاحة -1 (100% من الارتفاع الفعلي) يخفيها
// بالكامل مهما كان ارتفاعها.
//
// [TEST-FIX-NAVBADGE-01] راجع DECISIONS.md — كان هذا الاختبار يعيد إنتاج
// بطاقة البانر يدوياً بملف منفصل (لون خاطئ لا يطابق حتى AppColors.danger
// الحقيقي بأي من الوضعين الفاتح/الداكن، بلا ConnectivityProvider إطلاقاً،
// بلا فرع offline/serverSlow) — لا يفشل أبداً لو انكسرت البنية الفعلية أو
// منطق اختيار الرسالة/الأيقونة بـapp.dart. الآن `OfflineBanner` (كانت
// `_OfflineBanner`) رُفعت للرؤية العامة — الاختبار يبني الودجت الحقيقية
// كاملة، ويقود حالتها عبر ConnectivityProvider حقيقي (لا محاكاة للحالة عبر
// Positioned/AnimatedSlide مستقلَّين بالاختبار).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/app.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';
import 'package:sallehly_app/providers/connectivity_provider.dart';

void main() {
  Future<AnimatedSlide> pumpBanner(
    WidgetTester tester,
    ConnectivityProvider connectivity,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectivityProvider>.value(
        value: connectivity,
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Stack(children: [OfflineBanner()]),
        ),
      ),
    );
    // AnimatedSlide بمدة 300ms — البانر الحقيقي (خلافاً لنسخة الاختبار
    // القديمة) يستخدم مدة انتقال حقيقية، فلا بد من تجاوزها لقراءة الحالة
    // المستقرة النهائية.
    await tester.pumpAndSettle();
    return tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
  }

  testWidgets(
    '[FIX-BANNER-01] الحالة الطبيعية (متصل تماماً): مخفية بالكامل (offset -1)',
    (tester) async {
      final connectivity = ConnectivityProvider();
      final slide = await pumpBanner(tester, connectivity);

      expect(slide.offset, const Offset(0, -1));
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
    },
  );

  testWidgets(
    '[FIX-CONNECTIVITY-01] انقطاع فعلي (offline): ظاهرة، أيقونة wifi_off، '
    'رسالة انقطاع الإنترنت',
    (tester) async {
      final connectivity = ConnectivityProvider()..markOffline();
      final slide = await pumpBanner(tester, connectivity);

      expect(slide.offset, Offset.zero);
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    },
  );

  testWidgets(
    '[FIX-CONNECTIVITY-01] بطء الخادم (serverSlow، لا انقطاع فعلي): ظاهرة، '
    'أيقونة hourglass، رسالة بطء الخادم — لا رسالة الإنترنت المضلِّلة',
    (tester) async {
      final connectivity = ConnectivityProvider()..markServerSlow();
      final slide = await pumpBanner(tester, connectivity);

      expect(slide.offset, Offset.zero);
      expect(
        find.text('الخادم يستغرق وقتاً أطول من المعتاد للرد، يرجى الانتظار'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
    },
  );

  testWidgets(
    '[FIX-CONNECTIVITY-01] markOnline بعد انقطاع: تختفي البطاقة من جديد',
    (tester) async {
      final connectivity = ConnectivityProvider()..markOffline();
      await pumpBanner(tester, connectivity);

      connectivity.markOnline();
      await tester.pumpAndSettle();

      final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.offset, const Offset(0, -1));
    },
  );
}
