// LoginScreen بلا أي اختبار سابق رغم أنها أول شاشة يتفاعل معها كل مستخدم
// عائد. يغطي: فحوصات صحة الحقول قبل أي نداء شبكة، ونجاح الإرسال بالبيانات
// الصحيحة (استدعاء AuthProvider.login بالقيم المُدخلة فعلياً، بعد trim).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/features/auth/screens/login_screen.dart';
import 'package:sallehly_app/models/user_model.dart';
import 'package:sallehly_app/providers/auth_provider.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockAppStorage extends Mock implements AppStorage {}

class MockApiClient extends Mock implements ApiClient {}

UserModel _sampleUser() => UserModel(
      id: 1,
      role: 'customer',
      name: 'عميل',
      email: 'a@b.com',
      phone: '0790000000',
      rating: 0,
      balance: 0,
      active: true,
    );

// نفس نمط الملفات الأخرى: AppBackground تحوي حركة دائمة تمنع pumpAndSettle
// من الاستقرار أبداً.
Future<void> _pumpAnimated(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  late MockAuthApi mockAuthApi;
  late MockTokenStorage mockTokenStorage;
  late MockAppStorage mockAppStorage;
  late AuthProvider authProvider;

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

    authProvider = AuthProvider(
      tokenStorage: mockTokenStorage,
      apiClient: MockApiClient(),
      appStorage: mockAppStorage,
      authApiOverride: mockAuthApi,
    );
  });

  Widget wrap() => ChangeNotifierProvider.value(
        value: authProvider,
        child: const MaterialApp(home: LoginScreen()),
      );

  testWidgets('حقول فارغة: الضغط على "تسجيل الدخول" يُظهر أخطاء تحقق ولا يستدعي login()', (tester) async {
    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);

    await tester.tap(find.text('تسجيل الدخول'));
    await _pumpAnimated(tester);

    expect(find.text('أدخل البريد الإلكتروني'), findsOneWidget);
    expect(find.text('أدخل كلمة المرور'), findsOneWidget);
    verifyNever(() => mockAuthApi.login(email: any(named: 'email'), password: any(named: 'password')));
  });

  testWidgets('بريد بلا @: خطأ تحقق واضح، بلا نداء شبكة', (tester) async {
    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('تسجيل الدخول'));
    await _pumpAnimated(tester);

    expect(find.text('البريد الإلكتروني غير صحيح'), findsOneWidget);
    verifyNever(() => mockAuthApi.login(email: any(named: 'email'), password: any(named: 'password')));
  });

  testWidgets('بيانات صحيحة: يستدعي AuthProvider.login بالقيم المُدخلة فعلياً', (tester) async {
    when(() => mockAuthApi.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AuthResult(token: 'tok-123', user: _sampleUser()));

    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);

    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.tap(find.text('تسجيل الدخول'));
    // نجاح تسجيل الدخول يستدعي Navigator.pushAndRemoveUntil إلى الشاشة
    // الرئيسية الفعلية (CustomerLayout)، التي تحتاج شجرة Provider كاملة
    // (NotificationProvider، إلخ) غير مُجهَّزة هنا عمداً — هذا الاختبار يقيس
    // فقط أن LoginScreen استدعت AuthProvider.login بالقيم الصحيحة، وليس
    // سلوك الشاشة التالية بعد التنقل. أي استثناء ناتج عن غياب تلك الشجرة
    // متوقَّع تماماً ويُستهلَك هنا بأمان.
    await _pumpAnimated(tester, 3);
    tester.takeException();

    verify(() => mockAuthApi.login(email: 'user@example.com', password: 'secret123')).called(1);
  });

  testWidgets('كلمة مرور أقصر من 6 أحرف: خطأ تحقق، بلا نداء شبكة', (tester) async {
    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);

    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.enterText(find.byType(TextFormField).last, '123');
    await tester.tap(find.text('تسجيل الدخول'));
    await _pumpAnimated(tester);

    expect(find.text('كلمة المرور قصيرة'), findsOneWidget);
    verifyNever(() => mockAuthApi.login(email: any(named: 'email'), password: any(named: 'password')));
  });

  testWidgets('زر إظهار/إخفاء كلمة المرور يبدّل obscureText', (tester) async {
    await tester.pumpWidget(wrap());
    await _pumpAnimated(tester);

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await _pumpAnimated(tester);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
}
