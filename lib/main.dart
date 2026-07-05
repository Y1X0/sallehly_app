import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/notifications/firebase_notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // محاولة تهيئة Firebase — إذا لم يكن مهيّأً بعد (مثلاً لا يوجد google-services.json
  // مطابق) يتجاوز التطبيق الإشعارات ويكمل العمل بشكل طبيعي بدل أن يتعطل.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseNotificationService.init();
  } catch (e) {
    debugPrint('[Firebase] disabled — skipped init: $e');
  }

  runApp(
    const SallehlyApp(),
  );
}
