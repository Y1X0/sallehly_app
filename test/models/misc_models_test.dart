// test/models/misc_models_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sallehly_app/models/service_model.dart';
import 'package:sallehly_app/models/package_model.dart';
import 'package:sallehly_app/models/payment_method_model.dart';
import 'package:sallehly_app/models/review_model.dart';

void main() {
  group('ServiceModel.fromJson', () {
    test('تحليل صحيح مع أيقونة', () {
      final s = ServiceModel.fromJson({'id': 1, 'name': 'كهربائي', 'icon': '⚡'});
      expect(s.id, 1);
      expect(s.name, 'كهربائي');
      expect(s.icon, '⚡');
    });

    test('بلا أيقونة ترجع null بدل خطأ', () {
      final s = ServiceModel.fromJson({'id': 1, 'name': 'سباك'});
      expect(s.icon, null);
    });
  });

  group('PackageModel.fromJson', () {
    test('تحليل صحيح كامل، وtotal تجمع amount+bonus', () {
      final p = PackageModel.fromJson({'id': 1, 'name': 'باقة كبيرة', 'amount': 50, 'bonus': 5, 'commission_per_order': 3});
      expect(p.amount, 50);
      expect(p.bonus, 5);
      expect(p.total, 55);
      expect(p.commissionPerOrder, 3);
    });

    test('commission_per_order مفقودة ترجع 2 كقيمة افتراضية (مطابقة لسلوك الباك إند)', () {
      final p = PackageModel.fromJson({'id': 1, 'name': 'باقة', 'amount': 10, 'bonus': 0});
      expect(p.commissionPerOrder, 2);
    });
  });

  group('PaymentMethodModel.fromJson', () {
    test('تحليل صحيح كامل', () {
      final pm = PaymentMethodModel.fromJson({
        'id': 1, 'bank_name': 'البنك العربي', 'account_name': 'صلّحلي', 'account_number': '123456', 'phone': '0791234567',
        'instructions': 'حوّل ثم أرفق الإيصال',
      });
      expect(pm.bankName, 'البنك العربي');
      expect(pm.accountNumber, '123456');
      expect(pm.instructions, 'حوّل ثم أرفق الإيصال');
    });

    test('instructions مفقودة ترجع null بدل خطأ', () {
      final pm = PaymentMethodModel.fromJson({'id': 1, 'bank_name': 'ب', 'account_name': 'ح', 'account_number': '1', 'phone': 'p'});
      expect(pm.instructions, null);
    });
  });

  group('ReviewModel.fromJson', () {
    test('تحليل صحيح كامل', () {
      final r = ReviewModel.fromJson({'stars': 5, 'comment': 'ممتاز', 'customer_name': 'أحمد', 'created_at': '2026-07-01T10:00:00.000Z'});
      expect(r.stars, 5);
      expect(r.comment, 'ممتاز');
      expect(r.customerName, 'أحمد');
      expect(r.createdAt, isNotNull);
    });

    test('تقييم بلا تعليق (شائع جداً) — comment ترجع null بدل خطأ', () {
      final r = ReviewModel.fromJson({'stars': 4});
      expect(r.stars, 4);
      expect(r.comment, null);
    });
  });
}
