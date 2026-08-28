// اختبارات ApiClient.handleError() — أكبر منطق غير مختبَر مباشرة بالمشروع رغم
// أنه نقطة تحويل كل خطأ شبكة/سيرفر إلى رسالة عربية يراها المستخدم فعلياً.
// دالة نقية بالكامل (لا تحتاج اتصال شبكة حقيقي): تُبنى DioException يدوياً
// وتُقاس رسالة/رمز ApiException الناتجة.
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/api/api_exception.dart';
import 'package:sallehly_app/core/i18n/current_locale.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late ApiClient client;
  late RequestOptions options;

  setUp(() {
    client = ApiClient(MockTokenStorage());
    options = RequestOptions(path: '/api/requests');
  });

  DioException withType(DioExceptionType type) =>
      DioException(requestOptions: options, type: type);

  DioException withResponse(int status, dynamic data) => DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: status, data: data),
      );

  group('أخطاء الشبكة/الاتصال (بلا رد من الخادم)', () {
    test('connectionTimeout → رسالة "الخادم يستغرق وقتاً" (ليس رسالة انقطاع إنترنت)', () {
      final e = client.handleError(withType(DioExceptionType.connectionTimeout));
      expect(e.message, contains('الخادم يستغرق وقتاً'));
    });

    test('receiveTimeout → نفس رسالة بطء الخادم', () {
      final e = client.handleError(withType(DioExceptionType.receiveTimeout));
      expect(e.message, contains('الخادم يستغرق وقتاً'));
    });

    test('connectionError → رسالة "لا يوجد اتصال بالإنترنت" صراحة', () {
      final e = client.handleError(withType(DioExceptionType.connectionError));
      expect(e.message, contains('لا يوجد اتصال بالإنترنت'));
    });

    test('cancel → رسالة إلغاء واضحة', () {
      final e = client.handleError(withType(DioExceptionType.cancel));
      expect(e.message, contains('إلغاء'));
    });

    test('badCertificate → رسالة تأمين اتصال', () {
      final e = client.handleError(withType(DioExceptionType.badCertificate));
      expect(e.message, contains('تأمين الاتصال'));
    });

    test('unknown بلا أي رد إطلاقاً → رسالة تعذّر الوصول للخادم', () {
      final e = client.handleError(DioException(requestOptions: options, type: DioExceptionType.unknown));
      expect(e.message, contains('تعذّر الوصول إلى الخادم'));
    });
  });

  group('استخراج رسالة/رمز الخادم من data', () {
    test('data خريطة فيها message → تُستخدم كما هي مع statusCode', () {
      final e = client.handleError(withResponse(400, {'message': 'رسالة مخصصة من الخادم'}));
      expect(e.message, 'رسالة مخصصة من الخادم');
      expect(e.statusCode, 400);
    });

    test('data خريطة فيها error (وليس message) → تُستخدم أيضاً', () {
      final e = client.handleError(withResponse(400, {'error': 'رصيدك غير كافٍ'}));
      expect(e.message, 'رصيدك غير كافٍ');
    });

    test('[FIX-OFFERQUOTA-01] data فيها code صريح → يُمرَّر بمعزل عن الرسالة', () {
      final e = client.handleError(withResponse(402, {'error': 'رصيد غير كافٍ', 'code': 'INSUFFICIENT_BALANCE'}));
      expect(e.code, 'INSUFFICIENT_BALANCE');
      expect(e.message, 'رصيد غير كافٍ');
    });

    test('data نص عادي قصير (ليس HTML) → يُستخدم كرسالة', () {
      final e = client.handleError(withResponse(400, 'خطأ نصي بسيط من بروكسي'));
      expect(e.message, 'خطأ نصي بسيط من بروكسي');
    });

    test('data نص HTML (يبدأ بـ<) → يُتجاهل، تُستخدم الرسالة الافتراضية للرمز بدلاً منه', () {
      final e = client.handleError(withResponse(500, '<html><body>Internal Server Error</body></html>'));
      expect(e.message, contains('خطأ في الخادم'));
    });

    test('data خريطة بلا message ولا error → رسالة افتراضية حسب رمز الحالة', () {
      final e = client.handleError(withResponse(404, {'foo': 'bar'}));
      expect(e.message, contains('غير موجود'));
    });
  });

  group('الرسائل الافتراضية حسب رمز الحالة (بلا رسالة من الخادم)', () {
    test('429 → رسالة "محاولات كثيرة جداً"', () {
      final e = client.handleError(withResponse(429, null));
      expect(e.message, contains('محاولات كثيرة'));
    });

    test('500 وما فوق → رسالة خطأ خادم عامة', () {
      final e = client.handleError(withResponse(503, null));
      expect(e.message, contains('خطأ في الخادم'));
    });

    test('401 → رسالة بيانات دخول غير صحيحة', () {
      final e = client.handleError(withResponse(401, null));
      expect(e.message, contains('بيانات الدخول غير صحيحة'));
    });

    test('403 → نفس رسالة 401', () {
      final e = client.handleError(withResponse(403, null));
      expect(e.message, contains('بيانات الدخول غير صحيحة'));
    });

    test('404 → رسالة عنصر غير موجود', () {
      final e = client.handleError(withResponse(404, null));
      expect(e.message, contains('غير موجود'));
    });

    test('رمز غير مصنَّف (مثال 418) → رسالة عامة تتضمن رمز الحالة', () {
      final e = client.handleError(withResponse(418, null));
      expect(e.message, contains('418'));
    });
  });

  test('خطأ ليس DioException إطلاقاً → رسالة عامة غير متوقعة', () {
    final e = client.handleError(Exception('شيء عشوائي'));
    expect(e.message, 'حدث خطأ غير متوقع');
  });

  // [FIX-ERRCODE-01] resolveApiErrorCode() — راجع core/api/api_error_codes.dart.
  // الأربع حالات المطلوب أن تتدهور جميعها لنص قابل للقراءة بلا استثناء ولا
  // سناك بار فارغ: رمز غير معروف، لا يوجد رمز إطلاقاً، رمز يحتاج params لكنها
  // مفقودة، ورمز يحتاج params لكنها من نوع خاطئ. كل حالة أدناه مغطاة صراحة.
  group('[FIX-ERRCODE-01] ترجمة code إلى نص ARB', () {
    // currentAppLocale متغيّر عام (راجع core/i18n/current_locale.dart) —
    // نعيده لقيمته الافتراضية بعد أي اختبار يغيّره كي لا يتسرّب لاختبارات
    // أخرى بنفس الملف.
    tearDown(() {
      currentAppLocale = const Locale('ar');
    });

    test('code معروف بلا params + عربي (الافتراضي) → نص ARB مطابق حرفياً لنص الخادم', () {
      final e = client.handleError(
        withResponse(404, {'error': 'الطلب غير موجود', 'code': 'REQUEST_NOT_FOUND'}),
      );
      expect(e.code, 'REQUEST_NOT_FOUND');
      expect(e.message, 'الطلب غير موجود');
    });

    test('نفس code لكن بالإنجليزية → نص ARB الإنجليزي فعلاً (يثبت أن الترجمة حصلت، وليس تمريراً للنص الخام)', () {
      currentAppLocale = const Locale('en');
      final e = client.handleError(
        withResponse(404, {'error': 'الطلب غير موجود', 'code': 'REQUEST_NOT_FOUND'}),
      );
      expect(e.message, 'Request not found');
    });

    test('حالة 1: code غير معروف (خادم أحدث/أقدم) → العودة لنص الخادم الخام بلا كسر', () {
      final e = client.handleError(
        withResponse(400, {'error': 'رسالة من رمز لم يُبنَ التطبيق ليعرفه', 'code': 'SOME_FUTURE_CODE_NOT_MAPPED_YET'}),
      );
      expect(e.code, 'SOME_FUTURE_CODE_NOT_MAPPED_YET');
      expect(e.message, 'رسالة من رمز لم يُبنَ التطبيق ليعرفه');
    });

    test('حالة 2: لا يوجد code إطلاقاً → السلوك القديم تماماً، رسالة الخادم كما هي', () {
      final e = client.handleError(withResponse(400, {'error': 'رسالة بلا رمز على الإطلاق'}));
      expect(e.code, isNull);
      expect(e.message, 'رسالة بلا رمز على الإطلاق');
    });

    test('code معروف يحتاج params (الطلب النشط) + params صحيحة كاملة بالإنجليزية → نص مترجَم فعلياً بالقيم', () {
      currentAppLocale = const Locale('en');
      final e = client.handleError(withResponse(409, {
        'error': 'لا يمكنك إرسال عرض جديد قبل إنهاء طلبك الحالي رقم 7 - كهربائي',
        'code': 'OFFER_ACTIVE_REQUEST_EXISTS',
        'params': {'id': 7, 'service': 'كهربائي'},
      }));
      expect(e.message, "You can't send a new offer before finishing your current request #7 - كهربائي");
    });

    test('نفس الرمز، id بصيغة عدد عشري (شائع بعد فك ترميز JSON) → لا يزال يُحل بأمان', () {
      currentAppLocale = const Locale('en');
      final e = client.handleError(withResponse(409, {
        'error': 'نص احتياطي',
        'code': 'OFFER_ACTIVE_REQUEST_EXISTS',
        'params': {'id': 7.0, 'service': 'نجار'},
      }));
      expect(e.message, contains('#7 - نجار'));
    });

    test('حالة 3: نفس الرمز لكن params مفقودة تماماً → العودة لنص الخادم الخام، لا فراغات مكسورة', () {
      final e = client.handleError(withResponse(409, {
        'error': 'لا يمكنك إرسال عرض جديد قبل إنهاء طلبك الحالي رقم 5 - سباك',
        'code': 'OFFER_ACTIVE_REQUEST_EXISTS',
      }));
      expect(e.message, 'لا يمكنك إرسال عرض جديد قبل إنهاء طلبك الحالي رقم 5 - سباك');
    });

    test('حالة 4أ: params من نوع خاطئ تماماً (List بدل Map) → تُهمَل، رسالة الخادم الخام تظهر', () {
      final e = client.handleError(withResponse(409, {
        'error': 'رسالة احتياطية أخرى',
        'code': 'OFFER_ACTIVE_REQUEST_EXISTS',
        'params': [1, 2, 3],
      }));
      expect(e.message, 'رسالة احتياطية أخرى');
    });

    test('حالة 4ب: params من نوع Map لكن id/service بقيم غير صالحة (id نصي، service فارغ) → نفس التراجع الآمن', () {
      final e = client.handleError(withResponse(409, {
        'error': 'رسالة احتياطية ثالثة',
        'code': 'OFFER_ACTIVE_REQUEST_EXISTS',
        'params': {'id': 'not-a-number', 'service': ''},
      }));
      expect(e.message, 'رسالة احتياطية ثالثة');
    });

    test('لا سناك بار فارغ إطلاقاً بأي من الحالات أعلاه — الرسالة دائماً غير فارغة', () {
      final cases = [
        withResponse(400, {'error': 'أ', 'code': 'UNKNOWN_X'}),
        withResponse(400, {'error': 'ب'}),
        withResponse(409, {'error': 'ج', 'code': 'OFFER_ACTIVE_REQUEST_EXISTS'}),
        withResponse(409, {'error': 'د', 'code': 'OFFER_ACTIVE_REQUEST_EXISTS', 'params': 'ليست خريطة'}),
      ];
      for (final err in cases) {
        final e = client.handleError(err);
        expect(e.message, isNotEmpty);
      }
    });
  });

  test('ApiException.toString() يرجع نص الرسالة نفسه (يُستخدم مباشرة بالواجهة أحياناً)', () {
    final e = ApiException('رسالة تجريبية', statusCode: 400);
    expect(e.toString(), 'رسالة تجريبية');
  });
}
