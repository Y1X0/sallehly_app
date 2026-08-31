import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/notifications/firebase_notification_service.dart';
import 'core/socket/socket_service.dart';
import 'core/storage/app_storage.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/provider/admin_provider.dart';
import 'features/auth/screens/landing_screen.dart';
import 'features/chat/provider/chat_provider.dart';
import 'features/requests/provider/requests_provider.dart';
import 'features/splash/splash_screen.dart';
import 'features/support/provider/support_provider.dart';
import 'features/wallet/provider/wallet_provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/socket_provider.dart';
import 'providers/theme_controller.dart';

/// [FIX-SESSION-EXPIRY-01] يسمحان بالتنقّل وعرض رسالة من خارج شجرة الودجت
/// (من AuthProvider.onSessionExpired، مُستدعاة من طبقة بيانات صرفة بلا أي
/// BuildContext خاص بها) — النمط القياسي بفلَتّر لهذه الحالة بالضبط. مُعرَّفان
/// هنا (لا داخل auth_provider.dart) حتى يبقى AuthProvider خالياً من أي
/// استيراد لواجهة/تنقّل، بنفس نمط بقية hooks الملف (onAuthenticated/onLoggedOut).
final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// [BUG-FIX-DEEPLINKRACE-01] راجع DECISIONS.md — كانت onAuthenticated/
// onLoggedOut إغلاقين (closures) مُضمَّنين مباشرة داخل
// _SocketBootstrapperState.didChangeDependencies، فلا يمكن استدعاؤهما أو
// اختبارهما بمعزل عن بناء شجرة الودجت الكاملة (Firebase حقيقي، قنوات platform
// حقيقية غير متاحة بـ`flutter test`). استُخرجا هنا لدالة علوية مستقلة تأخذ كل
// الـProviders معاملات صريحة — بلا أي تغيير سلوكي عن الإغلاق السابق — خصيصاً
// ليتمكن اختبار حقيقي (test/widgets/auth_lifecycle_deeplink_test.dart) من
// استدعاء onAuthenticated الحقيقية بمزوّدات وهمية ويثبت مباشرة أنها لا تمسح
// FirebaseNotificationService.pendingDeepLink — وهو بالضبط ما كان غائباً حين
// أُدخِلت [SEC-FIX-DEEPLINKCLEAR-01] ذاتها بجولة سابقة: تعديل صحيح النية على
// إغلاق غير قابل للاختبار، فلم يلتقطه أي اختبار حين صار خاطئاً.
void bindAuthLifecycleCallbacks({
  required AuthProvider authProvider,
  required SocketProvider socketProvider,
  required NotificationProvider notificationProvider,
  required ChatProvider chatProvider,
  required RequestsProvider requestsProvider,
  required WalletProvider walletProvider,
  required AdminProvider adminProvider,
  required SupportProvider supportProvider,
}) {
  authProvider.onAuthenticated = () async {
    // [CRIT-FIX-02] / [SEC-FIX-CHATCLEAR-01] راجع DECISIONS.md — أول شيء
    // يحدث عند أي تسجيل دخول/تسجيل حساب/استعادة جلسة — قبل أي شيء آخر.
    // AuthProvider.login()/verifyOtp() يمسحان tokenStorage/appStorage
    // دفاعياً بدايةً بغض النظر عن استدعاء logout() صراحة قبلهما أم لا
    // (نفس النمط بالضبط بـlib/providers/auth_provider.dart) — أي "تسجيل
    // دخول" قد يكون فعلياً تبديل مستخدم على نفس الجهاز دون مرور صريح
    // بمسار تسجيل خروج. قبل هذا الإصلاح، loadNotifications() (أدناه)
    // كانت تدمج إشعارات المستخدم الجديد فوق أي إشعارات (لحظية أو محمَّلة
    // سابقاً) للمستخدم *السابق* المتبقية بالقائمة — تسريب بيانات خاصة بين
    // حسابين مختلفين على نفس الجهاز. clear() هنا يضمن حالة فارغة قبل أي
    // تحميل جديد، بصرف النظر تماماً عن أي مسار أدّى لهذا التسجيل. نفس
    // المنطق يشمل الآن كل Provider يخبّئ بيانات خاصة بحساب مُعيَّن —
    // رسائل الشات، الطلبات/العروض، سجل الشحن/دفتر الحساب، بيانات لوحة
    // الأدمن، تذاكر الدعم — لا الإشعارات وحدها.
    notificationProvider.clear();
    chatProvider.clear();
    requestsProvider.clear();
    walletProvider.clear();
    adminProvider.clear();
    supportProvider.clear();
    // [SEC-FIX-DEEPLINKCLEAR-01] عمداً بدون مسح pendingDeepLink هنا —
    // راجع DECISIONS.md لتفصيل [BUG-FIX-DEEPLINKRACE-01]. main.dart يستدعي
    // FirebaseNotificationService.init() (يملأ pendingDeepLink من
    // getInitialMessage() عند إقلاع بارد بضغطة إشعار) قبل runApp()، وأما
    // onAuthenticated فيُطلَق أثناء استعادة الجلسة، قبل بناء أي Layout
    // بحسب الدور أصلاً. مسح القيمة هنا كان يُفرغها دائماً قبل أن يصل أي
    // مستهلك حقيقي لها (مستمع Layout المرفق لاحقاً، أو postFrameCallback
    // الخاص به) — فهدف التنقّل يُفقَد بصمت بكل إقلاع بارد من إشعار،
    // ١٠٠٪ من الوقت، لا فقط بحافة نادرة. سيناريو التسريب الفعلي الذي
    // صُمِّم هذا المسح لأجله (ضغط إشعار ثم تسجيل خروج قبل استهلاكه) يبقى
    // مغطّى بالكامل عبر onLoggedOut أدناه — الذي يُطلَق من logout()/
    // deleteAccount()/handleUnauthorized() الثلاثة. لا تُعِد إضافة هذا
    // السطر هنا بدون حل مشكلة الترتيب أولاً.
    await socketProvider.reconnect();
    // [FIX-CHATBADGE-01] بدون هذا، شارة الشات بالشريط السفلي (المرتبطة
    // بـChatProvider.totalUnread — المصدر الحقيقي المدعوم من الخادم عبر
    // GET /chats) تبقى صفراً منذ إقلاع التطبيق حتى يفتح المستخدم تبويب
    // "الدردشات" يدوياً ولو مرة واحدة. تحميل صامت هنا (بعد كل تسجيل
    // دخول/استعادة جلسة) يضمن ظهور الشارة الصحيحة فوراً من اللحظة
    // الأولى — يشمل إعادة تشغيل التطبيق واستعادة الجلسة المحفوظة تماماً.
    await chatProvider.loadChats(silent: true);
    // [NOTIF-FLUTTER-PHASE2A] نفس المنطق تماماً لإشعارات الخادم الدائمة —
    // اسحبها فوراً بعد كل تسجيل دخول/تسجيل حساب/استعادة جلسة، بدل انتظار
    // وصول أول حدث Socket.IO حي (الذي قد لا يصل لفترة، أو يفوت المستخدم
    // كل ما تراكم بينما كان غير متصل).
    await notificationProvider.loadNotifications();
  };
  authProvider.onLoggedOut = () {
    socketProvider.disconnect();
    // [CRIT-FIX-02] / [SEC-FIX-CHATCLEAR-01] راجع DECISIONS.md — امسح
    // فوراً عند تسجيل الخروج أيضاً (logout()، deleteAccount()،
    // وhandleUnauthorized() عبر logout() الداخلي — الثلاثة تستدعي
    // onLoggedOut) — لا تترك بيانات المستخدم الذي خرج للتو جالسة بالذاكرة
    // حتى لحظة دخول المستخدم التالي، حتى لو لم يُغلَق التطبيق بينهما.
    // نفس القائمة المُنظَّفة بـonAuthenticated أعلاه بالضبط.
    notificationProvider.clear();
    chatProvider.clear();
    requestsProvider.clear();
    walletProvider.clear();
    adminProvider.clear();
    supportProvider.clear();
    // [SEC-FIX-DEEPLINKCLEAR-01] راجع DECISIONS.md — نفس القائمة المُنظَّفة
    // بـonAuthenticated أعلاه بالضبط.
    FirebaseNotificationService.pendingDeepLink.value = null;
  };
}

