// [SEC-FIX-MEPWSOCKET-CLIENT-01] راجع DECISIONS.md. الخادم
// (SEC-FIX-MEPWSOCKET-01، مستودع sallehly) يقطع الآن أي اتصال Socket.IO حي
// بالحساب فور نجاح POST /me/password — يشمل سوكت الجهاز الحالي نفسه، الذي
// يستمر باستخدام التطبيق مباشرة بعد تغيير كلمة سره. بلا إعادة اتصال صريحة
// هنا، الشات/الإشعارات اللحظية كانت ستموت بصمت حتى استئناف التطبيق التالي
// من الخلفية أو تسجيل خروج/دخول جديد. هذا الاختبار يثبت أن ChangePasswordScreen
// تستدعي SocketProvider.reconnect() الحقيقية (لا نسخة معاد كتابتها) فور نجاح
// تغيير كلمة السر.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/socket/socket_events.dart';
import 'package:sallehly_app/core/socket/socket_service.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/core/widgets/gradient_button.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/features/settings/screens/change_password_screen.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';
import 'package:sallehly_app/providers/auth_provider.dart';
import 'package:sallehly_app/providers/socket_provider.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockAppStorage extends Mock implements AppStorage {}

class MockApiClient extends Mock implements ApiClient {}

class MockSocketService extends Mock implements SocketService {}

Future<void> _pumpAnimated(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  late MockAuthApi mockAuthApi;
  late MockSocketService mockSocketService;
  late MockTokenStorage mockSocketTokenStorage;
  late AuthProvider authProvider;
  late SocketProvider socketProvider;

  setUp(() {
    mockAuthApi = MockAuthApi();
    mockSocketService = MockSocketService();
    mockSocketTokenStorage = MockTokenStorage();

    final mockAuthTokenStorage = MockTokenStorage();
    final mockAppStorage = MockAppStorage();

    when(() => mockAuthApi.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        )).thenAnswer((_) async {});

    when(() => mockSocketTokenStorage.getToken()).thenAnswer((_) async => 'fresh-token-after-change');
    when(() => mockSocketService.connect(token: any(named: 'token'))).thenReturn(null);
    when(() => mockSocketService.disconnect()).thenReturn(null);
    when(() => mockSocketService.on(any(), any())).thenReturn(null);

    authProvider = AuthProvider(
      tokenStorage: mockAuthTokenStorage,
      apiClient: MockApiClient(),
      appStorage: mockAppStorage,
      authApiOverride: mockAuthApi,
    );
    socketProvider = SocketProvider(
      socketService: mockSocketService,
      tokenStorage: mockSocketTokenStorage,
    );
  });

  Widget wrap() => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<SocketProvider>.value(value: socketProvider),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChangePasswordScreen(),
        ),
      );

  testWidgets(
    '[SEC-FIX-MEPWSOCKET-CLIENT-01] تغيير كلمة السر بنجاح يعيد اتصال السوكت (الخادم يقطعه فوراً الآن)',
    (tester) async {
      await tester.pumpWidget(wrap());
      await _pumpAnimated(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'OldPass123');
      await tester.enterText(find.byType(TextFormField).at(1), 'NewPass456');
      await tester.enterText(find.byType(TextFormField).at(2), 'NewPass456');
      await _pumpAnimated(tester);

      await tester.tap(find.byType(GradientButton));
      await _pumpAnimated(tester, 10);

      verify(() => mockAuthApi.changePassword(
            currentPassword: 'OldPass123',
            newPassword: 'NewPass456',
          )).called(1);

      // reconnect() الحقيقية بـSocketProvider: disconnect() ثم connect()
      // (تسجّل مستمعين جدداً — راجع FIX-SOCKETREBIND-01) بالتوكن المُخزَّن
      // حديثاً (الذي حفظه ApiClient تلقائياً من Set-Cookie استجابة الخادم).
      verify(() => mockSocketService.disconnect()).called(1);
      verify(() => mockSocketService.connect(token: 'fresh-token-after-change')).called(1);
      verify(() => mockSocketService.on(SocketEvents.connect, any())).called(1);
    },
  );
}
