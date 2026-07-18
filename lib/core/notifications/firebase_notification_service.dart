import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Background handler — لازم تكون top-level function خارج الكلاس ───
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // التطبيق في الخلفية أو مغلق — أظهر الإشعار محلياً
  await FirebaseNotificationService._showLocalNotificationStatic(message);
}

class FirebaseNotificationService {
  FirebaseNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'sallehly_main',
    'صلّحلي Notifications',
    description: 'إشعارات تطبيق صلّحلي',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // ─── الـDio للتواصل مع السيرفر — يتعمل inject من الخارج ───
  static Dio? _dio;
  static String? _baseUrl;

  /// استدعيها بعد تسجيل الدخول مباشرة
  static void configure({required Dio dio, required String baseUrl}) {
    _dio = dio;
    _baseUrl = baseUrl;
  }

  // ─── [FIX-DEEPLINK-01] هدف التنقّل المُعلَّق من آخر إشعار ضُغط عليه ───
  // القيمة تبقى محفوظة هنا (وليست عابرة) حتى تُقرأ فعلياً — يغطي حالتين:
  // ١) التطبيق كان بالخلفية والمستخدم ضغط الإشعار (onMessageOpenedApp).
  // ٢) التطبيق كان مغلقاً تماماً وفُتح من الإشعار (getInitialMessage) — هنا
  //    الشاشة الرئيسية (Layout) قد لا تكون بُنيت بعد وقت الضغط، فنُبقي القيمة
  //    محفوظة إلى أن يقرأها الـLayout المناسب بعد اكتمال تسجيل الدخول/التوجيه.
  // كل Layout (Customer/Technician/Admin) يستمع لهذه القيمة ويستهلكها
  // (يعيدها null) بمجرد التعامل معها، حتى لا يُعاد تنفيذها بالخطأ لاحقاً.
  static final ValueNotifier<Map<String, dynamic>?> pendingDeepLink =
      ValueNotifier<Map<String, dynamic>?>(null);

