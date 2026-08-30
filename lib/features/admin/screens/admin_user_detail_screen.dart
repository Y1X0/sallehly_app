import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/widgets/app_background.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../provider/admin_provider.dart';
import '../../../core/widgets/success_feedback.dart';

/// [FIX-ADMINPROFILE-01] بروفايل مستخدم كامل — التاريخ الحقيقي بمكان واحد
/// (طلبات، عروض، دفتر حساب، مخالفات) بدل شاشة القائمة المختصرة فقط.
/// [FIX-ROLECHANGE-01] تحويل الدور (customer ↔ technician) يظهر هنا فقط،
/// ومقيَّد بـsuper admin فعلياً — الزر لا يظهر حتى لغير super admin أصلاً،
/// لكن الحماية الحقيقية بالسيرفر (403) بغض النظر عمّا تعرضه الواجهة.
class AdminUserDetailScreen extends StatefulWidget {
  final int userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminProvider>().loadUserDetail(widget.userId);
    });
  }

  @override
  void dispose() {
    // لا تستخدم context هنا (قد لا يكون mounted) — نصل للـprovider مباشرة
    // عبر لا شيء إضافي؛ التنظيف يحدث تلقائياً بفتح تفاصيل مستخدم آخر لاحقاً.
    super.dispose();
  }

  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> verify() async {
    final t = AppLocalizations.of(context)!;
    try {
      await context.read<AdminProvider>().verifyTechnician(widget.userId);
      showSuccess(t.technicianVerifiedMessage);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.verifyTechnicianFailedMessage);
    }
  }

  Future<void> changeRole(String currentRole) async {
    final t = AppLocalizations.of(context)!;
    final targetRole = currentRole == 'technician' ? 'customer' : 'technician';
    final nationalNumberController = TextEditingController();
    final servicesController = TextEditingController();
    final areasController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          targetRole == 'technician' ? t.convertToTechnicianLabel : t.convertToCustomerLabel,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                targetRole == 'technician'
                    ? t.convertToTechnicianRequirementsMessage
                    : t.convertToCustomerRequirementsMessage,
                style: TextStyle(color: AppColors.textSecondary, height: 1.6),
              ),
              if (targetRole == 'technician') ...[
                const SizedBox(height: 14),
                TextField(
                  controller: nationalNumberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t.nationalNumberDigitsFieldLabel),
                ),
                TextField(
                  controller: servicesController,
                  decoration: InputDecoration(labelText: t.servicesCommaSeparatedLabel),
                ),
                TextField(
                  controller: areasController,
                  decoration: InputDecoration(labelText: t.areasCommaSeparatedLabel),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancelButton)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.convertButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<AdminProvider>().changeUserRole(
            id: widget.userId,
            role: targetRole,
            nationalNumber: targetRole == 'technician' ? nationalNumberController.text : null,
            services: targetRole == 'technician' ? servicesController.text : null,
            areas: targetRole == 'technician' ? areasController.text : null,
          );
      showSuccess(t.roleChangedMessage);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.changeRoleFailedMessage);
    }
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
    final t = AppLocalizations.of(context)!;
    final admin = context.watch<AdminProvider>();
    final isSuperAdmin = context.watch<AuthProvider>().user?.isSuperAdmin ?? false;
    final detail = admin.userDetail;
    final user = detail?['user'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(user?['name']?.toString() ?? t.userDetailsTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: admin.userDetailLoading && detail == null
          ? const Center(child: CircularProgressIndicator())
          : admin.userDetailError != null && detail == null
              ? _ErrorState(message: admin.userDetailError!, onRetry: () => context.read<AdminProvider>().loadUserDetail(widget.userId))
              : detail == null || user == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: () => context.read<AdminProvider>().loadUserDetail(widget.userId),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 66, 20, 20),
                        children: [
                          _SummaryCard(user: user),
                          const SizedBox(height: 16),
                          if (user['role'] == 'technician' && user['verification_status'] == 'pending')
                            _ActionTile(
                              icon: Icons.verified_rounded,
                              color: AppColors.success,
                              title: t.verifyThisTechnicianLabel,
                              onTap: admin.actionLoading ? null : verify,
                            ),
                          if (isSuperAdmin && user['role'] != 'admin') ...[
                            const SizedBox(height: 10),
                            _ActionTile(
                              icon: Icons.swap_horiz_rounded,
                              color: AppColors.warning,
                              title: user['role'] == 'technician' ? t.convertToCustomerLabel : t.convertToTechnicianLabel,
                              subtitle: t.superAdminOnlyLabel,
                              onTap: admin.actionLoading ? null : () => changeRole(user['role'].toString()),
                            ),
                          ],
                          const SizedBox(height: 20),
                          _SectionTitle(t.requestsAsCustomerSectionTitle((detail['requestsAsCustomer'] as List).length)),
                          ..._requestTiles(context, detail['requestsAsCustomer'] as List),
                          if (user['role'] == 'technician') ...[
                            const SizedBox(height: 20),
                            _SectionTitle(t.requestsAsTechnicianSectionTitle((detail['requestsAsTechnician'] as List).length)),
                            ..._requestTiles(context, detail['requestsAsTechnician'] as List),
                            const SizedBox(height: 20),
                            _SectionTitle(t.userOffersSectionTitle((detail['offers'] as List).length)),
                            ...(detail['offers'] as List).map((o) => _SimpleTile(
                                  title: formatJod(context, double.tryParse('${o['price']}') ?? 0),
                                  subtitle: '${t.requestNumberLabel(o['request_id'] as int)} • ${o['status']}',
                                  trailing: _formatDate(o['created_at']?.toString()),
                                )),
                          ],
                          const SizedBox(height: 20),
                          _SectionTitle(t.ledgerSectionTitleWithCount((detail['ledger'] as List).length)),
                          ...(detail['ledger'] as List).map((l) => _SimpleTile(
                                title: l['type']?.toString() ?? '',
                                subtitle: l['note']?.toString() ?? '',
                                trailing: formatJod(context, double.tryParse('${l['amount']}') ?? 0),
                                trailingColor: (double.tryParse('${l['amount']}') ?? 0) >= 0 ? AppColors.success : AppColors.danger,
                              )),
                          const SizedBox(height: 20),
                          _SectionTitle(t.monitoringSectionTitle),
                          _SimpleTile(
                            title: t.violationsSentLabel,
                            trailing: '${(detail['moderation'] as Map)['violationsCount']}',
                          ),
                          _SimpleTile(
                            title: t.reportsAgainstLabel,
                            trailing: '${(detail['moderation'] as Map)['reportsAgainstCount']}',
                          ),
                          _SimpleTile(
                            title: t.complaintsFiledLabel,
                            trailing: '${(detail['moderation'] as Map)['complaintsFiledCount']}',
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  List<Widget> _requestTiles(BuildContext context, List requests) {
    if (requests.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(AppLocalizations.of(context)!.noneLabel, style: TextStyle(color: AppColors.textMuted)),
        ),
      ];
    }
    return requests
        .map((r) => _SimpleTile(
              title: r['service']?.toString() ?? '',
              subtitle: '#${r['id']} • ${r['status']}',
              trailing: _formatDate(r['created_at']?.toString()),
            ))
        .toList();
  }
}

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _SummaryCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final active = user['is_active'] == 1 || user['is_active'] == true;
    final suspensionReason = user['suspension_reason']?.toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${user['email']} • ${user['phone']}', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text('${user['city'] ?? ''}', style: TextStyle(color: AppColors.textSecondary)),
          if (user['role'] == 'technician') ...[
            const SizedBox(height: 10),
            Text(AppLocalizations.of(context)!.balanceWithAmountLabel(formatJod(context, double.tryParse('${user['balance']}') ?? 0)),
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
            Text(
                AppLocalizations.of(context)!.ratingSummaryLabel(
                    '${user['rating_avg']}', '${user['rating_count']}', '${user['completed_jobs']}'),
                style: TextStyle(color: AppColors.textSecondary)),
          ],
          if (!active && suspensionReason != null && suspensionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(AppLocalizations.of(context)!.suspensionReasonLabel(suspensionReason),
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _ActionTile({required this.icon, required this.color, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                    if (subtitle != null)
                      Text(subtitle!, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12)),
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
    );
  }
}

class _SimpleTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String trailing;
  final Color? trailingColor;

  const _SimpleTile({required this.title, this.subtitle, required this.trailing, this.trailingColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(trailing, style: TextStyle(color: trailingColor ?? AppColors.textSecondary, fontWeight: FontWeight.w700)),
        ],
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
            Text(
              AppLocalizations.of(context)!.userLoadFailedTitle,
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context)!.retryButton),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
