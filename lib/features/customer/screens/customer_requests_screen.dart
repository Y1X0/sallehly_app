import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/request_card_skeleton.dart';
import '../../../core/widgets/section_title.dart';
import '../../../models/request_model.dart';
import '../../requests/provider/requests_provider.dart';
import '../widgets/customer_request_card.dart';
import 'customer_request_details_screen.dart';

/// [FIX-CUSTFILTER-01] فلاتر شاشة "طلباتي" — تبديل فوري بلا أي طلب شبكة
/// (القائمة محمَّلة أصلاً بالذاكرة، الفلترة محلية فقط).
enum _RequestsFilter { all, active, completed, cancelled }

class CustomerRequestsScreen extends StatefulWidget {
  const CustomerRequestsScreen({super.key});

  @override
  State<CustomerRequestsScreen> createState() => _CustomerRequestsScreenState();
}

class _CustomerRequestsScreenState extends State<CustomerRequestsScreen> {
  _RequestsFilter _filter = _RequestsFilter.all;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      context.read<RequestsProvider>().loadRequests();
    });
  }

  bool _matchesFilter(RequestModel request, _RequestsFilter filter) {
    switch (filter) {
      case _RequestsFilter.all:
        return true;
      case _RequestsFilter.active:
        return !request.isCompleted && !request.isCancelled;
      case _RequestsFilter.completed:
        return request.isCompleted;
      case _RequestsFilter.cancelled:
        return request.isCancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestsProvider>();

    final requests = provider.requests;
    final activeCount = requests
        .where((e) => e.status != 'مكتمل' && e.status != 'ملغي')
        .length;
    final completedCount = requests.where((e) => e.isCompleted).length;
    final cancelledCount = requests.where((e) => e.isCancelled).length;
    final offersCount = requests.where((e) => e.hasOffers).length;

    final filteredRequests =
        requests.where((r) => _matchesFilter(r, _filter)).toList();

    return Scaffold(
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              const _TopBar(),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: provider.loadRequests,
                  child: provider.loading && requests.isEmpty
                      ? Semantics(
                    label: 'جاري تحميل الطلبات',
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                      children: const [
                        RequestCardSkeleton(),
                        SizedBox(height: 14),
                        RequestCardSkeleton(),
                        SizedBox(height: 14),
                        RequestCardSkeleton(),
                      ],
                    ),
                  )
                      // [FIX-EMPTYSTATE-01] كان يُظهر "لا يوجد طلبات بعد" حتى
                      // لو فشل الجلب فعلياً (مثال: انتهت الجلسة) — الآن يتحقق
                      // من provider.error أولاً ويُظهر رسالة الخطأ الحقيقية.
                      : provider.error != null && requests.isEmpty
                      ? _RequestsErrorState(
                    message: provider.error!,
                    onRetry: provider.loadRequests,
                  )
                      : requests.isEmpty
                      ? const _EmptyRequests()
                      : FadeIn(
                    child: ListView(
                    padding:
                    const EdgeInsets.fromLTRB(20, 8, 20, 110),
                    children: [
                      _SummaryCard(
                        total: requests.length,
                        active: activeCount,
                        offers: offersCount,
                      ),
                      const SizedBox(height: 20),
                      const SectionTitle(
                        title: 'طلباتي',
                        subtitle: 'تابع حالة الطلبات والعروض',
                      ),
                      const SizedBox(height: 14),
                      _FilterBar(
                        selected: _filter,
                        allCount: requests.length,
                        activeCount: activeCount,
                        completedCount: completedCount,
                        cancelledCount: cancelledCount,
                        onSelect: (filter) {
                          setState(() => _filter = filter);
                        },
                      ),
                      const SizedBox(height: 14),
                      if (filteredRequests.isEmpty)
                        _EmptyFilterResult(
                          filter: _filter,
                          onShowAll: () => setState(() => _filter = _RequestsFilter.all),
                        )
                      else
                        ...filteredRequests.map((request) {
                          return Padding(
                            padding:
                            const EdgeInsets.only(bottom: 14),
                            child: CustomerRequestCard(
                              request: request,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) {
                                      return CustomerRequestDetailsScreen(
                                        request: request,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _RequestsFilter selected;
  final int allCount;
  final int activeCount;
  final int completedCount;
  final int cancelledCount;
  final ValueChanged<_RequestsFilter> onSelect;

  const _FilterBar({
    required this.selected,
    required this.allCount,
    required this.activeCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (_RequestsFilter.all, 'الكل', allCount),
      (_RequestsFilter.active, 'نشطة', activeCount),
      (_RequestsFilter.completed, 'مكتملة', completedCount),
      (_RequestsFilter.cancelled, 'ملغاة', cancelledCount),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label, count) = items[index];
          final isSelected = filter == selected;

          return ChoiceChip(
            label: Text('$label ($count)'),
            selected: isSelected,
            onSelected: (_) => onSelect(filter),
            showCheckmark: false,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            backgroundColor: AppColors.surface.withValues(alpha: 0.75),
            selectedColor: AppColors.primary,
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          );
        },
      ),
    );
  }
}

class _EmptyFilterResult extends StatelessWidget {
  final _RequestsFilter filter;
  final VoidCallback onShowAll;

  const _EmptyFilterResult({
    required this.filter,
    required this.onShowAll,
  });

  String get _message {
    switch (filter) {
      case _RequestsFilter.all:
        return 'لا يوجد طلبات بعد';
      case _RequestsFilter.active:
        return 'لا توجد طلبات نشطة حالياً';
      case _RequestsFilter.completed:
        return 'لا توجد طلبات مكتملة بعد';
      case _RequestsFilter.cancelled:
        return 'لا توجد طلبات ملغاة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.filter_list_off_rounded,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _message,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (filter != _RequestsFilter.all) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: onShowAll,
              child: const Text('عرض كل الطلبات'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              'طلباتي',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;
  final int active;
  final int offers;

  const _SummaryCard({
    required this.total,
    required this.active,
    required this.offers,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      radius: 28,
      child: Row(
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
              title: 'عروض',
              value: '$offers',
              icon: Icons.local_offer_rounded,
            ),
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
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.secondary, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestsErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _RequestsErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 110),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 42,
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
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 110),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.inbox_rounded,
                  color: AppColors.primary,
                  size: 42,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'لا يوجد طلبات بعد',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'عند إنشاء أول طلب صيانة سيظهر هنا ويمكنك متابعة العروض والحالة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}