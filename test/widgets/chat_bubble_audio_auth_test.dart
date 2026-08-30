// [SEC-FIX-AUDIOAUTH-01] راجع DECISIONS.md (كلا المستودعين) — يثبت أن تشغيل
// رسالة صوتية بالشات يجلب البايتات عبر طلب Dio مصادَق (Authorization: Bearer
// <JWT>) فقط لو كان الرابط يعود فعلاً لخادمنا، تماماً كالإصلاح المطابق
// لصور الشات (chat_bubble_media_test.dart / SEC-FIX-C1). قبل هذا الإصلاح
// كان audioplayers's UrlSource يُشغَّل مباشرة من express.static العام بلا
// أي مصادقة إطلاقاً، ولم يكن أي طلب Dio يُرسَل من هذا الودجت أصلاً — أي أن
// وجود طلب Dio بالهيدر الصحيح أصلاً هو الإثبات المباشر للإصلاح.
//
// لا يختبر هذا الملف تشغيل الصوت الفعلي عبر AudioPlayer (يتطلب قناة منصّة
// أصلية (xyz.luan/audioplayers) غير متاحة إطلاقاً ببيئة الاختبار، وينتظر
// حدث "prepared" عبر EventChannel لا يصل أبداً بلا تطبيق أصلي حقيقي) — هذا
// خارج نطاق ثغرة المصادقة التي يعالجها هذا الإصلاح تحديداً، ونفس القرار
// المتّبع أصلاً بـchat_bubble_key_test.dart الذي لا يضغط تشغيل إطلاقاً لنفس
// السبب. تحقَّق تجريبياً (تصحيح مباشر) أن player.play() لا يرمي استثناءً
// بلا هذه القناة بل يعلَّق للأبد (creatingCompleter لا يُرفَض)، لذا تتجنّب
// الاختبارات هنا استخدام pumpAndSettle بعد نجاح الجلب — فقط عدد محدود من
// pump() كافٍ لالتقاط الطلب الصادر فعلياً قبل أي محاولة تشغيل.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/features/chat/widgets/chat_bubble.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';
import 'package:sallehly_app/models/message_model.dart';

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// [SEC-FIX-AUDIOAUTH-01] بديل اختباري لـHttpClientAdapter الحقيقي — يسجّل
/// الـRequestOptions الفعلية التي أرسلها ChatBubble (الرابط والهيدرز)، ويسمح
/// بالتحكم بتوقيت/نتيجة الاستجابة، بدل أي اتصال شبكة حقيقي بخادم الإنتاج.
class _RecordingAudioAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  Object? throwError;
  List<int> responseBytes = const [1, 2, 3, 4];
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    if (gate != null) await gate!.future;
    if (throwError != null) {
      throw Exception(throwError);
    }
    return ResponseBody.fromBytes(responseBytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

MessageModel _audioMessage(String body) {
  return MessageModel(id: 1, requestId: 1, senderId: 2, body: body);
}

Future<void> _pumpAudioBubble(WidgetTester tester, MessageModel message) {
  return tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ChatBubble(message: message, isMe: false)),
  ));
}

void main() {
  late _RecordingAudioAdapter adapter;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
      if (call.method == 'read') return 'fake-jwt-token';
      return null;
    });
    adapter = _RecordingAudioAdapter();
    ChatBubble.debugAudioDio = Dio()..httpClientAdapter = adapter;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
    ChatBubble.debugAudioDio = null;
  });

  testWidgets(
    '[SEC-FIX-AUDIOAUTH-01] رسالة صوتية من خادمنا: طلب جلب البايتات يُرفق هيدر Authorization الصحيح',
    (tester) async {
      final message = _audioMessage('[audio]/uploads/audios/voice_1.wav|5');
      await _pumpAudioBubble(tester, message);
      await tester.pump();

      await tester.tap(find.byType(InkWell));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(adapter.lastOptions, isNotNull);
      expect(
        adapter.lastOptions!.uri.toString(),
        'https://sallehly.com/uploads/audios/voice_1.wav',
      );
      expect(
        adapter.lastOptions!.headers['Authorization'],
        'Bearer fake-jwt-token',
      );
    },
  );

  testWidgets(
    '[SEC-FIX-AUDIOAUTH-01] رابط صوتي خارجي (منتحَل): لا يُرفق هيدر Authorization إطلاقاً',
    (tester) async {
      final message =
          _audioMessage('[audio]https://attacker.example.com/x.wav|5');
      await _pumpAudioBubble(tester, message);
      await tester.pump();

      await tester.tap(find.byType(InkWell));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(adapter.lastOptions, isNotNull);
      expect(
        adapter.lastOptions!.uri.toString(),
        'https://attacker.example.com/x.wav',
      );
      expect(adapter.lastOptions!.headers.containsKey('Authorization'), isFalse);
    },
  );

  testWidgets(
    '[SEC-FIX-AUDIOAUTH-01] أثناء جلب البايتات: مؤشر تحميل يظهر ويُعطّل الضغط المتكرر',
    (tester) async {
      final message = _audioMessage('[audio]/uploads/audios/voice_2.wav|5');
      await _pumpAudioBubble(tester, message);
      await tester.pump();

      adapter.gate = Completer<void>();

      await tester.tap(find.byType(InkWell));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);

      // يُنهي الجلب المعلَّق كي لا يترك الاختبار مؤقّتاً داخلياً بـDio عالقاً
      // بعد تفكيك شجرة الودجت (flutter_test يفشل الاختبار لو بقي أي Timer).
      adapter.gate!.complete();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
    },
  );

  testWidgets(
    '[SEC-FIX-AUDIOAUTH-01] فشل جلب البايتات: تظهر رسالة خطأ ولا يبقى مؤشر التحميل عالقاً',
    (tester) async {
      final message = _audioMessage('[audio]/uploads/audios/voice_3.wav|5');
      await _pumpAudioBubble(tester, message);
      await tester.pump();

      adapter.throwError = Exception('network down');

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('تعذر تشغيل التسجيل الصوتي'), findsOneWidget);
    },
  );
}
