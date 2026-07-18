import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/admin_user_model.dart';
import '../provider/admin_provider.dart';
import 'admin_user_detail_screen.dart';

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
    if (!user.active) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تفعيل الحساب'),
          content: Text('هل تريد تفعيل حساب ${user.name}؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      try {
        await context.read<AdminProvider>().toggleUser(user.id);
      } on ApiException catch (e) {
        showError(e.message);
      } catch (_) {
        showError('تعذر تحديث الحساب');
      }
      return;
    }

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('إيقاف الحساب', style: TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('سبب إيقاف حساب ${user.name} (اختياري، يُسجَّل بسجل الحساب):',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'السبب'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إيقاف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await context.read<AdminProvider>().toggleUser(user.id, reason: reasonController.text);
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر تحديث الحساب');
    }
  }

  Future<void> editProfile(AdminUserModel user) async {
    final nameController = TextEditingController(text: user.name);
    final cityController = TextEditingController(text: user.city ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('تعديل البيانات',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              TextField(
                controller: cityController,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'المدينة'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ'),
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
          const SnackBar(content: Text('تم حفظ البيانات')),
        );
      }
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر تعديل البيانات');
    }
  }

  Future<void> adjustBalance(AdminUserModel user) async {
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
              title: const Text('تعديل الرصيد',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الرصيد الحالي: ${user.balance.toStringAsFixed(2)} د.أ',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('إضافة'),
                            selected: isAdd,
                            onSelected: (_) => setLocal(() => isAdd = true),
                            selectedColor: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('خصم'),
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
                      decoration: const InputDecoration(labelText: 'المبلغ'),
                    ),
                    TextField(
                      controller: reasonController,
                      maxLength: 200,
                      decoration:
                          const InputDecoration(labelText: 'سبب التعديل (إلزامي)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('تنفيذ'),
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
      showError('أدخل مبلغاً صحيحاً');
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
          const SnackBar(content: Text('تم تعديل الرصيد')),
        );
      }
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر تعديل الرصيد');
    }
  }

  Future<void> deleteUser(AdminUserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('حذف المستخدم',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: Text(
            'سيتم حذف حساب ${user.name} نهائياً وإيقاف وصوله. '
            'لا يمكن التراجع. هذا الإجراء يُسجَّل في سجل العمليات.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف نهائي'),
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
          const SnackBar(content: Text('تم حذف المستخدم')),
        );
      }
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر حذف المستخدم');
    }
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    title: 'الكل',
                    active: query == 'all',
                    onTap: () => setState(() => query = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    title: 'عملاء',
                    active: query == 'customer',
                    onTap: () => setState(() => query = 'customer'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    title: 'فنيين',
                    active: query == 'technician',
                    onTap: () => setState(() => query = 'technician'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    title: 'بانتظار التوثيق',
                    active: query == 'pending_verification',
                    onTap: () => setState(() => query = 'pending_verification'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (admin.loading && users.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 120),
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
              const _EmptyState(text: 'لا يوجد مستخدمين')
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
    final color = user.active ? AppColors.success : AppColors.danger;

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
                      '${user.roleAr} • ${user.phone}',
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
                      user.active ? 'نشط' : 'موقوف',
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
                        'بانتظار التوثيق',
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
                  '${user.balance.toStringAsFixed(2)} د.أ',
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
              label: Text(user.active ? 'إيقاف الحساب' : 'تفعيل الحساب'),
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
                    label: const Text('تعديل'),
                  ),
                ),
                if (user.isTechnician) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : onBalance,
                      icon: const Icon(Icons.account_balance_wallet_rounded,
                          size: 18),
                      label: const Text('الرصيد'),
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
                label: const Text('حذف المستخدم'),
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
            'تعذّر تحميل المستخدمين',
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
            label: const Text('إعادة المحاولة'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}