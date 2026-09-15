// [FIX-SOCIALDELETE-01] راجع DECISIONS.md — حساب جوجل/أبل (hasPassword=false)
// كلمة سره الحقيقية عشوائية غير معروفة حتى لصاحبه، فحقل "كلمة المرور الحالية"
// بحوار حذف الحساب (settings_screen.dart deleteAccountFlow) يجب ألا يظهر له
// أصلاً — يقفل عليه بلا أي طريقة يتجاوزها. هذا الاختبار يثبت: الحقل يظهر
// لحساب عادي (hasPassword=true)، ويختفي لحساب اجتماعي (hasPassword=false)،
// والتأكيد بالحالة الثانية يستدعي AuthProvider.deleteAccount(password: '')
// بلا أي إدخال مطلوب من المستخدم.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/features/settings/screens/settings_screen.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';
import 'package:sallehly_app/models/user_model.dart';
import 'package:sallehly_app/providers/auth_provider.dart';
import 'package:sallehly_app/providers/locale_provider.dart';
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

UserModel _user({required bool hasPassword}) => UserModel(
      id: 1,
      role: 'customer',
      name: 'مستخدم اختبار',
      email: 'test@example.com',
      phone: '0791234567',
      rating: 0,
      balance: 0,
      active: true,
      hasPassword: hasPassword,
    );

void main() {
  late MockAuthApi mockAuthApi;
  late MockTokenStorage mockTokenStorage;
  late MockAppStorage mockAppStorage;
  late AuthProvider authProvider;
  late ThemeController themeController;
  late LocaleProvider localeProvider;

  Future<void> loginAs(UserModel user) async {
    when(() => mockAuthApi.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AuthResult(token: 'tok', user: user));
    await authProvider.login(email: user.email, password: 'whatever');
  }

  setUp(() {
    mockAuthApi = MockAuthApi();
    mockTokenStorage = MockTokenStorage();
    mockAppStorage = MockAppStorage();
    when(() => mockTokenStorage.clearToken()).thenAnswer((_) async {});
    when(() => mockTokenStorage.saveToken(any())).thenAnswer((_) async {});
    when(() => mockAppStorage.clear()).thenAnswer((_) async {});
    when(() => mockAppStorage.saveRole(any())).thenAnswer((_) async {});
    when(() => mockAppStorage.saveUserId(any())).thenAnswer((_) async {});
    when(() => mockAppStorage.saveUserName(any())).thenAnswer((_) async {});
    when(() => mockAuthApi.deleteAccount(password: any(named: 'password')))
        .thenAnswer((_) async => 'ok');

    authProvider = AuthProvider(
      tokenStorage: mockTokenStorage,
      apiClient: MockApiClient(),
      appStorage: mockAppStorage,
      authApiOverride: mockAuthApi,
    );
    themeController = ThemeController();
    localeProvider = LocaleProvider();
  });

  Widget wrap() => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<ThemeController>.value(value: themeController),
          ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      );

  Future<void> openDeleteDialog(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);
    await tester.scrollUntilVisible(find.text('حذف الحساب نهائياً'), 300, scrollable: find.byType(Scrollable).first);
    await _pumpAnimated(tester);
    await tester.tap(find.text('حذف الحساب نهائياً'));
    await _pumpAnimated(tester);
  }

  testWidgets('حساب عادي (hasPassword=true): حقل كلمة المرور الحالية يظهر بحوار الحذف', (tester) async {
    await loginAs(_user(hasPassword: true));
    await openDeleteDialog(tester);

    expect(find.widgetWithText(TextFormField, 'كلمة المرور الحالية'), findsOneWidget);
  });

  testWidgets('حساب اجتماعي (hasPassword=false): حقل كلمة السر لا يظهر، والتأكيد ينجح بلا أي إدخال', (tester) async {
    await loginAs(_user(hasPassword: false));
    await openDeleteDialog(tester);

    expect(find.widgetWithText(TextFormField, 'كلمة المرور الحالية'), findsNothing);

    await tester.tap(find.text('حذف نهائياً'));
    await _pumpAnimated(tester, 10);

    verify(() => mockAuthApi.deleteAccount(password: '')).called(1);
  });
}
