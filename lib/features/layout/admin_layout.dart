import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/firebase_notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../admin/screens/admin_dashboard_screen.dart';
import '../admin/screens/admin_meta_screen.dart';
import '../admin/screens/admin_support_screen.dart';
import '../admin/screens/admin_topups_screen.dart';
import '../admin/screens/admin_users_screen.dart';
import '../auth/screens/login_screen.dart';
import '../notifications/widgets/notification_bell.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int currentIndex = 0;

  late final List<Widget> pages = const [
    AdminDashboardScreen(),
    AdminUsersScreen(),
    AdminTopupsScreen(),
    AdminSupportScreen(),
    AdminMetaScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // [FIX-DEEPLINK-01] استمع لأي إشعار FCM ضُغط عليه (بالخلفية أو من إغلاق
    // كامل للتطبيق) وحوّل الأدمن للتبويب الصحيح.
    FirebaseNotificationService.pendingDeepLink.addListener(_handleDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLink());
  }

  @override
  void dispose() {
    FirebaseNotificationService.pendingDeepLink.removeListener(_handleDeepLink);
    super.dispose();
  }

  /// يقرأ هدف التنقّل المعلّق من إشعار FCM ويطبّقه، ثم يستهلكه (يصفّره).
  void _handleDeepLink() {
    final data = FirebaseNotificationService.pendingDeepLink.value;
    if (data == null || !mounted) return;

    final type = data['type']?.toString() ?? '';

    switch (type) {
      case 'support':
        context.read<NotificationProvider>().markSupportNotificationsRead();
        setState(() => currentIndex = 3); // الدعم
        break;
      case 'topup':
        context.read<NotificationProvider>().markTopupNotificationsRead();
        setState(() => currentIndex = 2); // الشحن
        break;
    // [FIX-DEEPLINK-01] 'complaint' لا تُطابَق بأي تبويب هنا عمداً — شاشة
    // الشكاوى (admin_moderation_screen) ليست ضمن الشريط السفلي الحالي ولا
    // تملك مساراً مباشراً بدون سياق إضافي. تخمين وجهة خاطئة أسوأ من عدم
    // التنقّل إطلاقاً؛ الأدمن يفتح التطبيق بشكل طبيعي على الرئيسية كما كان
    // يحدث قبل هذا الإصلاح تماماً.
      default:
        break;
    }

    FirebaseNotificationService.pendingDeepLink.value = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<NotificationProvider>().setCurrentUser(
      context.read<AuthProvider>().user,
    );
  }

  Future<void> logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من حساب الأدمن؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('خروج'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    await auth.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notify = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        // [FIX-BACK-LOGOUT-01] حماية إضافية (دفاع بعمق) — نفس السبب الموثّق
        // بـ customer_layout.dart وlogin_screen.dart.
        automaticallyImplyLeading: false,
        title: const Text('لوحة الأدمن'),
        actions: [
          NotificationBell(
            onOpenRequests: () => setState(() => currentIndex = 2),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          // [FIX-NOTIF-05] فتح تبويب "الشحن" أو "الدعم" → صفّر عدّاد كل واحد
          // منهم لحاله (نفس نمط التصفير المستخدم بلوحة الفني تماماً).
          if (index == 2) {
            context.read<NotificationProvider>().markTopupNotificationsRead();
          } else if (index == 3) {
            context.read<NotificationProvider>().markSupportNotificationsRead();
          }
          setState(() {
            currentIndex = index;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'المستخدمين',
          ),
          NavigationDestination(
            icon: _BadgeIcon(
              icon: Icons.receipt_long_outlined,
              count: notify.topupUnreadCount,
            ),
            selectedIcon: _BadgeIcon(
              icon: Icons.receipt_long,
              count: notify.topupUnreadCount,
            ),
            label: 'الشحن',
          ),
          NavigationDestination(
            icon: _BadgeIcon(
              icon: Icons.support_agent_outlined,
              count: notify.supportUnreadCount,
            ),
            selectedIcon: _BadgeIcon(
              icon: Icons.support_agent,
              count: notify.supportUnreadCount,
            ),
            label: 'الدعم',
          ),
          const NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const _BadgeIcon({
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(icon),
    );
  }
}