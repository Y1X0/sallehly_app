import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/admin_stats_model.dart';
import '../provider/admin_provider.dart';
import 'admin_audit_screen.dart';
import 'admin_ledger_screen.dart';
import 'admin_moderation_screen.dart';
import 'admin_requests_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final stats = admin.stats;
    // [FIX-DASHBOARD-01] لا يوجد "تحميل أول مرة" منفصل بهذا الـmodel (على
    // عكس شاشات أخرى بقائمة List فارغة واضحة) — نستدل عليه من عدم وصول أي
    // رقم حقيقي بعد، لتفادي إظهار بطاقات مُصفَّرة بصمت أثناء التحميل أو الخطأ.
    final noDataYet = stats.requests == 0 && stats.customers == 0 && stats.technicians == 0;
    final isInitialLoading = admin.loading && noDataYet;
    final hasError = admin.error != null && noDataYet;

    // [FIX-DUPLICATE-APPBAR-01] كانت هذه الشاشة تبني Scaffold + AppBar خاصين
    // بها فوق Scaffold + AppBar الموجودين أصلاً بـ AdminLayout (الأب الذي
    // يحتضنها ضمن pages[])، فتظهر عنوان "لوحة الأدمن" مكرراً مرتين، وأخطر من
    // هيك: AppBar الداخلي هذا كان يضيف سهم رجوع تلقائياً (لأن الشاشة السابقة
    // لتسجيل الدخول تبقى بمكدّس الـ Navigator بسبب استخدام pushReplacement
    // بدل pushAndRemoveUntil)، والضغط عليه يُخرج الأدمن فعلياً من التطبيق
    // بالكامل (يشبه تسجيل الخروج) بدل تنظيف الجلسة بشكل صحيح. الحل الجذري:
    // إزالة الـ Scaffold/AppBar الداخلي من كل شاشات الأدمن الخمس والاكتفاء
    // بالـ Scaffold الواحد الموجود فعلاً بـ AdminLayout.
    return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: admin.loadDashboard,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'إدارة صلّحلي\nتحكم كامل بالمنصة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.35,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (isInitialLoading)
              Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            // [FIX-DASHBOARD-01] كانت هذه الشاشة تُظهر إحصائيات مُصفَّرة بصمت
            // عند فشل الجلب (مثلاً جلسة منتهية) بدل رسالة خطأ حقيقية — بعكس كل
            // شاشات الأدمن الأخرى التي تتحقق من admin.error أولاً.
            else if (hasError)
              _DashboardErrorState(message: admin.error!, onRetry: admin.loadDashboard)
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  _StatCard(
                    title: 'العملاء',
                    value: stats.customers,
                    icon: Icons.people_alt_rounded,
                  ),
                  _StatCard(
                    title: 'الفنيين',
                    value: stats.technicians,
                    icon: Icons.engineering_rounded,
                  ),
                  _StatCard(
                    title: 'الطلبات',
                    value: stats.requests,
                    icon: Icons.assignment_rounded,
                  ),
                  _StatCard(
                    title: 'شحن معلق',
                    value: stats.pendingTopups,
                    icon: Icons.payments_rounded,
                  ),
                  _StatCard(
                    title: 'مكتملة',
                    value: stats.completed,
                    icon: Icons.verified_rounded,
                  ),
                  _StatCard(
                    title: 'ملغاة',
                    value: stats.cancelled,
                    icon: Icons.cancel_rounded,
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (!isInitialLoading && !hasError) ...[
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      title: 'إجمالي الإيرادات',
                      value: '${stats.revenue.toStringAsFixed(2)} د.أ',
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      title: 'معدل الإلغاء',
                      value: '${stats.cancelRate.toStringAsFixed(1)}%',
                      icon: Icons.trending_down_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      title: 'حسابات موقوفة',
                      value: '${stats.suspendedUsers}',
                      icon: Icons.block_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      title: 'بانتظار التوثيق',
                      value: '${stats.pendingVerification}',
                      icon: Icons.verified_outlined,
                    ),
                  ),
                ],
              ),
              // [FIX-STATS-01] نشاط الفترات الزمنية — طلبات/مستخدمون جدد وإيراد
              // كل فترة، بلا أي مكتبة رسوم بيانية إضافية (أرقام واضحة تكفي هنا).
              const SizedBox(height: 20),
              Text('النشاط', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _ActivityCard(title: 'اليوم', activity: stats.dailyActivity)),
                  const SizedBox(width: 10),
                  Expanded(child: _ActivityCard(title: '٧ أيام', activity: stats.weeklyActivity)),
                  const SizedBox(width: 10),
                  Expanded(child: _ActivityCard(title: '٣٠ يوماً', activity: stats.monthlyActivity)),
                ],
              ),
            ],
            if (!isInitialLoading && !hasError && stats.topServices.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'أكثر الخدمات طلباً',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: stats.topServices
                      .map((s) => _RankRow(title: s.service, trailing: '${s.count}'))
                      .toList(),
                ),
              ),
            ],
            if (!isInitialLoading && !hasError && stats.topTechs.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'أفضل الفنيين أداءً',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: stats.topTechs
                      .map((t) => _RankRow(
                            title: t.name,
                            trailing:
                                '${t.completedJobs} عمل • ⭐ ${t.ratingAvg.toStringAsFixed(1)}',
                          ))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _ActionCard(
              icon: Icons.assignment_rounded,
              title: 'إدارة الطلبات',
              subtitle: 'عرض كل الطلبات والتدخّل الإداري عند النزاعات',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminRequestsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.shield_rounded,
              title: 'المراقبة والشكاوى',
              subtitle: 'مخالفات الشات وشكاوى العملاء',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminModerationScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.history_rounded,
              title: 'سجل العمليات',
              subtitle: 'تتبّع كل العمليات الإدارية على المنصة',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminAuditScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // [FIX-LEDGER-01] دفتر الحساب الشامل — عرض/بحث فقط، لا يعدّل أي منطق مالي.
            _ActionCard(
              icon: Icons.receipt_long_rounded,
              title: 'دفتر الحساب',
              subtitle: 'كل الحركات المالية عبر المنصة',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminLedgerScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final ActivityWindowModel activity;

  const _ActivityCard({required this.title, required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 8),
          Text('${activity.newRequests} طلب', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
          Text('${activity.newUsers} مستخدم', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          Text('${activity.revenue.toStringAsFixed(1)} د.أ', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _DashboardErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 56, color: AppColors.danger),
          const SizedBox(height: 14),
          Text(
            'تعذّر تحميل الإحصائيات',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _RankRow extends StatelessWidget {
  final String title;
  final String trailing;

  const _RankRow({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            trailing,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 34),
          const Spacer(),
          Text(
            '$value',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}