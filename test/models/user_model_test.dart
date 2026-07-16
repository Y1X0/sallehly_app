// test/models/user_model_test.dart
// اختبارات منطقية بحتة (بدون واجهة) لـ UserModel.fromJson — بالذات الحقول التي للسيرفر
// فيها أكثر من اسم محتمل (avatar/avatar_url، areas/area، services/service_name/profession)
// لأن هذا بالضبط نوع الباغ الصامت الذي اكتشفناه سابقاً بـ AdminStatsModel.

import 'package:flutter_test/flutter_test.dart';
import 'package:sallehly_app/models/user_model.dart';

void main() {
  group('UserModel.fromJson — الحالة الطبيعية الكاملة', () {
    test('يحلّل كل الحقول الأساسية بشكل صحيح', () {
      final user = UserModel.fromJson({
        'id': 5,
        'role': 'technician',
        'name': 'أحمد الفني',
        'email': 'ahmad@example.com',
        'phone': '0791234567',
        'city': 'عمان',
        'areas': 'القويسمة,صويلح',
        'national_number': '1234567890',
        'avatar_url': 'https://sallehly.com/uploads/a.png',
        'services': 'كهربائي',
        'rating_avg': 4.5,
        'balance': 12.75,
        'is_active': 1,
      });

      expect(user.id, 5);
      expect(user.role, 'technician');
      expect(user.name, 'أحمد الفني');
      expect(user.email, 'ahmad@example.com');
      expect(user.phone, '0791234567');
      expect(user.city, 'عمان');
      expect(user.area, 'القويسمة,صويلح');
      expect(user.nationalNumber, '1234567890');
      expect(user.avatar, 'https://sallehly.com/uploads/a.png');
      expect(user.serviceName, 'كهربائي');
      expect(user.rating, 4.5);
      expect(user.balance, 12.75);
      expect(user.active, true);
      expect(user.isTechnician, true);
      expect(user.isCustomer, false);
      expect(user.isAdmin, false);
    });
  });

  group('UserModel.fromJson — أسماء الحقول البديلة (fallback)', () {
    test('avatar بدل avatar_url لو avatar_url غير موجود', () {
      final user = UserModel.fromJson({
        'id': 1, 'role': 'customer', 'name': 'test', 'email': 'a@a.com', 'phone': '0791111111',
        'avatar': 'legacy_avatar.png',
      });
      expect(user.avatar, 'legacy_avatar.png');
    });

    test('area بدل areas لو areas غير موجود', () {
      final user = UserModel.fromJson({
        'id': 1, 'role': 'customer', 'name': 'test', 'email': 'a@a.com', 'phone': '0791111111',
        'area': 'خلدا',
      });
      expect(user.area, 'خلدا');
    });

    test('service_name ثم profession كبدائل لو services غير موجود', () {
      final withServiceName = UserModel.fromJson({
        'id': 1, 'role': 'technician', 'name': 'test', 'email': 'a@a.com', 'phone': '0791111111',
        'service_name': 'سباك',
      });
      expect(withServiceName.serviceName, 'سباك');

      final withProfession = UserModel.fromJson({
        'id': 1, 'role': 'technician', 'name': 'test', 'email': 'a@a.com', 'phone': '0791111111',
        'profession': 'نجار',
      });
      expect(withProfession.serviceName, 'نجار');
    });

    test('rating بدل rating_avg لو rating_avg غير موجود', () {
      final user = UserModel.fromJson({
        'id': 1, 'role': 'technician', 'name': 'test', 'email': 'a@a.com', 'phone': '0791111111',
        'rating': 3.2,
      });
      expect(user.rating, 3.2);
    });

    test('is_active كـ bool صحيح (true) وليس فقط int', () {
      final user = UserModel.fromJson({
        'id': 1, 'role': 'admin', 'name': 'test', 'email': 'a@a.com', 'phone': '0791111111',
        'is_active': true,
      });
      expect(user.active, true);
    });
  });

  group('UserModel.fromJson — قيم مفقودة يجب ألا تسبب انهياراً', () {
    test('حقول اختيارية مفقودة بالكامل ترجع null بدل رمي خطأ', () {
      final user = UserModel.fromJson({
        'id': 1, 'role': 'customer', 'name': 'test', 'email': 'a@a.com', 'phone': '0791111111',
      });
      expect(user.city, null);
      expect(user.area, null);
      expect(user.nationalNumber, null);
      expect(user.avatar, null);
      expect(user.serviceName, null);
      expect(user.rating, 0);
      expect(user.balance, 0);
      expect(user.active, false); // بلا is_active/active إطلاقاً => غير نشط افتراضياً
    });

    test('id كنص رقمي (كما قد يصل أحياناً بترميز JSON) يُحلَّل بشكل صحيح', () {
      final user = UserModel.fromJson({
        'id': '42', 'role': 'customer', 'name': 'test', 'email': 'a@a.com', 'phone': '0791111111',
      });
      expect(user.id, 42);
    });

    test('id مفقود كلياً يرجع 0 بدل رمي خطأ', () {
      final user = UserModel.fromJson({
        'role': 'customer', 'name': 'test', 'email': 'a@a.com', 'phone': '0791111111',
      });
      expect(user.id, 0);
    });

    // [FIX-SUPERADMIN-01]
    test('is_super_admin مفقودة ترجع false افتراضياً', () {
      final user = UserModel.fromJson({
        'id': 1, 'role': 'admin', 'name': 'test', 'email': 'a@a.com', 'phone': '0791111111',
      });
      expect(user.isSuperAdmin, false);
    });

    test('is_super_admin=1 يُحلَّل كـ true', () {
      final user = UserModel.fromJson({
        'id': 1, 'role': 'admin', 'name': 'test', 'email': 'a@a.com', 'phone': '0791111111',
        'is_super_admin': 1,
      });
      expect(user.isSuperAdmin, true);
    });
  });
}
