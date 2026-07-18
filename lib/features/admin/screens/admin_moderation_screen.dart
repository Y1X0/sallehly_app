import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../provider/admin_provider.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminProvider>().loadModeration();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} - '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'المراقبة والشكاوى',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: 'مخالفات الشات (${admin.violations.length})'),
            Tab(text: 'الشكاوى (${admin.complaints.length})'),
            Tab(text: 'بلاغات الرسائل (${admin.messageReports.length})'),
          ],
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 114),
            child: admin.moderationLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : TabBarView(
              controller: _tab,
              children: [
                _buildList(
                  context,
                  items: admin.violations,
                  error: admin.error,
                  emptyText: 'لا توجد مخالفات',
                  emptyIcon: Icons.shield_outlined,
                  builder: (v) => _ModerationCard(
                    title: '${v['reason'] ?? 'مخالفة'}',
                    subtitle: '${v['user_name'] ?? 'مستخدم'}'
                        '${v['user_email'] != null ? ' • ${v['user_email']}' : ''}',
                    body: '${v['body'] ?? ''}',
                    meta: [
                      if (v['service'] != null) 'الخدمة: ${v['service']}',
                      if (v['request_id'] != null) 'طلب #${v['request_id']}',
                      _formatDate(v['created_at'] as String?),
                    ],
                    color: AppColors.danger,
                    icon: Icons.report_rounded,
                    trailing: _ViolationStatusMenu(violation: v),
                  ),
                ),
                _buildList(
                  context,
                  items: admin.complaints,
                  error: admin.error,
                  emptyText: 'لا توجد شكاوى',
                  emptyIcon: Icons.inbox_outlined,
                  builder: (c) => _ModerationCard(
                    title: 'شكوى من ${c['customer_name'] ?? 'عميل'}',
                    subtitle: c['technician_name'] != null
                        ? 'بحق الفني: ${c['technician_name']}'
                        : '',
                    body: '${c['body'] ?? ''}',
                    meta: [
                      if (c['customer_phone'] != null)
                        'هاتف العميل: ${c['customer_phone']}',
                      if (c['request_id'] != null) 'طلب #${c['request_id']}',
                      _formatDate(c['created_at'] as String?),
                    ],
                    color: AppColors.primary,
                    icon: Icons.feedback_rounded,
                    trailing: _ComplaintStatusMenu(complaint: c),
                  ),
                ),
                // [FIX-UGC-01] بلاغات الرسائل — سياسة UGC بمنصّة Google Play
                _buildList(
                  context,
                  items: admin.messageReports,
                  error: admin.error,
                  emptyText: 'لا توجد بلاغات رسائل',
                  emptyIcon: Icons.flag_outlined,
                  builder: (r) => _ModerationCard(
                    title: '${r['reason'] ?? 'بلاغ'}',
                    subtitle: r['reported_name'] != null
                        ? 'المُبلَّغ عنه: ${r['reported_name']}'
                            '${r['reported_email'] != null ? ' • ${r['reported_email']}' : ''}'
                        : '',
                    body: '${r['message_body'] ?? '(لم تُحدَّد رسالة معيّنة)'}',
                    meta: [
                      if (r['reporter_name'] != null)
                        'المُبلِّغ: ${r['reporter_name']}',
                      if (r['request_id'] != null) 'طلب #${r['request_id']}',
                      _formatDate(r['created_at'] as String?),
                    ],
                    color: AppColors.danger,
                    icon: Icons.flag_rounded,
                    trailing: _MessageReportStatusMenu(report: r),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context, {
    required List<Map<String, dynamic>> items,
    required String? error,
    required String emptyText,
    required IconData emptyIcon,
    required Widget Function(Map<String, dynamic>) builder,
  }) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<AdminProvider>().loadModeration(),
      child: error != null && items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 40),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: () =>
                          context.read<AdminProvider>().loadModeration(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary),
                    ),
                  ],
                ),
              ),
            )
          : items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(emptyIcon, color: AppColors.textSecondary, size: 40),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      emptyText,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => builder(items[i]),
            ),
    );
  }
}

class _ComplaintStatusMenu extends StatelessWidget {
  final Map<String, dynamic> complaint;

  const _ComplaintStatusMenu({required this.complaint});

  static const _labels = {
    'open': 'مفتوحة',
    'in_review': 'قيد المراجعة',
    'resolved': 'تم الحل',
    'rejected': 'مرفوضة',
  };

