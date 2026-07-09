// [FIX-EMPTYSTATE-03] يتحقق من أن شاشة قائمة المحادثات تُظهر رسالة الخطأ
// الحقيقية عند فشل الجلب، بدل رسالة "لا توجد محادثات" المضلِّلة — بنفس نمط
// الإصلاح المُتحقّق منه مسبقاً في customer_requests_screen وشاشتي المحفظة.
//
// ملاحظة: نفس الإصلاح طُبِّق أيضاً على ChatRoomScreen (غرفة الشات) بنفس
// الطريقة تماماً، لكن لا يوجد له اختبار Widget هنا: تشغيله يتطلب تفعيل
// SocketProvider/NotificationProvider/AuthProvider الحقيقية معاً، وهذا
// يُصادف قيداً معروفاً بـFlutter (تفكيك dispose() الذي يقرأ Provider عبر
// context.read يفشل تحت ظروف تفكيك شجرة اختبار معيّنة، رغم أنه نمط آمن
// ومُوثَّق رسمياً بحزمة provider للاستخدام الفعلي بالتطبيق). الإصلاح نفسه في
// chat_room_screen.dart تحقّقنا منه يدوياً بتشغيل التطبيق الفعلي بدلاً من ذلك.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/chat/screens/chats_screen.dart';
import 'package:sallehly_app/features/requests/data/requests_api.dart';
import 'package:sallehly_app/features/requests/provider/requests_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockRequestsApi extends Mock implements RequestsApi {}

// AppBackground (المستخدَمة بهذه الشاشة) تحوي AnimationController..repeat()
// دائم الحركة — هذا يجعل pumpAndSettle() لا "يستقر" أبداً (مهلة/timeout)،
// فنستخدم بدلاً منه دفعات pump() بمهلة محددة، وهي كافية لإنجاز الجلب الفاشل
// (Future.microtask + فشل مزامن من الـMock) دون انتظار توقف الحركة.
Future<void> _pumpUntilSettledIgnoringAnimation(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets(
    'ChatsScreen يُظهر رسالة خطأ حقيقية (وليس "لا توجد محادثات") عند فشل جلب الطلبات',
    (tester) async {
      final mockApi = MockRequestsApi();
      when(() => mockApi.getRequests())
          .thenThrow(Exception('فشل الاتصال بالخادم'));

      final provider = RequestsProvider(
        apiClient: MockApiClient(),
        apiOverride: mockApi,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: ChatsScreen()),
        ),
      );

      await _pumpUntilSettledIgnoringAnimation(tester);

      expect(find.text('لا توجد محادثات حالياً'), findsNothing);
      expect(find.text('تعذّر تحميل المحادثات'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    },
  );
}
