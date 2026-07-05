// test/models/admin_stats_model_test.dart
// هذا الملف يختبر مباشرة الباغ الحقيقي الذي اكتشفناه: AdminStatsModel كانت تتجاهل
// 5 حقول يرسلها الباك إند فعلياً (cancelled, cancelRate, revenue, topServices, topTechs).
// أهم جزء هنا: revenue وcancelRate يصلان من السيرفر كنص (toFixed) وليس رقماً — لازم
// tryParse صريح، والتحقق من هذا التفصيل بالذات هو ما كان يمنع ظهور الباغ سابقاً.

import 'package:flutter_test/flutter_test.dart';
import 'package:sallehly_app/models/admin_stats_model.dart';

void main() {
  group('AdminStatsModel.fromJson — كل الحقول العشرة كما يرسلها الباك إند فعلياً', () {
    test('يحلّل الحقول الأساسية + الحقول التي كانت مفقودة سابقاً', () {
      final stats = AdminStatsModel.fromJson({
        'customers': 120,
        'technicians': 40,
        'requests': 300,
        'pendingTopups': 5,
        'completed': 250,
        'cancelled': 20,
        // ⚠️ هذول بالذات يصلوا كنص من السيرفر (toFixed) وليس رقماً
        'cancelRate': '6.7',
        'revenue': '4520.50',
        'topServices': [
          {'service': 'كهربائي', 'cnt': 80},
          {'service': 'سباك', 'cnt': 65},
        ],
        'topTechs': [
          {'name': 'سامر', 'completed_jobs': 45, 'rating_avg': 4.9},
        ],
      });

      expect(stats.customers, 120);
      expect(stats.technicians, 40);
      expect(stats.requests, 300);
      expect(stats.pendingTopups, 5);
      expect(stats.completed, 250);
      expect(stats.cancelled, 20);
      expect(stats.cancelRate, 6.7);
      expect(stats.revenue, 4520.50);
      expect(stats.topServices.length, 2);
      expect(stats.topServices[0].service, 'كهربائي');
      expect(stats.topServices[0].count, 80);
      expect(stats.topTechs.length, 1);
      expect(stats.topTechs[0].name, 'سامر');
      expect(stats.topTechs[0].completedJobs, 45);
      expect(stats.topTechs[0].ratingAvg, 4.9);
    });

    test('revenue/cancelRate كرقم مباشر (وليس نص) يُحلَّلوا أيضاً بشكل صحيح', () {
      final stats = AdminStatsModel.fromJson({
        'customers': 1, 'technicians': 1, 'requests': 1, 'pendingTopups': 0, 'completed': 1,
        'cancelRate': 0,
        'revenue': 0,
      });
      expect(stats.cancelRate, 0);
      expect(stats.revenue, 0);
    });
  });

  group('AdminStatsModel.fromJson — استجابة قديمة أو ناقصة لا تسبب انهياراً', () {
    test('الحقول الخمسة الجديدة مفقودة بالكامل ترجع قيماً افتراضية آمنة', () {
      final stats = AdminStatsModel.fromJson({
        'customers': 10, 'technicians': 5, 'requests': 20, 'pendingTopups': 1, 'completed': 15,
      });
      expect(stats.cancelled, 0);
      expect(stats.cancelRate, 0);
      expect(stats.revenue, 0);
      expect(stats.topServices, isEmpty);
      expect(stats.topTechs, isEmpty);
    });

    test('AdminStatsModel.empty قيمة افتراضية آمنة تماماً للاستخدام قبل تحميل البيانات', () {
      const stats = AdminStatsModel.empty;
      expect(stats.customers, 0);
      expect(stats.topServices, isEmpty);
      expect(stats.topTechs, isEmpty);
    });
  });
}
