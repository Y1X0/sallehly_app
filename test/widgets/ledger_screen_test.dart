// [FEAT-DEDUP-01] راجع DECISIONS.md — LedgerScreen كانت "قريباً" ثابتة رغم أن
// WalletProvider.ledger/loadLedger() تعملان فعلياً. هذا الاختبار يتحقق من أن
// الشاشة تعرض حركات الدفتر الحقيقية (وليس نص "قريباً")، وأن حالتي الفراغ
// والخطأ الحقيقيتين ما زالتا تعملان كما بأي شاشة أخرى بالتطبيق.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/wallet/data/wallet_api.dart';
import 'package:sallehly_app/features/wallet/provider/wallet_provider.dart';
import 'package:sallehly_app/features/wallet/screens/ledger_screen.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';
import 'package:sallehly_app/models/ledger_model.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockWalletApi extends Mock implements WalletApi {}

// نفس سبب my_reviews_error_state_test.dart / wallet_error_state_test.dart:
// AppBackground تحوي AnimationController..repeat() دائم الحركة، فـ
// pumpAndSettle() لا يتوقف أبداً — نستخدم دفعات pump() بمهلة محددة بدلاً منه.
Future<void> _pumpSteps(WidgetTester tester, {int steps = 6}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _pumpApp(WidgetTester tester, WalletProvider provider) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LedgerScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'LedgerScreen يعرض حركات الدفتر الحقيقية من WalletProvider (لا نص "قريباً")',
    (tester) async {
      final mockApi = MockWalletApi();
      when(() => mockApi.getLedger()).thenAnswer(
        (_) async => [
          const LedgerModel(
            id: 1,
            userId: 5,
            type: 'شحن رصيد',
            amount: 20,
            balanceAfter: 20,
            note: 'تعبئة يدوية',
          ),
          const LedgerModel(
            id: 2,
            userId: 5,
            type: 'عمولة طلب',
            amount: -2,
            balanceAfter: 18,
            note: 'طلب #14',
          ),
        ],
      );

      final provider = WalletProvider(apiClient: MockApiClient(), apiOverride: mockApi);
      await _pumpApp(tester, provider);
      await _pumpSteps(tester);

      expect(find.text('قريباً'), findsNothing);
      expect(find.text('شحن رصيد'), findsOneWidget);
      expect(find.text('عمولة طلب'), findsOneWidget);
      expect(find.text('لا توجد عمليات بعد'), findsNothing);
      verify(() => mockApi.getLedger()).called(1);
    },
  );

  testWidgets(
    'LedgerScreen يعرض حالة الفراغ الحقيقية عند عدم وجود أي حركة',
    (tester) async {
      final mockApi = MockWalletApi();
      when(() => mockApi.getLedger()).thenAnswer((_) async => []);

      final provider = WalletProvider(apiClient: MockApiClient(), apiOverride: mockApi);
      await _pumpApp(tester, provider);
      await _pumpSteps(tester);

      expect(find.text('لا توجد عمليات بعد'), findsOneWidget);
    },
  );

  testWidgets(
    'LedgerScreen يُظهر رسالة خطأ حقيقية (وليس "لا توجد عمليات") عند فشل الجلب، ويعيد المحاولة عبر الزر',
    (tester) async {
      final mockApi = MockWalletApi();
      var callCount = 0;
      when(() => mockApi.getLedger()).thenAnswer((_) {
        callCount++;
        return Future<List<LedgerModel>>.error(Exception('network down'));
      });

      final provider = WalletProvider(apiClient: MockApiClient(), apiOverride: mockApi);
      await _pumpApp(tester, provider);
      await _pumpSteps(tester);

      expect(find.text('لا توجد عمليات بعد'), findsNothing);
      expect(find.text('تعذّر تحميل سجل العمليات'), findsOneWidget);
      expect(find.text('تعذر تحميل سجل العمليات'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(callCount, 1);

      await tester.tap(find.text('إعادة المحاولة'));
      await _pumpSteps(tester);

      expect(callCount, 2);
    },
  );

  testWidgets(
    'LedgerScreen يعرض مؤشر تحميل قبل اكتمال الجلب',
    (tester) async {
      final mockApi = MockWalletApi();
      final completer = Completer<List<LedgerModel>>();
      when(() => mockApi.getLedger()).thenAnswer((_) => completer.future);

      final provider = WalletProvider(apiClient: MockApiClient(), apiOverride: mockApi);
      await _pumpApp(tester, provider);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete([]);
      await _pumpSteps(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
