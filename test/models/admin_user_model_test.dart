// test/models/admin_user_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sallehly_app/models/admin_user_model.dart';

void main() {
  group('AdminUserModel.fromJson', () {
    test('تحليل صحيح كامل لفني نشط', () {
      final u = AdminUserModel.fromJson({
        'id': 1, 'role': 'technician', 'name': 'سامر', 'email': 's@s.com', 'phone': '0791111111',
        'city': 'عمان', 'areas': 'خلدا', 'services': 'كهربائي',
        'balance': 15.5, 'is_active': 1, 'rating_avg': 4.7, 'rating_count': 20, 'completed_jobs': 30,
      });
      expect(u.active, true);
      expect(u.balance, 15.5);
      expect(u.isTechnician, true);
      expect(u.roleAr, 'فني');
    });

    test('مستخدم موقوف (is_active=0)', () {
      final u = AdminUserModel.fromJson({
        'id': 1, 'role': 'customer', 'name': 'أحمد', 'email': 'a@a.com', 'phone': '0791111111',
        'balance': 0, 'is_active': 0, 'rating_avg': 0, 'rating_count': 0, 'completed_jobs': 0,
      });
      expect(u.active, false);
      expect(u.roleAr, 'عميل');
    });

    test('roleAr للأدمن وللدور غير المعروف', () {
      final admin = AdminUserModel.fromJson({
        'id': 1, 'role': 'admin', 'name': 'a', 'email': 'a@a.com', 'phone': 'p', 'balance': 0, 'is_active': 1,
        'rating_avg': 0, 'rating_count': 0, 'completed_jobs': 0,
      });
      expect(admin.roleAr, 'أدمن');

      final unknown = AdminUserModel.fromJson({
        'id': 1, 'role': 'weird_role', 'name': 'a', 'email': 'a@a.com', 'phone': 'p', 'balance': 0, 'is_active': 1,
        'rating_avg': 0, 'rating_count': 0, 'completed_jobs': 0,
      });
      expect(unknown.roleAr, 'weird_role'); // يرجع القيمة الخام لو غير معروفة
    });

    test('city/areas/services مفقودة ترجع null بدل خطأ', () {
      final u = AdminUserModel.fromJson({
        'id': 1, 'role': 'customer', 'name': 'a', 'email': 'a@a.com', 'phone': 'p', 'balance': 0, 'is_active': 1,
        'rating_avg': 0, 'rating_count': 0, 'completed_jobs': 0,
      });
      expect(u.city, null);
      expect(u.areas, null);
      expect(u.services, null);
    });
  });

  // [FIX-SUPERADMIN-01]
  group('AdminUserModel.fromJson — الحقول الجديدة', () {
    test('حقول مفقودة ترجع قيماً افتراضية آمنة (توافق رجعي كامل)', () {
      final u = AdminUserModel.fromJson({
        'id': 1, 'role': 'technician', 'name': 'a', 'email': 'a@a.com', 'phone': 'p', 'balance': 0, 'is_active': 1,
        'rating_avg': 0, 'rating_count': 0, 'completed_jobs': 0,
      });
      expect(u.verificationStatus, 'verified');
      expect(u.suspensionReason, null);
      expect(u.suspendedAt, null);
      expect(u.isSuperAdmin, false);
      expect(u.isPendingVerification, false);
    });

    test('فني بانتظار التوثيق: isPendingVerification صحيحة', () {
      final u = AdminUserModel.fromJson({
        'id': 1, 'role': 'technician', 'name': 'a', 'email': 'a@a.com', 'phone': 'p', 'balance': 0, 'is_active': 1,
        'rating_avg': 0, 'rating_count': 0, 'completed_jobs': 0, 'verification_status': 'pending',
      });
      expect(u.isPendingVerification, true);
    });

    test('عميل بحالة pending لا يُعتبَر "بانتظار التوثيق" (مفهوم خاص بالفنيين فقط)', () {
      final u = AdminUserModel.fromJson({
        'id': 1, 'role': 'customer', 'name': 'a', 'email': 'a@a.com', 'phone': 'p', 'balance': 0, 'is_active': 1,
        'rating_avg': 0, 'rating_count': 0, 'completed_jobs': 0, 'verification_status': 'pending',
      });
      expect(u.isPendingVerification, false);
    });

    test('حساب موقوف مع سبب وتاريخ يُحلَّلان بشكل صحيح', () {
      final u = AdminUserModel.fromJson({
        'id': 1, 'role': 'technician', 'name': 'a', 'email': 'a@a.com', 'phone': 'p', 'balance': 0, 'is_active': 0,
        'rating_avg': 0, 'rating_count': 0, 'completed_jobs': 0,
        'suspension_reason': 'مخالفات متكررة', 'suspended_at': '2026-07-01T10:00:00.000Z',
      });
      expect(u.active, false);
      expect(u.suspensionReason, 'مخالفات متكررة');
      expect(u.suspendedAt, isNotNull);
    });

    test('is_super_admin=1 يُحلَّل كـ true', () {
      final u = AdminUserModel.fromJson({
        'id': 1, 'role': 'admin', 'name': 'a', 'email': 'a@a.com', 'phone': 'p', 'balance': 0, 'is_active': 1,
        'rating_avg': 0, 'rating_count': 0, 'completed_jobs': 0, 'is_super_admin': 1,
      });
      expect(u.isSuperAdmin, true);
    });
  });
}
