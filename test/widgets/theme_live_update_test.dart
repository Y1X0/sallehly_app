// [FIX-THEME-01] تبديل الوضع الفاتح/الداكن من الإعدادات كان لا يُطبَّق فعلياً
// على أي تبويب زُيِّر سابقاً إلا بعد إعادة تشغيل التطبيق بالكامل. السبب:
// شاشات التبويبات بـ customer/technician/admin _layout.dart كانت مُخزَّنة
// بحقل `late final List<Widget> pages = const [...]` — نفس مرجع الـWidget
// (identical) يُعاد تمريره لـIndexedStack بكل build() لاحق، فيتجاهل Flutter
// إعادة بناء تلك الشاشات كلياً حتى لو تغيّرت ThemeController (لأنها لا تراقبها
// أصلاً)، رغم أن الجذر (_SocketBootstrapperState بـapp.dart) يُعيد بناء
// MaterialApp نفسه بشكل صحيح. هذا الاختبار يحاكي نفس البنية بالضبط (Provider
// لـThemeController + IndexedStack + صفحة تقرأ AppColors مباشرة كحقل ساكن)
// ويثبت الفرق: قائمة صفحات مُخزَّنة (const/late final) لا تتحدّث لحظياً،
// بينما قائمة تُبنى من جديد بكل build() (الحل المُطبَّق فعلياً) تتحدّث فوراً
// بدون أي إعادة تشغيل ولا فقدان لحالة الشاشة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sallehly_app/core/theme/app_colors.dart';
import 'package:sallehly_app/providers/theme_controller.dart';

/// نسخة مصغَّرة تماماً من بنية _CustomerLayoutState الفعلية — تبويب واحد
/// فقط يُبقيه IndexedStack حياً، يعرض لون AppColors.textPrimary مباشرة
/// (بلا أي Provider.watch لـThemeController داخل الصفحة نفسها — تماماً كحال
/// الشاشات الحقيقية اليوم).
class _StaleHarness extends StatefulWidget {
  const _StaleHarness();
  @override
  State<_StaleHarness> createState() => _StaleHarnessState();
}

class _StaleHarnessState extends State<_StaleHarness> {
  // إعادة إنتاج العلّة بالضبط: قائمة مُخزَّنة مرة واحدة فقط.
  late final List<Widget> pages = const [_ColorProbe()];

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>(); // نفس مراقبة _SocketBootstrapperState
    return IndexedStack(index: 0, children: pages);
  }
}

/// النسخة المُصلَحة — نفس الشيء لكن بدون تخزين const/late final.
class _FixedHarness extends StatefulWidget {
  const _FixedHarness();
  @override
  State<_FixedHarness> createState() => _FixedHarnessState();
}

class _FixedHarnessState extends State<_FixedHarness> {
  // بلا const هنا عمداً — مرجع Widget جديد بكل استدعاء، تماماً كالإصلاح
  // الفعلي بـ customer_layout.dart/technician_layout.dart/admin_layout.dart.
  List<Widget> get pages => [_ColorProbe()];

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    return IndexedStack(index: 0, children: pages);
  }
}

class _ColorProbe extends StatelessWidget {
  const _ColorProbe();
  @override
  Widget build(BuildContext context) {
    return Text('probe', style: TextStyle(color: AppColors.textPrimary));
  }
}

Color _probeColor(WidgetTester tester) {
  final text = tester.widget<Text>(find.text('probe'));
  return text.style!.color!;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.applyDark();
  });

  testWidgets(
    '[FIX-THEME-01] قبل الإصلاح: pages مُخزَّنة (const) لا تعكس تبديل الثيم بدون إعادة إنشاء',
    (tester) async {
      final controller = ThemeController();
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeController>.value(
          value: controller,
          child: const MaterialApp(home: _StaleHarness()),
        ),
      );

      final darkColor = _probeColor(tester);

      await controller.setLight(true);
      await tester.pump();

      expect(
        _probeColor(tester),
        darkColor,
        reason: 'هذا بالضبط الخلل المُبلَّغ عنه: اللون القديم يبقى ظاهراً '
            'رغم استدعاء setLight(true) بنجاح، لأن IndexedStack لم يُعِد '
            'بناء الصفحة (نفس مرجع الـWidget المُخزَّن).',
      );
    },
  );

  testWidgets(
    '[FIX-THEME-01] بعد الإصلاح: pages جديدة بكل build() تعكس تبديل الثيم فوراً',
    (tester) async {
      final controller = ThemeController();
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeController>.value(
          value: controller,
          child: const MaterialApp(home: _FixedHarness()),
        ),
      );

      final darkColor = _probeColor(tester);

      await controller.setLight(true);
      await tester.pump();

      expect(
        _probeColor(tester),
        isNot(darkColor),
        reason: 'بعد الإصلاح، يجب أن يتحدّث اللون فوراً بنفس الجلسة بدون '
            'الحاجة لإعادة تشغيل التطبيق أو إعادة بناء الشاشة يدوياً.',
      );
      expect(_probeColor(tester), AppColors.textPrimary);
    },
  );
}
