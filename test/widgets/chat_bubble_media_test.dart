// يثبت اثنين من سلوكيات ChatBubble غير المغطاة بالاختبارات الأخرى:
// 1) _mediaUrl() تُلحق AppConfig.baseUrl بمسار الصورة النسبي القادم من
//    الخادم (الشكل الفعلي لـbody كما يخزّنه routes/chat.routes.js:
//    '[image]/uploads/requests/xxx.png' — مسار نسبي، وليس رابطاً كاملاً).
// 2) رسالة صوتية بلا لاحقة "|مدة" بالـbody (رسائل قديمة قبل
//    FIX-AUDIODUR-01، أو أي رسالة أُرسلت بدون durationSeconds) تعرض "00:00"
//    فوراً ولحين بدء التشغيل الفعلي — يكمل تغطية chat_bubble_key_test.dart
//    (الذي يغطي فقط حالة وجود المدة).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/features/chat/widgets/chat_bubble.dart';
import 'package:sallehly_app/models/message_model.dart';

// [SEC-FIX-C1] تختبر أن Authorization: Bearer <JWT> يُرفَق فقط عند فتح صورة
// الشات بالعرض الكامل لو كان الرابط يعود فعلاً لخادمنا (نفس host الخاص
// بـAppConfig.baseUrl = sallehly.com) — وليس لأي رابط خارجي، حتى لو وصل
// كـ body رسالة يبدأ بـ"[image]" (المسار الذي كانت الثغرة تُستغَل عبره قبل
// إصلاح السيرفر أيضاً بـ isSpoofedMediaBody). قناة flutter_secure_storage
// مُموَّهة (mocked) هنا لأنها method channel أصلي لا يعمل بلا منصة حقيقية.
const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
      if (call.method == 'read') return 'fake-jwt-token';
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets('صورة برابط نسبي: Image.network يستخدم الرابط الكامل مع baseUrl', (tester) async {
    final message = MessageModel(
      id: 1,
      requestId: 1,
      senderId: 2,
      body: '[image]/uploads/requests/1784229840881-b0edc79e61ccd913.png',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ChatBubble(message: message, isMe: true)),
    ));
    await tester.pump();

    final networkImage =
        tester.widget<Image>(find.byType(Image)).image as NetworkImage;

    expect(
      networkImage.url,
      'https://sallehly.com/uploads/requests/1784229840881-b0edc79e61ccd913.png',
    );
  });

  testWidgets('رسالة صوتية بلا لاحقة مدة: تعرض 00:00 فوراً بدل تجميد أو خطأ', (tester) async {
    final message = MessageModel(
      id: 2,
      requestId: 1,
      senderId: 2,
      body: '[audio]/uploads/audios/1784229966094-a755a8616b0ef656.wav',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ChatBubble(message: message, isMe: true)),
    ));
    await tester.pump();

    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('[SEC-FIX-C1] صورة برابط خارجي: العرض الكامل لا يُرفق هيدر Authorization', (tester) async {
    final message = MessageModel(
      id: 3,
      requestId: 1,
      senderId: 2,
      body: '[image]https://attacker.example.com/x.png',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ChatBubble(message: message, isMe: true)),
    ));
    await tester.pump();

    await tester.tap(find.byType(ClipRRect));
    await tester.pumpAndSettle();

    final fullImage = tester.widget<Image>(find.byType(Image).last);
    final networkImage = fullImage.image as NetworkImage;

    expect(networkImage.url, 'https://attacker.example.com/x.png');
    expect(networkImage.headers?.containsKey('Authorization') ?? false, isFalse);
  });

  testWidgets('[SEC-FIX-C1] صورة من خادمنا: العرض الكامل يُرفق هيدر Authorization الصحيح', (tester) async {
    final message = MessageModel(
      id: 4,
      requestId: 1,
      senderId: 2,
      body: '[image]/uploads/requests/legit.png',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ChatBubble(message: message, isMe: true)),
    ));
    await tester.pump();

    await tester.tap(find.byType(ClipRRect));
    await tester.pumpAndSettle();

    final fullImage = tester.widget<Image>(find.byType(Image).last);
    final networkImage = fullImage.image as NetworkImage;

    expect(networkImage.url, 'https://sallehly.com/uploads/requests/legit.png');
    expect(networkImage.headers?['Authorization'], 'Bearer fake-jwt-token');
  });
}
