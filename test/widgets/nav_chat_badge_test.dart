// [FIX-CHATBADGE-01] شارة الدردشات بالشريط السفلي (customer_layout.dart /
// technician_layout.dart) كانت مرتبطة بـNotificationProvider.chatUnreadCount
// — قائمة إشعارات محلية بالذاكرة فقط، تبدأ فارغة عند كل إقلاع للتطبيق ولا
// تُحمَّل أبداً من الخادم. النتيجة: الشارة لا تظهر إطلاقاً بعد إعادة التشغيل
// أو تسجيل الدخول حتى تصل رسالة جديدة فعلياً أثناء تشغيل التطبيق مباشرة.
// المصدر الصحيح موجود أصلاً ويعمل: ChatProvider.totalUnread (من GET /chats،
// مدعوم من جدول chat_reads بالخادم).
//
// [TEST-FIX-NAVBADGE-01] راجع DECISIONS.md — هذا الاختبار كان يعيد إنتاج
// بنية الشارة يدوياً بملف منفصل (Badge بلا NotifyPulse، بلا اقتطاع "99+"،
// بلون/حجم مختلفَين تماماً عن الحقيقيَّين، ولا يقرأ ChatProvider إلا عبر نسخة
// مستقلة كتبها الاختبار نفسه) — لا يفشل أبداً لو انكسرت البنية الفعلية
// بـcustomer_layout.dart. الآن `GlassNav`/`NavItem` (كانا `_GlassNav`/
// `_NavItem`) رُفعا للرؤية العامة، و`resolveChatBadgeCount` (كان سطراً
// مضمَّناً بداخل `build()`) صار دالة `@visibleForTesting` منفصلة — الاختبار
// يستدعي الثلاثة حقيقيَّة مباشرة، لا نسخة معاد كتابتها.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/widgets/notify_pulse.dart';
import 'package:sallehly_app/features/chat/data/chat_api.dart';
import 'package:sallehly_app/features/chat/provider/chat_provider.dart';
import 'package:sallehly_app/features/layout/customer_layout.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';
import 'package:sallehly_app/models/chat_summary_model.dart';
import 'package:sallehly_app/providers/notification_provider.dart';

class MockChatApi extends Mock implements ChatApi {}

class MockApiClient extends Mock implements ApiClient {}

void main() {
  group('[FIX-CHATBADGE-01] مصدر عدد شارة الدردشات — resolveChatBadgeCount الحقيقية', () {
    testWidgets(
      'تعكس ChatProvider.totalUnread فور تحميله، لا NotificationProvider.chatUnreadCount',
      (tester) async {
        final mockApi = MockChatApi();
        when(() => mockApi.getChats()).thenAnswer((_) async => (
              [
                ChatSummaryModel(
                  requestId: 1,
                  service: 'كهربائي',
                  status: 'قيد التنفيذ',
                  otherName: 'أحمد',
                  unreadCount: 3,
                ),
              ],
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
            child: MaterialApp(
              // resolveChatBadgeCount تستدعي context.watch<ChatProvider>() —
              // يجب استدعاؤها من داخل build() حقيقي (لا مباشرة من جسم
              // الاختبار) حتى تُعاد قراءتها فعلياً عند إعادة البناء بعد
              // notifyListeners()، تماماً كما يحدث بـGlassNav الحقيقية.
              home: Builder(
                builder: (context) => Text('${resolveChatBadgeCount(context)}'),
              ),
            ),
          ),
        );
        await tester.pump();

        // قبل أي تحميل: صفر (لا صفر مزيّف من NotificationProvider — ChatProvider
        // نفسه يبدأ فارغاً).
        expect(find.text('0'), findsOneWidget);

        // [FIX-CHATBADGE-01] محاكاة ما يحدث فعلياً بعد تسجيل الدخول/استعادة
        // الجلسة (authProvider.onAuthenticated بـapp.dart الآن يستدعي هذا).
        await chatProvider.loadChats(silent: true);
        await tester.pump();

        // القيمة الحقيقية من الخادم (5) تصل فوراً — بلا علاقة بـNotificationProvider
        // (يبقى صفراً).
        expect(find.text('5'), findsOneWidget);
        expect(notificationProvider.chatUnreadCount, 0);
      },
    );
  });

  group('[TEST-FIX-NAVBADGE-01] GlassNav الحقيقية: اقتطاع 99+، وظهور/اختفاء الشارة', () {
    Widget wrap(Widget bottomBar) => MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(bottomNavigationBar: bottomBar),
        );

    testWidgets(
      'عدد أقل من 100 يظهر كما هو، عبر NotifyPulse/Badge الحقيقيَّين',
      (tester) async {
        await tester.pumpWidget(wrap(
          GlassNav(
            selectedIndex: 0,
            onTap: (_) {},
            items: const [
              NavItem(Icons.chat_bubble_outline, Icons.chat, 'الدردشات', 5),
            ],
          ),
        ));
        await tester.pump();

        expect(find.text('5'), findsOneWidget);
        expect(find.byType(NotifyPulse), findsOneWidget);
        final badge = tester.widget<Badge>(find.byType(Badge));
        expect(badge.isLabelVisible, isTrue);
      },
    );

    testWidgets(
      'عدد أكبر من 99 يُقتَطع لعرض "99+" (لا الرقم الحقيقي)',
      (tester) async {
        await tester.pumpWidget(wrap(
          GlassNav(
            selectedIndex: 0,
            onTap: (_) {},
            items: const [
              NavItem(Icons.chat_bubble_outline, Icons.chat, 'الدردشات', 150),
            ],
          ),
        ));
        await tester.pump();

        expect(find.text('99+'), findsOneWidget);
        expect(find.text('150'), findsNothing);
      },
    );

    testWidgets(
      'عدد صفر: الشارة غير ظاهرة إطلاقاً (isLabelVisible false)',
      (tester) async {
        await tester.pumpWidget(wrap(
          GlassNav(
            selectedIndex: 0,
            onTap: (_) {},
            items: const [
              NavItem(Icons.chat_bubble_outline, Icons.chat, 'الدردشات', 0),
            ],
          ),
        ));
        await tester.pump();

        final badge = tester.widget<Badge>(find.byType(Badge));
        expect(badge.isLabelVisible, isFalse);
      },
    );
  });
}