  static Map<String, Color> get _colors => {
    'open': AppColors.danger,
    'in_review': Colors.orange,
    'resolved': Colors.green,
    'rejected': AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final status = '${complaint['status'] ?? 'open'}';
    final color = _colors[status] ?? AppColors.textSecondary;
    final id = complaint['id'];

    return PopupMenuButton<String>(
      tooltip: 'تغيير حالة الشكوى',
      onSelected: (newStatus) async {
        if (id == null) return;
        try {
          await context.read<AdminProvider>().updateComplaintStatus(
                id: id is int ? id : int.tryParse('$id') ?? 0,
                status: newStatus,
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تم تحديث الحالة إلى: ${_labels[newStatus]}')),
            );
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تعذر تحديث حالة الشكوى')),
            );
          }
        }
      },
      itemBuilder: (context) => _labels.entries
          .map((e) => PopupMenuItem<String>(value: e.key, child: Text(e.value)))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _labels[status] ?? status,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

/// [FIX-MODERATION-01] نفس نمط _ComplaintStatusMenu تماماً — توثيق أن الأدمن
/// راجع المخالفة/البلاغ، بدون حذف أي محتوى أو حظر مباشر من هنا (الحظر/الإيقاف
/// عبر شاشة تفاصيل المستخدم — لا تكرار منطق).
class _ViolationStatusMenu extends StatelessWidget {
  final Map<String, dynamic> violation;

  const _ViolationStatusMenu({required this.violation});

  static const _labels = {
    'مفتوح': 'مفتوح',
    'تمت المراجعة': 'تمت المراجعة',
    'تم اتخاذ إجراء': 'تم اتخاذ إجراء',
  };

  static Map<String, Color> get _colors => {
    'مفتوح': AppColors.danger,
    'تمت المراجعة': Colors.orange,
    'تم اتخاذ إجراء': Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    final status = '${violation['status'] ?? 'مفتوح'}';
    final color = _colors[status] ?? AppColors.textSecondary;
    final id = violation['id'];

    return PopupMenuButton<String>(
      tooltip: 'تحديث حالة المخالفة',
      onSelected: (newStatus) async {
        if (id == null) return;
        try {
          await context.read<AdminProvider>().updateViolationStatus(
                id: id is int ? id : int.tryParse('$id') ?? 0,
                status: newStatus,
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تم تحديث الحالة إلى: ${_labels[newStatus]}')),
            );
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تعذر تحديث حالة المخالفة')),
            );
          }
        }
      },
      itemBuilder: (context) => _labels.entries
          .map((e) => PopupMenuItem<String>(value: e.key, child: Text(e.value)))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _labels[status] ?? status,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _MessageReportStatusMenu extends StatelessWidget {
  final Map<String, dynamic> report;

  const _MessageReportStatusMenu({required this.report});

  static const _labels = {
    'قيد المراجعة': 'قيد المراجعة',
    'تم اتخاذ إجراء': 'تم اتخاذ إجراء',
    'مرفوض': 'مرفوض',
  };

  static Map<String, Color> get _colors => {
    'قيد المراجعة': Colors.orange,
    'تم اتخاذ إجراء': Colors.green,
    'مرفوض': AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final status = '${report['status'] ?? 'قيد المراجعة'}';
    final color = _colors[status] ?? AppColors.textSecondary;
    final id = report['id'];

    return PopupMenuButton<String>(
      tooltip: 'تحديث حالة البلاغ',
      onSelected: (newStatus) async {
        if (id == null) return;
        try {
          await context.read<AdminProvider>().updateMessageReportStatus(
                id: id is int ? id : int.tryParse('$id') ?? 0,
                status: newStatus,
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تم تحديث الحالة إلى: ${_labels[newStatus]}')),
            );
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تعذر تحديث حالة البلاغ')),
            );
          }
        }
      },
      itemBuilder: (context) => _labels.entries
          .map((e) => PopupMenuItem<String>(value: e.key, child: Text(e.value)))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _labels[status] ?? status,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _ModerationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String body;
  final List<String> meta;
  final Color color;
  final IconData icon;
  final Widget? trailing;

  const _ModerationCard({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.meta,
    required this.color,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final metaText = meta.where((e) => e.trim().isNotEmpty).join('  •  ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (body.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                body,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (metaText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              metaText,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
