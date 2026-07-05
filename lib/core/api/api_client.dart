import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  final TokenStorage tokenStorage;

  late final Dio dio;

  /// تُستدعى عند نجاح أي طلب (متصل).
  void Function()? onOnline;

  /// تُستدعى عند فشل طلب بسبب الشبكة (غير متصل).
  void Function()? onOffline;

  ApiClient(this.tokenStorage) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.getToken();

          options.headers.remove('Cookie');

          if (token != null && token.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${token.trim()}';
          } else {
            options.headers.remove('Authorization');
          }

          handler.next(options);
        },
        onResponse: (response, handler) async {
          onOnline?.call();

          final token = _extractTokenFromSetCookie(response.headers);

          if (token.isNotEmpty) {
            await tokenStorage.saveToken(token);
          }

          handler.next(response);
        },
        onError: (error, handler) async {
          // وصل رد من الخادم (حتى لو خطأ) → نحن متصلون.
          // لا يوجد رد بسبب الشبكة → غير متصلين.
          if (error.response != null) {
            onOnline?.call();
          } else if (_shouldRetry(error)) {
            onOffline?.call();
          }

          // إعادة المحاولة تلقائياً عند فشل الشبكة أو بطء الخادم
          // (مفيد خصوصاً عندما يكون الخادم "نائماً" ويستغرق وقتاً ليستيقظ).
          if (_shouldRetry(error)) {
            final options = error.requestOptions;
            final attempt = (options.extra['retry_attempt'] as int?) ?? 0;

            if (attempt < 3) {
              options.extra['retry_attempt'] = attempt + 1;

              // انتظار متزايد: 1s ثم 2s ثم 4s قبل كل إعادة محاولة
              await Future.delayed(Duration(seconds: 1 << attempt));

              try {
                // أعطِ مهلة أطول لإعادة المحاولة (الخادم قد يكون يستيقظ)
                final retryDio = Dio(
                  BaseOptions(
                    baseUrl: AppConfig.apiUrl,
                    connectTimeout: const Duration(seconds: 40),
                    receiveTimeout: const Duration(seconds: 40),
                    sendTimeout: const Duration(seconds: 40),
                    headers: options.headers,
                  ),
                );

                final response = await retryDio.fetch(options);
                return handler.resolve(response);
              } catch (_) {
                // فشلت إعادة المحاولة أيضاً — كمّل بمعالجة الخطأ العادية
              }
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  bool _shouldRetry(DioException error) {
    // أعد المحاولة فقط لأخطاء الشبكة/المهلة — وليس لأخطاء الخادم
    // (مثل كلمة مرور خاطئة أو 4xx) التي لن تتغير بإعادة المحاولة.
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        // عادةً مشاكل DNS / انقطاع شبكة (لا يوجد رد من الخادم)
        return error.response == null;
      default:
        return false;
    }
  }

  String _extractTokenFromSetCookie(Headers headers) {
    final cookies = headers.map['set-cookie'];

    if (cookies == null || cookies.isEmpty) {
      return '';
    }

    for (final cookie in cookies) {
      final parts = cookie.split(';');

      for (final part in parts) {
        final item = part.trim();

        if (item.startsWith('token=')) {
          return item.substring('token='.length).trim();
        }
      }
    }

    return '';
  }

  ApiException handleError(dynamic error) {
    if (error is DioException) {
      // أخطاء الشبكة/الاتصال — رسائل واضحة للمستخدم
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiException(
            'انتهت مهلة الاتصال. تأكد من اتصالك بالإنترنت وحاول مرة أخرى',
          );
        case DioExceptionType.connectionError:
          return ApiException(
            'لا يوجد اتصال بالإنترنت. تحقق من الشبكة وحاول مجدداً',
          );
        case DioExceptionType.badCertificate:
          return ApiException('تعذّر تأمين الاتصال بالخادم');
        case DioExceptionType.cancel:
          return ApiException('تم إلغاء الطلب');
        case DioExceptionType.badResponse:
        case DioExceptionType.unknown:
          break;
      }

      // لا يوجد رد من الخادم إطلاقاً (غالباً انقطاع شبكة)
      if (error.response == null) {
        return ApiException(
          'تعذّر الوصول إلى الخادم. تحقق من اتصالك بالإنترنت',
        );
      }

      final data = error.response?.data;
      final status = error.response?.statusCode;

      // رسالة الخطأ القادمة من السيرفر إن وُجدت
      String? serverMessage;
      if (data is Map && data['message'] != null) {
        serverMessage = data['message'].toString();
      } else if (data is Map && data['error'] != null) {
        serverMessage = data['error'].toString();
      } else if (data is String && data.trim().isNotEmpty) {
        // أحياناً يرجع السيرفر/البروكسي نصاً عادياً أو HTML — حاول استخراج رسالة
        final text = data.trim();
        if (!text.startsWith('<') && text.length < 200) {
          serverMessage = text;
        }
      }

      if (serverMessage != null && serverMessage.isNotEmpty) {
        return ApiException(serverMessage, statusCode: status);
      }

      // رسائل افتراضية حسب رمز الحالة عندما لا يرسل السيرفر نصاً
      String fallback;
      if (status == 429) {
        fallback = 'محاولات كثيرة جداً. انتظر قليلاً ثم حاول مرة أخرى';
      } else if (status != null && status >= 500) {
        fallback = 'حدث خطأ في الخادم. حاول مرة أخرى بعد قليل';
      } else if (status == 401 || status == 403) {
        fallback = 'بيانات الدخول غير صحيحة';
      } else if (status == 404) {
        fallback = 'العنصر المطلوب غير موجود';
      } else {
        fallback = 'حدث خطأ بالاتصال (رمز: ${status ?? 'غير معروف'})';
      }

      return ApiException(fallback, statusCode: status);
    }

    return ApiException('حدث خطأ غير متوقع');
  }
}