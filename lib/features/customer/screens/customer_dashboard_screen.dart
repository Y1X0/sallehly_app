import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../models/service_model.dart';
import '../../requests/provider/requests_provider.dart';
import 'create_request_screen.dart';
import 'customer_requests_screen.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RequestsProvider>().loadRequests();
      // [FIX-SERVICES-04] المهن كانت تُعرض من قائمة ثابتة — الآن حيّة من
      // نفس المصدر المستخدم بالتسجيل وإنشاء الطلب (لا نداء API إضافي إن كان
      // محمّلاً مسبقاً بفضل التخزين المؤقت داخل RequestsProvider).
      context.read<RequestsProvider>().loadMeta();
    });
  }

  void openRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerRequestsScreen()),
    );
  }

  void openCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
    );
  }

  void showAllServices() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: ListView(
                children: [
                  Text(
                    'كل الخدمات',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 16),
                  _ServicesGrid(inSheet: true),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestsProvider>();

    final total = provider.requests.length;
    final offers = provider.requests.where((e) => e.hasOffers).length;
    final completed = provider.requests.where((e) => e.isCompleted).length;

    return Scaffold(
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: provider.loadRequests,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
              children: [
                const _HeroCard(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        title: 'إنشاء طلب',
                        subtitle: 'طلب صيانة جديد',
                        icon: Icons.add_rounded,
                        onTap: openCreate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        title: 'طلباتي',
                        subtitle: 'متابعة الطلبات',
                        icon: Icons.receipt_long_rounded,
                        onTap: openRequests,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'طلباتي',
                        value: '$total',
                        icon: Icons.assignment_rounded,
                        onTap: openRequests,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        title: 'عروض',
                        value: '$offers',
                        icon: Icons.local_offer_rounded,
                        onTap: openRequests,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        title: 'مكتملة',
                        value: '$completed',
                        icon: Icons.verified_rounded,
                        onTap: openRequests,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Text(
                      'خدمات صلّحلي',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: showAllServices,
                      child: const Text('عرض الكل'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _ServicesGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 238,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -25,
            top: -35,
            child: Icon(
              Icons.settings_rounded,
              size: 125,
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
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.handyman_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'صلّحلي',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                'كل خدمات الصيانة\nفي مكان واحد',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'اطلب الفني الأقرب إليك واستقبل العروض بسرعة وبشكل آمن.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onHighlightChanged: (value) => setState(() => _pressed = value),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 104,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(22),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onHighlightChanged: (value) => setState(() => _pressed = value),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 112,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: AppColors.primary, size: 24),
              const SizedBox(height: 4),
              Text(
                widget.value,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
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

class _ServicesGrid extends StatelessWidget {
  final bool inSheet;

  const _ServicesGrid({
    this.inSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // [RESPONSIVE-01] على الهواتف columns تساوي 2 دائماً، فتُعطي نفس صيغة
    // الحساب الأصلية بالضبط (بدون أي تغيير بصري) — الأعمدة الإضافية تُستخدم
    // فقط على الشاشات الأعرض (أجهزة لوحية) بدل بطاقات متمدّدة بعرض غير متناسق.
    final columns = responsiveColumns(width);
    final outerPad = inSheet ? 72.0 : 52.0;
    final itemWidth = columns == 2
        ? (width - outerPad) / 2
        : (width - outerPad - 12.0 * (columns - 2)) / columns;
    // [RESPONSIVE-04] الارتفاع 116 يبقى كما هو بالضبط على كل الهواتف
    // (columns == 2). فقط على الأجهزة اللوحية/الشاشات الأعرض حيث يكبر عرض
    // البطاقة أكثر بكثير، يتمدد الارتفاع بنفس النسبة تقريباً بدل بقائه 116
    // ثابتاً — لتفادي بطاقات مسطّحة وعريضة بشكل غير متناسق.
    final tileHeight = columns == 2 ? 116.0 : itemWidth / 1.5;

    // [FIX-SERVICES-04] نفس مصدر البيانات الحيّ المستخدم بالتسجيل وإنشاء
    // الطلب — /meta أصلاً يُرجع المهن الفعّالة فقط، فلا حاجة لأي فلترة هنا.
    final meta = context.watch<RequestsProvider>().meta;

    // حالة التحميل: لم تصل بيانات /meta بعد.
    if (meta == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final services = meta.services;

    // حالة فارغة: لا توجد أي مهنة فعّالة حالياً.
    if (services.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'لا توجد خدمات متاحة حالياً',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return FadeIn(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: services.map((service) {
          return _ServiceTile(
            service: service,
            width: itemWidth,
            height: tileHeight,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

class _ServiceTile extends StatefulWidget {
  final ServiceModel service;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.service,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  State<_ServiceTile> createState() => _ServiceTileState();
}

class _ServiceTileState extends State<_ServiceTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(22),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onHighlightChanged: (value) => setState(() => _pressed = value),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.service.icon ?? '🔧',
                style: const TextStyle(fontSize: 26),
              ),
              const Spacer(),
              Text(
                widget.service.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'اطلب الخدمة الآن',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}