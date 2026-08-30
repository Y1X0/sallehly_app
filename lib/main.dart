import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/notifications/firebase_notification_service.dart';
import 'firebase_options.dart';

// [FIX-CRASHREPORT-01] راجع DECISIONS.md — قبل هذا الإصلاح لم يكن هناك أي
// تقرير أعطال إطلاقاً: لا runZonedGuarded، لا FlutterError.onError، لا
// PlatformDispatcher.instance.onError، ولا أي تبعية Crashlytics/Sentry
// بـpubspec.yaml. أي خطأ غير مُتوقَّع بيد مستخدم حقيقي كان بلا أي أثر يصل
// لفريق التطوير — كل خطأ اكتُشف بهذا المشروع حتى الآن جاء من قراءة الكود،
// لا من أي إشارة فعلية. Firebase مُهيَّأ أصلاً بهذا التطبيق (firebase_messaging)،
// فـCrashlytics إعادة استخدام لنفس البنية التحتية، لا مشروعاً جديداً.
void main() {
  runZonedGuarded<void>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // محاولة تهيئة Firebase — إذا لم يكن مهيّأً بعد (مثلاً لا يوجد google-services.json
    // مطابق) يتجاوز التطبيق الإشعارات وتقرير الأعطال ويكمل العمل بشكل طبيعي بدل أن يتعطل.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseNotificationService.init();

      // لا تُسجَّل أعطال التطوير المحلي بلوحة Crashlytics — تُغرق إشارة
      // الأعطال الحقيقية من مستخدمين فعليين بضجيج غير ذي قيمة.
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

      // أخطاء إطار Flutter نفسه (استثناء بـbuild()، مثلاً) — كل تفاصيلها
      // (بما فيها الـstack trace الكامل) تُرفَع لـCrashlytics.
      FlutterError.onError = (FlutterErrorDetails details) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        if (kDebugMode) FlutterError.presentError(details);
      };

      // أخطاء غير متزامنة تصل خارج شجرة ودجت Flutter تماماً (مثال: Future
      // غير مُنتظَر برمي استثناءً، أو أي كود Dart خام آخر) — الشبكة الأخيرة
      // على مستوى isolate بأكمله. `true` تمنع الإطار الافتراضي من طباعتها
      // للـconsole فقط (لا تكتم التطبيق ولا تُسقطه)؛ نطبعها بأنفسنا بوضع
      // التطوير أدناه.
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        if (kDebugMode) debugPrint('[CRASH] PlatformDispatcher error: $error\n$stack');
        return true;
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[Firebase] disabled — skipped init: $e');
    }

    runApp(
      const SallehlyApp(),
    );
  }, (Object error, StackTrace stack) {
    // شبكة أمان أخيرة: أي استثناء يهرب حتى من PlatformDispatcher.onError
    // أعلاه (مثلاً لو حدث قبل أن تتم تهيئة Firebase أصلاً). محاولة الرفع هنا
    // محمية بـtry/catch صريح — Crashlytics نفسه قد لا يكون مُهيَّأً بعد بهذه
    // النقطة المبكرة جداً.
    if (kDebugMode) debugPrint('[CRASH] uncaught zone error: $error\n$stack');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
  });
}
