// lib/core/perf_trace/perf_trace.dart
// ==========================================================================
// [TEMP-PERF-TRACE] أداة قياس مؤقتة فقط — لا تُغيّر أي منطق أو سلوك بالتطبيق.
// الهدف الوحيد: جمع أدلة حقيقية من الإنتاج لتحديد السبب الجذري الفعلي
// لرسالة "الخادم يستغرق وقتاً" (انظر تقرير Root Cause Investigation).
//
// كل استدعاء هنا: fire-and-forget بالكامل (لا await بمسار الطلب الحقيقي،
// لا يؤثر على أي مهلة/إعادة محاولة/رسالة خطأ حالية)، عبر Dio منفصل تماماً
// (لا يمر بأي interceptor من ApiClient الأساسي)، بمهلة قصيرة 3 ثوانٍ فقط
// وبلا إعادة محاولة إطلاقاً — حتى لا يُضيف هذا القياس نفسه أي حمل شبكة
// إضافي في حال كان الخادم متعثّراً أصلاً (وهو بالضبط ما نقيسه).
//
// كيف تُزال لاحقاً: احذف هذا الملف، واحذف كل استدعاء لـPerfTrace.* من
// api_client.dart وapp.dart (كل استدعاء معلَّم بتعليق [TEMP-PERF-TRACE]).
// ==========================================================================

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';

class PerfTrace {
  PerfTrace._();

  /// إيقاف/تشغيل سريع بلا حذف الكود — اجعلها false لتعطيل الإرسال للخادم
  /// فوراً (يبقى debugPrint المحلي فقط إن كان kDebugMode).
  static bool enabled = true;

  static final Dio _logDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 3),
      sendTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );

  static final Random _random = Random();

  static String newCorrelationId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'flt-$ts-$rand';
  }

  static void _send(Map<String, dynamic> payload) {
    if (kDebugMode) debugPrint('[PERF-TRACE-CLIENT] $payload');
    if (!enabled) return;
    // Fire-and-forget حقيقي: لا يُعاد رميه، لا ينتظره أي كود آخر.
    unawaited(
      _logDio.post<void>('/_debug/client-log', data: payload).catchError((
        _,
      ) {
        return Response<void>(
          requestOptions: RequestOptions(path: '/_debug/client-log'),
        );
      }),
    );
  }

  static void requestStart({
    required String correlationId,
    required String method,
    required String path,
  }) {
    _send({
      'correlationId': correlationId,
      'event': 'request_start',
      'method': method,
      'path': path,
      'clientTime': DateTime.now().toIso8601String(),
    });
  }

  static void requestEnd({
    required String correlationId,
    required String path,
    required int durationMs,
    int? statusCode,
  }) {
    _send({
      'correlationId': correlationId,
      'event': 'request_end',
      'path': path,
      'durationMs': durationMs,
      'statusCode': statusCode,
      'clientTime': DateTime.now().toIso8601String(),
    });
  }

  static void requestError({
    required String correlationId,
    required String path,
    required int durationMs,
    required String errorType,
  }) {
    _send({
      'correlationId': correlationId,
      'event': 'request_error',
      'path': path,
      'durationMs': durationMs,
      'errorType': errorType,
      'clientTime': DateTime.now().toIso8601String(),
    });
  }

  static void retryAttempt({
    required String correlationId,
    required String path,
    required int attempt,
  }) {
    _send({
      'correlationId': correlationId,
      'event': 'retry_attempt',
      'path': path,
      'attempt': attempt,
      'clientTime': DateTime.now().toIso8601String(),
    });
  }

  static void bannerShown({
    required String? correlationId,
    required String? path,
  }) {
    _send({
      'correlationId': correlationId,
      'event': 'banner_shown',
      'path': path,
      'clientTime': DateTime.now().toIso8601String(),
    });
  }
}