  static Future<void> init() async {
    // ١. سجّل background handler أولاً
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    await _requestPermission();
    await _initLocalNotifications();
    await _createAndroidChannel();

    // ٢. احصل على الـtoken وارسله للسيرفر
    await _fetchAndSaveToken();

    // ٣. لما يتجدد الـtoken (مثلاً بعد restore) — ارسله تلقائياً
    _messaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) debugPrint('[FCM] Token refreshed');
      _sendTokenToServer(newToken);
    });

    // ٤. الإشعارات لما التطبيق مفتوح (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM] Foreground message: ${message.notification?.title}');
      }
      _showLocalNotificationStatic(message);
    });

    // ٥. لما يضغط على الإشعار والتطبيق في الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) debugPrint('[FCM] Opened from background: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // ٦. لما يفتح التطبيق من إشعار وكان مغلقاً
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        debugPrint('[FCM] Opened from terminated: ${initialMessage.data}');
      }
      _handleNotificationTap(initialMessage.data);
    }
  }

  // ─── طلب الإذن ───
  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (kDebugMode) debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
  }

  // ─── تهيئة الإشعارات المحلية ───
  static Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings,
      // [FIX-DEEPLINK-02] هذا هو الاستدعاء الفعلي عند الضغط على الإشعار
      // بينما التطبيق مفتوح (onMessage يعرضه محلياً عبر
      // _showLocalNotificationStatic، وليس عبر عرض FCM التلقائي) — كان بلا
      // أي تأثير سوى debugPrint، فالضغط على إشعار وصل والتطبيق شغّال لا
      // يوصّل المستخدم لأي مكان إطلاقاً، بعكس onMessageOpenedApp/
      // getInitialMessage (يعملان فقط والتطبيق بالخلفية/مغلق). الآن يفكّ
      // ترميز الحمولة الكاملة (JSON، وليس النوع فقط كما كانت من قبل) ويمرّرها
      // لنفس _handleNotificationTap المستخدَم بمساري الخلفية/الإغلاق.
      onDidReceiveNotificationResponse: (details) {
        if (kDebugMode) {
          debugPrint('[FCM] Local notification tapped: ${details.payload}');
        }
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(
            jsonDecode(payload) as Map,
          );
          _handleNotificationTap(data);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[FCM] Failed to decode local notification payload: $e');
          }
        }
      },
    );
  }

  // ─── إنشاء Channel للأندرويد ───
  static Future<void> _createAndroidChannel() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
  }

  // ─── احصل على الـtoken واحفظه ───
  static Future<void> _fetchAndSaveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      if (kDebugMode) debugPrint('[FCM] Token received ✓');

      // احفظ محلياً
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);

      // ارسله للسيرفر
      await _sendTokenToServer(token);
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Error getting token: $e');
    }
  }

  // ─── إرسال الـtoken للسيرفر ───
  static Future<void> _sendTokenToServer(String token) async {
    if (_dio == null || _baseUrl == null) {
      // احفظه مؤقتاً — رح يتبعت لما يتسجل الدخول
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token_pending', token);
      if (kDebugMode) {
        debugPrint('[FCM] Token saved locally — will send after login');
      }
      return;
    }
    try {
      await _dio!.post(
        '$_baseUrl/api/fcm-token',
        data: {'token': token},
      );
      if (kDebugMode) debugPrint('[FCM] Token sent to server ✓');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Failed to send token: $e');
    }
  }

  /// استدعيها بعد تسجيل الدخول مباشرة
  static Future<void> sendPendingToken() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString('fcm_token_pending');
    if (pending != null && _dio != null) {
      await _sendTokenToServer(pending);
      await prefs.remove('fcm_token_pending');
    }
  }

  // ─── عرض الإشعار محلياً (static عشان تشتغل من background handler) ───
  static Future<void> _showLocalNotificationStatic(RemoteMessage message) async {
    final notification = message.notification;

    final title = notification?.title ??
        message.data['title']?.toString() ??
        'صلّحلي';
    final body = notification?.body ??
        message.data['body']?.toString() ??
        'لديك إشعار جديد';

    const androidDetails = AndroidNotificationDetails(
      'sallehly_main',
      'صلّحلي Notifications',
      channelDescription: 'إشعارات تطبيق صلّحلي',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    // [FIX-DEEPLINK-02] كانت الحمولة تحمل النوع (type) فقط — يكفي للاستدلال
    // لكن onDidReceiveNotificationResponse (أسفل) الآن يحتاج الحمولة الكاملة
    // (requestId/ticketId إلخ) لتمريرها لنفس _handleNotificationTap المستخدَم
    // بمساري الخلفية/الإغلاق. message.data كلها نصوص أصلاً (سيرفر Push يحوّلها
    // بـString(v) قبل الإرسال) فـjsonEncode آمن هنا بلا أي قيمة معقّدة متوقَّعة.
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  // ─── التعامل مع الضغط على الإشعار ───
  // [FIX-DEEPLINK-01] كانت هذه الدالة بلا أي تأثير فعلي (كود معلَّق فقط).
  // الآن تنشر بيانات الإشعار (type + requestId/ticketId) عبر pendingDeepLink
  // حتى تلتقطها شاشة الـLayout المناسبة (Customer/Technician/Admin) وتفتح
  // التبويب الصحيح. لا تنقل مباشرة لأي Widget هنا عمداً — هذه الدالة static
  // بلا BuildContext ولا تعرف دور المستخدم الحالي (customer/technician/admin)،
  // فترك القرار لكل Layout (الذي يعرف دوره وتبويباته) هو الصحيح والآمن.
  static void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (kDebugMode) debugPrint('[FCM] Notification type: $type');
    if (type == null || type.isEmpty) return;
    pendingDeepLink.value = Map<String, dynamic>.from(data);
  }
}
