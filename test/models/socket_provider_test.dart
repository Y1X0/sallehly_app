// SocketProvider بلا أي اختبار سابق رغم أنه يحمل منطق [FIX-CHAT-02] الحساس
// (إعادة الانضمام التلقائي لغرف الطلبات بعد إعادة اتصال) و[FIX-CHAT-02] الآخر
// (مسح غرف المستخدم السابق عند disconnect لمنع تسريبها لمستخدم لاحق على نفس
// الجهاز). يُختبر عبر Mock لـ SocketService — بلا أي اتصال شبكة حقيقي.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/socket/socket_events.dart';
import 'package:sallehly_app/core/socket/socket_service.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/admin/provider/admin_provider.dart';
import 'package:sallehly_app/features/chat/data/chat_api.dart';
import 'package:sallehly_app/features/chat/provider/chat_provider.dart';
import 'package:sallehly_app/features/requests/provider/requests_provider.dart';
import 'package:sallehly_app/features/support/provider/support_provider.dart';
import 'package:sallehly_app/features/wallet/provider/wallet_provider.dart';
import 'package:sallehly_app/models/message_model.dart';
import 'package:sallehly_app/providers/auth_provider.dart';
import 'package:sallehly_app/providers/notification_provider.dart';
import 'package:sallehly_app/providers/socket_provider.dart';

