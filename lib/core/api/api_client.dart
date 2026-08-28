import 'dart:math';

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../i18n/current_locale.dart';
import '../storage/token_storage.dart';
import 'api_error_codes.dart';
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

  /// [FIX-SESSION-EXPIRY-01] مفتاح Options.extra يسمح لطلب معيّن بتجاوز
  /// onUnauthorized عند 401 — لموقع/سياقات لا يمثّل فيها 401 بالضرورة "جلسة
  /// منتهية" (تحقّق فعلياً قبل استخدامه، لا تفترض). راجع
  /// AuthApi.changePassword()/deleteAccount() للتوثيق الكامل والحالة
  /// المُتحقَّقة فعلياً من كود الخادم لكل موقع استخدام.
  static const skipUnauthorizedRedirectKey = 'skipUnauthorizedRedirect';

  /// اختصار لبناء Options تحمل مفتاح التجاوز أعلاه.
  Options skipUnauthorizedRedirect() =>
      Options(extra: {skipUnauthorizedRedirectKey: true});

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
            // [FIX-SESSION-EXPIRY-01] استثناء صريح لطلبات معلَّمة بـ
            // skipUnauthorizedRedirectKey — راجع تعريفها أعلاه لمن يستخدمها ولماذا.
            final skipRedirect =
                error.requestOptions.extra[skipUnauthorizedRedirectKey] == true;
            if (error.response?.statusCode == 401 && !skipRedirect) {
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

            // [PERF-HARDEN-01] قُلِّل الحد الأقصى لإعادة المحاولة من 3 إلى 2:
            // كل إعادة محاولة تصل فعلياً كطلب إضافي جديد للخادم. أثناء ازدحام
            // حقيقي (وليس مجرد استيقاظ عادي من الخمول)، محاولات أقل تعني ضغطاً
            // إضافياً أقل بالضبط باللحظة التي يكون الخادم فيها الأكثر حساسية،
            // بينما تبقى كافية للحالة الشائعة (كل محاولة أصلاً تحمل مهلة 40
            // ثانية خاصة بها كافية لانتظار استيقاظ الخادم — انظر أدناه).
            if (attempt < 2) {
              options.extra['retry_attempt'] = attempt + 1;

              // [PERF-HARDEN-01] جيتر عشوائي (حتى 500ms) فوق الانتظار المتزايد
              // (1s ثم 2s). بدونه، لو انتهت مهلة الطلب لعدّة مستخدمين بنفس
              // اللحظة تقريباً (مثال شائع: استيقاظ الخادم يؤثر على كل من كان
              // متصلاً وقتها معاً)، ستُعاد كل طلباتهم بنفس التوقيت بالضبط بعد
              // كل فترة انتظار، فتصل دفعة طلبات متزامنة جديدة للخادم دفعة
              // واحدة بدل توزّعها زمنياً — وهذا يُضخّم الازدحام بدل تخفيفه.
              final jitter = Duration(milliseconds: Random().nextInt(500));
              await Future.delayed(Duration(seconds: 1 << attempt) + jitter);

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

  // [L10N-TODO] كل رسائل الفشل الثابتة بهذه الدالة (مهلة/انقطاع اتصال/رموز
  // حالة HTTP الافتراضية، السطر 312 نهاية الدالة) عربية ثابتة حالياً — طبقة
  // شبكة صرفة بلا BuildContext إطلاقاً، ومُستهلَكة عبر ApiException.message
  // من كل شاشة تقريباً بالتطبيق (أكبر مستهلِك واحد بكل الكود). هذا الجزء لا
  // يزال بلا ترجمة (خارج نطاق [FIX-ERRCODE-01] أدناه، الذي يعالج رسائل
  // الخادم فقط).
  //
  // [FIX-ERRCODE-01] `serverMessage` أدناه (نص فعلي من السيرفر) كان مستثنى
  // بالكامل سابقاً من أي ترجمة — الآن، إن أرسل الخادم code معروفاً بجانبه
  // (راجع server.js)، يُستخدم نص ARB مترجَم بدله عبر resolveApiErrorCode()
  // قبل الوصول لـserverMessage. عندما لا يوجد code أو كان غير معروف، يبقى
  // السلوك القديم تماماً: نص الخادم الخام كما هو، لا تغيير ولا فرق ملحوظ.
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

      // [FIX-ERRCODE-02] بيانات إضافية لبعض الرموز (حالياً 6 رموز ديناميكية:
      // OFFER_ACTIVE_REQUEST_EXISTS، DELETE_ACCOUNT_ACTIVE_REQUEST،
      // DELETE_ACCOUNT_BALANCE_REMAINING، OTP_INCORRECT، SUPPORT_INVALID_TYPE،
      // INSUFFICIENT_BALANCE) — راجع server.js وresolveApiErrorCode.
      final Map<String, dynamic>? errorParams =
          (data is Map && data['params'] is Map)
              ? Map<String, dynamic>.from(data['params'] as Map)
              : null;

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

      // [FIX-ERRCODE-01] إن كان code معروفاً، استخدم النص المترجَم محلياً عبر
      // ARB بدل نص الخادم العربي الخام — يعمل بأي لغة مدعومة، بما فيها
      // العربية (نص ARB مطابق حرفياً لنص الخادم). currentAppLocale (راجع
      // core/i18n/current_locale.dart) لأن هذه الطبقة صرفة بلا BuildContext.
      //
      // أي فشل هنا (رمز غير معروف، params ناقصة/تالفة لرمز يحتاجها، أو أي
      // استثناء غير متوقَّع من طبقة الترجمة نفسها) يُعيدنا لنفس سلوك
      // serverMessage أدناه تماماً كما كان قبل هذا التغيير — لا شاشة تنكسر
      // بسبب رمز خطأ لم يُبنَ التطبيق ليعرفه بعد.
      if (errorCode != null) {
        String? localized;
        try {
          localized = resolveApiErrorCode(
            lookupAppLocalizations(currentAppLocale),
            errorCode,
            params: errorParams,
          );
        } catch (_) {
          localized = null;
        }
        if (localized != null && localized.isNotEmpty) {
          return ApiException(localized, statusCode: status, code: errorCode);
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
