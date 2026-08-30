// [SEC-FIX-ADMINDOUBLESUBMIT-01] راجع DECISIONS.md — نفس فئة
// SEC-FIX-DOUBLESUBMIT-01: `actionLoading` بـAdminProvider يُكتَب بـ17 دالة
// كتابة مختلفة لكن لا يُقرَأ كحارس بأي منها — تعطيل الزر بالواجهة وحده لا
// يمنع نداءين حقيقيين متتاليين وصلا بلا await بينهما (ضغطتان أسرع من إطار
// رسم واحد). هذا الاختبار يغطي الطريقتين اللتين تحرِّكان أموالاً فعلياً:
// reviewTopup (اعتماد/رفض شحن رصيد) وadjustUserBalance (تعديل رصيد يدوي).
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/admin/data/admin_api.dart';
import 'package:sallehly_app/features/admin/provider/admin_provider.dart';
import 'package:sallehly_app/models/admin_stats_model.dart';
import 'package:sallehly_app/models/admin_user_model.dart';

class MockAdminApi extends Mock implements AdminApi {}

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockAdminApi mockApi;
  late AdminProvider provider;

  setUp(() {
    mockApi = MockAdminApi();
    provider = AdminProvider(apiClient: MockApiClient(), apiOverride: mockApi);

    when(() => mockApi.getStats()).thenAnswer((_) async => AdminStatsModel.empty);
    when(() => mockApi.getUsers()).thenAnswer((_) async => <AdminUserModel>[]);
    when(() => mockApi.getTopups()).thenAnswer((_) async => <Map<String, dynamic>>[]);
  });

  test(
    'reviewTopup: استدعاءان متزامنان (بلا انتظار الأول) يُرسلان طلب مراجعة واحداً فقط للخادم',
    () async {
      when(
        () => mockApi.reviewTopup(
          id: any(named: 'id'),
          status: any(named: 'status'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
      });

      final first = provider.reviewTopup(id: 7, status: 'approved');
      final second = provider.reviewTopup(id: 7, status: 'approved');

      await first;
      await second;

      verify(
        () => mockApi.reviewTopup(
          id: any(named: 'id'),
          status: any(named: 'status'),
          note: any(named: 'note'),
        ),
      ).called(1);
    },
  );

  test(
    'adjustUserBalance: استدعاءان متزامنان (بلا انتظار الأول) يُرسلان طلب تعديل رصيد واحداً فقط للخادم',
    () async {
      when(
        () => mockApi.adjustUserBalance(
          id: any(named: 'id'),
          amount: any(named: 'amount'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 50;
      });

      final first = provider.adjustUserBalance(id: 9, amount: 20, reason: 'تصحيح يدوي');
      final second = provider.adjustUserBalance(id: 9, amount: 20, reason: 'تصحيح يدوي');

      await first;
      await second;

      verify(
        () => mockApi.adjustUserBalance(
          id: any(named: 'id'),
          amount: any(named: 'amount'),
          reason: any(named: 'reason'),
        ),
      ).called(1);
    },
  );
}
