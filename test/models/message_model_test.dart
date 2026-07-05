// test/models/message_model_test.dart
// أهم جزء هنا: منطق isAudio/isImage/isLocation يعتمد على "بادئة" نصية بالـ body
// ([audio]/[image]/[location]) — أي خطأ صغير هون بيخلي الشات يعرض صوت كنص عادي أو العكس.

import 'package:flutter_test/flutter_test.dart';
import 'package:sallehly_app/models/message_model.dart';

void main() {
  group('MessageModel.fromJson — رسالة نصية عادية', () {
    test('تحليل كامل لرسالة نصية', () {
      final m = MessageModel.fromJson({
        'id': 1,
        'request_id': 10,
        'sender_id': 3,
        'sender_name': 'أحمد',
        'body': 'مرحباً، متى تصل؟',
        'created_at': '2026-07-01T10:00:00.000Z',
        'seen': 1,
      });
      expect(m.id, 1);
      expect(m.requestId, 10);
      expect(m.senderId, 3);
      expect(m.senderName, 'أحمد');
      expect(m.body, 'مرحباً، متى تصل؟');
      expect(m.seen, true);
      expect(m.isAudio, false);
      expect(m.isImage, false);
      expect(m.isLocation, false);
    });

    test('seen كـ bool صحيح (true) وليس فقط 1', () {
      final m = MessageModel.fromJson({'id': 1, 'request_id': 1, 'sender_id': 1, 'body': 'x', 'seen': true});
      expect(m.seen, true);
    });

    test('seen مفقودة ترجع false افتراضياً', () {
      final m = MessageModel.fromJson({'id': 1, 'request_id': 1, 'sender_id': 1, 'body': 'x'});
      expect(m.seen, false);
    });
  });

  group('MessageModel — تمييز نوع الرسالة من البادئة', () {
    test('رسالة صوتية: isAudio صحيحة، والرابط يُستخرَج بلا البادئة', () {
      final m = MessageModel.fromJson({
        'id': 1, 'request_id': 1, 'sender_id': 1,
        'body': '[audio]https://sallehly.com/uploads/voice.m4a',
      });
      expect(m.isAudio, true);
      expect(m.isImage, false);
      expect(m.isLocation, false);
      expect(m.audioUrl, 'https://sallehly.com/uploads/voice.m4a');
    });

    test('رسالة صورة: isImage صحيحة، والرابط يُستخرَج بلا البادئة', () {
      final m = MessageModel.fromJson({
        'id': 1, 'request_id': 1, 'sender_id': 1,
        'body': '[image]https://sallehly.com/uploads/pic.png',
      });
      expect(m.isImage, true);
      expect(m.imageUrl, 'https://sallehly.com/uploads/pic.png');
    });

    test('رسالة موقع: isLocation صحيحة، والبيانات تُستخرَج بلا البادئة', () {
      final m = MessageModel.fromJson({
        'id': 1, 'request_id': 1, 'sender_id': 1,
        'body': '[location]31.9539,35.9106',
      });
      expect(m.isLocation, true);
      expect(m.locationPayload, '31.9539,35.9106');
    });

    test('استدعاء audioUrl على رسالة نصية عادية يرجع نص فارغ بدل خطأ', () {
      final m = MessageModel.fromJson({'id': 1, 'request_id': 1, 'sender_id': 1, 'body': 'رسالة عادية'});
      expect(m.audioUrl, '');
      expect(m.imageUrl, '');
      expect(m.locationPayload, '');
    });
  });

  group('MessageModel.fromJson — أسماء حقول بديلة (camelCase احتياطية)', () {
    test('requestId/senderId/createdAt كبدائل لو الأسماء بصيغة snake_case غير موجودة', () {
      final m = MessageModel.fromJson({
        'id': 1, 'requestId': 5, 'senderId': 2, 'body': 'test', 'createdAt': '2026-07-01T10:00:00.000Z',
      });
      expect(m.requestId, 5);
      expect(m.senderId, 2);
      expect(m.createdAt, isNotNull);
    });

    test('message بدل body لو body غير موجود', () {
      final m = MessageModel.fromJson({'id': 1, 'request_id': 1, 'sender_id': 1, 'message': 'نص بديل'});
      expect(m.body, 'نص بديل');
    });
  });
}
