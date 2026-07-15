// [FIX-BADGE-01] يتحقق من سيناريو العلة الأصلي بالضبط: طلبان متاحان، قبول
// عرض على أحدهما يُنقص العداد إلى 1 فوراً (محلياً، دون انتظار الشبكة)، وقبول
// عرض على الأخير يُصفّر العداد. يتحقق أيضاً أن عدّاد الإشعارات غير المقروءة
// (الجرس) مستقل تماماً ولا يتأثر بأي من ذلك.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/requests/data/requests_api.dart';
import 'package:sallehly_app/features/requests/provider/requests_provider.dart';
import 'package:sallehly_app/models/request_model.dart';
import 'package:sallehly_app/models/notification_model.dart';
import 'package:sallehly_app/providers/notification_provider.dart';
import 'package:sallehly_app/models/user_model.dart';

class MockRequestsApi extends Mock implements RequestsApi {}

class MockApiClient extends Mock implements ApiClient {}

RequestModel _req({required int id, required String status, int? technicianId}) {
  return RequestModel(
    id: id,
    customerId: 10,
    technicianId: technicianId,
    service: 'كهربائي',
    city: 'عمان',
    description: 'وصف تجريبي طويل بما فيه الكفاية لتجاوز التحقق',
    status: status,
  );
}

void main() {
  group('availableNewRequestsCount (تبويب "جديدة" للفني)', () {
    late MockRequestsApi mockApi;
    late RequestsProvider provider;

    setUp(() {
      mockApi = MockRequestsApi();
      provider = RequestsProvider(apiClient: MockApiClient(), apiOverride: mockApi);
    });

    test('يعكس فقط الطلبات المنتظرة/التي وصلتها عروض، لا كل الطلبات', () async {
      when(() => mockApi.getRequests()).thenAnswer((_) async => [
            _req(id: 1, status: 'بانتظار العروض'),
            _req(id: 2, status: 'وصلت عروض'),
            _req(id: 3, status: 'تم اختيار عرض', technicianId: 99),
            _req(id: 4, status: 'مكتمل', technicianId: 99),
            _req(id: 5, status: 'ملغي'),
          ]);

      await provider.loadRequests();

      expect(provider.availableNewRequestsCount, 2);
    });

    test(
      'مثال المستخدم بالضبط: طلبان متاحان → قبول عرض على أحدهما ينزل العداد '
      'لـ1 فوراً (محلياً)، وقبول الأخير يُصفّره',
      () async {
        when(() => mockApi.getRequests()).thenAnswer((_) async => [
              _req(id: 1, status: 'وصلت عروض'),
              _req(id: 2, status: 'وصلت عروض'),
            ]);

        await provider.loadRequests();
        expect(provider.availableNewRequestsCount, 2);

        // محاكاة وصول حدث Socket.IO "requests-updated" فور قبول عرض الطلب 1 —
        // هذا بالضبط ما يستدعيه SocketProvider محلياً قبل إعادة الجلب الصامت.
        provider.applyRequestStatusUpdate(
          requestId: 1,
          status: 'تم اختيار عرض',
          technicianId: 77,
        );

        expect(provider.availableNewRequestsCount, 1);
        expect(provider.requests.length, 2); // لم يُحذف الطلب، فقط تغيّرت حالته

        provider.applyRequestStatusUpdate(
          requestId: 2,
          status: 'تم اختيار عرض',
          technicianId: 88,
        );

        expect(provider.availableNewRequestsCount, 0);
      },
    );

    test('لا يغيّر شيئاً إذا كان الطلب غير موجود محلياً (لا يوجد ما يُحدَّث)', () async {
      when(() => mockApi.getRequests()).thenAnswer((_) async => [
            _req(id: 1, status: 'وصلت عروض'),
          ]);
      await provider.loadRequests();

      provider.applyRequestStatusUpdate(requestId: 999, status: 'تم اختيار عرض');

      expect(provider.availableNewRequestsCount, 1);
    });
  });

  group('استقلالية العدّادات (لا يجوز لأحدهما أن يطغى على الآخر)', () {
    test('unreadNotificationsCount لا يتأثر بقائمة الطلبات المتاحة إطلاقاً', () {
      final notify = NotificationProvider();
      notify.setCurrentUser(
        const UserModel(
          id: 1,
          role: 'technician',
          name: 'فني',
          email: 'tech@example.com',
          phone: '0790000000',
          rating: 0,
          balance: 0,
          active: true,
        ),
      );

      expect(notify.unreadNotificationsCount, 0);

      notify.addNotification(
        title: 'طلب جديد',
        body: 'تجريبي',
        type: 'request',
        sound: false,
      );

      expect(notify.unreadNotificationsCount, 1);
      expect(notify.items, isA<List<NotificationModel>>());

      // قراءة الإشعار الوحيد يجب أن يُصفّر عدّاد الجرس فقط.
      notify.markNotificationRead(notify.items.first.id);
      expect(notify.unreadNotificationsCount, 0);
    });
  });
}
