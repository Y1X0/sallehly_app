// [FIX-TEST-01] اختبارات RequestsProvider — تغطي أهم مسارات العمل (تحميل
// الطلبات، إنشاء طلب، قبول/رفض عرض، إلغاء طلب) دون أي اتصال شبكة حقيقي.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/api/api_exception.dart';
import 'package:sallehly_app/features/requests/data/requests_api.dart';
import 'package:sallehly_app/features/requests/provider/requests_provider.dart';
import 'package:sallehly_app/models/request_model.dart';

class MockRequestsApi extends Mock implements RequestsApi {}

class MockApiClient extends Mock implements ApiClient {}

RequestModel _sampleRequest({int id = 1, String status = 'بانتظار العروض'}) {
  return RequestModel(
    id: id,
    customerId: 10,
    service: 'كهربائي',
    city: 'عمان',
    description: 'وصف تجريبي طويل بما فيه الكفاية لتجاوز التحقق',
    status: status,
  );
}

void main() {
  late MockRequestsApi mockApi;
  late RequestsProvider provider;

  setUp(() {
    mockApi = MockRequestsApi();
    provider = RequestsProvider(
      apiClient: MockApiClient(),
      apiOverride: mockApi,
    );
  });

  group('loadRequests', () {
    test('عند النجاح: يملأ القائمة ويبدّل loading صحيحاً', () async {
      when(() => mockApi.getRequests())
          .thenAnswer((_) async => [_sampleRequest()]);

      expect(provider.loading, isFalse);
      final future = provider.loadRequests();
      // يجب أن يتحول loading لـtrue فوراً (بشكل متزامن) قبل اكتمال الطلب.
      expect(provider.loading, isTrue);

      await future;

      expect(provider.loading, isFalse);
      expect(provider.requests, hasLength(1));
      expect(provider.error, isNull);
    });

    test('عند الفشل: يسجّل رسالة الخطأ ولا يُبقي loading معلّقاً', () async {
      when(() => mockApi.getRequests())
          .thenThrow(ApiException('تعذر تحميل الطلبات'));

      await provider.loadRequests();

      expect(provider.error, 'تعذر تحميل الطلبات');
      expect(provider.loading, isFalse);
    });
  });

  group('createRequest', () {
    test('يستدعي الـAPI بالبيانات الصحيحة ثم يعيد تحميل القائمة', () async {
      when(
        () => mockApi.createRequest(
          service: any(named: 'service'),
          city: any(named: 'city'),
          area: any(named: 'area'),
          description: any(named: 'description'),
          preferredTime: any(named: 'preferredTime'),
          imagePath: any(named: 'imagePath'),
        ),
      ).thenAnswer((_) async => _sampleRequest());
      when(() => mockApi.getRequests())
          .thenAnswer((_) async => [_sampleRequest()]);

      await provider.createRequest(
        service: 'كهربائي',
        city: 'عمان',
        area: 'خلدا',
        description: 'وصف تجريبي طويل بما فيه الكفاية لتجاوز التحقق',
      );

      expect(provider.requests, hasLength(1));
      verify(
        () => mockApi.createRequest(
          service: 'كهربائي',
          city: 'عمان',
          area: 'خلدا',
          description: 'وصف تجريبي طويل بما فيه الكفاية لتجاوز التحقق',
          preferredTime: null,
          imagePath: null,
        ),
      ).called(1);
    });

    test('عند فشل الإنشاء: يرمي الاستثناء ولا يُحدَّث شيء بصمت', () async {
      when(
        () => mockApi.createRequest(
          service: any(named: 'service'),
          city: any(named: 'city'),
          area: any(named: 'area'),
          description: any(named: 'description'),
          preferredTime: any(named: 'preferredTime'),
          imagePath: any(named: 'imagePath'),
        ),
      ).thenThrow(ApiException('تعذر إنشاء الطلب'));

      await expectLater(
        provider.createRequest(
          service: 'كهربائي',
          city: 'عمان',
          area: 'خلدا',
          description: 'وصف تجريبي طويل بما فيه الكفاية لتجاوز التحقق',
        ),
        throwsA(isA<ApiException>()),
      );

      expect(provider.error, 'تعذر إنشاء الطلب');
      expect(provider.requests, isEmpty);
    });
  });

  group('acceptOffer', () {
    test('يرسل قرار accepted ثم يحدّث العروض والطلبات', () async {
      when(
        () => mockApi.decideOffer(
          offerId: any(named: 'offerId'),
          decision: any(named: 'decision'),
        ),
      ).thenAnswer((_) async => _sampleRequest(status: 'تم اختيار عرض'));
      when(() => mockApi.getOffers(any())).thenAnswer((_) async => []);
      when(() => mockApi.getRequests()).thenAnswer(
        (_) async => [_sampleRequest(status: 'تم اختيار عرض')],
      );

      final result = await provider.acceptOffer(requestId: 1, offerId: 5);

      expect(result?.status, 'تم اختيار عرض');
      verify(
        () => mockApi.decideOffer(offerId: 5, decision: 'accepted'),
      ).called(1);
      verify(() => mockApi.getOffers(1)).called(1);
    });
  });

  group('cancelRequest', () {
    test('يستدعي الإلغاء ثم يعيد تحميل القائمة', () async {
      when(() => mockApi.cancelRequest(any()))
          .thenAnswer((_) async => _sampleRequest(status: 'ملغي'));
      when(() => mockApi.getRequests()).thenAnswer((_) async => []);

      await provider.cancelRequest(1);

      verify(() => mockApi.cancelRequest(1)).called(1);
      expect(provider.requests, isEmpty);
    });
  });
}
