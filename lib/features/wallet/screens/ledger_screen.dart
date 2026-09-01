import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/widgets/app_background.dart';
import '../../../l10n/app_localizations.dart';
import '../provider/wallet_provider.dart';

/// [FEAT-DEDUP-01] راجع DECISIONS.md — كانت هذه الشاشة "قريباً" ثابتة رغم أن
/// WalletProvider.ledger/loadLedger() ومسار الخادم كانا يعملان فعلياً
/// وتُستهلَكان أصلاً بشاشة المحفظة الرئيسية. لا بيانات وهمية هنا: تُعرَض نفس
/// حركات الدفتر الحقيقية التي تجلبها WalletProvider.
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<WalletProvider>().loadLedger();
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} - ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(t.ledgerTitle),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: wallet.loading && wallet.ledger.isEmpty
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : wallet.error != null && wallet.ledger.isEmpty
                  ? _ErrorState(message: wallet.error!, onRetry: () => context.read<WalletProvider>().loadLedger())
                  : wallet.ledger.isEmpty
                      ? const _EmptyState()
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () => context.read<WalletProvider>().loadLedger(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 66, 16, 16),
                            itemCount: wallet.ledger.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final entry = wallet.ledger[i];
                              final color = entry.isDebit ? AppColors.danger : AppColors.success;
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
                                        entry.isDebit ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(entry.type,
                                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900)),
                                          if (entry.note != null && entry.note!.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(entry.note!,
                                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                          ],
                                          const SizedBox(height: 3),
                                          Text(_formatDate(entry.createdAt),
                                              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(formatJod(context, entry.amount),
                                            style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                                        Text(t.walletLedgerBalanceAfterLabel(formatJod(context, entry.balanceAfter)),
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
    final t = AppLocalizations.of(context)!;
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
            Text(t.walletLedgerEmptyTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text(t.walletLedgerEmptySubtitle, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
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
    final t = AppLocalizations.of(context)!;
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
            Text(t.walletLedgerLoadFailedTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t.retryButton),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
