// [SEC-FIX-BGHANDLERCATCH-01] راجع DECISIONS.md — يثبت أن firebaseBackgroundHandler
// لا يرمي استثناءً للخارج حتى لو فشل عرض الإشعار المحلي فعلياً. هذا isolate
// يعمل خارج runZonedGuarded/FlutterError.onError (المُضافة بـFIX-CRASHREPORT-01
// بـmain() فقط) — استثناء غير مُلتقَط هنا يفشل بصمت تام، بلا أي تقرير عطل.
//
// بيئة flutter test لا تحمل قناة منصّة أصلية لـflutter_local_notifications
// (بلا محاكاة) — استدعاء _localNotifications.show() داخلياً يفشل حتماً
// (MissingPluginException)، وهذا بالضبط ما يثبته الاختبار الأول: الفشل الآن
// يُبتلَع بدل أن يرمى للخارج.
//
// [TEST-FIX-NOTIFSHOW-01] راجع DECISIONS.md — الاختبار الثاني يثبت ادّعاءً
// أدقّ لا يثبته الاختبار الأول: ليس فقط "لا يرمي استثناءً"، بل "يستدعي
// show() فعلاً بالعنوان/النص/الحمولة الصحيحة المُستخرَجة من رسالة FCM
// الواردة". هذا يتطلَّب أن ينجح استدعاء show() فعلياً (لا أن يفشل بصمت كما
// بالاختبار الأول) — عبر تسجيل AndroidFlutterLocalNotificationsPlugin
// الحقيقية (لا مزيَّفة يدوياً) كمنفِّذ المنصّة، وuseDefaultTargetPlatformOverride
// = android (استعلام resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
// الداخلي يتحقق من كليهما معاً)، ثم محاكاة القناة الأصلية نفسها
// (dexterous.com/flutter/local_notifications، مصدرها الحقيقي بالحزمة —
// راجعناه مباشرة لا خمّناه) لالتقاط استدعاء 'show' الفعلي والتحقق من
// معاملاته، بدل مجرد قبول أن الاستدعاء "لا يرمي".
//
// **حدود هذين الاختبارين معاً — ما لا يثبتانه**: أن الإشعار وصل فعلياً من
// خوادم Google، أو أن Google Play Services على الجهاز عالجه، أو أن نظام
// أندرويد نفسه عرضه على الشاشة فعلياً، أو أن الضغط عليه فتح التطبيق حقاً.
// السلسلة من استلام الرسالة الفعلي وحتى ظهورها على الشاشة تمر بكود
// Java/Kotlin أصلي للحزمة نفسها خارج أي قناة تختبرها بيئة flutter test —
// هذا الجزء يحتاج فحصاً يدوياً حقيقياً على جهاز فعلي (راجع وصف الفحص
// المطلوب بمحادثة هذا التغيير)، ولا بديل برمجي كامل عنه بمعزل عن هذا
// المشروع بالذات.
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/core/notifications/firebase_notification_service.dart';

const _localNotificationsChannel =
    MethodChannel('dexterous.com/flutter/local_notifications');

// [ملاحظة تقنية] debugDefaultTargetPlatformOverride متغيّر تصحيح على
// مستوى foundation — إطار flutter_test يتحقق أنه يعود null بعد كل
// اختبار عبر _verifyInvariants، الذي يُنفَّذ **داخل** استدعاء testWidgets
// نفسه (قبل أن يصل الدور لأي tearDown مسجَّل خارجياً بمستوى group/main).
// لذلك، بعكس ما قد يبدو طبيعياً، الضبط والاستعادة يجب أن يكونا داخل كل
// اختبار مباشرة (try/finally)، لا بـsetUp/tearDown منفصلين.
Future<List<MethodCall>> runWithMockedAndroidChannel(
  Future<void> Function() body,
) async {
  final calls = <MethodCall>[];
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_localNotificationsChannel, (call) async {
    calls.add(call);
    return null;
  });
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localNotificationsChannel, null);
  }
  return calls;
}

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

  group('[DEFERRED-AUDIT-10] معرِّف الإشعار المحلي: عشوائي بدل طابع زمني '
      'بدقة الثانية', () {
    testWidgets(
      'إشعارات متعددة خلال نفس اللحظة تحصل على معرِّفات مختلفة، وكلها ضمن '
      'حدود 32-bit صحيحة دائماً (لا علاقة بالوقت — لا خطر تجاوز عام 2038)',
      (tester) async {
        const message = RemoteMessage(data: {'type': 'chat'});

        final calls = await runWithMockedAndroidChannel(() async {
          for (var i = 0; i < 20; i++) {
            await firebaseBackgroundHandler(message);
          }
        });

        final showCalls = calls.where((c) => c.method == 'show').toList();
        expect(showCalls, hasLength(20));

        final ids = showCalls
            .map((c) => (c.arguments as Map)['id'] as int)
            .toList();

        for (final id in ids) {
          expect(id, greaterThanOrEqualTo(0));
          expect(id, lessThanOrEqualTo(0x7FFFFFFF));
        }

        // العشرون استدعاءً وقعت عملياً بنفس اللحظة تقريباً (تنفيذ الحلقة
        // الكاملة يستغرق أجزاءً من الثانية) — بلا أي معرِّفَين متطابقَين.
        expect(ids.toSet(), hasLength(20));
      },
    );
  });

  group('[TEST-FIX-NOTIFSHOW-01] show() يُستدعى بالمعاملات الصحيحة عند وصول رسالة', () {
    testWidgets(
      'رسالة FCM (بيانات فقط، بلا notification) بالخلفية: show() تستقبل العنوان/النص/الحمولة الصحيحة',
      (tester) async {
        const message = RemoteMessage(
          data: {
            'title': 'رسالة جديدة من العميل',
            'body': 'أهلاً، متى تصل؟',
            'type': 'chat',
            'requestId': '55',
          },
        );

        final calls = await runWithMockedAndroidChannel(
          () => firebaseBackgroundHandler(message),
        );

        final showCalls = calls.where((c) => c.method == 'show').toList();
        expect(showCalls, hasLength(1));

        final args = Map<String, dynamic>.from(showCalls.single.arguments as Map);
        expect(args['title'], 'رسالة جديدة من العميل');
        expect(args['body'], 'أهلاً، متى تصل؟');

        final payload = Map<String, dynamic>.from(
          jsonDecode(args['payload'] as String) as Map,
        );
        expect(payload['type'], 'chat');
        expect(payload['requestId'], '55');
      },
    );

    testWidgets(
      'رسالة FCM بلا title/body بالحمولة (حالة احتياطية): عنوان/نص افتراضيان، بلا فشل',
      (tester) async {
        const message = RemoteMessage(data: {'type': 'chat'});

        final calls = await runWithMockedAndroidChannel(
          () => firebaseBackgroundHandler(message),
        );

        final showCalls = calls.where((c) => c.method == 'show').toList();
        expect(showCalls, hasLength(1));
        final args = Map<String, dynamic>.from(showCalls.single.arguments as Map);
        // القيم الافتراضية المعرَّفة بـ_showLocalNotificationStatic بالضبط.
        expect(args['title'], 'صلّحلي');
        expect(args['body'], 'لديك إشعار جديد');
      },
    );
  });
}
