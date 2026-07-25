// [FIX-SUPPORTBADGE-01] عداد رسائل الدعم عند الفني كان يبقى ظاهراً حتى بعد
// فتح محادثة الدعم — السبب: إشعارات الدعم الدائمة (GET /api/notifications)
// تصل من الخادم بمعرّف التذكرة داخل عمود ticket_id منفصل (وليس request_id)،
// بينما markSupportNotificationsReadForTicket كانت تقارن requestId فقط.
// هذا الاختبار يثبت أن NotificationModel.effectiveTicketId يوحّد المصدرين،
// وأن تصفير تذكرة معيّنة يعمل بشكل صحيح بكلا المصدرين (لحظي ودائم).
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/models/notification_model.dart';
import 'package:sallehly_app/providers/notification_provider.dart';

NotificationModel _liveSupportItem({required int ticketId, bool read = false}) {
  // كما تُنشئها NotificationProvider.handleSupportMessage فعلياً — تخزّن
  // معرّف التذكرة بحقل requestId (لا يوجد ticketId بهذا المسار إطلاقاً).
  return NotificationModel(
    id: 'local-$ticketId',
    title: 'رسالة من الدعم',
    body: 'وصلتك رسالة جديدة من الدعم',
    type: 'support',
    requestId: ticketId,
    createdAt: DateTime.now(),
    read: read,
  );
}

NotificationModel _serverSupportItem({required int ticketId, bool read = false}) {
  // كما يصل فعلياً من GET /api/notifications (NotificationModel.fromJson) —
  // request_id فارغ دائماً لهذا النوع، وticket_id هو من يحمل المعرّف الحقيقي.
  return NotificationModel(
    id: 'server-$ticketId',
    title: 'تذكرة دعم جديدة',
    body: 'فتح فني تذكرة',
    type: 'support',
    requestId: null,
    ticketId: ticketId,
    createdAt: DateTime.now(),
    read: read,
    serverId: ticketId + 1000,
  );
}

void main() {
  group('[FIX-SUPPORTBADGE-01] NotificationModel.effectiveTicketId', () {
    test('يفضّل requestId (المصدر اللحظي) عند وجوده', () {
      final item = _liveSupportItem(ticketId: 7);
      expect(item.effectiveTicketId, 7);
    });

    test('يستخدم ticketId (المصدر الدائم من الخادم) عند غياب requestId', () {
      final item = _serverSupportItem(ticketId: 9);
      expect(item.effectiveTicketId, 9);
    });
  });

  group('[FIX-SUPPORTBADGE-01] NotificationProvider.markSupportNotificationsReadForTicket', () {
    test('يصفّر عدّاد الدعم لإشعار لحظي (requestId) بنفس التذكرة', () {
      final provider = NotificationProvider();
      provider.handleSupportMessage({'ticketId': 5, 'body': 'رد جديد', 'senderId': 999});

      expect(provider.supportUnreadCount, 1);

      provider.markSupportNotificationsReadForTicket(5);

      expect(
        provider.supportUnreadCount,
        0,
        reason: 'فتح نفس التذكرة يجب أن يصفّر إشعارها اللحظي فوراً',
      );
    });

    test(
      'يصفّر عدّاد الدعم لإشعار دائم من الخادم (ticket_id فقط، لا request_id) — هذا بالضبط الخلل المُصلَح',
      () {
        final provider = NotificationProvider();
        provider.addTestItem(_serverSupportItem(ticketId: 12));

        expect(provider.supportUnreadCount, 1);

        provider.markSupportNotificationsReadForTicket(12);

        expect(
          provider.supportUnreadCount,
          0,
          reason:
              'قبل الإصلاح: المقارنة كانت على requestId (دائماً null هنا)، '
              'فلا يتصفّر العداد أبداً رغم فتح المحادثة فعلياً.',
        );
      },
    );

    test('لا يصفّر إشعارات تذاكر أخرى غير المفتوحة حالياً', () {
      final provider = NotificationProvider();
      provider.addTestItem(_serverSupportItem(ticketId: 1));
      provider.addTestItem(_serverSupportItem(ticketId: 2));

      provider.markSupportNotificationsReadForTicket(1);

      expect(provider.supportUnreadCount, 1);
    });
  });
}
