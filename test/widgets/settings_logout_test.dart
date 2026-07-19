// SettingsScreen logout — بلا أي اختبار سابق رغم أنه إجراء نهائي مهم. يغطي:
// نافذة التأكيد تظهر، "إلغاء" لا يُسجّل الخروج فعلياً، "خروج" يستدعي
// AuthProvider.logout() وينتقل لـLoginScreen (شاشة خفيفة بلا مشاكل Provider).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/features/settings/screens/settings_screen.dart';
import 'package:sallehly_app/providers/auth_provider.dart';
import 'package:sallehly_app/providers/theme_controller.dart';

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
  late MockTokenStorage mockTokenStorage;
  late AuthProvider authProvider;
  late ThemeController themeController;

  setUp(() {
    mockAuthApi = MockAuthApi();
    mockTokenStorage = MockTokenStorage();
    final mockAppStorage = MockAppStorage();
    when(() => mockTokenStorage.clearToken()).thenAnswer((_) async {});
    when(() => mockAppStorage.clear()).thenAnswer((_) async {});
    when(() => mockAuthApi.logout()).thenAnswer((_) async {});

    authProvider = AuthProvider(
      tokenStorage: mockTokenStorage,
      apiClient: MockApiClient(),
      appStorage: mockAppStorage,
      authApiOverride: mockAuthApi,
    );
    themeController = ThemeController();
  });

  Widget wrap() => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<ThemeController>.value(value: themeController),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      );

  testWidgets('الضغط على تسجيل الخروج يُظهر نافذة تأكيد؛ "إلغاء" لا يسجّل الخروج فعلياً', (tester) async {
    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);

    // "تسجيل الخروج" أسفل القائمة الطويلة (ListView → Sliver) — لا يُبنى فعلياً
    // ضمن شجرة العناصر إلا بعد التمرير إليه (خارج نطاق العرض الافتراضي للاختبار).
    await tester.scrollUntilVisible(find.text('تسجيل الخروج'), 300, scrollable: find.byType(Scrollable).first);
    await _pumpAnimated(tester);
    await tester.tap(find.text('تسجيل الخروج'));
    await _pumpAnimated(tester);

    expect(find.text('هل أنت متأكد أنك تريد تسجيل الخروج؟'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await _pumpAnimated(tester);

    verifyNever(() => mockAuthApi.logout());
    verifyNever(() => mockTokenStorage.clearToken());
  });

  testWidgets('تأكيد الخروج يستدعي AuthProvider.logout() فعلياً وينتقل لشاشة تسجيل الدخول', (tester) async {
    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);

    await tester.scrollUntilVisible(find.text('تسجيل الخروج'), 300, scrollable: find.byType(Scrollable).first);
    await _pumpAnimated(tester);
    await tester.tap(find.text('تسجيل الخروج'));
    await _pumpAnimated(tester);
    await tester.tap(find.text('خروج'));
    await _pumpAnimated(tester, 10);

    verify(() => mockAuthApi.logout()).called(1);
    verify(() => mockTokenStorage.clearToken()).called(1);
    expect(authProvider.isLoggedIn, isFalse);
    expect(find.text('أهلاً بعودتك'), findsOneWidget); // LoginScreen
  });
}
