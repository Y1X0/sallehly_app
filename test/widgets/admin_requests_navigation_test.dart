// [FEAT-ADMINREQUESTDETAIL-01] راجع DECISIONS.md — قبل هذا الإصلاح، لا طريقة
// للأدمن يفتح تفاصيل طلب واحد إطلاقاً من شاشة القائمة — بطاقة الطلب كانت
// عرضاً فقط بلا أي onTap. هذا الاختبار يثبت أن الضغط على بطاقة طلب فعلياً
// يفتح AdminRequestDetailScreen بمعرّف الطلب الصحيح.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/admin/data/admin_api.dart';
import 'package:sallehly_app/features/admin/provider/admin_provider.dart';
import 'package:sallehly_app/features/admin/screens/admin_request_detail_screen.dart';
import 'package:sallehly_app/features/admin/screens/admin_requests_screen.dart';
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
    '[FEAT-ADMINREQUESTDETAIL-01] الضغط على بطاقة طلب بقائمة الأدمن يفتح شاشة تفاصيله بمعرّفه الصحيح',
    (tester) async {
      final mockApi = MockAdminApi();
      when(() => mockApi.getAllRequests()).thenAnswer((_) async => [
            {
              'id': 55,
              'service': 'كهربائي',
              'status': 'قيد التنفيذ',
              'city': 'عمان',
              'customer_name': 'عميل الملاحة',
              'technician_name': 'فني الملاحة',
            },
          ]);
      when(() => mockApi.getRequestDetail(55)).thenAnswer((_) async => {
            'request': {'id': 55, 'service': 'كهربائي', 'status': 'قيد التنفيذ'},
            'offers': <Map<String, dynamic>>[],
            'messages': <Map<String, dynamic>>[],
          });

      final provider = AdminProvider(apiClient: MockApiClient(), apiOverride: mockApi);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AdminRequestsScreen(),
          ),
        ),
      );
      await _pumpUntilSettledIgnoringAnimation(tester);

      expect(find.byType(AdminRequestDetailScreen), findsNothing);

      await tester.tap(find.textContaining('عميل الملاحة'));
      await _pumpUntilSettledIgnoringAnimation(tester);

      final detailScreen = tester.widget<AdminRequestDetailScreen>(find.byType(AdminRequestDetailScreen));
      expect(detailScreen.requestId, 55);
    },
  );

  testWidgets(
    '[FEAT-ADMINREQUESTDETAIL-01] الضغط على زر الإلغاء لا يفتح شاشة التفاصيل أيضاً (لا تضارب بين الإيماءتين)',
    (tester) async {
      final mockApi = MockAdminApi();
      when(() => mockApi.getAllRequests()).thenAnswer((_) async => [
            {
              'id': 66,
              'service': 'سباكة',
              'status': 'قيد التنفيذ',
              'city': 'عمان',
              'customer_name': 'عميل آخر',
            },
          ]);

      final provider = AdminProvider(apiClient: MockApiClient(), apiOverride: mockApi);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AdminRequestsScreen(),
          ),
        ),
      );
      await _pumpUntilSettledIgnoringAnimation(tester);

      await tester.tap(find.text('إلغاء الطلب'));
      await _pumpUntilSettledIgnoringAnimation(tester);

      // نافذة تأكيد الإلغاء ظهرت (سلوك زر الإلغاء الأصلي، لم يتأثر) — لا
      // شاشة تفاصيل فُتحت بدلاً منه.
      expect(find.byType(AdminRequestDetailScreen), findsNothing);
      expect(find.text('تأكيد الإلغاء'), findsOneWidget);
    },
  );
}
