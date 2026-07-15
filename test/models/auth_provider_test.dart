// [FIX-TEST-01] اختبارات AuthProvider — تغطي أهم مسارات العمل (login, logout,
// loadMe) دون أي اتصال شبكة حقيقي، عبر Mock لـ AuthApi/TokenStorage/AppStorage.
//
// ملاحظة مهمة: `_sendFcmTokenToServer()` داخل AuthProvider تستدعي
// `FirebaseMessaging.instance.getToken()` مباشرة. في بيئة `flutter test` هذا
// النداء سيفشل (لا يوجد تطبيق Firebase مُهيّأ ولا Plugin حقيقي)، لكن الكود
// الإنتاجي نفسه يلتقط هذا الفشل داخلياً بـ try/catch صامت (راجع الدالة في
// auth_provider.dart) — لذلك لا نحتاج أي محاكاة لـ Firebase هنا؛ الفشل
// الداخلي لا يوقف تنفيذ login()/loadMe() ولا يظهر كخطأ بالاختبار.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/api/api_exception.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/models/user_model.dart';
import 'package:sallehly_app/providers/auth_provider.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockAppStorage extends Mock implements AppStorage {}

class MockApiClient extends Mock implements ApiClient {}

UserModel _sampleUser({int id = 1, String role = 'customer'}) {
  return UserModel(
    id: id,
    role: role,
    name: 'أحمد',
    email: 'ahmad@test.com',
    phone: '0790000000',
    rating: 0,
    balance: 0,
    active: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthApi mockAuthApi;
  late MockTokenStorage mockTokenStorage;
  late MockAppStorage mockAppStorage;
  late AuthProvider provider;

  setUp(() {
    mockAuthApi = MockAuthApi();
    mockTokenStorage = MockTokenStorage();
    mockAppStorage = MockAppStorage();

    // الحالات الشائعة لكل الاختبارات — تُفعَّل افتراضياً لتفادي تكرارها.
    when(() => mockTokenStorage.clearToken()).thenAnswer((_) async {});
    when(() => mockTokenStorage.saveToken(any())).thenAnswer((_) async {});
    when(() => mockAppStorage.clear()).thenAnswer((_) async {});
    when(() => mockAppStorage.saveRole(any())).thenAnswer((_) async {});
    when(() => mockAppStorage.saveUserId(any())).thenAnswer((_) async {});
    when(() => mockAppStorage.saveUserName(any())).thenAnswer((_) async {});

    provider = AuthProvider(
      tokenStorage: mockTokenStorage,
      apiClient: MockApiClient(),
      appStorage: mockAppStorage,
      authApiOverride: mockAuthApi,
    );
  });

  group('login', () {
    test('عند نجاح تسجيل الدخول: يُحفظ المستخدم وتُستدعى onAuthenticated',
        () async {
      final user = _sampleUser();
      when(
        () => mockAuthApi.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResult(token: 'tok-123', user: user));

      var authenticatedCalled = false;
      provider.onAuthenticated = () async {
        authenticatedCalled = true;
      };

      await provider.login(email: 'ahmad@test.com', password: 'password123');

      expect(provider.isLoggedIn, isTrue);
      expect(provider.user?.id, equals(1));
      expect(provider.error, isNull);
      expect(provider.loading, isFalse);
      expect(authenticatedCalled, isTrue);
      verify(
        () => mockAuthApi.login(
          email: 'ahmad@test.com',
          password: 'password123',
        ),
      ).called(1);
    });

    test('عند فشل تسجيل الدخول (بيانات خاطئة): يُحفظ رسالة الخطأ ولا يُسجَّل دخول',
        () async {
      when(
        () => mockAuthApi.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(ApiException('بيانات الدخول غير صحيحة', statusCode: 401));

      await expectLater(
        provider.login(email: 'x@test.com', password: 'wrong'),
        throwsA(isA<ApiException>()),
      );

      expect(provider.isLoggedIn, isFalse);
      expect(provider.error, 'بيانات الدخول غير صحيحة');
      expect(provider.loading, isFalse);
    });
  });

  group('logout', () {
    test('يمسح المستخدم ويستدعي onLoggedOut حتى لو فشل استدعاء /auth/logout',
        () async {
      // logout() بالكود الإنتاجي يبتلع أي استثناء من authApi.logout() عمداً —
      // نتأكد أن هذا السلوك (تسجيل خروج محلي دائماً ينجح) يبقى صحيحاً.
      when(() => mockAuthApi.logout()).thenThrow(Exception('network down'));

      var loggedOutCalled = false;
      provider.onLoggedOut = () => loggedOutCalled = true;

      await provider.logout();

      expect(provider.isLoggedIn, isFalse);
      expect(provider.error, isNull);
      expect(loggedOutCalled, isTrue);
      verify(() => mockTokenStorage.clearToken()).called(greaterThanOrEqualTo(1));
    });
  });

  group('loadMe', () {
    test('لا يستدعي authApi.me() إطلاقاً إن لم يوجد توكن محفوظ', () async {
      when(() => mockTokenStorage.hasToken()).thenAnswer((_) async => false);

      await provider.loadMe();

      expect(provider.isLoggedIn, isFalse);
      verifyNever(() => mockAuthApi.me());
    });

    test('يستعيد الجلسة من التوكن المحفوظ عند وجوده', () async {
      when(() => mockTokenStorage.hasToken()).thenAnswer((_) async => true);
      when(() => mockAuthApi.me()).thenAnswer((_) async => _sampleUser());

      var authenticatedCalled = false;
      provider.onAuthenticated = () async {
        authenticatedCalled = true;
      };

      await provider.loadMe();

      expect(provider.isLoggedIn, isTrue);
      expect(authenticatedCalled, isTrue);
    });
  });
}
