// [SEC-FIX-DOUBLESUBMIT-01] راجع DECISIONS.md — "يبدو حامياً لكنه ليس كذلك
// دائماً": زر شحن الرصيد كان يعتمد حصراً على `submitting ? null : onPressed`
// بالواجهة لمنع الإرسال المزدوج، بلا أي حارس فعلي داخل WalletProvider نفسها.
// السيناريو العدائي: استدعاء submitTopup() مرتين بلا await بين الاستدعاءين
// (بالضبط كضغطتين سريعتين على نفس الزر قبل أن تُعيد الواجهة رسم نفسها
// وتعطّل الزر بصرياً) — يثبت أن طلب شحن حقيقياً واحداً فقط يصل للخادم.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/wallet/data/wallet_api.dart';
import 'package:sallehly_app/features/wallet/provider/wallet_provider.dart';
import 'package:sallehly_app/models/topup_model.dart';

class MockWalletApi extends Mock implements WalletApi {}

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockWalletApi mockApi;
  late WalletProvider provider;

  setUp(() {
    mockApi = MockWalletApi();
    provider = WalletProvider(
      apiClient: MockApiClient(),
      apiOverride: mockApi,
    );
  });

  test(
    'submitTopup: استدعاءان متزامنان (بلا انتظار الأول) يُرسلان طلب شحن واحداً فقط',
    () async {
      when(
        () => mockApi.createTopup(
          packageId: any(named: 'packageId'),
          receiptPath: any(named: 'receiptPath'),
        ),
      ).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return const TopupModel(
          id: 1,
          packageId: 3,
          amount: 20,
          bonus: 2,
          status: 'pending',
        );
      });

      final first = provider.submitTopup(
        packageId: 3,
        receiptPath: '/tmp/receipt.jpg',
      );
      final second = provider.submitTopup(
        packageId: 3,
        receiptPath: '/tmp/receipt.jpg',
      );

      await first;
      await second;

      verify(
        () => mockApi.createTopup(
          packageId: any(named: 'packageId'),
          receiptPath: any(named: 'receiptPath'),
        ),
      ).called(1);
      expect(provider.topups, hasLength(1));
    },
  );
}
