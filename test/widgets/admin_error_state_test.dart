// [FIX-EMPTYSTATE-04] يتحقق من أن شاشة إدارة المستخدمين (وبنفس النمط
// المُطبَّق على باقي شاشات الأدمن: السجل/الإعدادات/المراقبة/الطلبات/الدعم/
// الشحن) تُظهر رسالة الخطأ الحقيقية عند فشل الجلب، بدل رسالة "لا يوجد
// مستخدمين" المضلِّلة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/admin/provider/admin_provider.dart';
import 'package:sallehly_app/features/admin/screens/admin_users_screen.dart';

class MockApiClient extends Mock implements ApiClient {}

Future<void> _pumpUntilSettledIgnoringAnimation(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets(
    'AdminUsersScreen يُظهر رسالة خطأ حقيقية (وليس "لا يوجد مستخدمين") عند فشل الجلب',
    (tester) async {
      final provider = AdminProvider(apiClient: MockApiClient());

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: AdminUsersScreen()),
        ),
      );

      // initState يطلق loadUsers() عبر Future.microtask — الـApiClient غير
      // مهيّأ (Mock بلا stubbing) فيفشل الجلب فعلياً بنفس طريقة فشل شبكي حقيقي.
      await _pumpUntilSettledIgnoringAnimation(tester);

      expect(find.text('لا يوجد مستخدمين'), findsNothing);
      expect(find.text('تعذر تحميل المستخدمين'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    },
  );
}
