// [FIX-EMPTYSTATE-05] يتحقق من أن شاشة تذاكر الدعم تُظهر رسالة الخطأ الحقيقية
// عند فشل الجلب، بدل رسالة "لا توجد تذاكر دعم بعد" المضلِّلة — بنفس نمط
// الإصلاح المُتحقّق منه مسبقاً في customer_requests_screen وشاشات
// المحفظة/الشات/الأدمن. نفس الإصلاح طُبِّق أيضاً على support_chat_screen.dart
// وadmin_support_chat_screen.dart بنفس الطريقة تماماً (بلا اختبار مستقل هنا
// لتفادي تكرار نفس التعقيد بلا فائدة إضافية — النمط مطابق تماماً وتم التحقق
// من سلامته عبر flutter analyze والتحقق اليدوي من الكود).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/support/provider/support_provider.dart';
import 'package:sallehly_app/features/support/screens/support_screen.dart';

class MockApiClient extends Mock implements ApiClient {}

// AppBackground (المستخدَمة بهذه الشاشة) تحوي AnimationController..repeat()
// دائم الحركة — هذا يجعل pumpAndSettle() لا "يستقر" أبداً (مهلة/timeout)،
// فنستخدم بدلاً منه دفعات pump() بمهلة محددة.
Future<void> _pumpUntilSettledIgnoringAnimation(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets(
    'SupportScreen يُظهر رسالة خطأ حقيقية (وليس "لا توجد تذاكر دعم بعد") عند فشل الجلب',
    (tester) async {
      final provider = SupportProvider(apiClient: MockApiClient());

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: SupportScreen()),
        ),
      );

      // initState يطلق loadMyTickets() عبر Future.microtask — الـApiClient
      // غير مهيّأ (Mock بلا stubbing) فيفشل الجلب فعلياً بنفس طريقة فشل شبكي.
      await _pumpUntilSettledIgnoringAnimation(tester);

      expect(find.text('لا توجد تذاكر دعم بعد'), findsNothing);
      expect(find.text('تعذّر تحميل تذاكر الدعم'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    },
  );
}