class SallehlyApp extends StatelessWidget {
  const SallehlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tokenStorage = TokenStorage();
    final appStorage = AppStorage();
    final apiClient = ApiClient(tokenStorage);
    final socketService = SocketService();

    // كاشف الاتصال: يُحدّث من نتائج طلبات الـ API.
    final connectivityProvider = ConnectivityProvider();
    apiClient.onOnline = connectivityProvider.markOnline;
    apiClient.onOffline = connectivityProvider.markOffline;
    // [FIX-CONNECTIVITY-01] حالة منفصلة لبطء الخادم (وليس انقطاع الإنترنت).
    apiClient.onServerSlow = connectivityProvider.markServerSlow;

    return MultiProvider(
      providers: [
        // [FIX-AUTH-01] ApiClient نفسه لم يكن مُعرَّضاً عبر Provider — يلزم
        // الوصول إليه لاحقاً (في _SocketBootstrapper) لربط onUnauthorized
        // بـAuthProvider.handleUnauthorized بعد إنشائه فعلياً (نفس القيد
        // الموجود أصلاً مع onAuthenticated/onLoggedOut أدناه).
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider.value(value: connectivityProvider),
        // [FIX-THEME-01] وحدة التحكّم بالوضع الفاتح/الداكن — متاحة لكل
        // التطبيق حتى يقدر زر "الوايت مود" بالإعدادات يبدّلها من أي مكان.
        ChangeNotifierProvider(
          create: (_) => ThemeController()..loadSaved(),
        ),
        // [FIX-L10N-01] لغة الواجهة (عربي/إنجليزي) — نفس نمط ThemeController
        // أعلاه تماماً، متاحة لكل التطبيق حتى يقدر مفتاح اللغة بالإعدادات
        // يبدّلها من أي مكان.
        ChangeNotifierProvider(
          create: (_) => LocaleProvider()..loadSaved(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            tokenStorage: tokenStorage,
            apiClient: apiClient,
            appStorage: appStorage,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RequestsProvider(
            apiClient: apiClient,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(
            apiClient: apiClient,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SupportProvider(
            apiClient: apiClient,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WalletProvider(
            apiClient: apiClient,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminProvider(
            apiClient: apiClient,
          ),
        ),
        // [NOTIF-FLUTTER-PHASE1] apiClient يبقى اختيارياً على مستوى الصنف
        // نفسه (راجع تعليق NotificationProvider) — هنا بالتطبيق الفعلي نمرّره
        // دائماً، بنفس نمط بقية الـProviders أعلاه تماماً.
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(apiClient: apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => SocketProvider(
            socketService: socketService,
            tokenStorage: tokenStorage,
          ),
        ),
      ],
      child: const _SocketBootstrapper(),
    );
  }
}

class _SocketBootstrapper extends StatefulWidget {
  const _SocketBootstrapper();

  @override
  State<_SocketBootstrapper> createState() => _SocketBootstrapperState();
}

class _SocketBootstrapperState extends State<_SocketBootstrapper>
    with WidgetsBindingObserver {
  bool _bound = false;

  // [NOTIF-FLUTTER-PHASE2A] حماية بسيطة ضد أكثر من تحديث خلال فترة قصيرة —
  // نظام التشغيل قد يُصدر أكثر من resumed متتالٍ بلحظات متقاربة. هذا ليس
  // استقصاءً دورياً (polling)؛ فقط تحديث واحد فعلي لكل عودة حقيقية من الخلفية.
  DateTime _lastResumeRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// [NOTIF-FLUTTER-PHASE2A] عند عودة التطبيق من الخلفية (وليس أي انتقال
  /// آخر مثل inactive/paused/detached) ووجود مستخدم مسجّل دخوله فعلاً، اسحب
  /// الإشعارات الدائمة من الخادم — يغطي ما وصل بينما كان التطبيق بالخلفية
  /// وربما فات المستخدم أي Push مرتبط به. loadNotifications() نفسها تمتص
  /// أي فشل شبكة بصمت (راجع notification_provider.dart) فلا داعي لأي
  /// try/catch إضافي هنا.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn) return;

    final now = DateTime.now();
    if (now.difference(_lastResumeRefresh).inSeconds < 10) return;
    _lastResumeRefresh = now;

    context.read<NotificationProvider>().loadNotifications();

    // [BW-FIX-01] محاولات إعادة الاتصال بالسوكت أصبحت محدودة الآن (15
    // محاولة، راجع socket_service.dart) بدل 9999 — بعد عطل حقيقي أطول من
    // نافذة المحاولات، يتوقف السوكت عن المحاولة تلقائياً. بدون هذا التحقق
    // هنا، مستخدم يعيد فتح التطبيق بعد عطل طويل كان سيبقى بلا اتصال لحظي
    // (شات/إشعارات فورية) حتى يسجّل خروج ودخول من جديد. لا يفعل شيئاً إن
    // كان السوكت متصلاً أصلاً — لا يُعيد إنشاءه بلا داعٍ عند كل عودة عادية
    // للمقدمة.
    final socketProvider = context.read<SocketProvider>();
    if (!socketProvider.connected) {
      socketProvider.connect();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_bound) return;
    _bound = true;

    Future.microtask(() {
      if (!mounted) return;

      final socketProvider = context.read<SocketProvider>();
      final notificationProvider = context.read<NotificationProvider>();

      // اربط كل الـproviders مرة واحدة حتى يحدّثها السوكت لحظياً.
      socketProvider.bindProviders(
        requestsProvider: context.read<RequestsProvider>(),
        chatProvider: context.read<ChatProvider>(),
        notificationProvider: notificationProvider,
        authProvider: context.read<AuthProvider>(),
        adminProvider: context.read<AdminProvider>(),
        walletProvider: context.read<WalletProvider>(),
        supportProvider: context.read<SupportProvider>(),
      );

      // اربط دورة حياة المصادقة بالسوكت:
      // عند تسجيل الدخول/استعادة الجلسة → اتصال، وعند الخروج → قطع.
      final authProvider = context.read<AuthProvider>();
      bindAuthLifecycleCallbacks(
        authProvider: authProvider,
        socketProvider: socketProvider,
        notificationProvider: notificationProvider,
        chatProvider: context.read<ChatProvider>(),
        requestsProvider: context.read<RequestsProvider>(),
        walletProvider: context.read<WalletProvider>(),
        adminProvider: context.read<AdminProvider>(),
        supportProvider: context.read<SupportProvider>(),
      );
      // [FIX-SESSION-EXPIRY-01] فقط عند 401 حقيقي أثناء جلسة كانت نشطة
      // (راجع handleUnauthorized()) — وليس عند تسجيل الخروج الصريح من
      // المستخدم (تلك الشاشة تتولى تنقّلها الخاص أصلاً، فلا يُعاد التوجيه
      // مرتين). يعيد المستخدم لشاشة البداية (وليس شاشة تسجيل الدخول مباشرة،
      // حتى يبقى خيار "إنشاء حساب" متاحاً أيضاً — نفس ما تفعله SplashScreen
      // لمستخدم بلا جلسة) مع رسالة توضّح السبب.
      authProvider.onSessionExpired = () {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx == null) return;

        rootNavigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LandingScreen()),
          (route) => false,
        );

        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(ctx)!.sessionExpiredMessage)),
        );
      };

