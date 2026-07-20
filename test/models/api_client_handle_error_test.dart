// اختبارات ApiClient.handleError() — أكبر منطق غير مختبَر مباشرة بالمشروع رغم
// أنه نقطة تحويل كل خطأ شبكة/سيرفر إلى رسالة عربية يراها المستخدم فعلياً.
// دالة نقية بالكامل (لا تحتاج اتصال شبكة حقيقي): تُبنى DioException يدوياً
// وتُقاس رسالة/رمز ApiException الناتجة.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/api/api_exception.dart';
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

  test('ApiException.toString() يرجع نص الرسالة نفسه (يُستخدم مباشرة بالواجهة أحياناً)', () {
    final e = ApiException('رسالة تجريبية', statusCode: 400);
    expect(e.toString(), 'رسالة تجريبية');
  });
}
