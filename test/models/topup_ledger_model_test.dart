// test/models/topup_ledger_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sallehly_app/models/topup_model.dart';
import 'package:sallehly_app/models/ledger_model.dart';

void main() {
  group('TopupModel.fromJson', () {
    test('يحلّل كل الحقول بشكل صحيح', () {
      final t = TopupModel.fromJson({
        'id': 1,
        'package_id': 2,
        'amount': 20,
        'bonus': 2,
        'receipt_url': 'https://sallehly.com/uploads/r.png',
        'status': 'approved',
        'admin_note': 'تمت الموافقة',
        'package_name': 'باقة متوسطة',
        'created_at': '2026-07-01T10:00:00.000Z',
        'reviewed_at': '2026-07-01T11:00:00.000Z',
      });

      expect(t.id, 1);
      expect(t.packageId, 2);
      expect(t.amount, 20);
      expect(t.bonus, 2);
      expect(t.total, 22); // amount + bonus
      expect(t.status, 'approved');
      expect(t.isApproved, true);
      expect(t.isPending, false);
      expect(t.createdAt, isNotNull);
      expect(t.reviewedAt, isNotNull);
    });

    test('طلب شحن معلّق بلا مراجعة بعد — reviewed_at و admin_note يرجعوا null', () {
      final t = TopupModel.fromJson({
        'id': 1, 'package_id': 1, 'amount': 10, 'bonus': 0, 'status': 'pending',
      });
      expect(t.isPending, true);
      expect(t.adminNote, null);
      expect(t.reviewedAt, null);
      expect(t.total, 10);
    });
  });

  group('LedgerModel.fromJson', () {
    test('عملية إيداع (amount موجب) — isCredit صحيحة', () {
      final l = LedgerModel.fromJson({
        'id': 1, 'user_id': 5, 'type': 'شحن رصيد', 'amount': 20, 'balance_after': 20,
        'note': null, 'created_at': '2026-07-01T10:00:00.000Z',
      });
      expect(l.isCredit, true);
      expect(l.isDebit, false);
      expect(l.balanceAfter, 20);
    });

    test('عملية خصم (amount سالب) — isDebit صحيحة', () {
      final l = LedgerModel.fromJson({
        'id': 2, 'user_id': 5, 'type': 'خصم عمولة طلب', 'amount': -2, 'balance_after': 18,
      });
      expect(l.isDebit, true);
      expect(l.isCredit, false);
    });

    test('حقول اختيارية مفقودة لا تسبب انهياراً', () {
      final l = LedgerModel.fromJson({'id': 1, 'user_id': 1, 'type': 'test', 'amount': 0, 'balance_after': 0});
      expect(l.note, null);
      expect(l.createdAt, null);
    });
  });
}
