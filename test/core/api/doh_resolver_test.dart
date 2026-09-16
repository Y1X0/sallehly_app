// [FIX-DNSFALLBACK-01] راجع DECISIONS.md — يغطي DohResolver.parseFirstARecord
// (منطق تحليل رد Google DoH JSON الصرف، بلا أي طلب شبكة حقيقي) — الشكل
// الحقيقي لرد https://dns.google/resolve?name=...&type=A كما وثّقته Google.
import 'package:flutter_test/flutter_test.dart';
import 'package:sallehly_app/core/api/doh_resolver.dart';

void main() {
  group('DohResolver.parseFirstARecord', () {
    test('يستخرج أول سجل A من رد حقيقي الشكل ويطبّق حدود التخزين المؤقت', () {
      final json = {
        'Status': 0,
        'Answer': [
          {'name': 'sallehly.com.', 'type': 5, 'TTL': 300, 'data': 'sallehly.onrender.com.'},
          {'name': 'sallehly.onrender.com.', 'type': 1, 'TTL': 90, 'data': '216.24.57.1'},
        ],
      };

      final result = DohResolver.parseFirstARecord(json);

      expect(result.ip, '216.24.57.1');
      expect(result.cacheSeconds, 90);
    });

    test('TTL أقل من 60 يُرفَع إلى الحد الأدنى 60', () {
      final json = {
        'Answer': [
          {'type': 1, 'TTL': 10, 'data': '1.2.3.4'},
        ],
      };

      expect(DohResolver.parseFirstARecord(json).cacheSeconds, 60);
    });

    test('TTL أكبر من 120 يُخفَض إلى الحد الأقصى 120', () {
      final json = {
        'Answer': [
          {'type': 1, 'TTL': 3600, 'data': '1.2.3.4'},
        ],
      };

      expect(DohResolver.parseFirstARecord(json).cacheSeconds, 120);
    });

    test('غياب TTL بالرد لا يكسر التحليل — يفترض 60 ثانية', () {
      final json = {
        'Answer': [
          {'type': 1, 'data': '1.2.3.4'},
        ],
      };

      expect(DohResolver.parseFirstARecord(json).cacheSeconds, 60);
    });

    test('رد بلا أي سجل A (بس CNAME مثلاً) يرمي FormatException واضح', () {
      final json = {
        'Answer': [
          {'name': 'sallehly.com.', 'type': 5, 'TTL': 300, 'data': 'sallehly.onrender.com.'},
        ],
      };

      expect(
        () => DohResolver.parseFirstARecord(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('رد بلا حقل Answer إطلاقاً يرمي FormatException بدل NoSuchMethodError', () {
      expect(
        () => DohResolver.parseFirstARecord({'Status': 3}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
