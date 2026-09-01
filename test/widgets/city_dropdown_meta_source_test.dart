// [FEAT-DEDUP-01] راجع DECISIONS.md — أربع شاشات (تسجيل عميل، تسجيل فني،
// تعديل الملف الشخصي، إنشاء طلب) كانت تجلب قائمة المحافظات الحيّة من الخادم
// عبر RequestsProvider.loadMeta() (ثلاث منها فعلياً، والرابعة أُضيف لها
// الجلب بهذا الإصلاح) ثم تتجاهلها تماماً وتعرض AppConstants.cities الثابتة
// دائماً بدلاً منها. هذا الاختبار يثبت أن قائمة "المحافظة" المعروضة الآن
// تُبنى من القيمة المجلوبة فعلياً من RequestsProvider.meta — يُستخدَم مدينة
// اختبار وهمية غير موجودة إطلاقاً بـAppConstants.cities كدليل قاطع على المصدر.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/core/utils/app_constants.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/features/auth/screens/customer_register_screen.dart';
import 'package:sallehly_app/features/auth/screens/technician_register_screen.dart';
import 'package:sallehly_app/features/customer/screens/create_request_screen.dart';
import 'package:sallehly_app/features/requests/data/requests_api.dart';
import 'package:sallehly_app/features/requests/provider/requests_provider.dart';
import 'package:sallehly_app/features/settings/screens/edit_profile_screen.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';
import 'package:sallehly_app/models/meta_model.dart';
import 'package:sallehly_app/providers/auth_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockAuthApi extends Mock implements AuthApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockAppStorage extends Mock implements AppStorage {}

class MockRequestsApi extends Mock implements RequestsApi {}

const _fetchedCity = 'مدينة اختبار حيّة';

MetaModel _fakeMeta() => const MetaModel(services: [], cities: [_fetchedCity]);

AuthProvider _fakeAuthProvider() {
  return AuthProvider(
    tokenStorage: MockTokenStorage(),
    apiClient: MockApiClient(),
    appStorage: MockAppStorage(),
    authApiOverride: MockAuthApi(),
  );
}

// نفس سبب wallet_error_state_test.dart: AppBackground تحوي
// AnimationController..repeat() دائم الحركة، فـpumpAndSettle() لا يتوقف أبداً.
Future<void> _pumpSteps(WidgetTester tester, {int steps = 6}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

// [DropdownButtonFormField] لا يُخزّن `items`/`decoration` كحقول عامة قابلة
// للقراءة مباشرة بهذا الإصدار من Flutter — التحقق الوحيد الموثوق هو فتح
// القائمة فعلياً والتأكد من محتوى الـoverlay المعروض.
Future<void> _openCityDropdown(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(DropdownButtonFormField<String>, label);
  expect(finder, findsOneWidget, reason: 'حقل المحافظة "$label" غير موجود بالشاشة');
  // بعض النماذج (شاشة تسجيل الفني) طويلة بما يكفي ليكون حقل المحافظة خارج
  // حدود شاشة الاختبار الافتراضية قبل التمرير.
  await tester.ensureVisible(finder);
  await _pumpSteps(tester, steps: 2);
  await tester.tap(finder);
  await _pumpSteps(tester);
}

void main() {
  testWidgets(
    'CustomerRegisterScreen: قائمة المحافظة تُبنى من meta.cities المجلوبة فعلياً',
    (tester) async {
      final mockApi = MockRequestsApi();
      when(() => mockApi.getMeta()).thenAnswer((_) async => _fakeMeta());
      final requests = RequestsProvider(apiClient: MockApiClient(), apiOverride: mockApi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _fakeAuthProvider()),
            ChangeNotifierProvider.value(value: requests),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CustomerRegisterScreen(),
          ),
        ),
      );
      await _pumpSteps(tester);

      final t = AppLocalizations.of(tester.element(find.byType(CustomerRegisterScreen)))!;
      await _openCityDropdown(tester, t.cityFieldLabel);

      expect(find.text(_fetchedCity), findsWidgets);
      for (final city in AppConstants.cities) {
        expect(find.text(city), findsNothing);
      }
    },
  );

  testWidgets(
    'TechnicianRegisterScreen: قائمة المحافظة تُبنى من meta.cities المجلوبة فعلياً (لا Object.keys(JORDAN_AREAS) ولا AppConstants.cities)',
    (tester) async {
      final mockApi = MockRequestsApi();
      when(() => mockApi.getMeta()).thenAnswer((_) async => _fakeMeta());
      final requests = RequestsProvider(apiClient: MockApiClient(), apiOverride: mockApi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _fakeAuthProvider()),
            ChangeNotifierProvider.value(value: requests),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TechnicianRegisterScreen(),
          ),
        ),
      );
      await _pumpSteps(tester);

      final t = AppLocalizations.of(tester.element(find.byType(TechnicianRegisterScreen)))!;
      await _openCityDropdown(tester, t.cityFieldLabel);

      expect(find.text(_fetchedCity), findsWidgets);
    },
  );

  testWidgets(
    'EditProfileScreen: قائمة المحافظة تُبنى من meta.cities المجلوبة فعلياً حتى لعميل (loadMeta لم تعد مقتصرة على الفني)',
    (tester) async {
      final mockApi = MockRequestsApi();
      when(() => mockApi.getMeta()).thenAnswer((_) async => _fakeMeta());
      final requests = RequestsProvider(apiClient: MockApiClient(), apiOverride: mockApi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _fakeAuthProvider()),
            ChangeNotifierProvider.value(value: requests),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const EditProfileScreen(),
          ),
        ),
      );
      await _pumpSteps(tester);

      final t = AppLocalizations.of(tester.element(find.byType(EditProfileScreen)))!;
      await _openCityDropdown(tester, t.cityFieldLabel);

      expect(find.text(_fetchedCity), findsWidgets);
      verify(() => mockApi.getMeta()).called(1);
    },
  );

  testWidgets(
    'CreateRequestScreen: قائمة المحافظة تُبنى من meta.cities المجلوبة فعلياً',
    (tester) async {
      final mockApi = MockRequestsApi();
      when(() => mockApi.getMeta()).thenAnswer((_) async => _fakeMeta());
      final requests = RequestsProvider(apiClient: MockApiClient(), apiOverride: mockApi);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: requests,
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CreateRequestScreen(),
          ),
        ),
      );
      await _pumpSteps(tester);

      final t = AppLocalizations.of(tester.element(find.byType(CreateRequestScreen)))!;
      await _openCityDropdown(tester, t.cityFieldLabel);

      expect(find.text(_fetchedCity), findsWidgets);
    },
  );
}
