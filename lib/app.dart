import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/socket/socket_service.dart';
import 'core/storage/app_storage.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/provider/admin_provider.dart';
import 'features/chat/provider/chat_provider.dart';
import 'features/requests/provider/requests_provider.dart';
import 'features/splash/splash_screen.dart';
import 'features/support/provider/support_provider.dart';
import 'features/wallet/provider/wallet_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/socket_provider.dart';
import 'providers/theme_controller.dart';

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

class _SocketBootstrapperState extends State<_SocketBootstrapper> {
  bool _bound = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_bound) return;
    _bound = true;

    Future.microtask(() {
      if (!mounted) return;

      final socketProvider = context.read<SocketProvider>();

      // اربط كل الـproviders مرة واحدة حتى يحدّثها السوكت لحظياً.
      socketProvider.bindProviders(
        requestsProvider: context.read<RequestsProvider>(),
        chatProvider: context.read<ChatProvider>(),
        notificationProvider: context.read<NotificationProvider>(),
        authProvider: context.read<AuthProvider>(),
        adminProvider: context.read<AdminProvider>(),
        walletProvider: context.read<WalletProvider>(),
        supportProvider: context.read<SupportProvider>(),
      );

      // اربط دورة حياة المصادقة بالسوكت:
      // عند تسجيل الدخول/استعادة الجلسة → اتصال، وعند الخروج → قطع.
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      authProvider.onAuthenticated = () async {
        await socketProvider.reconnect();
        // [FIX-CHATBADGE-01] بدون هذا، شارة الشات بالشريط السفلي (المرتبطة
        // بـChatProvider.totalUnread — المصدر الحقيقي المدعوم من الخادم عبر
        // GET /chats) تبقى صفراً منذ إقلاع التطبيق حتى يفتح المستخدم تبويب
        // "الدردشات" يدوياً ولو مرة واحدة. تحميل صامت هنا (بعد كل تسجيل
        // دخول/استعادة جلسة) يضمن ظهور الشارة الصحيحة فوراً من اللحظة
        // الأولى — يشمل إعادة تشغيل التطبيق واستعادة الجلسة المحفوظة تماماً.
        await chatProvider.loadChats(silent: true);
      };
      authProvider.onLoggedOut = () => socketProvider.disconnect();

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

    return MaterialApp(
      title: 'صلّحلي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // ⚠️ ملاحظة موثّقة (قرار واعٍ، مو نسيان):
      // التطبيق عربي بالكامل حاليًا — locale مثبّتة على 'ar' دائمًا، وكل نصوص التطبيق
      // مكتوبة عربي مباشرة بالكود (لا يوجد ملفات ARB / .arb ولا نظام ترجمة فعلي).
      // [FIX-LOCALE-01] أُزيلت Locale('en') من supportedLocales — وجودها كان
      // يوحي بدعم إنجليزي فعلي (قد يُفهم خطأً بمتاجر التطبيقات كذلك) رغم عدم
      // ترجمة أي نص حقيقي. إذا قرّرتوا مستقبلاً دعم الإنجليزية فعليًا، أعيدوا
      // إضافتها هنا مع ARB files حقيقية لكل النصوص.
      locale: const Locale('ar'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(
            children: [
              child ?? const SizedBox(),
              const _OfflineBanner(),
            ],
          ),
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

    final String message;
    final IconData icon;
    if (offline) {
      message = 'لا يوجد اتصال بالإنترنت';
      icon = Icons.wifi_off;
    } else {
      message = 'الخادم يستغرق وقتاً أطول من المعتاد للرد، يرجى الانتظار';
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