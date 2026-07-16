// [FIX-CUSTFILTER-01] يتحقق من أن فلاتر شاشة "طلباتي" (الكل/نشطة/مكتملة/
// ملغاة) تبدّل القائمة المعروضة فوراً محلياً (بلا أي طلب شبكة إضافي)، وأن
// العدّاد بجانب كل فلتر صحيح، وأن حالة "لا نتائج" الخاصة بالفلتر (وليست
// الحالة العامة "لا يوجد طلبات بعد") تظهر حين لا يوجد أي طلب يطابق الفلتر
// المختار رغم وجود طلبات أخرى.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/customer/screens/customer_requests_screen.dart';
import 'package:sallehly_app/features/requests/data/requests_api.dart';
import 'package:sallehly_app/features/requests/provider/requests_provider.dart';
import 'package:sallehly_app/models/request_model.dart';

class MockRequestsApi extends Mock implements RequestsApi {}

class MockApiClient extends Mock implements ApiClient {}

RequestModel _req({required int id, required String status, required String service}) {
  return RequestModel(
    id: id,
    customerId: 1,
    service: service,
    city: 'عمان',
    description: 'وصف تجريبي طويل بما فيه الكفاية لتجاوز التحقق',
    status: status,
  );
}

Future<void> _pump(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'الفلاتر تبدّل القائمة فوراً وتُظهر العدّاد الصحيح لكل فلتر',
    (tester) async {
      final mockApi = MockRequestsApi();
      when(() => mockApi.getRequests()).thenAnswer((_) async => [
            _req(id: 1, status: 'بانتظار العروض', service: 'كهربائي نشط'),
            _req(id: 2, status: 'قيد التنفيذ', service: 'سباك نشط'),
            _req(id: 3, status: 'مكتمل', service: 'نجار مكتمل'),
            _req(id: 4, status: 'ملغي', service: 'دهان ملغي'),
          ]);

      final provider = RequestsProvider(
        apiClient: MockApiClient(),
        apiOverride: mockApi,
      );

      // القائمة تحوي أربع بطاقات طلب كاملة + بطاقة ملخص + شريط فلاتر — أكبر
      // من ارتفاع الشاشة الافتراضي بالاختبارات (600px)، فتبقى بعض البطاقات
      // خارج نطاق التخطيط اللازي لـSliverList ولا تُبنى إطلاقاً. نوسّع سطح
      // الاختبار حتى تُبنى كل البطاقات فعلياً بدل الاعتماد على تمرير يدوي.
      await tester.binding.setSurfaceSize(const Size(900, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: CustomerRequestsScreen()),
        ),
      );

      await _pump(tester);

      // الافتراضي: فلتر "الكل" — كل الطلبات الأربعة ظاهرة.
      expect(find.text('كهربائي نشط'), findsOneWidget);
      expect(find.text('سباك نشط'), findsOneWidget);
      expect(find.text('نجار مكتمل'), findsOneWidget);
      expect(find.text('دهان ملغي'), findsOneWidget);
      expect(find.text('الكل (4)'), findsOneWidget);
      expect(find.text('نشطة (2)'), findsOneWidget);
      expect(find.text('مكتملة (1)'), findsOneWidget);
      expect(find.text('ملغاة (1)'), findsOneWidget);

      // اختيار فلتر "نشطة" — يظهر فقط الطلبان النشطان، فوراً بلا انتظار شبكة.
      await tester.tap(find.text('نشطة (2)'));
      await tester.pump();

      expect(find.text('كهربائي نشط'), findsOneWidget);
      expect(find.text('سباك نشط'), findsOneWidget);
      expect(find.text('نجار مكتمل'), findsNothing);
      expect(find.text('دهان ملغي'), findsNothing);

      // فلتر "مكتملة" — طلب واحد فقط.
      await tester.tap(find.text('مكتملة (1)'));
      await tester.pump();

      expect(find.text('نجار مكتمل'), findsOneWidget);
      expect(find.text('كهربائي نشط'), findsNothing);
      expect(find.text('سباك نشط'), findsNothing);
      expect(find.text('دهان ملغي'), findsNothing);

      // getRequests لم يُستدعَ إلا مرة واحدة (تحميل أولي) — التبديل بين
      // الفلاتر لم يُطلق أي طلب شبكة إضافي (تصفية محلية بحتة).
      verify(() => mockApi.getRequests()).called(1);
    },
  );

  testWidgets(
    'فلتر بلا أي نتائج يُظهر حالة فارغة خاصة بالفلتر (وليست "لا يوجد طلبات بعد" العامة) مع زر "عرض كل الطلبات"',
    (tester) async {
      final mockApi = MockRequestsApi();
      when(() => mockApi.getRequests()).thenAnswer((_) async => [
            _req(id: 1, status: 'بانتظار العروض', service: 'كهربائي نشط'),
          ]);

      final provider = RequestsProvider(
        apiClient: MockApiClient(),
        apiOverride: mockApi,
      );

      // القائمة تحوي أربع بطاقات طلب كاملة + بطاقة ملخص + شريط فلاتر — أكبر
      // من ارتفاع الشاشة الافتراضي بالاختبارات (600px)، فتبقى بعض البطاقات
      // خارج نطاق التخطيط اللازي لـSliverList ولا تُبنى إطلاقاً. نوسّع سطح
      // الاختبار حتى تُبنى كل البطاقات فعلياً بدل الاعتماد على تمرير يدوي.
      await tester.binding.setSurfaceSize(const Size(900, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: CustomerRequestsScreen()),
        ),
      );

      await _pump(tester);

      await tester.tap(find.text('مكتملة (0)'));
      await tester.pump();

      expect(find.text('لا يوجد طلبات بعد'), findsNothing);
      expect(find.text('لا توجد طلبات مكتملة بعد'), findsOneWidget);
      expect(find.text('عرض كل الطلبات'), findsOneWidget);

      await tester.tap(find.text('عرض كل الطلبات'));
      await tester.pump();

      expect(find.text('كهربائي نشط'), findsOneWidget);
    },
  );
}
