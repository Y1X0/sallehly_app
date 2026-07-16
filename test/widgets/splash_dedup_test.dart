// [FIX-AUTH-04] SplashScreen.checkAuth() — Future.timeout() لا يُلغي عملية
// auth.loadMe() الأصلية، فقط يتوقف عن انتظارها. بدون _loadMeFuture، ضغط زر
// "إعادة المحاولة" أثناء استيقاظ خادم بطيء كان يُصدر طلب /me ثانياً متزامناً
// مع الأول الذي ما زال قيد التنفيذ فعلياً بالخلفية. هذا الاختبار يثبت أن
// authApi.me() يُستدعى مرة واحدة فقط حتى لو استُدعي checkAuth() (عبر زر
// إعادة المحاولة) بينما الاستدعاء الأول ما زال معلَّقاً.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/features/splash/splash_screen.dart';
import 'package:sallehly_app/models/user_model.dart';
import 'package:sallehly_app/providers/auth_provider.dart';
import 'package:sallehly_app/providers/notification_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockAuthApi extends Mock implements AuthApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockAppStorage extends Mock implements AppStorage {}

void main() {
  testWidgets(
    '[FIX-AUTH-04] إعادة المحاولة أثناء انتظار /me المعلّق لا تُصدر طلباً ثانياً',
    (tester) async {
      final mockAuthApi = MockAuthApi();
      final mockTokenStorage = MockTokenStorage();
      final mockAppStorage = MockAppStorage();

      when(() => mockTokenStorage.hasToken()).thenAnswer((_) async => true);

      var meCallCount = 0;
      when(() => mockAuthApi.me()).thenAnswer((_) {
        meCallCount++;
        // لا يكتمل أبداً خلال هذا الاختبار — يحاكي خادماً بطيئاً/نائماً لا
        // يزال يعالج الطلب الأول بالخلفية.
        return Completer<UserModel>().future;
      });

      final authProvider = AuthProvider(
        tokenStorage: mockTokenStorage,
        apiClient: MockApiClient(),
        appStorage: mockAppStorage,
        authApiOverride: mockAuthApi,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<NotificationProvider>(
              create: (_) => NotificationProvider(),
            ),
          ],
          child: const MaterialApp(home: SplashScreen()),
        ),
      );

      // initState يجدول checkAuth() الأول بعد 600ms.
      await tester.pump(const Duration(milliseconds: 700));
      expect(meCallCount, 1, reason: 'checkAuth() الأول يجب أن يستدعي /me مرة واحدة');

      // تجاوز مهلة الـ25 ثانية الخارجية — يظهر زر "إعادة المحاولة" الآن،
      // لكن authApi.me() الأصلي لا يزال معلَّقاً فعلياً بالخلفية (لم يُلغَ).
      await tester.pump(const Duration(seconds: 26));
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      // ضغط "إعادة المحاولة" أثناء الاستدعاء الأول ما زال معلَّقاً.
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        meCallCount,
        1,
        reason:
            'إعادة المحاولة يجب أن تُعيد استخدام نفس العملية المعلَّقة بدل '
            'إصدار طلب /me ثانٍ متزامن، طالما الأول لم يكتمل فعلياً بعد.',
      );

      // نُصرِّف مهلة الـ25 ثانية الخارجية الثانية (لإعادة المحاولة نفسها)
      // حتى لا يبقى أي Timer معلَّق عند نهاية الاختبار.
      await tester.pump(const Duration(seconds: 26));
    },
  );
}
