// [FIX-CHATUNREAD-01] اختبارات ChatProvider.loadChats — يتحقق من تعبئة قائمة
// المحادثات وعدّاد غير المقروء الكلي عند النجاح، وعدم بقاء chatsLoading
// معلّقاً عند الفشل، بنفس نمط requests_provider_test.dart.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/api/api_exception.dart';
import 'package:sallehly_app/features/chat/data/chat_api.dart';
import 'package:sallehly_app/features/chat/provider/chat_provider.dart';
import 'package:sallehly_app/models/chat_summary_model.dart';
import 'package:sallehly_app/models/message_model.dart';

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

  // [SEC-FIX-CHATCLEAR-01] راجع DECISIONS.md — تُثبت أن clear() (المُستدعاة
  // من app.dart عند تسجيل الخروج/الدخول) لا تترك أي بيانات حساب سابق بالذاكرة،
  // وأن عدّاد الجيل يمنع رداً وصل متأخراً لحساب سابق من إعادة تعبئة الحالة
  // بعد clear() — نفس اختبار NotificationProvider._generation (HIGH-FIX-STALEGEN-01)
  // لكن على ChatProvider.
  group('clear', () {
    test('يُفرّغ الرسائل، المحادثات، وحالة الحظر المخبَّأة بالكامل', () async {
      when(() => mockApi.getMessages(1, limit: any(named: 'limit'))).thenAnswer((_) async => (
            [MessageModel(id: 1, requestId: 1, senderId: 5, body: 'رسالة سرّية من الحساب السابق')],
            false,
          ));
      await provider.loadMessages(1);
      expect(provider.messagesFor(1), isNotEmpty);

      when(() => mockApi.getChats()).thenAnswer((_) async => (
            [_sampleChat(requestId: 1, unreadCount: 2)],
            2,
          ));
      await provider.loadChats();
      expect(provider.chats, isNotEmpty);
      expect(provider.totalUnread, 2);

      provider.clear();

      expect(provider.messagesFor(1), isEmpty);
      expect(provider.chats, isEmpty);
      expect(provider.totalUnread, 0);
      expect(provider.error, isNull);
      expect(provider.chatsError, isNull);
    });

    test('رد متأخر لطلب بدأ قبل clear() (حساب سابق) لا يُعيد ملء الحالة بعد الخروج', () async {
      final gate = Completer<void>();
      when(() => mockApi.getMessages(1, limit: any(named: 'limit'))).thenAnswer((_) async {
        await gate.future;
        return ([MessageModel(id: 1, requestId: 1, senderId: 5, body: 'رسالة وصلت متأخرة لحساب سابق')], false);
      });

      final pendingLoad = provider.loadMessages(1);
      // تسجيل خروج (أو دخول لحساب آخر) بينما الطلب لا يزال معلَّقاً.
      provider.clear();
      gate.complete();
      await pendingLoad;

      expect(provider.messagesFor(1), isEmpty, reason: 'رد متأخر لحساب سابق أعاد ملء الحالة بعد clear() — لا حماية جيل');
    });
  });

  // [FEAT-CHATPAGINATION-01] راجع DECISIONS.md — loadMessages تُحمِّل صفحة
  // محدودة الحجم (limit) بدل المحادثة كاملة، وتُسجِّل hasMore من الخادم.
  group('[FEAT-CHATPAGINATION-01] loadMessages — الصفحة الأولى', () {
    test('يمرّر limit ثابتاً للـAPI، ويسجّل hasMore من الرد', () async {
      when(() => mockApi.getMessages(1, limit: ChatProvider.pageSize)).thenAnswer((_) async => (
            [MessageModel(id: 5, requestId: 1, senderId: 9, body: 'رسالة')],
            true,
          ));

      await provider.loadMessages(1);

      expect(provider.messagesFor(1).length, 1);
      expect(provider.hasMoreFor(1), isTrue);
    });
  });

  // [FEAT-CHATPAGINATION-01] راجع DECISIONS.md — loadOlderMessages تُضيف
  // صفحة رسائل أقدم لبداية القائمة المحلية بدل استبدال كل شيء.
  group('[FEAT-CHATPAGINATION-01] loadOlderMessages', () {
    test('يضيف الرسائل الأقدم لبداية القائمة، ويحدّث hasMore', () async {
      when(() => mockApi.getMessages(1, limit: ChatProvider.pageSize)).thenAnswer((_) async => (
            [
              MessageModel(id: 10, requestId: 1, senderId: 9, body: 'رسالة 10'),
              MessageModel(id: 11, requestId: 1, senderId: 9, body: 'رسالة 11'),
            ],
            true,
          ));
      await provider.loadMessages(1);

      when(() => mockApi.getMessages(1, limit: ChatProvider.pageSize, beforeId: 10)).thenAnswer((_) async => (
            [MessageModel(id: 8, requestId: 1, senderId: 9, body: 'رسالة 8')],
            false,
          ));
      await provider.loadOlderMessages(1);

      expect(provider.messagesFor(1).map((m) => m.id), [8, 10, 11]);
      expect(provider.hasMoreFor(1), isFalse);
    });

    test('لا يستدعي الـAPI إطلاقاً لو hasMoreFor false', () async {
      when(() => mockApi.getMessages(1, limit: ChatProvider.pageSize)).thenAnswer((_) async => (
            [MessageModel(id: 10, requestId: 1, senderId: 9, body: 'رسالة 10')],
            false, // لا مزيد من الرسائل الأقدم
          ));
      await provider.loadMessages(1);

      var olderCalled = false;
      when(() => mockApi.getMessages(1, limit: ChatProvider.pageSize, beforeId: any(named: 'beforeId')))
          .thenAnswer((_) async {
        olderCalled = true;
        return (<MessageModel>[], false);
      });

      await provider.loadOlderMessages(1);

      expect(olderCalled, isFalse);
    });

    test('استدعاءان متزامنان لا يُشغّلان طلبين متوازيين (حماية التكرار)', () async {
      when(() => mockApi.getMessages(1, limit: ChatProvider.pageSize)).thenAnswer((_) async => (
            [MessageModel(id: 10, requestId: 1, senderId: 9, body: 'رسالة 10')],
            true,
          ));
      await provider.loadMessages(1);

      var callCount = 0;
      when(() => mockApi.getMessages(1, limit: ChatProvider.pageSize, beforeId: 10)).thenAnswer((_) async {
        callCount++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return (<MessageModel>[], false);
      });

      final first = provider.loadOlderMessages(1);
      final second = provider.loadOlderMessages(1);
      await Future.wait([first, second]);

      expect(callCount, 1);
    });
  });

  // [FEAT-CHATPAGINATION-01] راجع DECISIONS.md — addIncomingMessage (حدث
  // message-added اللحظي).
  group('[FEAT-CHATPAGINATION-01] addIncomingMessage', () {
    test('يضيف رسالة جديدة لنهاية المحادثة المُحمَّلة أصلاً', () async {
      when(() => mockApi.getMessages(1, limit: ChatProvider.pageSize)).thenAnswer((_) async => (
            [MessageModel(id: 1, requestId: 1, senderId: 9, body: 'الأولى')],
            false,
          ));
      await provider.loadMessages(1);

      provider.addIncomingMessage(1, MessageModel(id: 2, requestId: 1, senderId: 9, body: 'الثانية'));

      expect(provider.messagesFor(1).map((m) => m.body), ['الأولى', 'الثانية']);
    });

    test('لا تأثير لو المحادثة غير مُحمَّلة أصلاً بهذا الجهاز الآن', () {
      provider.addIncomingMessage(99, MessageModel(id: 1, requestId: 99, senderId: 9, body: 'رسالة'));
      expect(provider.messagesFor(99), isEmpty);
    });

    test('لا تكرار لو الرسالة موجودة مسبقاً (وصول مزدوج محتمل)', () async {
      when(() => mockApi.getMessages(1, limit: ChatProvider.pageSize)).thenAnswer((_) async => (
            [MessageModel(id: 1, requestId: 1, senderId: 9, body: 'الأولى')],
            false,
          ));
      await provider.loadMessages(1);

      provider.addIncomingMessage(1, MessageModel(id: 1, requestId: 1, senderId: 9, body: 'الأولى'));

      expect(provider.messagesFor(1).length, 1);
    });
  });

  // [FEAT-CHATPAGINATION-01] راجع DECISIONS.md — markSeenUpTo (حدث
  // messages-seen اللحظي).
  group('[FEAT-CHATPAGINATION-01] markSeenUpTo', () {
    test('يعلّم فقط رسائل الطرف الآخر بمعرّف ≤ upToMessageId كمقروءة', () async {
      when(() => mockApi.getMessages(1, limit: ChatProvider.pageSize)).thenAnswer((_) async => (
            [
              MessageModel(id: 1, requestId: 1, senderId: 9, body: 'من الفني'), // سيُقرأ
              MessageModel(id: 2, requestId: 1, senderId: 5, body: 'من العميل نفسه'), // ليست موجَّهة لهذا القارئ
              MessageModel(id: 3, requestId: 1, senderId: 9, body: 'من الفني، لاحقة'), // بعد upToMessageId
            ],
            false,
          ));
      await provider.loadMessages(1);

      provider.markSeenUpTo(1, 5, 1); // العميل (id=5) قرأ حتى الرسالة رقم 1

      final messages = provider.messagesFor(1);
      expect(messages.firstWhere((m) => m.id == 1).seen, isTrue);
      expect(messages.firstWhere((m) => m.id == 2).seen, isFalse);
      expect(messages.firstWhere((m) => m.id == 3).seen, isFalse);
    });

    test('لا تأثير لو المحادثة غير مُحمَّلة أصلاً', () {
      expect(() => provider.markSeenUpTo(99, 5, 10), returnsNormally);
    });
  });
}
