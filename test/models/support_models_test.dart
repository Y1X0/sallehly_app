// test/models/support_models_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sallehly_app/models/support_ticket_model.dart';
import 'package:sallehly_app/models/support_message_model.dart';

void main() {
  group('SupportTicketModel.fromJson', () {
    test('تحليل صحيح كامل', () {
      final t = SupportTicketModel.fromJson({
        'id': 1, 'user_id': 5, 'type': 'مشكلة حساب', 'title': 'لا أستطيع الدخول', 'body': 'تفاصيل المشكلة',
        'status': 'open', 'user_name': 'أحمد', 'user_role': 'customer', 'email': 'a@a.com',
        'created_at': '2026-07-01T10:00:00.000Z',
      });
      expect(t.type, 'مشكلة حساب');
      expect(t.status, 'open');
      expect(t.isOpen, true);
      expect(t.userName, 'أحمد');
    });

    test('type/status مفقودين يرجعوا القيم الافتراضية (عام/open) مطابقة لسلوك الباك إند', () {
      final t = SupportTicketModel.fromJson({'id': 1, 'user_id': 1, 'title': 'ت', 'body': 'ب'});
      expect(t.type, 'عام');
      expect(t.status, 'open');
      expect(t.isOpen, true);
    });

    test('تذكرة مغلقة — isOpen خاطئة', () {
      final t = SupportTicketModel.fromJson({'id': 1, 'user_id': 1, 'title': 'ت', 'body': 'ب', 'status': 'closed'});
      expect(t.isOpen, false);
    });
  });

  group('SupportMessageModel.fromJson', () {
    test('رسالة من الأدمن — isAdmin صحيحة', () {
      final m = SupportMessageModel.fromJson({
        'id': 1, 'ticket_id': 1, 'sender_id': 2, 'body': 'تم الحل', 'sender_name': 'الإدارة', 'sender_role': 'admin',
      });
      expect(m.isAdmin, true);
      expect(m.senderName, 'الإدارة');
    });

    test('رسالة من العميل — isAdmin خاطئة', () {
      final m = SupportMessageModel.fromJson({
        'id': 1, 'ticket_id': 1, 'sender_id': 5, 'body': 'سؤال', 'sender_role': 'customer',
      });
      expect(m.isAdmin, false);
    });

    test('sender_role مفقودة — isAdmin خاطئة افتراضياً (وليس خطأ)', () {
      final m = SupportMessageModel.fromJson({'id': 1, 'ticket_id': 1, 'sender_id': 1, 'body': 'x'});
      expect(m.isAdmin, false);
    });
  });
}
