import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../providers/auth_provider.dart';
import '../../requests/provider/requests_provider.dart';
import '../widgets/technician_request_card.dart';
import 'technician_request_details_screen.dart';

class TechnicianOrdersScreen extends StatefulWidget {
  const TechnicianOrdersScreen({super.key});

  @override
  State<TechnicianOrdersScreen> createState() => _TechnicianOrdersScreenState();
}

class _TechnicianOrdersScreenState extends State<TechnicianOrdersScreen> {
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

    final orders = provider.requests
        .where((e) => e.technicianId == auth.user?.id)
        .toList();

    final active = orders
        .where((e) => e.status != 'مكتمل' && e.status != 'ملغي')
        .length;

    final completed = orders.where((e) => e.status == 'مكتمل').length;

    return Scaffold(
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: provider.loadRequests,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
              children: [
                _SummaryCard(
                  total: orders.length,
                  active: active,
                  completed: completed,
                ),
                const SizedBox(height: 22),
                const SectionTitle(
                  title: 'طلباتي',
                  subtitle: 'الطلبات التي تم اختيارك لتنفيذها',
                ),
                const SizedBox(height: 14),
                if (provider.loading && orders.isEmpty)
                  SizedBox(
                    height: 280,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (provider.error != null && orders.isEmpty)
                  _ErrorOrders(
                    message: provider.error!,
                    onRetry: provider.loadRequests,
                  )
                else if (orders.isEmpty)
                  const _EmptyOrders()
                else
                  ...orders.map((request) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TechnicianRequestCard(
                        request: request,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) {
                                return TechnicianRequestDetailsScreen(
                                  request: request,
                                  canSendOffer: false,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;
  final int active;
  final int completed;

  const _SummaryCard({
    required this.total,
    required this.active,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'لوحة طلباتك',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'تابع الطلبات المقبولة والحالة الحالية لكل طلب.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  title: 'الكل',
                  value: '$total',
                  icon: Icons.assignment_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  title: 'نشطة',
                  value: '$active',
                  icon: Icons.timelapse_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  title: 'مكتملة',
                  value: '$completed',
                  icon: Icons.verified_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniStat({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.secondary, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorOrders extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorOrders({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'تعذّر تحميل الطلبات',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.assignment_late_rounded,
              color: AppColors.primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد طلبات مقبولة بعد',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'عندما يقبل العميل عرضك سيظهر الطلب هنا لتتابع التنفيذ والدردشة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}