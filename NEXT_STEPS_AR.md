# صلّحلي — الحالة النهائية والخطوات المتبقية

## ✅ ما تم إصلاحه بالكامل في الكود

1. **حُذف 56 ملف Dart فارغ** (من 151 إلى 95 ملفاً) — كل الاستيرادات سليمة.
2. **firebase_options.dart** أُنشئ ورُبط في main.dart.
3. **applicationId غُيّر** من `com.example.sallehly_app` إلى **`com.sallehly.app`** في:
   - android/app/build.gradle.kts  (namespace + applicationId)
   - MainActivity.kt  (نُقل للمسار الجديد com/sallehly/app + سطر package)
4. **توقيع الإصدار** صار صحيحاً عبر android/key.properties (مع رجوع آمن لـ debug).
5. **proguard-rules.pro** + تفعيل minify/shrink لتصغير الحجم.


## ⚠️ ما تبقّى — يحتاج تدخّلك (لا يمكن عمله بالكود)

### 1) Firebase: أضف التطبيق بالاسم الجديد ونزّل google-services.json  ← الأهم
السبب: ملف google-services.json الحالي ما زال يحمل الاسم القديم com.example،
وهذا الملف تولّده Google ولا يمكن تعديله يدوياً بأمان.

الخطوات (5 دقائق):
1. ادخل https://console.firebase.google.com  → مشروع **sallehly-9bc16**
2. إعدادات المشروع (⚙️) → قسم "تطبيقاتك" → **أضف تطبيقاً → Android**
3. في "اسم حزمة Android" اكتب بالضبط:  **com.sallehly.app**
4. (اختياري) أضف SHA-1 من مفتاح التوقيع لاحقاً إن احتجت ميزات تتطلبه.
5. اضغط "تنزيل google-services.json" وضع الملف مكان القديم في:
   **android/app/google-services.json**  (استبدل القديم)
6. افتح الملف الجديد وانسخ منه قيمتين إلى lib/firebase_options.dart:
   - mobilesdk_app_id   →  ضعها مكان  appId
   - api_key.current_key →  ضعها مكان  apiKey
   (الموضع معلّم بتعليق ⚠️ داخل الملف)

### 2) أنشئ مفتاح التوقيع (مرة واحدة فقط)
```
keytool -genkey -v -keystore sallehly-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sallehly
```
ثم: انسخ android/key.properties.example → android/key.properties واملأ القيم.
احفظ ملف .jks في مكان آمن جداً (فقدانه = استحالة تحديث التطبيق مستقبلاً).

### 3) التحقق والبناء
```
flutter clean
flutter pub get
flutter analyze        ← ابعت لي المخرجات إن ظهر أي خطأ
flutter build appbundle --release
```

### 4) (اختياري لكن مُفضّل) بدل الخطوة 1 يدوياً، استخدم:
```
flutterfire configure
```
يضيف التطبيق ويولّد firebase_options.dart رسمياً ويدعم iOS تلقائياً.

### 5) تأكد أن baseUrl صحيح
lib/config/app_config.dart → https://sallehly.com (مطابق لموقعكم ✓)
