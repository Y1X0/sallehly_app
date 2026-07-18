import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/firebase_notification_service.dart';
import '../../core/theme/app_colors.dart';
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
      extendBody: true,
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
      bottomNavigationBar: _GlassNav(
        selectedIndex: currentIndex,
        onTap: (index) {
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
        items: [
          const _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'الرئيسية', 0),
          const _NavItem(Icons.people_outline, Icons.people, 'المستخدمين', 0),
          _NavItem(
            Icons.receipt_long_outlined,
            Icons.receipt_long,
            'الشحن',
            notify.topupUnreadCount,
          ),
          _NavItem(
            Icons.support_agent_outlined,
            Icons.support_agent,
            'الدعم',
            notify.supportUnreadCount,
          ),
          const _NavItem(Icons.tune_outlined, Icons.tune, 'الإعدادات', 0),
        ],
      ),
    );
  }
}

/// شريط تنقّل زجاجي عائم بنفس هوية شريطي العميل والفني تماماً (نفس النصف
/// قطر، الحدود، الظل، وتدرّج البطاقة المختارة) بدل NavigationBar الافتراضي
/// الذي كان يجعل لوحة الأدمن تبدو كأنها تطبيق مختلف.
class _GlassNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;

  const _GlassNav({
    required this.selectedIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = selectedIndex == index;

            return Expanded(
              child: InkWell(
                onTap: () => onTap(index),
                borderRadius: BorderRadius.circular(22),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.primaryGradient : null,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Badge(
                        isLabelVisible: item.count > 0,
                        label: Text(item.count > 99 ? '99+' : '${item.count}'),
                        child: Icon(
                          selected ? item.selectedIcon : item.icon,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int count;

  const _NavItem(this.icon, this.selectedIcon, this.label, this.count);
}