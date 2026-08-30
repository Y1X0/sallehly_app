// [SEC-FIX-CHATCLEAR-01] راجع DECISIONS.md — clear() تُستدعى من app.dart عند
// تسجيل الخروج/الدخول، حتى لا تبقى بيانات حسّاسة لمستخدمي المنصة كلهم (قائمة
// مستخدمين، سجل تدقيق، بلاغات، شكاوى، دفتر حساب) بالذاكرة على جهاز مشترك بين
// حسابَي أدمن. services/packages (قوائم مرجعية عامة) تبقى عمداً بلا تغيير.
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
  test('AdminProvider.clear() يُفرّغ كل البيانات الخاصة بحساب/مستخدمين، ويبقي services/packages', () {
    final provider = AdminProvider(apiClient: MockApiClient(), apiOverride: MockAdminApi());

    provider.stats = const AdminStatsModel(
      customers: 5, technicians: 5, requests: 10, pendingTopups: 1, completed: 3,
      cancelled: 1, cancelRate: 10, revenue: 100, suspendedUsers: 0, pendingVerification: 0,
    );
    provider.users = const [
      AdminUserModel(
        id: 1, role: 'customer', name: 'مستخدم', email: 'a@a.com', phone: '0700000000',
        balance: 0, active: true, ratingAvg: 0, ratingCount: 0, completedJobs: 0,
      ),
    ];
    provider.topups = [
      {'id': 1},
    ];
    provider.auditLogs = [
      {'id': 1},
    ];
    provider.auditTotal = 1;
    provider.allRequests = [
      {'id': 1},
    ];
    provider.violations = [
      {'id': 1},
    ];
    provider.complaints = [
      {'id': 1},
    ];
    provider.messageReports = [
      {'id': 1},
    ];
    provider.userDetail = {'id': 1};
    provider.ledgerEntries = [
      {'id': 1},
    ];
    provider.ledgerTotal = 1;
    provider.error = 'خطأ سابق';
    provider.services = [
      {'id': 1, 'name': 'كهربائي'},
    ];
    provider.packages = [
      {'id': 1, 'name': 'باقة'},
    ];

    provider.clear();

    expect(provider.stats.customers, 0);
    expect(provider.users, isEmpty);
    expect(provider.topups, isEmpty);
    expect(provider.auditLogs, isEmpty);
    expect(provider.auditTotal, 0);
    expect(provider.allRequests, isEmpty);
    expect(provider.violations, isEmpty);
    expect(provider.complaints, isEmpty);
    expect(provider.messageReports, isEmpty);
    expect(provider.userDetail, isNull);
    expect(provider.ledgerEntries, isEmpty);
    expect(provider.ledgerTotal, 0);
    expect(provider.error, isNull);
    // بيانات مرجعية عامة — لا تُفرَّغ.
    expect(provider.services, isNotEmpty);
    expect(provider.packages, isNotEmpty);
  });
}
