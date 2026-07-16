// [FIX-CHATBADGE-01] شارة الدردشات بالشريط السفلي (customer_layout.dart /
// technician_layout.dart) كانت مرتبطة بـNotificationProvider.chatUnreadCount
// — قائمة إشعارات محلية بالذاكرة فقط، تبدأ فارغة عند كل إقلاع للتطبيق ولا
// تُحمَّل أبداً من الخادم. النتيجة: الشارة لا تظهر إطلاقاً بعد إعادة التشغيل
// أو تسجيل الدخول حتى تصل رسالة جديدة فعلياً أثناء تشغيل التطبيق مباشرة.
// المصدر الصحيح موجود أصلاً ويعمل: ChatProvider.totalUnread (من GET /chats،
// مدعوم من جدول chat_reads بالخادم). هذا الاختبار يعيد إنتاج بنية الشارة
// بالضبط (نفس الودجت Badge المستخدم بالتخطيطين) ويثبت أنها تعكس القيمة
// الصحيحة من ChatProvider فور تحميلها — وليست مرتبطة بـNotificationProvider.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/chat/data/chat_api.dart';
import 'package:sallehly_app/features/chat/provider/chat_provider.dart';
import 'package:sallehly_app/models/chat_summary_model.dart';
import 'package:sallehly_app/providers/notification_provider.dart';

class MockChatApi extends Mock implements ChatApi {}

class MockApiClient extends Mock implements ApiClient {}

/// نفس بنية شارة الدردشات بالضبط كما تظهر بـcustomer_layout.dart و
/// technician_layout.dart: عدد مصدره `context.watch<ChatProvider>().totalUnread`.
class _ChatNavBadgeHarness extends StatelessWidget {
  const _ChatNavBadgeHarness();

  @override
  Widget build(BuildContext context) {
    final chatUnread = context.watch<ChatProvider>().totalUnread;
    return Scaffold(
      body: Center(
        child: Badge(
          isLabelVisible: chatUnread > 0,
          label: Text('$chatUnread'),
          child: const Icon(Icons.chat_bubble_outline),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    '[FIX-CHATBADGE-01] شارة الدردشات تعكس ChatProvider.totalUnread فور تحميله، لا NotificationProvider',
    (tester) async {
      final mockApi = MockChatApi();
      when(() => mockApi.getChats()).thenAnswer((_) async => (
            [ChatSummaryModel(requestId: 1, service: 'كهربائي', status: 'قيد التنفيذ', otherName: 'أحمد', unreadCount: 3)],
            5, // إجمالي غير المقروء عبر كل المحادثات (مصدره GET /chats.total)
          ));

      final chatProvider = ChatProvider(apiClient: MockApiClient(), apiOverride: mockApi);
      final notificationProvider = NotificationProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
          ],
          child: const MaterialApp(home: _ChatNavBadgeHarness()),
        ),
      );
      await tester.pump();

      // قبل أي تحميل: لا شارة ظاهرة (لا صفر مزيّف ولا رقم قديم).
      expect(find.text('0'), findsNothing);

      // [FIX-CHATBADGE-01] محاكاة ما يحدث فعلياً بعد تسجيل الدخول/استعادة
      // الجلسة (authProvider.onAuthenticated بـapp.dart الآن يستدعي هذا).
      await chatProvider.loadChats(silent: true);
      await tester.pump();

      // الشارة تعكس القيمة الحقيقية من الخادم فوراً — بلا حاجة لفتح تبويب
      // الدردشات يدوياً، وبلا علاقة بـNotificationProvider (يبقى صفراً).
      expect(find.text('5'), findsOneWidget);
      expect(notificationProvider.chatUnreadCount, 0);
    },
  );
}
