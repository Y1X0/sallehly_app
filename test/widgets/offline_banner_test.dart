import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// إعادة إنتاج مبسّطة لبطاقة `_OfflineBanner` من lib/app.dart (نفس القياسات:
/// margin 8، padding رأسي 12، أيقونة+نص) لاختبار سلوك الإخفاء دون الحاجة
/// لتشغيل التطبيق كاملاً (الودجت الأصلية خاصة private بالملف).
Widget _bannerCard() {
  return Material(
    color: Colors.transparent,
    child: SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'الخادم يستغرق وقتاً أطول من المعتاد للرد، يرجى الانتظار',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  // ارتفاع شريط حالة نموذجي على هاتف حديث (يطابق ما يظهر في لقطة الشاشة).
  const statusBarHeight = 44.0;

  testWidgets(
    '[FIX-BANNER-01] القديم: إزاحة top:-80 الثابتة تترك شريطاً أحمر ظاهراً '
    'أعلى الشاشة حتى في حالة "مخفي"',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: statusBarHeight),
          ),
          child: MaterialApp(
            home: Stack(
              children: [
                Positioned(
                  top: -80, // الرقم السحري القديم في الكود قبل الإصلاح
                  left: 0,
                  right: 0,
                  child: _bannerCard(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final bottomEdge = tester.getBottomLeft(find.byType(Container)).dy;

      // إثبات وجود العلة: الحافة السفلية للبطاقة لا تزال داخل الشاشة (> 0)
      // رغم أن الحالة يفترض أن تكون "مخفية بالكامل".
      expect(
        bottomEdge,
        greaterThan(0),
        reason:
            'يوثّق العلة الأصلية: الإزاحة الثابتة -80 غير كافية لإخفاء '
            'البطاقة بالكامل، فيبقى جزء أحمر ظاهراً أعلى الشاشة.',
      );
    },
  );

  testWidgets(
    '[FIX-BANNER-01] الجديد: AnimatedSlide بإزاحة -1 (100% من الارتفاع) '
    'يخفي البطاقة بالكامل دائماً بغض النظر عن ارتفاعها الفعلي',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: statusBarHeight),
          ),
          child: MaterialApp(
            home: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    duration: Duration.zero,
                    offset: const Offset(0, -1), // مخفي
                    child: _bannerCard(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final bottomEdge = tester.getBottomLeft(find.byType(Container)).dy;

      expect(
        bottomEdge,
        lessThanOrEqualTo(0),
        reason: 'يجب أن تختفي البطاقة بالكامل خارج حدود الشاشة عند الإخفاء.',
      );
    },
  );

  testWidgets(
    '[FIX-BANNER-01] الجديد: offset صفر يُظهر البطاقة كاملة عند الحاجة',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: statusBarHeight),
          ),
          child: MaterialApp(
            home: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    duration: Duration.zero,
                    offset: Offset.zero, // ظاهر
                    child: _bannerCard(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Container), findsOneWidget);
      final topEdge = tester.getTopLeft(find.byType(Container)).dy;
      expect(topEdge, greaterThanOrEqualTo(0));
    },
  );
}
