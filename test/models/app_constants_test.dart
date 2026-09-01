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

    test('عمان (العاصمة) تحوي تغطية واسعة تعكس عدد أحيائها الفعلي', () {
      expect(AppConstants.areasByCity['عمان']!.length, greaterThanOrEqualTo(30));
    });

    test('لا محافظات مكرَّرة بقائمة cities', () {
      expect(AppConstants.cities.toSet().length, AppConstants.cities.length);
    });

    // [FEAT-DEDUP-01] راجع DECISIONS.md — "عمّان" (بشدة) كانت قيمة مختلفة
    // حرفياً عن "عمان" التي يُرجعها الخادم فعلياً (routes/meta.routes.js)
    // وتُستخدَم بكل مكان آخر بالتطبيق (نماذج الطلبات/المستخدمين). أي مطابقة
    // بين قيمة مجلوبة من الخادم ومفتاح areasByCity كانت ستفشل صامتة لعمّان
    // تحديداً (قائمة مناطق فارغة). هذا الاختبار يمنع عودة الشدة.
    test('عمان بلا شدة — تطابق القيمة الحقيقية من الخادم', () {
      expect(AppConstants.cities, contains('عمان'));
      expect(AppConstants.cities, isNot(contains('عمّان')));
      expect(AppConstants.areasByCity.containsKey('عمان'), isTrue);
      expect(AppConstants.areasByCity.containsKey('عمّان'), isFalse);
    });
  });

  // [FEAT-DEDUP-01] راجع DECISIONS.md — freeOffersExhaustedTitle/
  // commissionWillBeDeductedMessage/apiErrorInsufficientBalance تحمل صيغة
  // مثنى عربي ("فرصتان"/"فرصتين") ثابتة نصياً، لا مرتبطة ديناميكياً بهذا
  // الثابت (القيمة ليست حقلاً من API، فلا داعٍ حقيقي لتحويلها لـ
  // {quota, plural,...}) — لكن أي تعديل لهذا الثابت دون تحديث تلك النصوص
  // الثلاث يدوياً يُنتج نصاً يناقض القيمة الفعلية. هذا الاختبار قفل بسيط
  // يمنع تعديل الرقم بالخطأ دون ملاحظة الارتباط.
  test('[FEAT-DEDUP-01] AppConstants.freeTierQuota يطابق FREE_TIER_QUOTA بمستودع الخادم', () {
    expect(AppConstants.freeTierQuota, 2);
  });

  // [FEAT-DEDUP-01] راجع DECISIONS.md — طول كود OTP (6 أرقام، يطابق
  // utils/helpers.js:generateOtp() بمستودع الخادم) ونمط رقم الهاتف الأردني
  // (يطابق PHONE_REGEX بمستودع الخادم) — كانا مكرَّرين حرفياً بعدة شاشات
  // منفصلة قبل هذا التوحيد.
  group('[FEAT-DEDUP-01] AppConstants — OTP وتنسيق الهاتف', () {
    test('otpLength يساوي 6', () {
      expect(AppConstants.otpLength, 6);
    });

    test('phoneRegex يقبل صيغة 07 + 8 أرقام فقط', () {
      expect(AppConstants.phoneRegex.hasMatch('0791234567'), isTrue);
      expect(AppConstants.phoneRegex.hasMatch('07912345'), isFalse);
      expect(AppConstants.phoneRegex.hasMatch('06912345678'), isFalse);
      expect(AppConstants.phoneRegex.hasMatch('079123456700'), isFalse);
    });
  });
}
