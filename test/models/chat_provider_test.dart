// [FIX-CHATUNREAD-01] اختبارات ChatProvider.loadChats — يتحقق من تعبئة قائمة
// المحادثات وعدّاد غير المقروء الكلي عند النجاح، وعدم بقاء chatsLoading
// معلّقاً عند الفشل، بنفس نمط requests_provider_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/api/api_exception.dart';
import 'package:sallehly_app/features/chat/data/chat_api.dart';
import 'package:sallehly_app/features/chat/provider/chat_provider.dart';
import 'package:sallehly_app/models/chat_summary_model.dart';

class MockChatApi extends Mock implements ChatApi {}

class MockApiClient extends Mock implements ApiClient {}

ChatSummaryModel _sampleChat({
  int requestId = 1,
  int unreadCount = 0,
  String? lastBody,
}) {
  return ChatSummaryModel(
    requestId: requestId,
    service: 'كهربائي',
    status: 'قيد التنفيذ',
    otherName: 'أحمد',
    lastBody: lastBody,
    unreadCount: unreadCount,
  );
}

void main() {
  late MockChatApi mockApi;
  late ChatProvider provider;

  setUp(() {
    mockApi = MockChatApi();
    provider = ChatProvider(
      apiClient: MockApiClient(),
      apiOverride: mockApi,
    );
  });

  group('loadChats', () {
    test('عند النجاح: يملأ chats و totalUnread، ويصفّر chatsLoading', () async {
      when(() => mockApi.getChats()).thenAnswer((_) async => (
            [
              _sampleChat(requestId: 1, unreadCount: 3, lastBody: 'مرحباً'),
              _sampleChat(requestId: 2, unreadCount: 0),
            ],
            3,
          ));

      expect(provider.chatsLoading, isFalse);
      final future = provider.loadChats();
      expect(provider.chatsLoading, isTrue);

      await future;

      expect(provider.chatsLoading, isFalse);
      expect(provider.chats, hasLength(2));
      expect(provider.totalUnread, 3);
      expect(provider.unreadCountFor(1), 3);
      expect(provider.unreadCountFor(2), 0);
      // طلب غير موجود بالقائمة أصلاً → صفر، وليس خطأ.
      expect(provider.unreadCountFor(999), 0);
      expect(provider.chatsError, isNull);
    });

    test('عند الفشل: يسجّل رسالة الخطأ ولا يُبقي chatsLoading معلّقاً', () async {
      when(() => mockApi.getChats())
          .thenThrow(ApiException('تعذر تحميل المحادثات'));

      await provider.loadChats();

      expect(provider.chatsLoading, isFalse);
      expect(provider.chatsError, 'تعذر تحميل المحادثات');
      expect(provider.chats, isEmpty);
    });

    test('استدعاءان متزامنان لا يُشغّلان طلبين متوازيين (حماية التكرار)', () async {
      var callCount = 0;
      when(() => mockApi.getChats()).thenAnswer((_) async {
        callCount++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return (<ChatSummaryModel>[_sampleChat()], 0);
      });

      final first = provider.loadChats();
      final second = provider.loadChats();
      await Future.wait([first, second]);

      expect(callCount, 1);
    });
  });
}
