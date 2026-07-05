import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../chat/screens/chats_screen.dart';
import '../customer/screens/customer_dashboard_screen.dart';
import '../customer/screens/customer_requests_screen.dart';
import '../notifications/widgets/notification_bell.dart';
import '../settings/screens/settings_screen.dart';
import '../support/provider/support_provider.dart';
import '../support/screens/support_chat_screen.dart';

class CustomerLayout extends StatefulWidget {
  const CustomerLayout({super.key});

  @override
  State<CustomerLayout> createState() => _CustomerLayoutState();
}

class _CustomerLayoutState extends State<CustomerLayout> {
  int currentIndex = 0;

  late final List<Widget> pages = const [
    CustomerDashboardScreen(),
    CustomerRequestsScreen(),
    ChatsScreen(),
    SettingsScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().setCurrentUser(
        context.read<AuthProvider>().user,
      );
      // حمّل تذاكر الدعم حتى نعرف إن كان هناك محادثة مفتوحة (تظهر بالشريط).
      context.read<SupportProvider>().loadMyTickets(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notify = context.watch<NotificationProvider>();
    final support = context.watch<SupportProvider>();
    final openTicket = support.openTicket;

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      appBar: currentIndex == 0 || currentIndex == 3
          ? null
          : AppBar(
        title: const Text('صلّحلي'),
        actions: [
          NotificationBell(
            onOpenRequests: () => setState(() => currentIndex = 1),
          ),
        ],
      ),
      body: pages[currentIndex],
      bottomNavigationBar: _GlassNav(
        selectedIndex: currentIndex,
        onTap: (index) {
          if (index == 2) {
            context.read<NotificationProvider>().markChatNotificationsRead();
          }
          setState(() => currentIndex = index);
        },
        // يُفتح فقط عند وجود تذكرة دعم مفتوحة → يأخذنا مباشرة للمحادثة.
        onTapSupport: openTicket == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupportChatScreen(ticket: openTicket),
                  ),
                );
              },
        items: [
          _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'الرئيسية', 0),
          _NavItem(
            Icons.assignment_outlined,
            Icons.assignment,
            'طلباتي',
            notify.requestUnreadCount,
          ),
          _NavItem(
            Icons.chat_bubble_outline,
            Icons.chat,
            'الدردشات',
            notify.chatUnreadCount,
          ),
          _NavItem(Icons.settings_outlined, Icons.settings, 'الإعدادات', 0),
        ],
      ),
    );
  }
}

class _GlassNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;
  final VoidCallback? onTapSupport;

  const _GlassNav({
    required this.selectedIndex,
    required this.onTap,
    required this.items,
    this.onTapSupport,
  });

  @override
  Widget build(BuildContext context) {
    final showSupport = onTapSupport != null;

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
          children: [
            ...List.generate(items.length, (index) {
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
                          label: Text(
                              item.count > 99 ? '99+' : '${item.count}'),
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
            // أيقونة الدعم تظهر فقط عند وجود محادثة دعم مفتوحة، وتختفي عند إغلاقها.
            if (showSupport)
              Expanded(
                child: InkWell(
                  onTap: onTapSupport,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.support_agent,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الدعم',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
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