      // [FIX-AUTH-01] عند 401 حقيقي من أي طلب بالتطبيق (توكن منتهي فعلياً أو
      // حساب أُوقف)، نظّف الجلسة مركزياً بنفس مسار تسجيل الخروج المعتاد.
      context.read<ApiClient>().onUnauthorized = authProvider.handleUnauthorized;

      // إذا كانت هناك جلسة محفوظة أصلاً، اتصل فوراً.
      if (authProvider.isLoggedIn) {
        socketProvider.connect();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // [FIX-THEME-01] المراقبة هنا تضمن أن التطبيق بأكمله يُعاد بناؤه فوراً
    // عند تبديل الوضع من الإعدادات، فتلتقط كل الشاشات ألوان AppColors الجديدة.
    context.watch<ThemeController>();
    // [FIX-L10N-01] نفس المبدأ للغة — أي تبديل من شاشة الإعدادات يُعيد بناء
    // التطبيق بأكمله فوراً بلغته/اتجاهه الجديدين.
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp(
      // [FIX-SESSION-EXPIRY-01] يسمحان بالتنقّل وعرض رسالة من AuthProvider
      // (طبقة بيانات صرفة بلا BuildContext خاص بها) عند فقدان الجلسة —
      // راجع تعريفهما أعلى هذا الملف.
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      // [L10N-03] MaterialApp.title يُقيَّم بسياق (context) هذا الودجت نفسه —
      // فوق حيث تُبنى Localizations داخلياً بـMaterialApp، فـ
      // AppLocalizations.of(context) هنا سيفشل (ليس هناك سليل فعلي بعد).
      // onGenerateTitle هو الحل الرسمي بفلَتّر: يُستدعى بسياق سليل صحيح.
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appWordmark,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // [FIX-L10N-01] عربي هو الافتراضي والاحتياطي (fallback) دائماً — القيمة
      // الفعلية تأتي من LocaleProvider (محفوظة محلياً، راجع locale_provider.dart)
      // بدل تثبيتها. اتجاه الكتابة (RTL/LTR) يُشتقّ تلقائياً من هذه القيمة عبر
      // MaterialApp/Localizations نفسها — لا يوجد أي Directionality يدوي بعد
      // الآن (كان موجوداً هنا سابقاً مثبّتاً على rtl دائماً، أُزيل عمداً).
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      // دفاعي فقط: لا يُستدعى فعلياً طالما locale أعلاه دائماً غير null (يأتي
      // من LocaleProvider الذي يضبط عربي كافتراضي قبل تحميل أي تفضيل محفوظ)،
      // لكنه يضمن العربية كحل احتياطي لأي locale جهاز غير مدعوم إن تغيّر ذلك مستقبلاً.
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale != null) {
          for (final supported in supportedLocales) {
            if (supported.languageCode == deviceLocale.languageCode) {
              return supported;
            }
          }
        }
        return LocaleProvider.fallbackLocale;
      },
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox(),
            const _OfflineBanner(),
          ],
        );
      },
      home: const SplashScreen(),
    );
  }
}

