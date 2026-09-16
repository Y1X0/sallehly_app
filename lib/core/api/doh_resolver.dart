import 'dart:convert';
import 'dart:io';

/// [FIX-DNSFALLBACK-01] راجع DECISIONS.md — بعض شبكات الاتصال بالأردن تفشل
/// بحل DNS لموقعنا تحديداً بشكل متكرر ومؤكَّد (تجربة حقيقية: نفس الجهاز يفتح
/// جوجل/فيسبوك عادي، وموقعنا يفشل، وحل المشكلة نهائياً كان فقط تغيير DNS
/// الجهاز يدوياً لـ8.8.8.8). هذا يحل نفس المشكلة تلقائياً بلا أي تدخل من
/// المستخدم: DNS-over-HTTPS عبر خدمة جوجل العلنية — طلب HTTPS عادي (نفس
/// نوع الطلب الذي يعمل دائماً حتى على الشبكات المتأثرة، لأنه غير قابل
/// للتمييز عن أي حركة HTTPS عادية) يرجع نتيجة حل الاسم بدل استعلام DNS
/// تقليدي قد تفشل الشبكة تحديداً بتوصيله لاسمنا.
class DohResolver {
  DohResolver._();

  static final Map<String, _CachedResolution> _cache = {};

  /// يحل [hostname] لعنوان IPv4 عبر DNS-over-HTTPS، أو يرمي استثناءً لو فشل
  /// الحل أو انتهت مهلته — المستدعي مسؤول عن معالجة الفشل (راجع
  /// ApiClient._buildResilientHttpClient، يترك الاستثناء يتحول لخطأ اتصال
  /// عادي بلا أي تمييز عن فشل DNS النظام نفسه).
  static Future<InternetAddress> resolve(String hostname) async {
    final cached = _cache[hostname];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.address;
    }

    final client = HttpClient();
    try {
      final uri = Uri.https('dns.google', '/resolve', {
        'name': hostname,
        'type': 'A',
      });
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 6));
      final response = await request.close().timeout(const Duration(seconds: 6));
      final body = await response.transform(utf8.decoder).join();

      final parsed = parseFirstARecord(jsonDecode(body) as Map<String, dynamic>);
      final address = InternetAddress(parsed.ip);
      _cache[hostname] = _CachedResolution(
        address,
        DateTime.now().add(Duration(seconds: parsed.cacheSeconds)),
      );
      return address;
    } finally {
      client.close(force: true);
    }
  }

  /// [FIX-DNSFALLBACK-01] منطق تحليل رد Google DoH JSON مفصول بدالة صرفة —
  /// قابل للاختبار بلا أي طلب شبكة حقيقي (راجع test/doh_resolver_test.dart).
  /// يرمي [FormatException] لو الرد بلا أي سجل A (type=1، راجع RFC 1035).
  static ({String ip, int cacheSeconds}) parseFirstARecord(Map<String, dynamic> json) {
    final answers = (json['Answer'] as List?) ?? const [];

    // أول سجل A كافٍ — لا حاجة لموازنة حمل بين عناوين متعددة هنا، هذا مسار
    // احتياطي نادر لا طلبات مكثَّفة عليه.
    final aRecord = answers.cast<Map<String, dynamic>>().firstWhere(
      (a) => a['type'] == 1,
      orElse: () => throw const FormatException('no A record in DoH answer'),
    );

    // [FIX-DNSFALLBACK-01] لا نثق بـTTL طويل جداً (عناوين Render/Cloudflare
    // قد تتغيّر) ولا نعيد الاستعلام كل طلب (كلفة زمنية بلا داعٍ) — نافذة
    // بين 60 ثانية ودقيقتين تماماً كفاية لتغطية جلسة استخدام واحدة.
    final ttlSeconds = (aRecord['TTL'] as int?) ?? 60;
    final cacheSeconds = ttlSeconds < 60 ? 60 : (ttlSeconds > 120 ? 120 : ttlSeconds);

    return (ip: aRecord['data'].toString(), cacheSeconds: cacheSeconds);
  }
}

class _CachedResolution {
  final InternetAddress address;
  final DateTime expiresAt;

  _CachedResolution(this.address, this.expiresAt);
}
