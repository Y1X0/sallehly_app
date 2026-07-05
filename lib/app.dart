import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/socket/socket_service.dart';
import 'core/storage/app_storage.dart';
import 'core/storage/token_storage.dart';
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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connectivityProvider),
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
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(),
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
      authProvider.onAuthenticated = () => socketProvider.reconnect();
      authProvider.onLoggedOut = () => socketProvider.disconnect();

      // إذا كانت هناك جلسة محفوظة أصلاً، اتصل فوراً.
      if (authProvider.isLoggedIn) {
        socketProvider.connect();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'صلّحلي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // ⚠️ ملاحظة موثّقة (قرار واعٍ، مو نسيان):
      // التطبيق عربي بالكامل حاليًا — locale مثبّتة على 'ar' دائمًا، وكل نصوص التطبيق
      // مكتوبة عربي مباشرة بالكود (لا يوجد ملفات ARB / .arb ولا نظام ترجمة فعلي).
      // إدراج Locale('en') بـ supportedLocales تحت لا يترجم أي نص فعلي بالتطبيق —
      // تأثيره الوحيد هو على عناصر النظام الجاهزة من Flutter (مثل زر "OK"/"Cancel"
      // بمربعات الحوار الافتراضية) لو تغيّرت لغة نظام الجهاز. إذا قرّرتوا مستقبلاً
      // دعم الإنجليزية فعليًا، هذا هو المكان الصحيح للبدء + إضافة ARB files حقيقية.
      locale: const Locale('ar'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
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

/// بانر يظهر أعلى الشاشة عند انقطاع الاتصال بالخادم.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<ConnectivityProvider>().offline;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      top: offline ? 0 : -80,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'لا يوجد اتصال بالإنترنت',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}