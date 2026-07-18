import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_background.dart';
import '../../../providers/auth_provider.dart';
import '../../requests/provider/requests_provider.dart';
import '../../support/screens/support_screen.dart';
import '../screens/my_reviews_screen.dart';
import '../screens/new_requests_screen.dart';
import '../screens/technician_orders_screen.dart';
import '../../wallet/screens/wallet_screen.dart';

class TechnicianDashboardScreen extends StatefulWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  State<TechnicianDashboardScreen> createState() =>
      _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState extends State<TechnicianDashboardScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      context.read<RequestsProvider>().loadRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<RequestsProvider>();
    final user = auth.user;

    final newRequests = provider.availableNewRequestsCount;

    final myOrders = provider.requests
        .where((e) => e.status != 'بانتظار العروض' && e.status != 'وصلت عروض')
        .length;

    return Scaffold(
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: provider.loadRequests,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
          children: [
            _HeroCard(
              name: user?.name ?? 'فني صلّحلي',
              balance: user?.balance ?? 0,
            ),
            const SizedBox(height: 18),
            _MainActionCard(
              onNewRequests: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NewRequestsScreen(),
                  ),
                );
              },
              onWallet: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WalletScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'طلبات جديدة',
                    value: '$newRequests',
                    icon: Icons.campaign_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'طلباتي',
                    value: '$myOrders',
                    icon: Icons.assignment_turned_in_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(
              title: 'الرصيد الحالي',
              value: '${(user?.balance ?? 0).toStringAsFixed(2)} د.أ',
              icon: Icons.account_balance_wallet_rounded,
              wide: true,
            ),
            const SizedBox(height: 22),
            Text(
              'اختصارات الفني',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _ShortcutGrid(
              onOrders: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TechnicianOrdersScreen(),
                  ),
                );
              },
              onWallet: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WalletScreen(),
                  ),
                );
              },
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String name;
  final double balance;

  const _HeroCard({
    required this.name,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -34,
            left: -22,
            child: Icon(
              Icons.engineering_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) {
                        return Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.engineering_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const Text(
                'طلبات جديدة\nقريبة منك',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'قدّم عروضك، تابع طلباتك، وراقب رصيدك من مكان واحد.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'الرصيد: ${balance.toStringAsFixed(2)} د.أ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MainActionCard extends StatelessWidget {
  final VoidCallback onNewRequests;
  final VoidCallback onWallet;

  const _MainActionCard({
    required this.onNewRequests,
    required this.onWallet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: onNewRequests,
            icon: const Icon(Icons.search_rounded),
            label: const Text(
              'عرض الطلبات الجديدة',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onWallet,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('إدارة المحفظة'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool wide;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: wide ? 96 : 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment:
        wide ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          SizedBox(width: wide ? 14 : 10),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment:
              wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  final VoidCallback onOrders;
  final VoidCallback onWallet;

  const _ShortcutGrid({
    required this.onOrders,
    required this.onWallet,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ['طلباتي', Icons.assignment_rounded, onOrders],
      ['المحفظة', Icons.account_balance_wallet_rounded, onWallet],
      ['التقييمات', Icons.star_rounded, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyReviewsScreen()),
        );
      }],
      ['الدعم', Icons.support_agent_rounded, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SupportScreen()),
        );
      }],
    ];

    final width = MediaQuery.of(context).size.width;
    // [RESPONSIVE-01] نفس صيغة الحساب الأصلية بالضبط على الهواتف (columns=2)
    // — أعمدة إضافية فقط على الشاشات الأعرض (أجهزة لوحية).
    final columns = responsiveColumns(width);
    final itemWidth = columns == 2
        ? (width - 64) / 2
        : (width - 64 - 12.0 * (columns - 2)) / columns;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) {
        return InkWell(
          onTap: item[2] as VoidCallback,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: itemWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(item[1] as IconData, color: AppColors.secondary),
                const SizedBox(width: 10),
                Text(
                  item[0] as String,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}