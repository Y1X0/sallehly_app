import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../chat/screens/chats_screen.dart';
import '../notifications/widgets/notification_bell.dart';
import '../settings/screens/settings_screen.dart';
import '../support/provider/support_provider.dart';
import '../support/screens/support_screen.dart';
import '../technician/screens/new_requests_screen.dart';
import '../technician/screens/technician_dashboard_screen.dart';
import '../technician/screens/technician_orders_screen.dart';
import '../wallet/screens/wallet_screen.dart';

class TechnicianLayout extends StatefulWidget {
  const TechnicianLayout({super.key});

  @override
  State<TechnicianLayout> createState() => _TechnicianLayoutState();
}

class _TechnicianLayoutState extends State<TechnicianLayout> {
  int currentIndex = 0;

  // الصفحات الثابتة (بدون الدعم). أيقونة الدعم تظهر فقط عند وجود تذكرة مفتوحة.
  late final List<Widget> pages = const [
    TechnicianDashboardScreen(),
    NewRequestsScreen(),
    TechnicianOrdersScreen(),
    ChatsScreen(),
    WalletScreen(),
    SettingsScreen(),
  ];

  // مؤشر صفحة الدعم (يأتي بعد الصفحات الثابتة الست: 0..5 ثم 6 للدعم).
  static const int supportIndex = 6;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().setCurrentUser(
        context.read<AuthProvider>().user,
      );
      // تحميل تذاكر الدعم لمعرفة إن كان هناك تذكرة مفتوحة (تُظهر أيقونة الدعم).
      context.read<SupportProvider>().loadMyTickets(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notify = context.watch<NotificationProvider>();
    final support = context.watch<SupportProvider>();

    final hasSupport = support.hasOpenTicket;

    // إذا اختفت أيقونة الدعم بينما المستخدم واقف عليها، نرجعه للرئيسية.
    if (!hasSupport && currentIndex == supportIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => currentIndex = 0);
      });
    }

    // الصفحة المعروضة: إذا كان على الدعم نعرض شاشة الدعم، وإلا الصفحة العادية.
    final Widget currentPage = (currentIndex == supportIndex && hasSupport)
        ? const SupportScreen()
        : pages[currentIndex.clamp(0, pages.length - 1)];

    // إخفاء الـ AppBar في الرئيسية (0) والإعدادات (5) فقط.
    final bool hideAppBar = currentIndex == 0 || currentIndex == 5;

    // بناء عناصر الشريط السفلي.
    final navItems = <_NavItem>[
      _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'الرئيسية', 0),
      _NavItem(
        Icons.search_outlined,
        Icons.search,
        'جديدة',
        notify.requestUnreadCount,
      ),
      _NavItem(Icons.assignment_outlined, Icons.assignment, 'طلباتي', 0),
      _NavItem(
        Icons.chat_bubble_outline,
        Icons.chat,
        'الدردشات',
        notify.chatUnreadCount,
      ),
      _NavItem(
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet,
        'المحفظة',
        0,
      ),
      _NavItem(Icons.settings_outlined, Icons.settings, 'إعدادات', 0),
      if (hasSupport)
        _NavItem(
          Icons.support_agent_outlined,
          Icons.support_agent,
          'الدعم',
          notify.supportUnreadCount,
        ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      appBar: hideAppBar
          ? null
          : AppBar(
        title: const Text('لوحة الفني'),
        actions: [
          NotificationBell(
            onOpenRequests: () => setState(() => currentIndex = 1),
          ),
        ],
      ),
      body: currentPage,
      bottomNavigationBar: _GlassNav(
        selectedIndex: currentIndex,
        onTap: (index) {
          if (index == 3) {
            context.read<NotificationProvider>().markChatNotificationsRead();
          }

          // فتح تبويب الدعم → تصفير عدّاد رسائل الدعم.
          if (index == supportIndex) {
            context.read<NotificationProvider>().markSupportNotificationsRead();
          }

          setState(() {
            currentIndex = index;
          });
        },
        items: navItems,
      ),
    );
  }
}

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
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.primaryGradient : null,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Badge(
                        isLabelVisible: item.count > 0,
                        label: Text(item.count > 99 ? '99+' : '${item.count}'),
                        child: Icon(
                          selected ? item.selectedIcon : item.icon,
                          size: 22,
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
                          color:
                          selected ? Colors.white : AppColors.textSecondary,
                          fontSize: 10,
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