class MockSocketService extends Mock implements SocketService {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockApiClient extends Mock implements ApiClient {}

class MockChatApi extends Mock implements ChatApi {}

// [FEAT-CHATPAGINATION-01] راجع DECISIONS.md — bindProviders() تتطلب السبعة
// معاً (كلها required)، لكن اختبار حدثَي الشات الجديدين لا يحتاج فعلياً إلا
// ChatProvider حقيقياً (لمراقبة أثر فعلي). الستة الباقية Mock فارغة تماماً —
// extends Mock implements X لا يستدعي مُنشئ X الحقيقي إطلاقاً، فلا حاجة لأي
// من تبعياتها الفعلية (ApiClient حقيقي، AppStorage، إلخ) لمجرد إشباع التوقيع.
class MockRequestsProvider extends Mock implements RequestsProvider {}

class MockNotificationProvider extends Mock implements NotificationProvider {}

class MockAuthProvider extends Mock implements AuthProvider {}

class MockAdminProvider extends Mock implements AdminProvider {}

class MockWalletProvider extends Mock implements WalletProvider {}

class MockSupportProvider extends Mock implements SupportProvider {}

void main() {
  late MockSocketService mockSocket;
  late MockTokenStorage mockTokenStorage;
  late SocketProvider provider;

  setUp(() {
    mockSocket = MockSocketService();
    mockTokenStorage = MockTokenStorage();
    provider = SocketProvider(socketService: mockSocket, tokenStorage: mockTokenStorage);
    when(() => mockSocket.connect(token: any(named: 'token'))).thenReturn(null);
    when(() => mockSocket.disconnect()).thenReturn(null);
    when(() => mockSocket.on(any(), any())).thenReturn(null);
    when(() => mockSocket.joinRequest(any())).thenReturn(null);
    when(() => mockSocket.leaveRequest(any())).thenReturn(null);
  });

  /// يستخرج الـcallback المسجَّل لحدث socket معيّن من نداءات mockSocket.on()
  Function(dynamic) capturedCallbackFor(String event) {
    final calls = verify(() => mockSocket.on(captureAny(), captureAny())).captured;
    for (var i = 0; i < calls.length; i += 2) {
      if (calls[i] == event) return calls[i + 1] as Function(dynamic);
    }
    throw StateError('لم يُسجَّل أي مستمع للحدث: $event');
  }

  test('connect() بلا توكن مخزَّن: لا يستدعي socketService.connect إطلاقاً', () async {
    when(() => mockTokenStorage.getToken()).thenAnswer((_) async => null);
    await provider.connect();
    verifyNever(() => mockSocket.connect(token: any(named: 'token')));
  });

  test('connect() بتوكن فارغ (مسافات فقط): لا يتصل أيضاً', () async {
    when(() => mockTokenStorage.getToken()).thenAnswer((_) async => '   ');
    await provider.connect();
    verifyNever(() => mockSocket.connect(token: any(named: 'token')));
  });

  test('connect() بتوكن صالح: يتصل بتوكن مُنظَّف (trim) ويسجّل المستمعين', () async {
    when(() => mockTokenStorage.getToken()).thenAnswer((_) async => '  abc123  ');
    await provider.connect();
    verify(() => mockSocket.connect(token: 'abc123')).called(1);
    verify(() => mockSocket.on(SocketEvents.connect, any())).called(1);
  });

  test(
    '[FIX-SOCKETREBIND-01] connect() مرتين متتاليتين بلا reconnect()/disconnect() بينهما: '
    'المستمعون يُعاد تسجيلهم بالكامل في كل مرة — لا يبقون على "مرة واحدة فقط"',
    () async {
      when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok');

      await provider.connect();
      verify(() => mockSocket.on(SocketEvents.connect, any())).called(1);

      // [FIX-SOCKETREBIND-01] استدعاء ثانٍ لـconnect() بلا المرور بـ
      // reconnect()/disconnect() أولاً — بالضبط كما يحدث فعلياً بمسار استئناف
      // التطبيق من الخلفية (app.dart: didChangeAppLifecycleState يستدعي
      // .connect() مباشرة عند !connected، لا .reconnect()). الكود الحقيقي
      // بـsocket_service.dart ينشئ كائن io.Socket جديداً تماماً بكل استدعاء
      // connect() — فيلزم تسجيل المستمعين من جديد على الكائن الجديد، لا
      // الاكتفاء بتسجيل واحد يبقى "صالحاً" للأبد.
      clearInteractions(mockSocket);
      await provider.connect();

      // capturedCallbackFor نفسها تفشل (StateError "لم يُسجَّل أي مستمع
      // للحدث") إن لم يُسجَّل .on(SocketEvents.connect, ...) إطلاقاً بهذه
      // الدفعة الثانية — وهذا بالضبط ما كان يحدث قبل [FIX-SOCKETREBIND-01]
      // (المستمعون يبقون على تسجيل المرة الأولى فقط). ثم نُثبت أن المستمع
      // المُسجَّل هنا فعلياً حي ويعمل، لا مجرد موجود بالسجل.
      final onConnectSecond = capturedCallbackFor(SocketEvents.connect);
      onConnectSecond(null);
      expect(provider.connected, isTrue);
    },
  );

  test('[FIX-CHAT-02] joinRequest ثم حدث connect (إعادة اتصال): ينضم تلقائياً لنفس الغرفة على الخادم', () async {
    when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok');
    await provider.connect();
    final onConnect = capturedCallbackFor(SocketEvents.connect); // يُلتقط قبل مسح السجل أدناه
    provider.joinRequest(42);
    clearInteractions(mockSocket); // يصفّر عدّاد النداءات فقط — onConnect المُلتقطة أعلاه تبقى صالحة

    onConnect(null);

    verify(() => mockSocket.joinRequest(42)).called(1);
    expect(provider.connected, isTrue);
  });

  test('حدث disconnect من الخادم: connected تصبح false وتُبلَّغ الواجهة', () async {
    when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok');
    await provider.connect();
    final onDisconnect = capturedCallbackFor(SocketEvents.disconnect);

    var notified = false;
    provider.addListener(() => notified = true);
    onDisconnect(null);

    expect(provider.connected, isFalse);
    expect(notified, isTrue);
  });

  test('[FIX-CHAT-02] disconnect() اليدوي يمسح غرف الطلبات المنضمة — لا تُورَّث لمستخدم لاحق', () async {
    when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok1');
    await provider.connect();
    provider.joinRequest(7);
    provider.disconnect();

    expect(provider.connected, isFalse);
    verify(() => mockSocket.disconnect()).called(1);

    // اتصال جديد لاحق (مستخدم آخر) لا يُعاد الانضمام تلقائياً لغرفة المستخدم السابق
    clearInteractions(mockSocket);
    when(() => mockSocket.connect(token: any(named: 'token'))).thenReturn(null);
    when(() => mockSocket.on(any(), any())).thenReturn(null);
    when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok2');
    await provider.connect();
    final onConnect = capturedCallbackFor(SocketEvents.connect);
    onConnect(null);
    verifyNever(() => mockSocket.joinRequest(7));
  });

  test('leaveRequest() تزيل الغرفة من المجموعة المحلية أيضاً (لا تُعاد عند إعادة الاتصال لاحقاً)', () async {
    when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok');
    await provider.connect();
    final onConnect = capturedCallbackFor(SocketEvents.connect);
    provider.joinRequest(9);
    provider.leaveRequest(9);
    clearInteractions(mockSocket);

    onConnect(null);
    verifyNever(() => mockSocket.joinRequest(9));
  });

  test('reconnect() يفصل الاتصال الحالي ثم يعيد الاتصال من جديد بتوكن حالي', () async {
    when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok');
    await provider.connect();
    provider.connected = true;

    await provider.reconnect();

    verify(() => mockSocket.disconnect()).called(1);
    verify(() => mockSocket.connect(token: 'tok')).called(2); // مرة بـconnect() الأولى، ومرة بإعادة الاتصال
  });

  // [FEAT-CHATPAGINATION-01] راجع DECISIONS.md — message-added/messages-seen
  // اللحظيان الجديدان (يصلان بجانب messagesUpdated القديم من الخادم، هذه
  // النسخة لا تستمع للقديم بعد الآن). يثبت هذا القسم أن SocketProvider يفكّك
  // حمولة الحدث الخام بشكل صحيح ويستدعي طريقة ChatProvider الصحيحة بالضبط —
  // منطق التحديث نفسه (الإضافة/التكرار/seen) مختبَر بمعزل بـ
  // test/models/chat_provider_test.dart.
  group('[FEAT-CHATPAGINATION-01] message-added / messages-seen', () {
    late MockChatApi mockChatApi;
    late ChatProvider chatProvider;

    setUp(() {
      mockChatApi = MockChatApi();
      chatProvider = ChatProvider(apiClient: MockApiClient(), apiOverride: mockChatApi);
      provider.bindProviders(
        requestsProvider: MockRequestsProvider(),
        chatProvider: chatProvider,
        notificationProvider: MockNotificationProvider(),
        authProvider: MockAuthProvider(),
        adminProvider: MockAdminProvider(),
        walletProvider: MockWalletProvider(),
        supportProvider: MockSupportProvider(),
      );
    });

    test('message-added: يضيف الرسالة الواردة فعلياً لمحادثة مُحمَّلة أصلاً', () async {
      when(() => mockChatApi.getMessages(1, limit: ChatProvider.pageSize)).thenAnswer((_) async => (
            [MessageModel(id: 1, requestId: 1, senderId: 9, body: 'الأولى')],
            false,
          ));
      await chatProvider.loadMessages(1);

      when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok');
      await provider.connect();
      final onMessageAdded = capturedCallbackFor(SocketEvents.messageAdded);

      onMessageAdded({
        'requestId': 1,
        'message': {'id': 2, 'request_id': 1, 'sender_id': 9, 'body': 'الثانية'},
        'senderId': 9,
      });

      expect(chatProvider.messagesFor(1).map((m) => m.body), ['الأولى', 'الثانية']);
    });

    test('message-added: حمولة ناقصة (بلا message أو requestId) لا تسبّب أي خطأ ولا تُغيّر الحالة', () async {
      when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok');
      await provider.connect();
      final onMessageAdded = capturedCallbackFor(SocketEvents.messageAdded);

      expect(() => onMessageAdded({'requestId': 1}), returnsNormally);
      expect(() => onMessageAdded(null), returnsNormally);
    });

    test('messages-seen: يعلّم الرسائل المطابقة كمقروءة عبر ChatProvider فعلياً', () async {
      when(() => mockChatApi.getMessages(1, limit: ChatProvider.pageSize)).thenAnswer((_) async => (
            [MessageModel(id: 1, requestId: 1, senderId: 9, body: 'من الفني')],
            false,
          ));
      await chatProvider.loadMessages(1);

      when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok');
      await provider.connect();
      final onMessagesSeen = capturedCallbackFor(SocketEvents.messagesSeen);

      onMessagesSeen({'requestId': 1, 'readerId': 5, 'upToMessageId': 1});

      expect(chatProvider.messagesFor(1).first.seen, isTrue);
    });

    test('messages-seen: حمولة ناقصة (upToMessageId صفر) لا تسبّب أي خطأ', () async {
      when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok');
      await provider.connect();
      final onMessagesSeen = capturedCallbackFor(SocketEvents.messagesSeen);

      expect(() => onMessagesSeen({'requestId': 1, 'readerId': 5}), returnsNormally);
    });
  });
}
