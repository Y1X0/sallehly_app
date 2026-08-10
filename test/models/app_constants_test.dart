// [FIX-AREAS-01] كانت كل محافظة تحوي مناطق قليلة تجريبية فقط (عمّان 10 من
// عشرات الأحياء الفعلية) — وُسِّعت القائمة لتغطي كل محافظات الأردن الاثنتي
// عشرة بشكل شامل وواقعي. هذا الاختبار يحمي من انحراف مستقبلي: محافظة بلا
// مناطق، أو منطقة مكرَّرة (تُسبّب انهيار DropdownButtonFormField فعلياً —
// "There should be exactly one item with [DropdownButton]'s value").
import 'package:flutter_test/flutter_test.dart';
import 'package:sallehly_app/core/utils/app_constants.dart';

void main() {
  group('[FIX-AREAS-01] AppConstants — بيانات المحافظات والمناطق', () {
    test('كل محافظة بقائمة cities لها مدخل بـareasByCity', () {
      for (final city in AppConstants.cities) {
        expect(
          AppConstants.areasByCity.containsKey(city),
          isTrue,
          reason: 'المحافظة "$city" ضمن cities لكن بلا مناطق بـareasByCity',
        );
      }
    });

    test('كل محافظة تحوي منطقة واحدة على الأقل', () {
      for (final entry in AppConstants.areasByCity.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'المحافظة "${entry.key}" بلا أي منطقة',
        );
      }
    });

    test('لا مناطق مكرَّرة ضمن نفس المحافظة (يكسر DropdownButtonFormField فعلياً)', () {
      for (final entry in AppConstants.areasByCity.entries) {
        final unique = entry.value.toSet();
        expect(
          unique.length,
          entry.value.length,
          reason: 'المحافظة "${entry.key}" تحوي مناطق مكرَّرة',
        );
      }
    });

    test('عمّان (العاصمة) تحوي تغطية واسعة تعكس عدد أحيائها الفعلي', () {
      expect(AppConstants.areasByCity['عمّان']!.length, greaterThanOrEqualTo(30));
    });

    test('لا محافظات مكرَّرة بقائمة cities', () {
      expect(AppConstants.cities.toSet().length, AppConstants.cities.length);
    });
  });
}
