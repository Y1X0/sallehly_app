import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../provider/admin_provider.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
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
          ],
        ),
      ),
      body: admin.moderationLoading
          ? const Center(
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
              ],
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
          ? ListView(
              children: [
                const SizedBox(height: 120),
                const Icon(Icons.error_outline_rounded,
                    size: 70, color: AppColors.danger),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        context.read<AdminProvider>().loadModeration(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary),
                  ),
                ),
              ],
            )
          : items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Icon(emptyIcon, size: 70, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    emptyText,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
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

  static const _colors = {
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
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
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
                style: const TextStyle(
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
