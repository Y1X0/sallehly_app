// [FIX-EMPTYSTATE-06] MyReviewsScreen كانت بالفعل تتحقق من الخطأ قبل الحالة
// الفارغة (لا يوجد خطأ "إخفاء" هنا خلافاً لبقية الشاشات) — الإضافة الوحيدة
// هي زر "إعادة المحاولة" الصريح في حالة الخطأ، ليتّسق مع بقية شاشات هذه
// المرحلة. هذا الاختبار يتحقق من ظهور الزر ونجاح إعادة المحاولة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/features/technician/screens/my_reviews_screen.dart';
import 'package:sallehly_app/models/user_model.dart';
import 'package:sallehly_app/providers/auth_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockAuthApi extends Mock implements AuthApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockAppStorage extends Mock implements AppStorage {}

UserModel _sampleUser() {
  return UserModel(
    id: 1,
    role: 'technician',
    name: 'فني تجريبي',
    email: 'tech@test.com',
    phone: '0790000000',
    rating: 4.5,
    balance: 0,
    active: true,
  );
}

// AppBackground (المستخدَمة بهذه الشاشة) تحوي AnimationController..repeat()
// دائم الحركة — نستخدم دفعات pump() بمهلة محددة بدل pumpAndSettle().
Future<void> _pumpSteps(WidgetTester tester, {int steps = 6}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets(
    'MyReviewsScreen يُظهر رسالة الخطأ مع زر إعادة المحاولة، والضغط عليه يعيد المحاولة',
    (tester) async {
      final mockAuthApi = MockAuthApi();
      final mockTokenStorage = MockTokenStorage();
      final mockAppStorage = MockAppStorage();

      when(() => mockTokenStorage.clearToken()).thenAnswer((_) async {});
      when(() => mockTokenStorage.saveToken(any())).thenAnswer((_) async {});
      when(() => mockAppStorage.clear()).thenAnswer((_) async {});
      when(() => mockAppStorage.saveRole(any())).thenAnswer((_) async {});
      when(() => mockAppStorage.saveUserId(any())).thenAnswer((_) async {});
      when(() => mockAppStorage.saveUserName(any())).thenAnswer((_) async {});

      var callCount = 0;
      when(() => mockAuthApi.getReviews(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw Exception('فشل الاتصال بالخادم');
        return [];
      });

      final authProvider = AuthProvider(
        tokenStorage: mockTokenStorage,
        apiClient: MockApiClient(),
        appStorage: mockAppStorage,
        authApiOverride: mockAuthApi,
      );

      // نحقن المستخدم مباشرة (بدل استدعاء login) حتى تبدأ الشاشة وهي مسجَّلة
      // دخولها فعلياً - user هو حقل خاص، فنمرّ عبر loadMe مع token محفوظ.
      when(() => mockTokenStorage.hasToken()).thenAnswer((_) async => true);
      when(() => mockAuthApi.me()).thenAnswer((_) async => _sampleUser());
      await authProvider.loadMe();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authProvider,
          child: const MaterialApp(home: MyReviewsScreen()),
        ),
      );

      await _pumpSteps(tester);

      expect(find.text('تعذّر تحميل التقييمات'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      await _pumpSteps(tester);

      expect(find.text('تعذّر تحميل التقييمات'), findsNothing);
      expect(find.text('لا توجد تقييمات بعد.\nستظهر هنا بعد أن يقيّمك العملاء'),
          findsOneWidget);
    },
  );
}
