# ── قواعد ProGuard لتطبيق صلّحلي ──
# تحافظ على الكلاسات الضرورية عند تفعيل تصغير الكود (minify) في نسخة الإصدار.

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase (Core + Messaging)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Play Core — مكتبة المكوّنات المؤجّلة (Deferred Components / Split Install).
# Flutter يشير لهذه الأصناف داخلياً لكن المكتبة غير مضمّنة، لذا نتجاهلها عند R8
# حتى لا يفشل البناء. التطبيق لا يستخدم ميزة المكوّنات المؤجّلة فعلياً.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication

# منع التحذيرات من مكتبات قد تشير لأصناف غير موجودة وقت التصغير
-dontwarn javax.annotation.**
-dontwarn org.codehaus.**

# الإبقاء على الأصناف التي تستخدم التسلسل/الانعكاس
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
