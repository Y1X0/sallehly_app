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
}
