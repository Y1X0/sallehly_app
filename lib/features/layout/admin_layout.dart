import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
              count: notify.requestUnreadCount,
            ),
            selectedIcon: _BadgeIcon(
              icon: Icons.receipt_long,
              count: notify.requestUnreadCount,
            ),
            label: 'الشحن',
          ),
          const NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
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