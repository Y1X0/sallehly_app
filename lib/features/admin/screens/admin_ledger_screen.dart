import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../provider/admin_provider.dart';

/// [FIX-LEDGER-01] دفتر الحساب الشامل عبر المنصة كاملة — عرض/بحث فقط، لا
/// يعدّل أي منطق مالي (التعديلات الفعلية تبقى حصراً عبر شاشة تفاصيل المستخدم).
class AdminLedgerScreen extends StatefulWidget {
  const AdminLedgerScreen({super.key});

  @override
  State<AdminLedgerScreen> createState() => _AdminLedgerScreenState();
}

class _AdminLedgerScreenState extends State<AdminLedgerScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminProvider>().loadLedger();
    });
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} - ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('دفتر الحساب (${admin.ledgerTotal})', style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: admin.ledgerLoading && admin.ledgerEntries.isEmpty
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : admin.error != null && admin.ledgerEntries.isEmpty
              ? _ErrorState(message: admin.error!, onRetry: () => context.read<AdminProvider>().loadLedger())
              : admin.ledgerEntries.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => context.read<AdminProvider>().loadLedger(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 66, 16, 16),
                        itemCount: admin.ledgerEntries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final entry = admin.ledgerEntries[i];
                          final amount = double.tryParse('${entry['amount']}') ?? 0;
                          final color = amount >= 0 ? AppColors.success : AppColors.danger;
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    amount >= 0 ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry['type']?.toString() ?? '',
                                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 3),
                                      Text('${entry['user_name'] ?? ''} • ${entry['note'] ?? ''}',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                      const SizedBox(height: 3),
                                      Text(_formatDate(entry['created_at']?.toString()),
                                          style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${amount.toStringAsFixed(2)} د.أ',
                                        style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                                    Text('الرصيد: ${entry['balance_after']}',
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
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
              child: Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary, size: 40),
            ),
            const SizedBox(height: 18),
            Text('لا توجد حركات مالية بعد', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text('ستظهر هنا كل الحركات المالية عبر المنصة', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
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
              child: Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
            ),
            const SizedBox(height: 18),
            Text('تعذّر تحميل دفتر الحساب', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
