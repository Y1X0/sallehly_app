// test/models/request_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sallehly_app/models/request_model.dart';

void main() {
  group('RequestModel.fromJson — الحالة الطبيعية الكاملة', () {
    test('يحلّل كل الحقول بشكل صحيح', () {
      final r = RequestModel.fromJson({
        'id': 10,
        'customer_id': 3,
        'technician_id': 7,
        'service': 'كهربائي',
        'city': 'عمان',
        'area': 'القويسمة',
        'description': 'وصف المشكلة',
        'preferred_time': 'مساءً',
        'problem_image_url': 'https://sallehly.com/uploads/x.png',
        'status': 'قيد التنفيذ',
        'customer_name': 'أحمد',
        'technician_name': 'سامر',
        'offer_price': 15.5,
        'arrival_time': 'خلال ساعة',
        'created_at': '2026-07-01T10:00:00.000Z',
      });

      expect(r.id, 10);
      expect(r.customerId, 3);
      expect(r.technicianId, 7);
      expect(r.service, 'كهربائي');
      expect(r.city, 'عمان');
      expect(r.area, 'القويسمة');
      expect(r.description, 'وصف المشكلة');
      expect(r.preferredTime, 'مساءً');
      expect(r.problemImageUrl, 'https://sallehly.com/uploads/x.png');
      expect(r.status, 'قيد التنفيذ');
      expect(r.customerName, 'أحمد');
      expect(r.technicianName, 'سامر');
      expect(r.offerPrice, 15.5);
      expect(r.arrivalTime, 'خلال ساعة');
      expect(r.createdAt, isNotNull);
    });
  });

  group('RequestModel.fromJson — قيم مفقودة (طلب حديث بلا فني بعد)', () {
    test('technician_id و offer_price بلا قيمة يرجعوا null بدل خطأ', () {
      final r = RequestModel.fromJson({
        'id': 1,
        'customer_id': 2,
        'service': 'سباك',
        'city': 'إربد',
        'description': 'تسريب مياه',
        'status': 'بانتظار العروض',
      });
      expect(r.technicianId, null);
      expect(r.offerPrice, null);
      expect(r.technicianName, null);
      expect(r.arrivalTime, null);
    });

    test('id/customer_id بصيغة نصية يُحلَّلوا بشكل صحيح', () {
      final r = RequestModel.fromJson({
        'id': '99', 'customer_id': '5', 'service': 's', 'city': 'c', 'description': 'd', 'status': 'st',
      });
      expect(r.id, 99);
      expect(r.customerId, 5);
    });
  });

  group('RequestModel — دوال الحالة المساعدة (getters)', () {
    RequestModel withStatus(String status) => RequestModel.fromJson({
          'id': 1, 'customer_id': 1, 'service': 's', 'city': 'c', 'description': 'd', 'status': status,
        });

    test('isWaiting صحيحة فقط بحالة "بانتظار العروض"', () {
      expect(withStatus('بانتظار العروض').isWaiting, true);
      expect(withStatus('وصلت عروض').isWaiting, false);
    });

    test('hasOffers صحيحة فقط بحالة "وصلت عروض"', () {
      expect(withStatus('وصلت عروض').hasOffers, true);
      expect(withStatus('بانتظار العروض').hasOffers, false);
    });

    test('isCompleted و isCancelled', () {
      expect(withStatus('مكتمل').isCompleted, true);
      expect(withStatus('ملغي').isCancelled, true);
      expect(withStatus('مكتمل').isCancelled, false);
    });
  });
}
