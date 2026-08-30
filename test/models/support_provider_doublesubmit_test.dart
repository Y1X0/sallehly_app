// [SEC-FIX-DOUBLESUBMIT-01] راجع DECISIONS.md — نفس فئة الخطأ: زر فتح تذكرة
// دعم/إرسال رسالة كان يعتمد حصراً على `sending ? null : onPressed` بالواجهة
// بلا أي حارس فعلي داخل SupportProvider نفسها. السيناريو العدائي: استدعاء
// createTicket()/sendMessage() مرتين بلا await بين الاستدعاءين — يثبت أن
// طلباً حقيقياً واحداً فقط يصل للخادم.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/support/data/support_api.dart';
import 'package:sallehly_app/features/support/provider/support_provider.dart';
import 'package:sallehly_app/models/support_ticket_model.dart';

class MockSupportApi extends Mock implements SupportApi {}

class MockApiClient extends Mock implements ApiClient {}

SupportTicketModel _sampleTicket() => const SupportTicketModel(
      id: 1,
      userId: 5,
      type: 'شكوى',
      title: 'عنوان تجريبي',
      body: 'نص تجريبي',
      status: 'open',
    );

void main() {
  late MockSupportApi mockApi;
  late SupportProvider provider;

  setUp(() {
    mockApi = MockSupportApi();
    provider = SupportProvider(
      apiClient: MockApiClient(),
      apiOverride: mockApi,
    );
  });

  test(
    'createTicket: استدعاءان متزامنان (بلا انتظار الأول) ينشئان تذكرة واحدة فقط',
    () async {
      when(
        () => mockApi.createTicket(
          type: any(named: 'type'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return _sampleTicket();
      });
      when(() => mockApi.getMyTickets()).thenAnswer((_) async => [_sampleTicket()]);

      final first = provider.createTicket(
        type: 'شكوى',
        title: 'عنوان تجريبي',
        body: 'نص تجريبي',
      );
      final second = provider.createTicket(
        type: 'شكوى',
        title: 'عنوان تجريبي',
        body: 'نص تجريبي',
      );

      await first;
      await second;

      verify(
        () => mockApi.createTicket(
          type: any(named: 'type'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).called(1);
    },
  );

  test(
    'sendMessage: استدعاءان متزامنان (بلا انتظار الأول) يُرسلان رسالة واحدة فقط',
    () async {
      when(
        () => mockApi.sendMessage(
          ticketId: any(named: 'ticketId'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
      });
      when(() => mockApi.getMessages(any())).thenAnswer((_) async => []);

      final first = provider.sendMessage(ticketId: 1, body: 'مرحباً');
      final second = provider.sendMessage(ticketId: 1, body: 'مرحباً');

      await first;
      await second;

      verify(
        () => mockApi.sendMessage(
          ticketId: any(named: 'ticketId'),
          body: any(named: 'body'),
        ),
      ).called(1);
    },
  );
}
