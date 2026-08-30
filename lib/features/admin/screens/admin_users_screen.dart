import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/admin_user_model.dart';
import '../provider/admin_provider.dart';
import 'admin_user_detail_screen.dart';
import '../../../core/widgets/success_feedback.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String query = 'all';

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminProvider>().loadUsers();
    });
  }

  List<AdminUserModel> filter(List<AdminUserModel> users) {
    if (query == 'all') return users;
    if (query == 'pending_verification') return users.where((e) => e.isPendingVerification).toList();
    return users.where((e) => e.role == query).toList();
  }

  // [FIX-SUSPEND-01] الإيقاف الآن يطلب سبباً (يُسجَّل ويظهر بتفاصيل الحساب) —
  // التفعيل يبقى بضغطة تأكيد واحدة كما كان بالضبط.
  Future<void> toggleUser(AdminUserModel user) async {
    final t = AppLocalizations.of(context)!;
    if (!user.active) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(t.activateAccountTitle),
          content: Text(t.activateAccountConfirmMessage(user.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancelButton)),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(t.confirmButton)),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      try {
        await context.read<AdminProvider>().toggleUser(user.id);
      } on ApiException catch (e) {
        if (!mounted) return;
        showErrorSnackBar(context, e.message);
      } catch (_) {
        if (!mounted) return;
        showErrorSnackBar(context, t.accountUpdateFailedMessage);
      }
      return;
    }

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(t.suspendAccountTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.suspensionReasonPromptMessage(user.name),
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLength: 300,
                maxLines: 3,
                decoration: InputDecoration(labelText: t.reasonFieldLabel),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancelButton)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.suspendButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await context.read<AdminProvider>().toggleUser(user.id, reason: reasonController.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.accountUpdateFailedMessage);
    }
  }

  Future<void> editProfile(AdminUserModel user) async {
    final t = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: user.name);
    final cityController = TextEditingController(text: user.city ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(t.editDataTitle,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 60,
                decoration: InputDecoration(labelText: t.nameFieldLabel),
              ),
              TextField(
                controller: cityController,
                maxLength: 60,
                decoration: InputDecoration(labelText: t.cityLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.cancelButton),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.saveButton),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) return;
    try {
      await context.read<AdminProvider>().updateUserProfile(
            id: user.id,
            name: nameController.text,
            city: cityController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.dataSavedMessage)),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.editDataFailedMessage);
    }
  }

  Future<void> adjustBalance(AdminUserModel user) async {
    final t = AppLocalizations.of(context)!;
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    bool isAdd = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              title: Text(t.adjustBalanceTitle,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.currentBalanceLabel(formatJod(context, user.balance)),
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text(t.addButton),
                            selected: isAdd,
                            onSelected: (_) => setLocal(() => isAdd = true),
                            selectedColor: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: Text(t.deductChipLabel),
                            selected: !isAdd,
                            onSelected: (_) => setLocal(() => isAdd = false),
                            selectedColor: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: t.amountJodFieldLabel),
                    ),
                    TextField(
                      controller: reasonController,
                      maxLength: 200,
                      decoration:
                          InputDecoration(labelText: t.adjustmentReasonRequiredFieldLabel),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(t.cancelButton),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(t.executeButton),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) return;
    final raw = double.tryParse(amountController.text.trim());
    if (raw == null || raw <= 0) {
      showErrorSnackBar(context, t.enterValidAmountMessage);
      return;
    }
    final amount = isAdd ? raw : -raw;
    try {
      await context.read<AdminProvider>().adjustUserBalance(
            id: user.id,
            amount: amount,
            reason: reasonController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.balanceAdjustedMessage)),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.adjustBalanceFailedMessage);
    }
  }

  Future<void> deleteUser(AdminUserModel user) async {
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(t.deleteUserTitle,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Text(
            t.deleteUserConfirmMessage(user.name),
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.goBackButton),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.deleteForeverButton),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;
    try {
      await context.read<AdminProvider>().deleteUser(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.userDeletedMessage)),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.deleteUserFailedMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final admin = context.watch<AdminProvider>();
    final users = filter(admin.users);

    // [FIX-DUPLICATE-APPBAR-01] نفس السبب الموثّق بـ admin_dashboard_screen.dart
    // — إزالة الـ Scaffold/AppBar الداخلي المكرر فوق ذاك الموجود بـ AdminLayout.
    return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: admin.loadUsers,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    title: t.allFilterLabel,
                    active: query == 'all',
                    onTap: () => setState(() => query = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    title: t.customersFilterLabel,
                    active: query == 'customer',
                    onTap: () => setState(() => query = 'customer'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    title: t.techniciansFilterLabel,
                    active: query == 'technician',
                    onTap: () => setState(() => query = 'technician'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    title: t.pendingVerificationLabel,
                    active: query == 'pending_verification',
                    onTap: () => setState(() => query = 'pending_verification'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (admin.loading && users.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 120),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            // نتحقق من admin.users (لا users المفلترة) — قائمة فارغة بسبب
            // فلتر الدور المختار ليست خطأً، فقط لا نتائج مطابقة.
            else if (admin.error != null && admin.users.isEmpty)
              _ErrorState(
                message: admin.error!,
                onRetry: admin.loadUsers,
              )
            else if (users.isEmpty)
              _EmptyState(text: t.noUsersFoundTitle)
            else
              ...users.map(
                    (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _UserCard(
                    user: user,
                    loading: admin.actionLoading,
                    onToggle: () => toggleUser(user),
                    onEdit: () => editProfile(user),
                    onBalance: () => adjustBalance(user),
                    onDelete: () => deleteUser(user),
                    onOpenDetail: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AdminUserDetailScreen(userId: user.id)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
  }
}

class _FilterChip extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AdminUserModel user;
  final bool loading;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onBalance;
  final VoidCallback onDelete;
  final VoidCallback onOpenDetail;

  const _UserCard({
    required this.user,
    required this.loading,
    required this.onToggle,
    required this.onEdit,
    required this.onBalance,
    required this.onDelete,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final color = user.active ? AppColors.success : AppColors.danger;
    final roleLabel = user.isCustomer
        ? t.customerFallbackName
        : user.isTechnician
            ? t.technicianFallbackName
            : user.isAdmin
                ? t.adminRoleLabel
                : user.role;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(24),
        child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                child: Icon(
                  user.isTechnician ? Icons.engineering_rounded : Icons.person_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$roleLabel • ${user.phone}',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      user.active ? t.activeStatusLabel : t.suspendedStatusLabel,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (user.isPendingVerification) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        t.pendingVerificationLabel,
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  user.email,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              if (user.isTechnician)
                Text(
                  formatJod(context, user.balance),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading || user.isAdmin ? null : onToggle,
              icon: Icon(user.active ? Icons.block_rounded : Icons.check_circle_rounded),
              label: Text(user.active ? t.suspendAccountTitle : t.activateAccountTitle),
            ),
          ),
          if (!user.isAdmin) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: Text(t.editTooltip),
                  ),
                ),
                if (user.isTechnician) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : onBalance,
                      icon: const Icon(Icons.account_balance_wallet_rounded,
                          size: 18),
                      label: Text(t.balanceButtonLabel),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: loading ? null : onDelete,
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: Text(t.deleteUserTitle),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger),
                ),
              ),
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 140),
      child: Center(
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
              child: Icon(Icons.people_outline_rounded, size: 40, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppLocalizations.of(context)!.usersLoadFailedTitle,
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(AppLocalizations.of(context)!.retryButton),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}