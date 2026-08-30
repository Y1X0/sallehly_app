import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─── Background handler — لازم تكون top-level function خارج الكلاس ───
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // [SEC-FIX-BGHANDLERCATCH-01] راجع DECISIONS.md — هذا isolate يعمل خارج
  // main()'s runZonedGuarded/FlutterError.onError (المُضافة بـFIX-CRASHREPORT-01)
  // إطلاقاً — تلك الشبكة الآمنة تُنشَأ فقط داخل zone عملية main() نفسها، لا
  // تشمل isolate الخلفية المنفصل هذا. بلا try/catch هنا، أي فشل بمكوّن
  // الإشعارات المحلية (اختلاف جهاز/نظام تشغيل) كان يفشل بصمت تام — لا الإشعار
  // يظهر، ولا أي تقرير عطل يصل Crashlytics، رغم أن كل الهدف من الاستثمار
  // بالتبليغ عن الأعطال أصلاً هو ألا يمر أي فشل بلا أثر.
  try {
    // التطبيق في الخلفية أو مغلق — أظهر الإشعار محلياً
    await FirebaseNotificationService._showLocalNotificationStatic(message);
  } catch (e) {
    if (kDebugMode) debugPrint('[firebaseBackgroundHandler] فشل عرض إشعار الخلفية: $e');
  }
}

class FirebaseNotificationService {
  FirebaseNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // [L10N-05] اسم/وصف القناة `const` — لا BuildContext ولا حتى نداء دالة
  // ممكن هنا أصلاً. أهم من ذلك: أندرويد يخزّن بيانات القناة (بما فيها
  // الاسم/الوصف) مرتبطة بمعرّف القناة ('sallehly_main') مرة واحدة عند أول
  // إنشاء لها على جهاز المستخدم — تغيير النص بالكود لاحقاً بلا تغيير
  // المعرّف نفسه لا يُحدِّث القنوات الموجودة أصلاً لدى المستخدمين الحاليين
  // (سلوك منصّة أندرويد، وليس قيداً بفلَتّر). ليست هدفاً واقعياً للترحيل.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'sallehly_main',
    'صلّحلي Notifications',
    description: 'إشعارات تطبيق صلّحلي',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

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

    // [FIX-FCMREFRESH-01] راجع DECISIONS.md — إرسال التوكن الأولي وإعادة
    // إرساله عند التجدد كلاهما الآن مسؤولية AuthProvider حصراً
    // (lib/providers/auth_provider.dart)، لا هذا الملف: AuthProvider يملك
    // الاتصال الحقيقي بالسيرفر (authApi.apiClient.dio) أصلاً ويستدعي نفس
    // _sendFcmTokenToServer() بعد login/verifyOtp/loadMe وعند كل تجدد توكن.
    // كان هذا الملف يحمل تطبيقاً موازياً كاملاً (configure/_dio/_baseUrl/
    // _sendTokenToServer/sendPendingToken) لم يستدعِه أي كود إطلاقاً —
    // فالتوكن المتجدد كان يُحفظ محلياً فقط بصمت ولا يصل السيرفر أبداً لمستخدم
    // لا يزال مسجَّلاً دخوله. أُزيل كلياً بدل تركه مسار ميت ثانٍ بجانب المسار
    // الحقيقي الجديد.

    // ٢. الإشعارات لما التطبيق مفتوح (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM] Foreground message: ${message.notification?.title}');
      }
      _showLocalNotificationStatic(message);
    });

    // ٣. لما يضغط على الإشعار والتطبيق في الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) debugPrint('[FCM] Opened from background: ${message.data}');
      handleNotificationTap(message.data);
    });

    // ٤. لما يفتح التطبيق من إشعار وكان مغلقاً
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        debugPrint('[FCM] Opened from terminated: ${initialMessage.data}');
      }
      handleNotificationTap(initialMessage.data);
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
      settings: settings,
      // [FIX-DEEPLINK-02] هذا هو الاستدعاء الفعلي عند الضغط على الإشعار
      // بينما التطبيق مفتوح (onMessage يعرضه محلياً عبر
      // _showLocalNotificationStatic، وليس عبر عرض FCM التلقائي) — كان بلا
      // أي تأثير سوى debugPrint، فالضغط على إشعار وصل والتطبيق شغّال لا
      // يوصّل المستخدم لأي مكان إطلاقاً، بعكس onMessageOpenedApp/
      // getInitialMessage (يعملان فقط والتطبيق بالخلفية/مغلق). الآن يفكّ
      // ترميز الحمولة الكاملة (JSON، وليس النوع فقط كما كانت من قبل) ويمرّرها
      // لنفس handleNotificationTap المستخدَم بمساري الخلفية/الإغلاق.
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
          handleNotificationTap(data);
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

  // ─── عرض الإشعار محلياً (static عشان تشتغل من background handler) ───
  // [L10N-05] هذه الدالة تُستدعى أيضاً من firebaseBackgroundHandler أعلاه،
  // الذي يعمل بـisolate خلفية منفصل تماماً بلا أي شجرة ودجت/BuildContext
  // — ليس مؤجَّلاً لملف مستهلِك لاحق كباقي الحالات المشابهة بهذا المستند،
  // بل قيد بنيوي حقيقي (لا BuildContext ممكن هنا إطلاقاً بأي مرحلة). حل
  // الترجمة الصحيح هنا مختلف تماماً: قراءة لغة محفوظة عبر SharedPreferences
  // مباشرة (كما بباقي هذا الملف) ثم AppLocalizations.delegate.load(locale)
  // يدوياً بلا BuildContext — تغيير هيكلي أكبر من نطاق الترحيل الميكانيكي
  // الحالي، ومسار احتياطي نادر أصلاً (فقط لو حمولة FCM جاءت بلا title/body).
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
    // (requestId/ticketId إلخ) لتمريرها لنفس handleNotificationTap المستخدَم
    // بمساري الخلفية/الإغلاق. message.data كلها نصوص أصلاً (سيرفر Push يحوّلها
    // بـString(v) قبل الإرسال) فـjsonEncode آمن هنا بلا أي قيمة معقّدة متوقَّعة.
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
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
  //
  // [TEST-FIX-NOTIFTAP-01] راجع DECISIONS.md — بلا underscore وبـ
  // @visibleForTesting عمداً، لا لأنها جزء من الواجهة العامة المقصودة لهذا
  // الصنف (لم تكن كذلك قبل هذا التغيير، ولا تزال غير مقصودة للاستدعاء من
  // خارج هذا الملف بالتطبيق نفسه) — فقط لتمكين اختبارها مباشرة. المسار
  // الحقيقي الذي يستدعيها فعلياً (onDidReceiveNotificationResponse داخل
  // _initLocalNotifications) يبقى غير قابل للاختبار مباشرة بلا محاكاة
  // Firebase.initializeApp() كاملة (تكلفة غير متناسبة هنا) — هذا الكشف
  // يتيح اختبار المنطق الحقيقي لهذه الدالة بمعزل عن ذلك القيد تحديداً.
  @visibleForTesting
  static void handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (kDebugMode) debugPrint('[FCM] Notification type: $type');
    if (type == null || type.isEmpty) return;
    pendingDeepLink.value = Map<String, dynamic>.from(data);
  }
}
