import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [FIX-SECURESTORAGE-01] تجريد صغير حول FlutterSecureStorage يسمح بحقن
/// نسخة مزيَّفة عند الاختبار (بلا حاجة لقناة platform حقيقية غير متاحة أصلاً
/// بـ`flutter test`) — بنفس نمط `authApiOverride` المُعتمَد أصلاً بـ
/// AuthProvider.
abstract class SecureTokenBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class _FlutterSecureStorageBackend implements SecureTokenBackend {
  const _FlutterSecureStorageBackend();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

class TokenStorage {
  TokenStorage({SecureTokenBackend? backendOverride})
      : _backend = backendOverride ?? const _FlutterSecureStorageBackend();

  final SecureTokenBackend _backend;

  static const String _tokenKey = 'sallehly_token';

  Future<void> saveToken(String token) async {
    try {
      await _backend.write(_tokenKey, token);
    } on PlatformException {
      // [FIX-SECURESTORAGE-01] راجع DECISIONS.md — Android Keystore يصير
      // فاسداً بشكل معروف (تغيير قفل الشاشة/بصمة، استعادة نسخة احتياطية،
      // ترقية نظام) فيرفض كل قراءة/كتابة لاحقة بـPlatformException دائماً،
      // حتى لو كانت بيانات الدخول المُرسَلة صحيحة تماماً ونجح تسجيل الدخول
      // فعلياً على الخادم — بلا هذا الإصلاح، كل محاولة تسجيل دخول لاحقة كانت
      // ستفشل بنفس الطريقة للأبد حتى يمسح المستخدم بيانات التطبيق يدوياً (لا
      // يعرف غالباً أن هذا هو الحل). إعادة الضبط (deleteAll) هي طريقة الشفاء
      // الموثَّقة لهذا العطل تحديداً — تصلح الـKeystore الفاسد فوراً، والمحاولة
      // الثانية بعدها تنجح مباشرة لأن التخزين الآن نظيف من جديد.
      await _backend.deleteAll();
      await _backend.write(_tokenKey, token);
    }
  }

  Future<String?> getToken() async {
    try {
      return await _backend.read(_tokenKey);
    } on PlatformException {
      // [FIX-SECURESTORAGE-01] getToken() تُستدعى بكل طلب API (انظر معترض
      // ApiClient) — لو تُرك الاستثناء بلا التقاط هنا، كل طلب لاحق كان سيفشل
      // بنفس العطل، لا فقط تسجيل الدخول. المعاملة الآمنة الوحيدة الممكنة محلياً
      // هي اعتبار الحالة "لا يوجد توكن محفوظ" (تماماً كأول تشغيل للتطبيق) بعد
      // إعادة ضبط التخزين الفاسد، بدل ترك الاستثناء يُسقِط كل طلب API لاحق.
      await _backend.deleteAll();
      return null;
    }
  }

  Future<bool> hasToken() async {
    final token = await getToken();

    return token != null && token.isNotEmpty;
  }

  Future<void> clearToken() async {
    try {
      await _backend.delete(_tokenKey);
    } on PlatformException {
      // [FIX-SECURESTORAGE-01] تُستدعى بأول سطر بـlogin()/verifyOtp()، قبل أي
      // اتصال بالخادم أصلاً — عطل هنا كان يُسقط محاولة الدخول قبل أن تبدأ حتى.
      // deleteAll تصل لنفس الحالة النهائية المطلوبة (لا يوجد توكن محفوظ) مع
      // إصلاح التخزين الفاسد بنفس الوقت.
      await _backend.deleteAll();
    }
  }
}
