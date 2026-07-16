// [FIX-CHATBUBBLE-01] بدون key ثابت (ValueKey(message.id)) على ChatBubble
// داخل ListView.separated (reverse:true)، Flutter تُطابق عناصر القائمة حسب
// الموقع، فتُعيد استخدام نفس _ChatBubbleState لرسالة صوتية جديدة تصل لاحقاً
// بدل إنشاء حالة جديدة — initState (حيث تُقرأ مدة الصوت المخزَّنة) لا يُعاد
// تنفيذه، فتظهر المدة القديمة (أو "...") بدل مدة الرسالة الجديدة فعلياً حتى
// يضغط المستخدم تشغيل. هذا الاختبار يعيد إنتاج البنية الحقيقية بالضبط
// (ListView.separated + reverse:true + itemBuilder) ويثبت أن المدة الصحيحة
// تظهر فوراً لكل رسالة صوتية جديدة تصل لأعلى القائمة، دون أي تفاعل تشغيل.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/features/chat/widgets/chat_bubble.dart';
import 'package:sallehly_app/models/message_model.dart';

MessageModel _audioMessage({required int id, required int durationSeconds}) {
  return MessageModel(
    id: id,
    requestId: 1,
    senderId: 2,
    body: '[audio]/uploads/audios/voice_$id.wav|$durationSeconds',
  );
}

class _ChatListHarness extends StatefulWidget {
  const _ChatListHarness();

  @override
  State<_ChatListHarness> createState() => _ChatListHarnessState();
}

class _ChatListHarnessState extends State<_ChatListHarness> {
  // نفس الحالة الابتدائية بشاشة الشات الحقيقية: رسالة صوتية واحدة موجودة.
  List<MessageModel> messages = [_audioMessage(id: 1, durationSeconds: 5)];

  void addNewVoiceMessage() {
    setState(() {
      // رسالة جديدة تُضاف بنفس ترتيب السيرفر (الأحدث أولاً في القائمة
      // الأصلية، تماماً كما في ChatRoomScreen.reversedMessages).
      messages = [_audioMessage(id: 2, durationSeconds: 11), ...messages];
    });
  }

  @override
  Widget build(BuildContext context) {
    // نفس بنية ChatRoomScreen بالضبط: ListView.separated + reverse:true.
    final reversedMessages = messages;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              reverse: true,
              itemCount: reversedMessages.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final message = reversedMessages[index];
                return ChatBubble(
                  key: ValueKey(message.id),
                  message: message,
                  isMe: false,
                );
              },
            ),
          ),
          TextButton(
            onPressed: addNewVoiceMessage,
            child: const Text('إرسال رسالة صوتية جديدة'),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets(
    '[FIX-CHATBUBBLE-01] رسالة صوتية جديدة تُظهر مدتها فوراً دون تشغيل، ولا تحمل مدة رسالة سابقة',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _ChatListHarness()));
      await tester.pump();

      // الرسالة الأولى (5 ثوانٍ) تظهر بمدتها الصحيحة فوراً.
      expect(find.text('00:05'), findsOneWidget);

      // إضافة رسالة صوتية جديدة (11 ثانية) تصل لأعلى القائمة المعكوسة —
      // بالضبط كما يحدث فعلياً عند استلام رسالة جديدة من الخادم.
      await tester.tap(find.text('إرسال رسالة صوتية جديدة'));
      await tester.pump();

      // [FIX-CHATBUBBLE-01] الإثبات الحقيقي: مدة الرسالة الجديدة (11 ثانية)
      // يجب أن تظهر فوراً — بلا حاجة لأي تفاعل تشغيل — ولا تبقى الرسالة
      // القديمة (5 ثوانٍ) ظاهرة بدلاً منها بسبب إعادة استخدام حالة خاطئة.
      expect(find.text('00:11'), findsOneWidget);
      expect(find.text('00:05'), findsOneWidget);
    },
  );
}
