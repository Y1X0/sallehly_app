// [SEC-FIX-IMGHEADERCACHE-01] راجع DECISIONS.md — يثبت أن AuthenticatedNetworkImage
// يُعيد جلب هيدرز المصادقة عند تغيّر url على نفس الـState (بلا ValueKey يجبر
// إنشاء State جديد) — بدون didUpdateWidget، كان الهيدر القديم (Authorization
// لرابط سابق) يبقى مُرفَقاً مع طلب الرابط الجديد، حتى لو كان الرابط الجديد
// خارجياً بالكامل. flutter_secure_storage مُموَّه (نفس نمط
// chat_bubble_media_test.dart's SEC-FIX-C1) — قناة منصّة أصلية لا تعمل بلا
// جهاز حقيقي.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/core/widgets/authenticated_network_image.dart';

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

  testWidgets(
    '[SEC-FIX-IMGHEADERCACHE-01] تغيّر url على نفس الـState: الهيدر القديم لا يُرفَق مع الرابط الخارجي الجديد',
    (tester) async {
      Widget harness(String url) => MaterialApp(
            home: Scaffold(
              body: AuthenticatedNetworkImage(url: url),
            ),
          );

      // أولاً: رابط من خادمنا — يُرفَق هيدر Authorization الصحيح.
      await tester.pumpWidget(harness('https://sallehly.com/uploads/requests/legit.png'));
      await tester.pump();
      await tester.pump();

      var image = tester.widget<Image>(find.byType(Image)).image as NetworkImage;
      expect(image.headers?['Authorization'], 'Bearer fake-jwt-token');

      // ثانياً: نفس الـState (بلا key)، لكن url خارجي كلياً الآن.
      await tester.pumpWidget(harness('https://attacker.example.com/x.png'));
      await tester.pump();
      await tester.pump();

      image = tester.widget<Image>(find.byType(Image)).image as NetworkImage;
      expect(image.url, 'https://attacker.example.com/x.png');
      expect(
        image.headers?.containsKey('Authorization') ?? false,
        isFalse,
        reason: 'هيدر Authorization لرابط سابق تسرّب لطلب رابط خارجي مختلف تماماً',
      );
    },
  );
}
