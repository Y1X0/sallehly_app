// أداة CI لالتقاط لقطة PNG فعلية لكل حالة بجدول l10n_screen_smoke_test.dart
// (نفس الجدول المشترك test/support/l10n_screen_cases.dart) — الهدف: فحص
// بصري حقيقي (مقاسات نص، اتجاه RTL/LTR، أيقونات) بدل الاكتفاء بـ"لا استثناء"
// فقط، دون توفّر جهاز/محاكي محلي بهذه البيئة.
//
// خط حقيقي (لا خط الاختبار الافتراضي بفلَتّر، ذو حروف مربّعة بعرض ثابت يوسّع
// النص العربي بشكل غير واقعي — انظر تحقيق بطاقة الهيرو بـL10N_PROGRESS.md)
// يُحمَّل هنا بنفس الأسلوب: خطوط Noto حقيقية (عربي + لاتيني) تُثبَّت عبر apt
// بخطوة CI منفصلة (ليست أصلاً بالمشروع)، تُقرَأ من القرص، وتُسجَّل تحت اسم
// العائلة 'Roboto' — وهو ما تفترضه Typography الافتراضية بفلَتّر ضمنياً حين
// ThemeData.fontFamily == null (حال AppTheme فعلياً).
//
// كل لقطة تُلتقَط بغضّ النظر عن وجود RenderFlex overflow معروف مسبقاً (نفس
// الحالات المحجوبة بفحص الدخان) — الفيضان يظهر بصرياً بنفسه بمؤشر فلَتّر
// المعتاد (خطوط صفراء/سوداء مائلة)، وهذا مفيد للمراجعة البصرية لا ضار بها.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/l10n_screen_cases.dart';

/// مسارات خطوط حقيقية (عربي + لاتيني) مفصولة بـ":" عبر متغيّر بيئة من خطوة
/// تثبيت الخطوط بـCI — لا كأصل بالمشروع ولا كتعديل بـpubspec.yaml.
Future<void> _loadRealFonts() async {
  final raw = Platform.environment['REAL_FONT_PATHS'] ?? '';
  final paths = raw.split(':').where((p) => p.trim().isNotEmpty).toList();
  if (paths.isEmpty) {
    throw StateError(
      'REAL_FONT_PATHS فارغ — راجع خطوة تثبيت الخطوط بـCI. بدون خط حقيقي، '
      'اللقطات ستكون بخط الاختبار الوهمي ولن تعكس التخطيط الفعلي.',
    );
  }

  final loader = FontLoader('Roboto');
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('خط غير موجود بالمسار $path.');
    }
    final bytes = await file.readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    // ignore: avoid_print
    print('[SCREENSHOT] خط محمَّل: $path (${bytes.length} بايت).');
  }
  await loader.load();
}

Future<void> _captureScreenshot(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String outputPath,
) async {
  await tester.runAsync(() async {
    final renderObject = boundaryKey.currentContext!.findRenderObject();
    final boundary = renderObject! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  });
}

void main() {
  setUpAll(_loadRealFonts);

  final outDir = Platform.environment['SCREENSHOT_OUT_DIR'] ?? 'build/l10n_screenshots';

  for (final screenCase in screenCases) {
    for (final locale in testLocales) {
      for (final viewport in testViewports) {
        testWidgets(
          '[SCREENSHOT] ${screenCase.name} — locale=${locale.languageCode} — ${viewport.label}',
          (tester) async {
            tester.view.physicalSize = viewport.size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final providers = TestProviders();
            final boundaryKey = GlobalKey();

            await tester.pumpWidget(
              RepaintBoundary(
                key: boundaryKey,
                child: wrapScreen(screenCase.build(), providers, locale),
              ),
            );
            await pumpAnimated(tester);

            // مهمة هذا الاختبار التقاط لقطة فقط، لا فحص تخطيط — استنزف أي
            // استثناء معروف (فيضان RenderFlex محجوب أصلاً بفحص الدخان) حتى
            // لا يفشل هذا الاختبار بسببه ويمنع التقاط بقية اللقطات.
            tester.takeException();

            final filename =
                '${screenCase.slug}__${locale.languageCode}__${viewport.slug}.png';
            await _captureScreenshot(tester, boundaryKey, '$outDir/$filename');
          },
        );
      }
    }
  }
}
