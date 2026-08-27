// [FIX-L10N-01] يثبت السلوك المطلوب من مفتاح تبديل اللغة بشاشة الإعدادات:
// 1) الاستمرارية عبر "إعادة تشغيل" (نسخة LocaleProvider جديدة تحمّل نفس
//    التفضيل المحفوظ بـSharedPreferences، تماماً كحال إقلاع التطبيق فعلياً).
// 2) عند التبديل للإنجليزية، اتجاه الكتابة يصبح LTR تلقائياً (بلا أي
//    Directionality يدوي بعد الآن، راجع app.dart) بدون أي استثناء/فيضان
//    تخطيط (RenderFlex overflow) بشاشة الإعدادات.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/features/settings/screens/settings_screen.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';
import 'package:sallehly_app/providers/auth_provider.dart';
import 'package:sallehly_app/providers/locale_provider.dart';
import 'package:sallehly_app/providers/theme_controller.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockAppStorage extends Mock implements AppStorage {}

class MockApiClient extends Mock implements ApiClient {}

Future<void> _pumpAnimated(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('[FIX-L10N-01] LocaleProvider — استمرارية التفضيل المحفوظ', () {
    test('الافتراضي عربي قبل أي تحميل', () {
      final provider = LocaleProvider();
      expect(provider.locale, const Locale('ar'));
      expect(provider.isEnglish, isFalse);
    });

    test('setLocale(en) ثم إنشاء نسخة جديدة (محاكاة إعادة تشغيل) يحمّل en من جديد', () async {
      final first = LocaleProvider();
      await first.setLocale(LocaleProvider.englishLocale);
      expect(first.isEnglish, isTrue);

      // نسخة جديدة تماماً — لا رابط بالكائن السابق، فقط SharedPreferences
      // المشترك، تماماً كحال إعادة تشغيل التطبيق فعلياً.
      final restarted = LocaleProvider();
      await restarted.loadSaved();

      expect(restarted.locale, LocaleProvider.englishLocale);
      expect(restarted.isEnglish, isTrue);
    });

    test('العودة للعربية تُحفظ وتُحمَّل أيضاً', () async {
      final first = LocaleProvider();
      await first.setLocale(LocaleProvider.englishLocale);
      await first.setLocale(LocaleProvider.fallbackLocale);

      final restarted = LocaleProvider();
      await restarted.loadSaved();

      expect(restarted.locale, const Locale('ar'));
      expect(restarted.isEnglish, isFalse);
    });
  });

  group('[FIX-L10N-01] مفتاح اللغة بشاشة الإعدادات', () {
    late AuthProvider authProvider;
    late ThemeController themeController;
    late LocaleProvider localeProvider;

    setUp(() {
      final mockTokenStorage = MockTokenStorage();
      final mockAppStorage = MockAppStorage();
      when(() => mockTokenStorage.clearToken()).thenAnswer((_) async {});
      when(() => mockAppStorage.clear()).thenAnswer((_) async {});

      authProvider = AuthProvider(
        tokenStorage: mockTokenStorage,
        apiClient: MockApiClient(),
        appStorage: mockAppStorage,
        authApiOverride: MockAuthApi(),
      );
      themeController = ThemeController();
      localeProvider = LocaleProvider();
    });

    Widget wrap() => MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ThemeController>.value(value: themeController),
            ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: localeProvider.locale,
            home: const SettingsScreen(),
          ),
        );

    testWidgets(
      'التبديل للإنجليزية يقلب اتجاه الكتابة إلى LTR بلا أي استثناء (فيضان تخطيط)',
      (tester) async {
        // [FIX-L10N-06] الأخطاء الفعلية الثلاثة السابقة (زيادة عدد الدورات،
        // تثبيت حجم العرض، تضييق نطاق onError) لم تكن السبب الحقيقي — تحقّقنا
        // أخيراً: لا يوجد أي استثناء إطلاقاً هنا. السبب الفعلي: SettingsScreen
        // تعرض محتواها داخل ListView(children:) عادي، لكن Sliver الداخلي
        // (SliverList) يبني عناصره بتكاسل (lazily) حسب ما يظهر فعلياً بمساحة
        // العرض المرئية — تماماً كـ.builder — بغض النظر عن كون children ثابتة.
        // "اللغة" (بقسم "التطبيق" قرب أسفل الشاشة) لم تكن مبنية بعد أصلاً عند
        // فحصها مباشرة بعد أول pump، فيرجع find.text صفر عناصر بلا أي خطأ
        // إطلاقاً — ليس فيضان تخطيط ولا استثناء مبتلَع، فقط عنصر لم يُبنَ بعد
        // لأنه خارج حدود ما بُني من الـSliver. كان هذا يمرّ سابقاً بالصدفة فقط
        // (عرض الاختبار الافتراضي بفلَتّر أعرض من الهواتف الحقيقية، فالتفاف
        // النص أقل والمحتوى أقصر، فيقع "اللغة" ضمن حدود ما بُني من البداية).
        // الإصلاح الصحيح: scrollUntilVisible أولاً (يُمرِّر ويُنزِل الـSliver
        // تدريجياً حتى يُبنى العنصر فعلياً) قبل أي expect عليه — وليس بعده.
        await tester.pumpWidget(wrap());
        await _pumpAnimated(tester);

        expect(Directionality.of(tester.element(find.byType(SettingsScreen))),
            TextDirection.rtl);

        await tester.scrollUntilVisible(
          find.text('اللغة'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await _pumpAnimated(tester);
        expect(find.text('اللغة'), findsOneWidget);

        await tester.tap(find.byType(Switch).last);
        // rebuild التطبيق بأكمله (locale جديد) — نفس ما يحدث فعلياً عبر
        // MaterialApp.locale المُشتقّة من LocaleProvider في app.dart. شجرة
        // جديدة بالكامل = موضع التمرير يعود للأعلى، فنفس مشكلة البناء
        // الكسول تتكرر هنا أيضاً لنص "Language" ما لم نُمرِّر إليه مجدداً.
        await tester.pumpWidget(wrap());
        await _pumpAnimated(tester);

        expect(localeProvider.isEnglish, isTrue);
        expect(
          Directionality.of(tester.element(find.byType(SettingsScreen))),
          TextDirection.ltr,
          reason:
              'بلا أي Directionality يدوي بعد الآن، الاتجاه يجب أن يُشتقّ '
              'تلقائياً من locale الجديدة عبر MaterialApp/Localizations نفسها.',
        );

        await tester.scrollUntilVisible(
          find.text('Language'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await _pumpAnimated(tester);
        expect(find.text('Language'), findsOneWidget);

        // لا استثناء غير مُلتقَط (يشمل أخطاء RenderFlex overflow) بعد التبديل.
        expect(tester.takeException(), isNull);
      },
    );
  });
}
