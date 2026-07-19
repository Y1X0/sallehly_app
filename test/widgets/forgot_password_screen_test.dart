// ForgotPasswordScreen بلا أي اختبار سابق. يغطي المسار الكامل بخطوتيه: طلب
// كود التحقق، ثم إعادة التعيين بالكود وكلمة السر الجديدة — بلا اصطدام بمشكلة
// شجرة Provider الناقصة (تنتقل لـLoginScreen عند النجاح، وهي شاشة خفيفة لا
// تحتاج أي Provider إضافي غير AuthProvider الموجود أصلاً بهذا الاختبار).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/api/api_exception.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/features/auth/screens/forgot_password_screen.dart';
import 'package:sallehly_app/providers/auth_provider.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockAppStorage extends Mock implements AppStorage {}

class MockApiClient extends Mock implements ApiClient {}

Future<void> _pumpAnimated(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  late MockAuthApi mockAuthApi;
  late AuthProvider authProvider;

  setUp(() {
    mockAuthApi = MockAuthApi();
    final mockTokenStorage = MockTokenStorage();
    final mockAppStorage = MockAppStorage();
    when(() => mockTokenStorage.clearToken()).thenAnswer((_) async {});
    when(() => mockAppStorage.clear()).thenAnswer((_) async {});
    authProvider = AuthProvider(
      tokenStorage: mockTokenStorage,
      apiClient: MockApiClient(),
      appStorage: mockAppStorage,
      authApiOverride: mockAuthApi,
    );
  });

  Widget wrap() => ChangeNotifierProvider.value(
        value: authProvider,
        child: const MaterialApp(home: ForgotPasswordScreen()),
      );

  testWidgets('بريد فارغ: خطأ تحقق، بلا نداء شبكة', (tester) async {
    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);

    await tester.tap(find.text('إرسال كود التحقق'));
    await _pumpAnimated(tester);

    expect(find.text('أدخل البريد الإلكتروني'), findsOneWidget);
    verifyNever(() => mockAuthApi.forgotPassword(email: any(named: 'email')));
  });

  testWidgets('بريد صحيح: ينتقل تلقائياً لخطوة إدخال الكود وكلمة السر الجديدة', (tester) async {
    when(() => mockAuthApi.forgotPassword(email: any(named: 'email')))
        .thenAnswer((_) async => 'تم إرسال الكود');

    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);

    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.tap(find.text('إرسال كود التحقق'));
    await _pumpAnimated(tester);

    verify(() => mockAuthApi.forgotPassword(email: 'user@example.com')).called(1);
    expect(find.text('أدخل الكود الذي وصلك وكلمة المرور الجديدة'), findsOneWidget);
    expect(find.text('كود التحقق'), findsOneWidget);
  });

  testWidgets('كود أقصر من 6 أرقام: خطأ تحقق، بلا نداء resetPassword', (tester) async {
    when(() => mockAuthApi.forgotPassword(email: any(named: 'email')))
        .thenAnswer((_) async => 'تم إرسال الكود');

    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);
    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.tap(find.text('إرسال كود التحقق'));
    await _pumpAnimated(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '123');
    await tester.enterText(find.byType(TextFormField).at(1), 'NewPassword123');
    await tester.tap(find.text('تغيير كلمة المرور'));
    await _pumpAnimated(tester);

    expect(find.text('أدخل الكود المكوّن من 6 أرقام'), findsOneWidget);
    verifyNever(() => mockAuthApi.resetPassword(
          email: any(named: 'email'),
          otp: any(named: 'otp'),
          newPassword: any(named: 'newPassword'),
        ));
  });

  testWidgets('كود وكلمة سر صحيحان: يستدعي resetPassword بالقيم الصحيحة وينجح', (tester) async {
    when(() => mockAuthApi.forgotPassword(email: any(named: 'email')))
        .thenAnswer((_) async => 'تم إرسال الكود');
    when(() => mockAuthApi.resetPassword(
          email: any(named: 'email'),
          otp: any(named: 'otp'),
          newPassword: any(named: 'newPassword'),
        )).thenAnswer((_) async => 'تم تغيير كلمة المرور بنجاح');

    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);
    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.tap(find.text('إرسال كود التحقق'));
    await _pumpAnimated(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '654321');
    await tester.enterText(find.byType(TextFormField).at(1), 'NewPassword123');
    await tester.tap(find.text('تغيير كلمة المرور'));
    await _pumpAnimated(tester);

    verify(() => mockAuthApi.resetPassword(
          email: 'user@example.com',
          otp: '654321',
          newPassword: 'NewPassword123',
        )).called(1);
    // ينتقل لـLoginScreen عند النجاح — شاشة خفيفة، لا اصطدام بشجرة Provider ناقصة.
    expect(find.text('أهلاً بعودتك'), findsOneWidget);
  });

  testWidgets('فشل الخادم أثناء طلب الكود (ApiException): يُظهر رسالة الخطأ ويبقى بالخطوة الأولى', (tester) async {
    when(() => mockAuthApi.forgotPassword(email: any(named: 'email')))
        .thenThrow(ApiException('تعذر إرسال الكود'));

    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);
    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.tap(find.text('إرسال كود التحقق'));
    await _pumpAnimated(tester);

    expect(find.text('تعذر إرسال الكود'), findsOneWidget);
    expect(find.text('إرسال كود التحقق'), findsOneWidget); // لا يزال بالخطوة الأولى
  });
}
