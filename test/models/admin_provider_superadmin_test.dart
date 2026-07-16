// test/models/admin_provider_superadmin_test.dart
// [FIX-SUPERADMIN-01] اختبارات AdminProvider للقدرات الجديدة: بروفايل مستخدم
// كامل، تحويل الأدوار، توثيق الفني، دفتر الحساب، وحل المخالفات/البلاغات.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/api/api_exception.dart';
import 'package:sallehly_app/features/admin/data/admin_api.dart';
import 'package:sallehly_app/features/admin/provider/admin_provider.dart';
import 'package:sallehly_app/models/admin_user_model.dart';

class MockAdminApi extends Mock implements AdminApi {}

class MockApiClient extends Mock implements ApiClient {}

AdminUserModel _sampleUser({int id = 1, String role = 'technician'}) {
  return AdminUserModel(
    id: id,
    role: role,
    name: 'مستخدم اختبار',
    email: 'test@example.com',
    phone: '0791111111',
    balance: 0,
    active: true,
    ratingAvg: 0,
    ratingCount: 0,
    completedJobs: 0,
  );
}

void main() {
  late MockAdminApi mockApi;
  late AdminProvider provider;

  setUp(() {
    mockApi = MockAdminApi();
    provider = AdminProvider(apiClient: MockApiClient(), apiOverride: mockApi);
  });

  group('loadUserDetail', () {
    test('عند النجاح: يملأ userDetail ويصفّر userDetailLoading', () async {
      when(() => mockApi.getUserDetail(1)).thenAnswer((_) async => {
            'user': {'id': 1, 'name': 'فني اختبار'},
            'requestsAsCustomer': [],
            'requestsAsTechnician': [],
            'offers': [],
            'ledger': [],
            'moderation': {'violationsCount': 0, 'reportsAgainstCount': 0, 'complaintsFiledCount': 0},
          });

      await provider.loadUserDetail(1);

      expect(provider.userDetailLoading, isFalse);
      expect(provider.userDetail, isNotNull);
      expect(provider.userDetail!['user']['name'], 'فني اختبار');
      expect(provider.userDetailError, isNull);
    });

    test('عند الفشل: يسجّل رسالة الخطأ ولا يُبقي userDetailLoading معلّقاً', () async {
      when(() => mockApi.getUserDetail(1)).thenThrow(ApiException('تعذر تحميل بيانات المستخدم'));

      await provider.loadUserDetail(1);

      expect(provider.userDetailLoading, isFalse);
      expect(provider.userDetail, isNull);
      expect(provider.userDetailError, 'تعذر تحميل بيانات المستخدم');
    });

    test('clearUserDetail يصفّر الحالة', () async {
      when(() => mockApi.getUserDetail(1)).thenAnswer((_) async => {
            'user': {'id': 1},
            'requestsAsCustomer': [],
            'requestsAsTechnician': [],
            'offers': [],
            'ledger': [],
            'moderation': {'violationsCount': 0, 'reportsAgainstCount': 0, 'complaintsFiledCount': 0},
          });
      await provider.loadUserDetail(1);
      expect(provider.userDetail, isNotNull);

      provider.clearUserDetail();
      expect(provider.userDetail, isNull);
    });
  });

  group('changeUserRole', () {
    test('عند النجاح: يستدعي API بالحقول الصحيحة ويعيد تحميل المستخدمين', () async {
      when(() => mockApi.changeUserRole(
            id: 1,
            role: 'customer',
            nationalNumber: null,
            services: null,
            areas: null,
          )).thenAnswer((_) async => _sampleUser(role: 'customer'));
      when(() => mockApi.getUsers()).thenAnswer((_) async => [_sampleUser(role: 'customer')]);

      await provider.changeUserRole(id: 1, role: 'customer');

      expect(provider.users.single.role, 'customer');
      expect(provider.error, isNull);
    });

    test('عند الفشل (مثلاً رصيد متبقٍّ): يسجّل رسالة الخطأ ويعيد رميه', () async {
      when(() => mockApi.changeUserRole(
            id: 1,
            role: 'customer',
            nationalNumber: null,
            services: null,
            areas: null,
          )).thenThrow(ApiException('لا يمكن التحويل — رصيده الحالي 5 د.أ'));

      await expectLater(
        provider.changeUserRole(id: 1, role: 'customer'),
        throwsA(isA<ApiException>()),
      );

      expect(provider.error, 'لا يمكن التحويل — رصيده الحالي 5 د.أ');
      expect(provider.actionLoading, isFalse);
    });
  });

  group('verifyTechnician', () {
    test('عند النجاح: يعيد تحميل المستخدمين', () async {
      when(() => mockApi.verifyTechnician(1)).thenAnswer((_) async {});
      when(() => mockApi.getUsers()).thenAnswer((_) async => [_sampleUser()]);

      await provider.verifyTechnician(1);

      expect(provider.users, hasLength(1));
      expect(provider.error, isNull);
    });
  });

  group('loadLedger', () {
    test('عند النجاح: يملأ ledgerEntries وledgerTotal', () async {
      when(() => mockApi.getLedger(userId: null, limit: 100)).thenAnswer((_) async => {
            'entries': [
              {'id': 1, 'type': 'شحن رصيد', 'amount': 10},
            ],
            'total': 1,
          });

      await provider.loadLedger();

      expect(provider.ledgerEntries, hasLength(1));
      expect(provider.ledgerTotal, 1);
      expect(provider.ledgerLoading, isFalse);
    });

    test('بفلترة user_id: يمرّرها للـAPI', () async {
      when(() => mockApi.getLedger(userId: 7, limit: 100)).thenAnswer((_) async => {
            'entries': <Map<String, dynamic>>[],
            'total': 0,
          });

      await provider.loadLedger(userId: 7);

      verify(() => mockApi.getLedger(userId: 7, limit: 100)).called(1);
    });
  });

  group('updateViolationStatus / updateMessageReportStatus', () {
    test('updateViolationStatus يحدّث العنصر محلياً دون إعادة تحميل كامل القائمة', () async {
      provider.violations = [
        {'id': 5, 'status': 'مفتوح'},
      ];
      when(() => mockApi.updateViolationStatus(id: 5, status: 'تمت المراجعة'))
          .thenAnswer((_) async {});

      await provider.updateViolationStatus(id: 5, status: 'تمت المراجعة');

      expect(provider.violations.single['status'], 'تمت المراجعة');
      verifyNever(() => mockApi.getViolations());
    });

    test('updateMessageReportStatus يحدّث العنصر محلياً', () async {
      provider.messageReports = [
        {'id': 9, 'status': 'قيد المراجعة'},
      ];
      when(() => mockApi.updateMessageReportStatus(id: 9, status: 'تم اتخاذ إجراء'))
          .thenAnswer((_) async {});

      await provider.updateMessageReportStatus(id: 9, status: 'تم اتخاذ إجراء');

      expect(provider.messageReports.single['status'], 'تم اتخاذ إجراء');
    });
  });

  group('togglePackageActive', () {
    test('يستدعي updatePackage بنفس بيانات الباقة مع is_active معكوساً', () async {
      when(() => mockApi.updatePackage(
            id: 3,
            name: 'باقة العمل',
            amount: 20,
            bonus: 2,
            commissionPerOrder: 2,
            isActive: true,
          )).thenAnswer((_) async {});
      when(() => mockApi.getMeta()).thenAnswer((_) async => {'packages': []});
      when(() => mockApi.getAllServices()).thenAnswer((_) async => []);

      await provider.togglePackageActive({
        'id': 3, 'name': 'باقة العمل', 'amount': 20, 'bonus': 2, 'commission_per_order': 2, 'is_active': 0,
      });

      verify(() => mockApi.updatePackage(
            id: 3,
            name: 'باقة العمل',
            amount: 20,
            bonus: 2,
            commissionPerOrder: 2,
            isActive: true,
          )).called(1);
    });
  });
}
