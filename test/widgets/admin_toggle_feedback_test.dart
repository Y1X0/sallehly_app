// [FIX-TOGGLEFEEDBACK-01] يتحقق من أن تبديل حالة مهنة (تفعيل/تعطيل) بشاشة
// AdminMetaScreen يُظهر رسالة خطأ حقيقية عند فشل الطلب — قبل هذا الإصلاح،
// onToggle كان يستدعي admin.toggleService(...) مباشرة بلا await ولا
// try/catch، فأي فشل فعلي (شبكة، 403، 500) كان يمر بصمت تماماً بلا أي
// مؤشّر للأدمن.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/admin/data/admin_api.dart';
import 'package:sallehly_app/features/admin/provider/admin_provider.dart';
import 'package:sallehly_app/features/admin/screens/admin_meta_screen.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockAdminApi extends Mock implements AdminApi {}

Future<void> _pumpUntilSettledIgnoringAnimation(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets(
    '[FIX-TOGGLEFEEDBACK-01] تبديل حالة مهنة فاشل يُظهر رسالة خطأ حقيقية، لا يمر بصمت',
    (tester) async {
      final mockApi = MockAdminApi();
      when(() => mockApi.getMeta()).thenAnswer((_) async => {'packages': []});
      when(() => mockApi.getAllServices()).thenAnswer(
        (_) async => [
          {'id': 1, 'name': 'كهربائي', 'icon': '🔧', 'is_active': 1},
        ],
      );
      when(() => mockApi.toggleService(any(), any()))
          .thenThrow(Exception('network failure'));

      final provider = AdminProvider(
        apiClient: MockApiClient(),
        apiOverride: mockApi,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AdminMetaScreen()),
          ),
        ),
      );

      await _pumpUntilSettledIgnoringAnimation(tester);

      expect(find.byType(Switch), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await _pumpUntilSettledIgnoringAnimation(tester);

      // [FIX-TOGGLEFEEDBACK-01] قبل الإصلاح: لا شيء يظهر إطلاقاً هنا رغم
      // فشل الطلب فعلياً (toggleService رُميت استثناءً). بعده: SnackBar خطأ.
      expect(find.text('تعذر تعديل البيانات'), findsOneWidget);
    },
  );
}
