import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  final TokenStorage tokenStorage;

  late final Dio dio;

  /// تُستدعى عند نجاح أي طلب (متصل).
  void Function()? onOnline;

  /// تُستدعى فقط عند خطأ شبكة حقيقي (لا يوجد اتصال إنترنت إطلاقاً).
  void Function()? onOffline;

  /// [FIX-AUTH-01] تُستدعى فقط عند 401 حقيقي قادم من الخادم (وليس أي خطأ
  /// شبكة/مهلة) — لتنظيف الجلسة مركزياً من مكان واحد بدل كل شاشة على حدة.
  void Function()? onUnauthorized;

  /// [FIX-CONNECTIVITY-01] تُستدعى عند انتهاء مهلة الاتصال بينما الإنترنت
  /// نفسه قد يكون سليماً — الخادم فقط بطيء بالرد (مثلاً استيقاظ خادم Render
  /// المجاني بعد خمول). منفصلة تماماً عن onOffline لتفادي رسالة مضلِّلة.
  void Function()? onServerSlow;

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
          // وصل رد من الخادم (حتى لو خطأ) → نحن متصلون والخادم يستجيب.
          // [FIX-CONNECTIVITY-01] فصلنا "لا يوجد إنترنت فعلاً" عن "الخادم بطيء
          // بالرد فقط" — كانا يُعاملان كنفس الشيء سابقاً، ما ينتج رسالة خاطئة
          // ("لا يوجد اتصال بالإنترنت") بينما إنترنت المستخدم سليم تماماً
          // والمشكلة فقط إبطاء خادم Render المجاني عند استيقاظه من الخمول.
          if (error.response != null) {
            onOnline?.call();

            // [FIX-AUTH-01] 401 حقيقي من الخادم فقط (رد فعلي وصل، برمز 401) —
            // لا علاقة له بانقطاع الشبكة أو بطء الخادم (تلك تُعالَج بالفروع
            // أدناه). هذا وحده يعني أن الجلسة/التوكن لم يعودا صالحين.
            if (error.response?.statusCode == 401) {
              onUnauthorized?.call();
            }
          } else if (_isTrueOfflineError(error)) {
            onOffline?.call();
          } else if (_isServerTimeoutError(error)) {
            onServerSlow?.call();
          }

          // إعادة المحاولة تلقائياً عند فشل الشبكة أو بطء الخادم
          // (مفيد خصوصاً عندما يكون الخادم "نائماً" ويستغرق وقتاً ليستيقظ).
          //
          // [FIX-RETRY-01] مُقيَّدة الآن بطلبات GET/HEAD فقط (انظر _shouldRetry).
          // السبب: عند timeout لا نعرف يقيناً هل الخادم نفّذ الطلب فعلاً قبل
          // انقطاع الرد أم لا. لطلبات القراءة (GET) هذا غير مهم — إعادة الطلب
          // آمنة دائماً. لكن لطلبات مثل إنشاء طلب صيانة (POST /requests)،
          // إرسال عرض (POST /requests/:id/offer)، أو طلب شحن رصيد
          // (POST /topups)، إعادة الإرسال التلقائي قد تُنشئ نسخة مكرّرة من
          // نفس العملية فعلياً على الخادم دون علم المستخدم. لذلك أي طلب غير
          // GET/HEAD يفشل بسبب الشبكة يُترك ليظهر خطأه للمستخدم مباشرة
          // (عبر handleError) بدل إعادة إرساله تلقائياً.
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
                // [FIX-RETRY-02] retryDio كائن منفصل بلا أي Interceptors —
                // نجاح الطلب هنا لا يمر إطلاقاً عبر onResponse الأصلي أعلاه،
                // فكان onOnline() لا يُستدعى أبداً رغم نجاح الطلب فعلياً،
                // ويبقى البانر ظاهراً على الشاشة حتى ينجح طلب آخر لاحق
                // بالصدفة عبر المسار الطبيعي. استدعاء صريح هنا يصحّح الحالة
                // فوراً بمجرد أن نعرف يقيناً أن الخادم استجاب.
                onOnline?.call();
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

  /// [FIX-CONNECTIVITY-01] خطأ شبكة حقيقي من جهاز المستخدم نفسه — لا يوجد
  /// مسار اتصال بالإنترنت إطلاقاً (فشل DNS، لا شبكة، وضع الطيران...).
  /// هذا النوع تحديداً (connectionError) يعني عدم القدرة على فتح أي اتصال
  /// إطلاقاً، بعكس الـ timeouts أدناه التي قد تعني فقط خادماً بطيئاً بالرد.
  bool _isTrueOfflineError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        // عادةً فشل DNS أو انقطاع شبكة حقيقي (لا يوجد رد من الخادم إطلاقاً)
        return error.response == null;
      default:
        return false;
    }
  }

  /// [FIX-CONNECTIVITY-01] انتهت مهلة الاتصال، لكن هذا لا يعني بالضرورة عدم
  /// وجود إنترنت — الاحتمال الأقوى عملياً هو خادم Render (الخطة المجانية)
  /// "نائم" ويستغرق حتى 50 ثانية أو أكثر ليستيقظ (موثّق رسمياً من Render
  /// نفسها)، فتنتهي مهلة الاتصال قبل أن يستجيب رغم أن إنترنت المستخدم سليم.
  bool _isServerTimeoutError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return true;
      default:
        return false;
    }
    }
  /// هل هذا خطأ شبكة بأي من نوعيه (لأغراض إعادة المحاولة التلقائية فقط —
  /// انظر _isTrueOfflineError/_isServerTimeoutError لتصنيف البانر الصحيح).
  bool _isNetworkError(DioException error) =>
      _isTrueOfflineError(error) || _isServerTimeoutError(error);

  /// هل يجوز إعادة إرسال هذا الطلب تلقائياً؟
  /// [FIX-RETRY-01] يشترط أن يكون الخطأ خطأ شبكة (_isNetworkError) وأن يكون
  /// الطلب من نوع GET/HEAD حصراً — وهما الطريقتان الآمنتان للتكرار (idempotent)
  /// بحكم تعريفهما. أي طلب POST/PUT/PATCH/DELETE لا يُعاد تلقائياً أبداً.
  bool _shouldRetry(DioException error) {
    if (!_isNetworkError(error)) return false;

    final method = error.requestOptions.method.toUpperCase();
    return method == 'GET' || method == 'HEAD';
  }

  /// [FIX-UPLOADTIMEOUT-01] رفع الملفات (صور/تسجيلات صوتية) يشارك نفس مهلة
  /// الـ20 ثانية العامة لكل طلبات API رغم أن مدة الرفع تعتمد على سرعة رفع
  /// المستخدم نفسها لا على استجابة الخادم — ملف صوتي 5MB على شبكة ضعيفة
  /// (~150KB/s) يحتاج فعلياً أكثر من 30 ثانية لمجرد الإرسال، فتظهر رسالة
  /// "الخادم بطيء" رغم أن المشكلة بالكامل هي سرعة رفع المستخدم. مهلة أطول
  /// خاصة بطلبات الرفع فقط (لا تؤثر على أي طلب API عادي آخر).
  Options uploadOptions({Duration timeout = const Duration(seconds: 60)}) {
    return Options(sendTimeout: timeout, receiveTimeout: timeout);
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
        case DioExceptionType.transformTimeout:
          // [FIX-CONNECTIVITY-02] كانت هذه الرسالة تقول "تأكد من اتصالك
          // بالإنترنت" لنفس أنواع الأخطاء التي صار البانر العام (app.dart)
          // يصنّفها الآن كـ"الخادم بطيء بالرد" — تناقض مباشر كان يظهر
          // للمستخدم رسالتين مختلفتين بنفس اللحظة. وحّدنا الصياغة.
          return ApiException(
            'الخادم يستغرق وقتاً أطول من المعتاد للرد. حاول مرة أخرى بعد قليل',
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

      // [FIX-OFFERQUOTA-01] رمز الخطأ الصريح (إن وُجد) — مثل 'INSUFFICIENT_BALANCE'.
      final String? errorCode =
          (data is Map && data['code'] != null) ? data['code'].toString() : null;

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
        return ApiException(serverMessage, statusCode: status, code: errorCode);
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

      return ApiException(fallback, statusCode: status, code: errorCode);
    }

    return ApiException('حدث خطأ غير متوقع');
  }
}
