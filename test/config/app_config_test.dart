// [FIX-DEVCLEARTEXT-01] راجع DECISIONS.md — يحمي قيمة AppConfig.baseUrl
// الافتراضية (بلا --dart-define) من أي تغيير غير مقصود لاحقاً. لا CI حالياً
// (android-build.yml، android-release-signed.yml، temp-build-apk.yml) يمرر
// --dart-define=API_BASE_URL عند بناء appbundle/apk --release — كلها تعتمد
// على هذه القيمة الافتراضية بالذات لتصل فعلياً للإنتاج الحقيقي. تغييرها
// بغفلة (مثلاً أثناء تطوير محلي، بنسيان --dart-define) يكسر كل بناء إنتاجي
// حقيقي بصمت.
import 'package:flutter_test/flutter_test.dart';

import 'package:sallehly_app/config/app_config.dart';

void main() {
  test('AppConfig.baseUrl الافتراضية (بلا --dart-define) تبقى الإنتاج الحقيقي', () {
    expect(AppConfig.baseUrl, 'https://sallehly.com');
    expect(AppConfig.apiUrl, 'https://sallehly.com/api');
  });
}
