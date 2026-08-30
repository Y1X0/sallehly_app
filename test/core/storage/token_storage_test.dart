// [FIX-SECURESTORAGE-01] يغطي: عطل Android Keystore الفاسد (PlatformException
// من FlutterSecureStorage) لا يجعل تسجيل دخول ناجح فعلياً يبدو فاشلاً للأبد —
// TokenStorage يشفي نفسه (deleteAll ثم إعادة محاولة) بدل ترك الاستثناء ينتشر.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/core/storage/token_storage.dart';

class _FakeBackend implements SecureTokenBackend {
  final Map<String, String> _store = {};

  /// عند true: أول استدعاء لـwrite/read يفشل بـPlatformException (يحاكي
  /// Keystore فاسداً)، ثم ينجح ما بعده — بالضبط كسلوك العطل الحقيقي بعد
  /// deleteAll (إعادة الضبط تُصلح الفساد فوراً).
  bool failNextCall = false;
  int deleteAllCallCount = 0;
  int writeCallCount = 0;
  int readCallCount = 0;

  @override
  Future<String?> read(String key) async {
    readCallCount++;
    if (failNextCall) {
      failNextCall = false;
      throw PlatformException(code: 'KeyStoreException', message: 'corrupt');
    }
    return _store[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writeCallCount++;
    if (failNextCall) {
      failNextCall = false;
      throw PlatformException(code: 'KeyStoreException', message: 'corrupt');
    }
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failNextCall) {
      failNextCall = false;
      throw PlatformException(code: 'KeyStoreException', message: 'corrupt');
    }
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCallCount++;
    _store.clear();
  }
}

void main() {
  group('[FIX-SECURESTORAGE-01] TokenStorage يشفي نفسه من Keystore فاسد', () {
    late _FakeBackend backend;
    late TokenStorage storage;

    setUp(() {
      backend = _FakeBackend();
      storage = TokenStorage(backendOverride: backend);
    });

    test('saveToken: أول كتابة تفشل بـPlatformException — لا ينتشر الاستثناء، وتُحفَظ القيمة فعلياً بعد إعادة الضبط', () async {
      backend.failNextCall = true;

      await storage.saveToken('tok-123');

      expect(backend.deleteAllCallCount, 1);
      expect(await storage.getToken(), 'tok-123');
    });

    test('getToken: قراءة فاشلة بـPlatformException تُعامَل كـ"لا يوجد توكن" بدل إسقاط الاستثناء لكل طلب API لاحق', () async {
      await backend.write('sallehly_token', 'existing');
      backend.failNextCall = true;

      final result = await storage.getToken();

      expect(result, isNull);
      expect(backend.deleteAllCallCount, 1);
    });

    test('clearToken: حذف فاشل بـPlatformException (أول سطر بlogin()) لا يُسقط محاولة الدخول قبل أن تبدأ', () async {
      await backend.write('sallehly_token', 'old');
      backend.failNextCall = true;

      await storage.clearToken();

      expect(backend.deleteAllCallCount, 1);
      expect(await storage.getToken(), isNull);
    });

    test('التدفق الكامل: كتابة تفشل، ثم قراءة لاحقة (كأنها طلب API تالٍ) تنجح بلا أي عطل متبقٍّ', () async {
      backend.failNextCall = true;
      await storage.saveToken('tok-after-corruption');

      // لا فشل متبقٍّ — التخزين شُفي فعلياً، لا مجرد نجاح صدفة بهذه المحاولة.
      expect(await storage.getToken(), 'tok-after-corruption');
      expect(await storage.hasToken(), isTrue);
    });
  });
}
