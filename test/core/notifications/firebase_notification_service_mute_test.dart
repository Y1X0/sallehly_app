// [FIX-FCMFOREGROUNDMUTE-01] راجع DECISIONS.md — قبل هذا الإصلاح، رسالة شات
// وصلت عبر FCM بالمقدمة (onMessage) كانت تُظهر إشعاراً محلياً حقيقياً (صوت +
// اهتزاز) حتى لو كانت المحادثة نفسها مفتوحة فعلياً على الشاشة — مسار السوكت
// الحي (NotificationProvider.handleChatNotify) يكتم نفس الحدث، لكن FCM لا
// يقرأ نفس الحالة. isCurrentlyViewedChatMessage() هي منطق القرار المُستخرَج
// (raced قبل _showLocalNotificationStatic بـonMessage.listen) — يثبت هذا
// الملف سلوكها مباشرة بمعزل عن أي محاكاة Firebase/local_notifications.
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/core/notifications/firebase_notification_service.dart';

void main() {
  setUp(() {
    // حالة static مشتركة — تصفير صريح قبل كل اختبار حتى لا يتسرّب أثر اختبار
    // سابق (نفس التحذير الموثَّق بتعليق FirebaseNotificationService.activeChatRequestId).
    FirebaseNotificationService.activeChatRequestId = null;
  });

  tearDown(() {
    FirebaseNotificationService.activeChatRequestId = null;
  });

  test('رسالة شات لطلب مفتوح فعلياً على الشاشة تُكتَم', () {
    FirebaseNotificationService.activeChatRequestId = 55;
    final data = {'type': 'chat', 'requestId': '55'};

    expect(FirebaseNotificationService.isCurrentlyViewedChatMessage(data), isTrue);
  });

  test('رسالة شات لطلب مختلف عن المفتوح حالياً لا تُكتَم', () {
    FirebaseNotificationService.activeChatRequestId = 55;
    final data = {'type': 'chat', 'requestId': '99'};

    expect(FirebaseNotificationService.isCurrentlyViewedChatMessage(data), isFalse);
  });

  test('رسالة شات ولا محادثة مفتوحة إطلاقاً لا تُكتَم', () {
    FirebaseNotificationService.activeChatRequestId = null;
    final data = {'type': 'chat', 'requestId': '55'};

    expect(FirebaseNotificationService.isCurrentlyViewedChatMessage(data), isFalse);
  });

  test('إشعار من نوع آخر (غير chat) لا يُكتَم أبداً حتى لو تطابق requestId', () {
    FirebaseNotificationService.activeChatRequestId = 55;
    final data = {'type': 'offer', 'requestId': '55'};

    expect(FirebaseNotificationService.isCurrentlyViewedChatMessage(data), isFalse);
  });

  test('حمولة بلا requestId إطلاقاً لا تُكتَم (لا تطابق شيئاً)', () {
    FirebaseNotificationService.activeChatRequestId = 55;
    final data = {'type': 'chat'};

    expect(FirebaseNotificationService.isCurrentlyViewedChatMessage(data), isFalse);
  });
}
