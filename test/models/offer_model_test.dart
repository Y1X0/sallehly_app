// test/models/offer_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sallehly_app/models/offer_model.dart';

void main() {
  group('OfferModel.fromJson — الحالة الطبيعية الكاملة', () {
    test('يحلّل كل الحقول بشكل صحيح', () {
      final o = OfferModel.fromJson({
        'id': 1,
        'request_id': 10,
        'technician_id': 3,
        'price': 25.0,
        'duration': 'خلال ساعة',
        'note': 'أستطيع الوصول بسرعة',
        'status': 'pending',
        'technician_name': 'سامر',
        'technician_city': 'عمان',
        'avatar_url': 'https://sallehly.com/uploads/a.png',
        'rating_avg': 4.8,
        'rating_count': 12,
        'completed_jobs': 30,
      });

      expect(o.id, 1);
      expect(o.requestId, 10);
      expect(o.technicianId, 3);
      expect(o.price, 25.0);
      expect(o.duration, 'خلال ساعة');
      expect(o.note, 'أستطيع الوصول بسرعة');
      expect(o.status, 'pending');
      expect(o.technicianName, 'سامر');
      expect(o.technicianCity, 'عمان');
      expect(o.avatarUrl, 'https://sallehly.com/uploads/a.png');
      expect(o.ratingAvg, 4.8);
      expect(o.ratingCount, 12);
      expect(o.completedJobs, 30);
    });
  });

  group('OfferModel.fromJson — فني جديد بلا تقييمات بعد', () {
    test('rating_avg/rating_count/completed_jobs مفقودة ترجع أصفار بدل خطأ', () {
      final o = OfferModel.fromJson({
        'id': 1, 'request_id': 1, 'technician_id': 1, 'price': 10, 'duration': 'قريباً', 'status': 'pending',
      });
      expect(o.ratingAvg, 0);
      expect(o.ratingCount, 0);
      expect(o.completedJobs, 0);
      expect(o.note, null);
    });
  });

  group('OfferModel — دوال الحالة المساعدة', () {
    test('isPending / isAccepted / isRejected', () {
      OfferModel withStatus(String status) => OfferModel.fromJson({
            'id': 1, 'request_id': 1, 'technician_id': 1, 'price': 10, 'duration': 'd', 'status': status,
          });
      expect(withStatus('pending').isPending, true);
      expect(withStatus('accepted').isAccepted, true);
      expect(withStatus('rejected').isRejected, true);
      expect(withStatus('accepted').isPending, false);
    });
  });
}
