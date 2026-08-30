// [SEC-FIX-OPENLOCATION-01] راجع DECISIONS.md — يثبت أن الضغط على رسالة موقع
// بالشات يُظهر رسالة خطأ حقيقية عند فشل launchUrl، بدل عدم فعل أي شيء بصمت.
// بيئة flutter test لا تحمل أي تطبيق خرائط حقيقي ولا قناة منصّة أصلية لـ
// url_launcher (بلا محاكاة) — أي استدعاء launchUrl هنا يفشل حتماً
// (MissingPluginException)، وهذا بالضبط ما يثبته هذا الاختبار: أن الفشل الآن
// يظهر للمستخدم بدل أن يُبتلَع بصمت.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/features/chat/widgets/chat_bubble.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';
import 'package:sallehly_app/models/message_model.dart';

void main() {
  testWidgets(
    '[SEC-FIX-OPENLOCATION-01] فشل فتح رسالة الموقع يُظهر رسالة خطأ، لا يمر بصمت',
    (tester) async {
      final message = MessageModel(
        id: 1,
        requestId: 1,
        senderId: 2,
        body: '[location]31.9539,35.9106',
      );

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ChatBubble(message: message, isMe: false)),
      ));
      await tester.pump();

      await tester.tap(find.byType(InkWell));
      // [مهم] رد قناة url_launcher (حتى الفاشل/غير المُموَّه) لا يكتمل بمجرد
      // pump() عادي بهذه البيئة — تحقَّق تجريبياً (تصحيح مباشر) أنه يبقى
      // معلَّقاً إلى الأبد بدون هذا. runAsync يسمح بجولة حدث حقيقية واحدة
      // خارج التحكم الزمني الوهمي لـtestWidgets حتى يكتمل الرد فعلياً.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump();

      final t = AppLocalizations.of(tester.element(find.byType(ChatBubble)))!;
      expect(find.text(t.openLocationFailedMessage), findsOneWidget);
    },
  );
}