/// بانر يظهر أعلى الشاشة عند انقطاع الاتصال بالخادم، أو عند بطء استجابته.
/// [FIX-CONNECTIVITY-01] كان يظهر بنفس الرسالة المضلِّلة ("لا يوجد اتصال
/// بالإنترنت") في كلتا الحالتين، رغم أن الحالة الثانية (بطء الخادم، غالباً
/// بسبب استيقاظ خادم Render المجاني من الخمول) لا علاقة لها بإنترنت المستخدم.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    final offline = connectivity.offline;
    final serverSlow = connectivity.serverSlow;
    final visible = offline || serverSlow;

    final t = AppLocalizations.of(context)!;
    final String message;
    final IconData icon;
    if (offline) {
      message = t.connectivityOfflineMessage;
      icon = Icons.wifi_off;
    } else {
      message = t.connectivityServerSlowMessage;
      icon = Icons.hourglass_top_rounded;
    }

    // [FIX-BANNER-01] كان يُستخدم AnimatedPositioned مع إزاحة ثابتة (top: -80)
    // لإخفاء البانر. هذه الإزاحة كانت أصغر من الارتفاع الفعلي للبطاقة (يتغيّر
    // حسب ارتفاع شريط الحالة/حجم الخط لكل جهاز)، فيبقى جزء منها ظاهراً دائماً
    // كخط أحمر رفيع أعلى الشاشة حتى عندما تكون الحالة "غير ظاهر". AnimatedSlide
    // يزيح البطاقة بمقدار ارتفاعها الكامل (نسبة 1-) مهما كان، فتختفي بالكامل.
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: visible ? Offset.zero : const Offset(0, -1),
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}