// [FIX-EMPTYSTATE-02] يتحقق من أن شاشتي المحفظة (الرئيسية والباقات) تُظهران
// رسالة الخطأ الحقيقية عند فشل الجلب، بدل رسالة "لا توجد بيانات" المضلِّلة —
// بنفس نمط الإصلاح المُتحقّق منه مسبقاً في customer_requests_screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/features/wallet/provider/wallet_provider.dart';
import 'package:sallehly_app/features/wallet/screens/packages_screen.dart';
import 'package:sallehly_app/features/wallet/screens/wallet_screen.dart';
import 'package:sallehly_app/providers/auth_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockAuthApi extends Mock implements AuthApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockAppStorage extends Mock implements AppStorage {}

// WalletScreen وPackagesScreen يستخدمان AppBackground (خلفية متحركة) التي
// تحوي AnimationController..repeat() دائم الحركة — نفس السبب الموثّق بـ
// my_reviews_error_state_test.dart. pumpAndSettle() لا يتوقف أبداً مع
// أنيميشن متكرر بلا نهاية، فنستخدم دفعات pump() بمهلة محددة بدلاً منه.
Future<void> _pumpSteps(WidgetTester tester, {int steps = 6}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

// WalletScreen يقرأ AuthProvider أيضاً (لعرض الرصيد)، فلا بد من توفيره كأب
// حتى لو لم تُستدعَ أي دالة دخول فعلية هنا.
AuthProvider _fakeAuthProvider() {
  return AuthProvider(
    tokenStorage: MockTokenStorage(),
    apiClient: MockApiClient(),
    appStorage: MockAppStorage(),
    authApiOverride: MockAuthApi(),
  );
}

void main() {
  testWidgets(
    'WalletScreen يُظهر رسالة خطأ حقيقية (وليس "لا توجد بيانات") عند فشل جلب المحفظة',
    (tester) async {
      final provider = WalletProvider(apiClient: MockApiClient());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: _fakeAuthProvider()),
          ],
          child: const MaterialApp(home: WalletScreen()),
        ),
      );

      // initState يطلق loadWallet() عبر Future.microtask — الـApiClient غير
      // مهيّأ (Mock بلا stubbing) فيفشل الجلب فعلياً بنفس طريقة فشل شبكي حقيقي.
      await _pumpSteps(tester);

      expect(find.text('لا توجد طلبات شحن بعد'), findsNothing);
      expect(find.text('تعذّر تحميل المحفظة'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    },
  );

  testWidgets(
    'PackagesScreen يُظهر رسالة خطأ حقيقية (وليس "لا توجد باقات") عند فشل جلب الباقات',
    (tester) async {
      final provider = WalletProvider(apiClient: MockApiClient());

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: PackagesScreen()),
        ),
      );

      await _pumpSteps(tester);

      expect(find.text('لا توجد باقات حالياً'), findsNothing);
      expect(find.text('تعذّر تحميل الباقات'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    },
  );
}
