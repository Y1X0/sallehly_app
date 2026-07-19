// SocketProvider بلا أي اختبار سابق رغم أنه يحمل منطق [FIX-CHAT-02] الحساس
// (إعادة الانضمام التلقائي لغرف الطلبات بعد إعادة اتصال) و[FIX-CHAT-02] الآخر
// (مسح غرف المستخدم السابق عند disconnect لمنع تسريبها لمستخدم لاحق على نفس
// الجهاز). يُختبر عبر Mock لـ SocketService — بلا أي اتصال شبكة حقيقي.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/socket/socket_events.dart';
import 'package:sallehly_app/core/socket/socket_service.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/providers/socket_provider.dart';

class MockSocketService extends Mock implements SocketService {}

class MockTokenStorage extends Mock implements TokenStorage {}

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

  test('connect() مرتين متتاليتين: المستمعون يُسجَّلون مرة واحدة فقط (_listenersBound)', () async {
    when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok');
    await provider.connect();
    await provider.connect();
    // نفس مجموعة on() الكاملة لا تتكرر بمكالمة ثانية
    verify(() => mockSocket.on(SocketEvents.connect, any())).called(1);
  });

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
}
