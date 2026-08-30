// [FIX-DEEPLINK-02] عند وصول إشعار والتطبيق مفتوح (foreground)، الإشعار
// المعروض هو محلي دوماً (flutter_local_notifications عبر
// _showLocalNotificationStatic)، وليس عرض FCM التلقائي — فالضغط عليه يمرّ
// حصراً عبر onDidReceiveNotificationResponse، وليس
// FirebaseMessaging.onMessageOpenedApp (المخصَّص فقط لحالتَي الخلفية/الإغلاق
// الكامل، وله مسار تنقّل منفصل تم إصلاحه سابقاً بـ[FIX-DEEPLINK-01]).
// onDidReceiveNotificationResponse كان بلا أي تأثير فعلي — الضغط على إشعار
// وصل والتطبيق شغّال لا يوصّل المستخدم لأي مكان إطلاقاً. هذا الاختبار يغطي
// الجزأين اللذين تغيّرا فعلياً:
// ١) صيغة الحمولة: كانت النوع (type) فقط، أصبحت JSON كاملاً (يشمل
//    requestId/ticketId) — يثبت أن الترميز/فك الترميز يحافظان على كل الحقول.
// ٢) بمجرد وصول الحمولة المفكوكة، الدالة الحقيقية
//    FirebaseNotificationService.handleNotificationTap (كانت _handleNotificationTap،
//    راجع [TEST-FIX-NOTIFTAP-01] بـDECISIONS.md — رُفعت لـ@visibleForTesting
//    بلا underscore لتمكين هذا الاستدعاء المباشر، لا مجرد محاكاة منفصلة
//    لمنطقها) تُستدعى فعلياً، ثم يعيد هذا الاختبار إنتاج نفس منطق التوجيه
//    بـcustomer_layout.dart (تبديل لتبويب الدردشات لنوع "chat") ليثبت أن
//    القيمة الناتجة عن الدالة الحقيقية (لا نسخة مُعاد كتابتها) تُفهَم بشكل
//    صحيح. **حدود هذا الاختبار**: يثبت أن دالة معالجة الضغط الحقيقية تعمل
//    صحيحاً بمعزل، لا أن onDidReceiveNotificationResponse الفعلية
//    بـ_initLocalNotifications تستدعيها فعلاً عند ضغطة حقيقية — ذلك يتطلَّب
//    Firebase.initializeApp() كاملة (غير مُتاحة ببيئة flutter_test)، خارج
//    نطاق هذا الاختبار عمداً.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/core/notifications/firebase_notification_service.dart';

/// نسخة مصغَّرة من منطق _handleDeepLink بـcustomer_layout.dart — فقط الجزء
/// الخاص بنوع "chat" (المسار الذي كان الإصلاح يستهدفه)، لإثبات أن القيمة
/// الناتجة فعلياً من الدالة الحقيقية handleNotificationTap تُوجَّه بشكل صحيح.
class _DeepLinkRoutingHarness extends StatefulWidget {
  const _DeepLinkRoutingHarness();

  @override
  State<_DeepLinkRoutingHarness> createState() => _DeepLinkRoutingHarnessState();
}

class _DeepLinkRoutingHarnessState extends State<_DeepLinkRoutingHarness> {
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    FirebaseNotificationService.pendingDeepLink.addListener(_handleDeepLink);
  }

  @override
  void dispose() {
    FirebaseNotificationService.pendingDeepLink.removeListener(_handleDeepLink);
    super.dispose();
  }

  void _handleDeepLink() {
    final data = FirebaseNotificationService.pendingDeepLink.value;
    if (data == null || !mounted) return;
    final type = data['type']?.toString() ?? '';
    switch (type) {
      case 'chat':
        setState(() => currentIndex = 2);
        break;
      default:
        break;
    }
    FirebaseNotificationService.pendingDeepLink.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('tab:$currentIndex')));
  }
}

void main() {
  tearDown(() {
    FirebaseNotificationService.pendingDeepLink.value = null;
  });

  test('[FIX-DEEPLINK-02] ترميز/فك ترميز حمولة الإشعار المحلي يحافظ على كل الحقول', () {
    final original = {'type': 'chat', 'requestId': '42'};

    // بالضبط كما يفعل _showLocalNotificationStatic الآن.
    final payload = jsonEncode(original);

    // بالضبط كما يفعل onDidReceiveNotificationResponse الآن.
    final decoded = Map<String, dynamic>.from(jsonDecode(payload) as Map);

    expect(decoded, equals(original));
    expect(decoded['requestId'], '42');
  });

  testWidgets(
    '[FIX-DEEPLINK-02] إشعار محلي مضغوط عليه (foreground) يوصّل لتبويب الدردشات الصحيح',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _DeepLinkRoutingHarness()));
      await tester.pump();

      expect(find.text('tab:0'), findsOneWidget);

      // محاكاة الحمولة الكاملة كما تصل فعلياً بعد جولة الترميز/فك الترميز
      // (وليس Map مكتوبة يدوياً بلا علاقة بالتنفيذ الفعلي).
      final rawData = {'type': 'chat', 'requestId': '42'};
      final decoded = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(rawData)) as Map,
      );

      // [TEST-FIX-NOTIFTAP-01] الدالة الحقيقية بالضبط — لا محاكاة منفصلة
      // لمنطقها، ولا تعيين pendingDeepLink.value يدوياً.
      FirebaseNotificationService.handleNotificationTap(decoded);
      await tester.pump();

      expect(find.text('tab:2'), findsOneWidget);
      expect(FirebaseNotificationService.pendingDeepLink.value, isNull);
    },
  );

  test(
    '[TEST-FIX-NOTIFTAP-01] handleNotificationTap بحمولة بلا type (أو type فارغ): لا تُنشر أي قيمة',
    () {
      FirebaseNotificationService.handleNotificationTap({'requestId': '42'});
      expect(FirebaseNotificationService.pendingDeepLink.value, isNull);

      FirebaseNotificationService.handleNotificationTap({'type': ''});
      expect(FirebaseNotificationService.pendingDeepLink.value, isNull);
    },
  );

  test(
    '[TEST-FIX-NOTIFTAP-01] handleNotificationTap بحمولة صحيحة: تنشر نسخة كاملة من البيانات (لا مرجعاً للـMap الأصلية)',
    () {
      final original = {'type': 'chat', 'requestId': '99'};
      FirebaseNotificationService.handleNotificationTap(original);

      final published = FirebaseNotificationService.pendingDeepLink.value;
      expect(published, equals(original));

      // [Map.from] نسخة جديدة — تعديل الأصل بعد الاستدعاء لا يغيّر المنشور.
      original['requestId'] = '000';
      expect(published!['requestId'], '99');
    },
  );
}
