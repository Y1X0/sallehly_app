// File generated based on android/app/google-services.json
//
// تم تحديث هذا الملف تلقائياً بعد إضافة تطبيق com.sallehly.app في Firebase Console.
// الأفضل لاحقاً إعادة توليده رسمياً عبر الأمر:
//   flutterfire configure
// خصوصاً عند إضافة منصة iOS أو Web، لأن القيم هنا تخص أندرويد فقط.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// خيارات Firebase الافتراضية للتطبيق.
///
/// الاستخدام:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'لم تتم تهيئة Firebase للويب بعد - '
        'أعد توليد هذا الملف عبر FlutterFire CLI لدعم الويب.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'لم تتم تهيئة Firebase لنظام iOS بعد - '
          'أضف تطبيق iOS في Firebase Console وأعد توليد هذا الملف.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'لم تتم تهيئة Firebase لنظام macOS بعد.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'لم تتم تهيئة Firebase لنظام Windows بعد.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'لم تتم تهيئة Firebase لنظام Linux بعد.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions غير مدعوم لهذه المنصة.',
        );
    }
  }

  // ✅ هذه القيم مأخوذة من google-services.json (تطبيق com.sallehly.app الجديد).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB1U9FxhveMTbpw0o_Ko9JTB6DwDveMHJ8',
    appId: '1:213407241503:android:4a32b8ac536ca6ed40cc2a',
    messagingSenderId: '213407241503',
    projectId: 'sallehly-9bc16',
    storageBucket: 'sallehly-9bc16.firebasestorage.app',
  );
}
