// [SEC-FIX-COMPLETEREQUEST-01] يتحقق من أن ضغط "إنهاء الطلب" الفاشل بشاشة
// CustomerRequestDetailsScreen يُظهر رسالة خطأ حقيقية — قبل هذا الإصلاح،
// onPressed كان يستدعي provider.completeRequest(...) بلا try/catch، فأي فشل
// فعلي (شبكة، خادم مستيقظ ببطء) كان يمر بصمت: الزر يتوقف عن الدوران بلا أي
// رسالة ولا انتقال، والمستخدم لا يعرف هل اكتمل الطلب فعلاً أم لا. نفس نمط
// admin_toggle_feedback_test.dart بالضبط.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/customer/screens/customer_request_details_screen.dart';
import 'package:sallehly_app/features/requests/data/requests_api.dart';
import 'package:sallehly_app/features/requests/provider/requests_provider.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';
import 'package:sallehly_app/models/request_model.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockRequestsApi extends Mock implements RequestsApi {}

RequestModel _inProgressRequest() {
  return RequestModel(
    id: 7,
    customerId: 1,
    service: 'كهربائي',
    city: 'عمان',
    description: 'وصف تجريبي كافٍ للطول لاختبار زر إنهاء الطلب',
    status: 'قيد التنفيذ',
  );
}

void main() {
  testWidgets(
    '[SEC-FIX-COMPLETEREQUEST-01] إنهاء طلب فاشل يُظهر رسالة خطأ حقيقية، لا يمر بصمت',
    (tester) async {
      final mockApi = MockRequestsApi();
      when(() => mockApi.updateStatus(requestId: any(named: 'requestId'), status: any(named: 'status')))
          .thenThrow(Exception('network failure'));

      final provider = RequestsProvider(apiClient: MockApiClient(), apiOverride: mockApi);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: CustomerRequestDetailsScreen(request: _inProgressRequest())),
          ),
        ),
      );
      // لا pumpAndSettle هنا — AppBackground يحمل AnimationController دائم
      // التكرار (..repeat())، فلن يستقر إطلاقاً. عدد ثابت من pump() يكفي
      // لتفريغ تأخيرات FadeIn (حتى 210ms) وحركة دخول/خروج SnackBar.
      await tester.pump(const Duration(milliseconds: 300));

      final t = AppLocalizations.of(tester.element(find.byType(CustomerRequestDetailsScreen)))!;
      await tester.tap(find.text(t.completeRequestButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(t.completeRequestFailedMessage), findsOneWidget);
      // الشاشة لم تُغلَق (Navigator.pop لا يُستدعى إلا عند النجاح فعلاً).
      expect(find.byType(CustomerRequestDetailsScreen), findsOneWidget);
    },
  );
}
