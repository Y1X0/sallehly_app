// [SEC-FIX-CHATCLEAR-01] راجع DECISIONS.md — clear() تُستدعى من app.dart عند
// تسجيل الخروج/الدخول، حتى لا يبقى محتوى تذاكر/رسائل دعم (قد تتضمن شكاوى
// شخصية) لحساب سابق بالذاكرة على جهاز مشترك.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/features/support/provider/support_provider.dart';
import 'package:sallehly_app/models/support_message_model.dart';
import 'package:sallehly_app/models/support_ticket_model.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  test('SupportProvider.clear() يُفرّغ التذاكر والرسائل المخبَّأة', () {
    final provider = SupportProvider(apiClient: MockApiClient());

    provider.tickets = const [
      SupportTicketModel(id: 1, userId: 5, type: 'شكوى', title: 'عنوان', body: 'نص الشكوى', status: 'open'),
    ];
    provider.messages = const [
      SupportMessageModel(id: 1, ticketId: 1, senderId: 5, body: 'رسالة سرّية من حساب سابق'),
    ];
    provider.error = 'خطأ سابق';

    provider.clear();

    expect(provider.tickets, isEmpty);
    expect(provider.messages, isEmpty);
    expect(provider.error, isNull);
  });
}
