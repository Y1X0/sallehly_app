import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/request_card_skeleton.dart';
import '../../../core/widgets/section_title.dart';
import '../../requests/provider/requests_provider.dart';
import '../widgets/technician_request_card.dart';
import 'technician_request_details_screen.dart';

class NewRequestsScreen extends StatefulWidget {
  const NewRequestsScreen({super.key});

  @override
  State<NewRequestsScreen> createState() => _NewRequestsScreenState();
}

class _NewRequestsScreenState extends State<NewRequestsScreen> {
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
    final provider = context.watch<RequestsProvider>();

    final requests = provider.availableNewRequests;

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
                _HeroCard(
                  count: requests.length,
                  loading: provider.loading,
                ),
                const SizedBox(height: 22),
                const SectionTitle(
                  title: 'طلبات العملاء',
                  subtitle: 'اختر الطلب المناسب وقدّم عرضك',
                ),
                const SizedBox(height: 14),
                if (provider.loading && requests.isEmpty)
                  Semantics(
                    label: 'جاري تحميل الطلبات',
                    child: Column(
                      children: const [
                        RequestCardSkeleton(),
                        SizedBox(height: 14),
                        RequestCardSkeleton(),
                        SizedBox(height: 14),
                        RequestCardSkeleton(),
                      ],
                    ),
                  )
                else if (provider.error != null && requests.isEmpty)
                  _ErrorState(
                    message: provider.error!,
                    onRetry: provider.loadRequests,
                  )
                else if (requests.isEmpty)
                  const _EmptyState()
                else
                  ...requests.map((request) {
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
                                  canSendOffer: true,
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

class _HeroCard extends StatelessWidget {
  final int count;
  final bool loading;

  const _HeroCard({
    required this.count,
    required this.loading,
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
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -30,
            top: -35,
            child: Icon(
              Icons.campaign_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 38,
              ),
              const SizedBox(height: 18),
              Text(
                loading
                    ? 'جاري تحديث الطلبات...'
                    : count == 0
                    ? 'لا توجد طلبات جديدة'
                    : '$count طلب جديد بانتظارك',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'تابع الطلبات القريبة منك وقدّم عرضك بسرعة قبل باقي الفنيين.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              Icons.inbox_rounded,
              color: AppColors.primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد طلبات حالياً',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'عند وصول طلب جديد ضمن منطقتك سيظهر هنا مباشرة.',
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