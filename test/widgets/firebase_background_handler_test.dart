// [SEC-FIX-BGHANDLERCATCH-01] راجع DECISIONS.md — يثبت أن firebaseBackgroundHandler
// لا يرمي استثناءً للخارج حتى لو فشل عرض الإشعار المحلي فعلياً. هذا isolate
// يعمل خارج runZonedGuarded/FlutterError.onError (المُضافة بـFIX-CRASHREPORT-01
// بـmain() فقط) — استثناء غير مُلتقَط هنا يفشل بصمت تام، بلا أي تقرير عطل.
//
// بيئة flutter test لا تحمل قناة منصّة أصلية لـflutter_local_notifications
// (بلا محاكاة) — استدعاء _localNotifications.show() داخلياً يفشل حتماً
// (MissingPluginException)، وهذا بالضبط ما يثبته هذا الاختبار: الفشل الآن
// يُبتلَع بدل أن يرمى للخارج.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/core/notifications/firebase_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '[SEC-FIX-BGHANDLERCATCH-01] فشل عرض إشعار الخلفية لا يرمي استثناءً للخارج',
    (tester) async {
      const message = RemoteMessage(
        data: {'title': 'عنوان تجريبي', 'body': 'نص تجريبي', 'type': 'chat'},
      );

      await expectLater(
        firebaseBackgroundHandler(message),
        completes,
      );
    },
  );
}
