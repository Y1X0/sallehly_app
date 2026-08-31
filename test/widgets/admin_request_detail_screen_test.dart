// [FEAT-ADMINREQUESTDETAIL-01] راجع DECISIONS.md — AdminRequestDetailScreen
// أول شاشة تعرض صورة كاملة لطلب واحد (الطلب + العروض + المحادثة) بمكان
// واحد، والوسيلة الوحيدة فعلياً لأدمن ليقرأ محادثة طلب — الصلاحية موجودة
// أصلاً بالسيرفر (canAccessRequestChat) لكن بلا هذه الشاشة لا شيء يستدعيها.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/admin/data/admin_api.dart';
import 'package:sallehly_app/features/admin/provider/admin_provider.dart';
import 'package:sallehly_app/features/admin/screens/admin_request_detail_screen.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockAdminApi extends Mock implements AdminApi {}

Future<void> _pumpUntilSettledIgnoringAnimation(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Widget _wrap(AdminProvider provider, Widget child) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets(
    '[FEAT-ADMINREQUESTDETAIL-01] طلب مكتمل الخطوات: يعرض اسم العميل/الفني، العرض، والمحادثة الكاملة',
    (tester) async {
      final mockApi = MockAdminApi();
      when(() => mockApi.getRequestDetail(11)).thenAnswer((_) async => {
            'request': {
              'id': 11,
              'service': 'كهربائي',
              'status': 'تم اختيار عرض',
              'city': 'عمان',
              'area': 'القويسمة',
              'customer_name': 'عميل النزاع',
              'customer_phone': '0790000001',
              'technician_name': 'فني النزاع',
              'technician_phone': '0790000002',
              'commission_charged': null,
              'cancel_reason': null,
              'cancelled_by_name': null,
              'cancelled_at': null,
            },
            'offers': [
              {
                'id': 1,
                'technician_name': 'فني النزاع',
                'price': 25,
                'duration': 'خلال ساعة',
                'status': 'accepted',
                'created_at': '2026-01-01T10:00:00.000Z',
              },
            ],
            'messages': [
              {'sender_name': 'عميل النزاع', 'body': 'متى تصل؟', 'created_at': '2026-01-01T10:05:00.000Z'},
              {'sender_name': 'فني النزاع', 'body': 'بعد 20 دقيقة', 'created_at': '2026-01-01T10:06:00.000Z'},
            ],
          });

      final provider = AdminProvider(apiClient: MockApiClient(), apiOverride: mockApi);

      await tester.pumpWidget(_wrap(provider, const AdminRequestDetailScreen(requestId: 11)));
      await _pumpUntilSettledIgnoringAnimation(tester);

      expect(find.textContaining('عميل النزاع'), findsWidgets);
      expect(find.textContaining('فني النزاع'), findsWidgets);
      expect(find.textContaining('خلال ساعة'), findsOneWidget);
      expect(find.text('متى تصل؟'), findsOneWidget);
      expect(find.text('بعد 20 دقيقة'), findsOneWidget);
      // لا قسم إلغاء يظهر لطلب غير ملغي.
      expect(find.text('سبب الإلغاء'), findsNothing);
    },
  );

  testWidgets(
    '[FEAT-ADMINREQUESTDETAIL-01] طلب مُلغى من الأدمن: سبب الإلغاء ومن ألغى ومتى تظهر كلها',
    (tester) async {
      final mockApi = MockAdminApi();
      when(() => mockApi.getRequestDetail(22)).thenAnswer((_) async => {
            'request': {
              'id': 22,
              'service': 'سباكة',
              'status': 'ملغي',
              'city': 'عمان',
              'area': null,
              'customer_name': 'عميل ٢',
              'customer_phone': '0790000003',
              'technician_name': null,
              'technician_phone': null,
              'commission_charged': null,
              'cancel_reason': 'العميل والفني لم يتفقا على السعر',
              'cancelled_by_name': 'أدمن الاختبار',
              'cancelled_at': '2026-01-02T09:00:00.000Z',
            },
            'offers': <Map<String, dynamic>>[],
            'messages': <Map<String, dynamic>>[],
          });

      final provider = AdminProvider(apiClient: MockApiClient(), apiOverride: mockApi);

      await tester.pumpWidget(_wrap(provider, const AdminRequestDetailScreen(requestId: 22)));
      await _pumpUntilSettledIgnoringAnimation(tester);

      expect(find.textContaining('العميل والفني لم يتفقا على السعر'), findsOneWidget);
      expect(find.textContaining('أدمن الاختبار'), findsOneWidget);
      // لا عروض ولا رسائل — الحالات الفارغة تظهر بلا أي خطأ.
      expect(find.text('لا يوجد'), findsOneWidget);
      expect(find.text('لا توجد رسائل بعد'), findsOneWidget);
    },
  );

  testWidgets(
    '[FEAT-ADMINREQUESTDETAIL-01] فشل الجلب: رسالة خطأ حقيقية تظهر، لا شاشة فارغة',
    (tester) async {
      final mockApi = MockAdminApi();
      when(() => mockApi.getRequestDetail(33)).thenThrow(Exception('network failure'));

      final provider = AdminProvider(apiClient: MockApiClient(), apiOverride: mockApi);

      await tester.pumpWidget(_wrap(provider, const AdminRequestDetailScreen(requestId: 33)));
      await _pumpUntilSettledIgnoringAnimation(tester);

      expect(find.text('تعذّر تحميل تفاصيل الطلب'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    },
  );
}
