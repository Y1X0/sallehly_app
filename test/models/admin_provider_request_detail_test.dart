// [FEAT-ADMINREQUESTDETAIL-01] راجع DECISIONS.md — AdminProvider.loadRequestDetail/
// clearRequestDetail، نفس نمط loadUserDetail/clearUserDetail تماماً.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/admin/data/admin_api.dart';
import 'package:sallehly_app/features/admin/provider/admin_provider.dart';

class MockAdminApi extends Mock implements AdminApi {}

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockAdminApi mockApi;
  late AdminProvider provider;

  setUp(() {
    mockApi = MockAdminApi();
    provider = AdminProvider(apiClient: MockApiClient(), apiOverride: mockApi);
  });

  test('loadRequestDetail: عند النجاح يملأ requestDetail ويصفّر requestDetailError', () async {
    when(() => mockApi.getRequestDetail(7)).thenAnswer((_) async => {
          'request': {'id': 7, 'status': 'تم اختيار عرض'},
          'offers': <Map<String, dynamic>>[],
          'messages': <Map<String, dynamic>>[],
        });

    await provider.loadRequestDetail(7);

    expect(provider.requestDetail, isNotNull);
    expect(provider.requestDetail!['request']['id'], 7);
    expect(provider.requestDetailError, isNull);
    expect(provider.requestDetailLoading, isFalse);
  });

  test('loadRequestDetail: عند الفشل يضبط requestDetailError ويبقي requestDetail null', () async {
    when(() => mockApi.getRequestDetail(9)).thenThrow(Exception('network failure'));

    await provider.loadRequestDetail(9);

    expect(provider.requestDetail, isNull);
    expect(provider.requestDetailError, isNotNull);
    expect(provider.requestDetailLoading, isFalse);
  });

  test('clearRequestDetail: يصفّر requestDetail وrequestDetailError', () async {
    when(() => mockApi.getRequestDetail(3)).thenAnswer((_) async => {
          'request': {'id': 3},
          'offers': <Map<String, dynamic>>[],
          'messages': <Map<String, dynamic>>[],
        });
    await provider.loadRequestDetail(3);
    expect(provider.requestDetail, isNotNull);

    provider.clearRequestDetail();

    expect(provider.requestDetail, isNull);
    expect(provider.requestDetailError, isNull);
  });

  // [FEAT-ADMINREQUESTDETAIL-01] requestDetail يحمل محادثة خاصة كاملة —
  // clear() (تُستدعى عند تسجيل الخروج، SEC-FIX-CHATCLEAR-01) يجب أن تمسحها
  // بنفس صرامة userDetail، لا أقل.
  test('clear(): يمسح requestDetail أيضاً (نفس صرامة مسح userDetail — يحمل محادثة خاصة)', () async {
    when(() => mockApi.getRequestDetail(5)).thenAnswer((_) async => {
          'request': {'id': 5},
          'offers': <Map<String, dynamic>>[],
          'messages': <Map<String, dynamic>>[
            {'sender_name': 'أحمد', 'body': 'رسالة خاصة'},
          ],
        });
    await provider.loadRequestDetail(5);
    expect(provider.requestDetail, isNotNull);

    provider.clear();

    expect(provider.requestDetail, isNull);
    expect(provider.requestDetailError, isNull);
  });
}
