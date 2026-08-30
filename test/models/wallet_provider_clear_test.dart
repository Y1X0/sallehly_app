// [SEC-FIX-CHATCLEAR-01] راجع DECISIONS.md — clear() تُستدعى من app.dart عند
// تسجيل الخروج/الدخول، حتى لا يبقى سجل شحن رصيد ودفتر حساب (بيانات مالية
// خاصة بحساب سابق) بالذاكرة على جهاز مشترك. packages/paymentMethods (قوائم
// مرجعية عامة، ليست خاصة بحساب) تبقى عمداً بلا تغيير — راجع تعليق clear()
// بالكود المصدري.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/wallet/provider/wallet_provider.dart';
import 'package:sallehly_app/models/ledger_model.dart';
import 'package:sallehly_app/models/package_model.dart';
import 'package:sallehly_app/models/topup_model.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  test('WalletProvider.clear() يُفرّغ topups وledger، ويبقي packages كما هي', () {
    final provider = WalletProvider(apiClient: MockApiClient());

    provider.topups = const [
      TopupModel(id: 1, packageId: 1, amount: 20, bonus: 2, status: 'pending'),
    ];
    provider.ledger = const [
      LedgerModel(id: 1, userId: 5, type: 'شحن رصيد', amount: 20, balanceAfter: 20),
    ];
    provider.packages = const [
      PackageModel(id: 1, name: 'باقة أساسية', amount: 20, bonus: 2, commissionPerOrder: 1),
    ];
    provider.error = 'خطأ سابق';

    provider.clear();

    expect(provider.topups, isEmpty);
    expect(provider.ledger, isEmpty);
    expect(provider.error, isNull);
    // بيانات مرجعية عامة — لا تُفرَّغ (لا فائدة أمنية، فقط تهدر استدعاء شبكة).
    expect(provider.packages, isNotEmpty);
  });
}
