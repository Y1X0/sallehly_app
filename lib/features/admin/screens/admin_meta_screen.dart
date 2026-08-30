import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../l10n/app_localizations.dart';
import '../provider/admin_provider.dart';
import '../../../core/widgets/success_feedback.dart';

class AdminMetaScreen extends StatefulWidget {
  const AdminMetaScreen({super.key});

  @override
  State<AdminMetaScreen> createState() => _AdminMetaScreenState();
}

class _AdminMetaScreenState extends State<AdminMetaScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminProvider>().loadMeta();
    });
  }

  Future<void> addService() async {
    final t = AppLocalizations.of(context)!;
    final name = TextEditingController();
    final icon = TextEditingController(text: '🔧');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(t.addProfessionTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: InputDecoration(labelText: t.professionNameFieldLabel)),
                const SizedBox(height: 10),
                TextField(controller: icon, decoration: InputDecoration(labelText: t.iconFieldLabel)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancelButton)),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(t.addButton)),
          ],
        );
      },
    );

    if (ok != true) return;
    if (!mounted) return;

    try {
      await context.read<AdminProvider>().createService(
        name: name.text,
        icon: icon.text,
      );
    } on ApiException catch (e) {
      showErrorSnackBar(context, e.message);
    }
  }

  /// [FIX-SERVICES-03] تعديل اسم/أيقونة مهنة موجودة — نفس نمط addService()
  /// تماماً، مع تحميل القيم الحالية مسبقاً والتحقق قبل الحفظ.
  Future<void> editService(Map<String, dynamic> existing) async {
    final t = AppLocalizations.of(context)!;
    final name = TextEditingController(text: '${existing['name'] ?? ''}');
    final icon = TextEditingController(text: '${existing['icon'] ?? '🔧'}');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(t.editProfessionTitle),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: InputDecoration(labelText: t.professionNameFieldLabel),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? t.professionNameTooShortValidation
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: icon, decoration: InputDecoration(labelText: t.iconFieldLabel)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancelButton)),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(context, true);
              },
              child: Text(t.saveButton),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    if (!mounted) return;

    try {
      await context.read<AdminProvider>().updateService(
        id: int.tryParse('${existing['id']}') ?? 0,
        name: name.text,
        icon: icon.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.professionUpdatedMessage)),
      );
    } on ApiException catch (e) {
      showErrorSnackBar(context, e.message);
    } catch (_) {
      showErrorSnackBar(context, t.editProfessionFailedMessage);
    }
  }

  Future<void> addPackage({Map<String, dynamic>? existing}) async {
    final t = AppLocalizations.of(context)!;
    final isEdit = existing != null;
    final name = TextEditingController(text: isEdit ? '${existing['name'] ?? ''}' : '');
    final amount = TextEditingController(
      text: isEdit ? '${existing['amount'] ?? ''}' : '',
    );
    final bonus = TextEditingController(
      text: isEdit ? '${existing['bonus'] ?? 0}' : '0',
    );
    final commission = TextEditingController(
      text: isEdit ? '${existing['commission_per_order'] ?? 2}' : '2',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(isEdit ? t.editPackageTitle : t.addPackageTitle),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: name, decoration: InputDecoration(labelText: t.packageNameFieldLabel)),
                const SizedBox(height: 10),
                TextField(controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t.amountFieldLabel)),
                const SizedBox(height: 10),
                TextField(controller: bonus, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t.bonusFieldLabel)),
                const SizedBox(height: 10),
                TextField(controller: commission, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t.commissionPerOrderFieldLabel)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancelButton)),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(isEdit ? t.saveButton : t.addButton)),
          ],
        );
      },
    );

    if (ok != true) return;
    if (!mounted) return;

    try {
      if (isEdit) {
        await context.read<AdminProvider>().updatePackage(
          id: int.tryParse('${existing['id']}') ?? 0,
          name: name.text,
          amount: double.tryParse(amount.text) ?? 0,
          bonus: double.tryParse(bonus.text) ?? 0,
          commissionPerOrder: double.tryParse(commission.text) ?? 2,
        );
      } else {
        await context.read<AdminProvider>().createPackage(
          name: name.text,
          amount: double.tryParse(amount.text) ?? 0,
          bonus: double.tryParse(bonus.text) ?? 0,
          commissionPerOrder: double.tryParse(commission.text) ?? 2,
        );
      }
    } on ApiException catch (e) {
      showErrorSnackBar(context, e.message);
    }
  }

  // [FIX-TOGGLEFEEDBACK-01] راجع DECISIONS.md — onToggle أدناه كان يستدعي
  // admin.toggleService(...) مباشرة بلا await ولا try/catch (بعكس onDelete
  // الذي يمر عبر confirmDelete، وهي الوحيدة التي تلتقط الأخطاء وتعرضها). فشل
  // فعلي (شبكة، 403، 500) كان يمر بصمت تماماً — لا SnackBar خطأ، لا أي مؤشّر
  // للأدمن أن الحالة لم تتغيّر فعلياً على الخادم رغم تبديل المفتاح بصرياً.
  Future<void> toggleServiceWithFeedback(int id, bool isActive) async {
    final t = AppLocalizations.of(context)!;
    try {
      await context.read<AdminProvider>().toggleService(id, isActive);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.editDataFailedMessage);
    }
  }

  // [FIX-TOGGLEFEEDBACK-02] راجع DECISIONS.md — نفس علة toggleServiceWithFeedback
  // أعلاه بالضبط، لكن بتبويب الباقات: onToggle كان يستدعي admin.togglePackageActive(e)
  // مباشرة بلا await ولا try/catch. togglePackageActive نفسها تُعيد رمي (rethrow)
  // أي فشل من updatePackage الداخلية (راجع admin_provider.dart) — لكن بلا أي
  // مستدعٍ يلتقط ذلك الرمي هنا، الفشل يمرّ بصمت تماماً بالواجهة رغم وصوله فعلياً.
  Future<void> togglePackageWithFeedback(Map<String, dynamic> package) async {
    final t = AppLocalizations.of(context)!;
    try {
      await context.read<AdminProvider>().togglePackageActive(package);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.editDataFailedMessage);
    }
  }

  Future<void> confirmDelete({
    required String title,
    required String name,
    required Future<void> Function() onConfirm,
  }) async {
    final t = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Text(t.deleteConfirmMessage(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.deleteButton, style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (!mounted) return;

    try {
      await onConfirm();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.deletedSuccessMessage)),
      );
    } on ApiException catch (e) {
      showErrorSnackBar(context, e.message);
    } catch (_) {
      showErrorSnackBar(context, t.deleteFailedMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final admin = context.watch<AdminProvider>();

    // [FIX-DUPLICATE-APPBAR-01] نفس السبب الموثّق بـ admin_dashboard_screen.dart
    // — إزالة الـ Scaffold/AppBar الداخلي المكرر فوق ذاك الموجود بـ AdminLayout.
    // بعكس باقي شاشات الأدمن، هاي الشاشة فيها TabBar وظيفي فعلي (يبدّل بين
    // "المهن" و"الباقات")، فما ينحذف — بس ينتقل من AppBar.bottom لصف مستقل
    // أعلى المحتوى (ملفوف بـ Material حتى يشتغل تأثير التحديد بشكل طبيعي).
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppColors.background,
            child: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: t.professionsTabLabel),
                Tab(text: t.packagesTabLabel),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
            _MetaList(
              loading: admin.loading,
              error: admin.error,
              onRetry: () => admin.loadMeta(),
              items: admin.services,
              empty: t.noProfessionsFoundTitle,
              onAdd: addService,
              titleBuilder: (e) => '${e['icon'] ?? '🔧'}  ${e['name'] ?? ''}',
              subtitleBuilder: (e) => (e['is_active'] == 0)
                  ? t.professionDisabledSubtitle
                  : t.professionActiveSubtitle,
              isActiveGetter: (e) => e['is_active'] != 0,
              onToggle: (e) => toggleServiceWithFeedback(
                int.tryParse('${e['id']}') ?? 0,
                e['is_active'] == 0,
              ),
              onEdit: (e) => editService(e),
              onDelete: (e) => confirmDelete(
                title: t.deleteProfessionTitle,
                name: '${e['name'] ?? ''}',
                onConfirm: () => admin.deleteService(
                  int.tryParse('${e['id']}') ?? 0,
                ),
              ),
            ),
            _MetaList(
              loading: admin.loading,
              error: admin.error,
              onRetry: () => admin.loadMeta(),
              items: admin.packages,
              empty: t.noPackagesFoundTitle,
              onAdd: addPackage,
              titleBuilder: (e) => '${e['name'] ?? ''}',
              subtitleBuilder: (e) {
                final amount = double.tryParse('${e['amount'] ?? 0}') ?? 0;
                final bonus = double.tryParse('${e['bonus'] ?? 0}') ?? 0;
                final activeText = (e['is_active'] == 0)
                    ? t.packageDisabledSubtitle
                    : t.packageAmountBonusSubtitle(formatJod(context, amount), formatJod(context, bonus));
                return activeText;
              },
              isActiveGetter: (e) => e['is_active'] != 0,
              onToggle: (e) => togglePackageWithFeedback(e),
              onEdit: (e) => addPackage(existing: e),
              onDelete: (e) => confirmDelete(
                title: t.deletePackageTitle,
                name: '${e['name'] ?? ''}',
                onConfirm: () => admin.deletePackage(
                  int.tryParse('${e['id']}') ?? 0,
                ),
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

class _MetaList extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final List<Map<String, dynamic>> items;
  final String empty;
  final VoidCallback onAdd;
  final String Function(Map<String, dynamic>) titleBuilder;
  final String Function(Map<String, dynamic>) subtitleBuilder;
  final void Function(Map<String, dynamic>)? onDelete;
  final void Function(Map<String, dynamic>)? onEdit;
  // [FIX-SERVICES-01] دعم تفعيل/تعطيل — اختياري، غير مستخدم بتبويب الباقات.
  final bool Function(Map<String, dynamic>)? isActiveGetter;
  final void Function(Map<String, dynamic>)? onToggle;

  const _MetaList({
    required this.loading,
    this.error,
    this.onRetry,
    required this.items,
    required this.empty,
    required this.onAdd,
    required this.titleBuilder,
    required this.subtitleBuilder,
    this.onDelete,
    this.onEdit,
    this.isActiveGetter,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: [
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: Text(t.addNewButton),
        ),
        const SizedBox(height: 16),
        if (loading && items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 120),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (error != null && items.isEmpty)
          Padding(
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
                  child: Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 40),
                ),
                const SizedBox(height: 14),
                Text(
                  t.metaListLoadFailedTitle,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(t.retryButton),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                ],
              ],
            ),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 120),
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
                    child: Icon(Icons.inventory_2_outlined,
                        color: AppColors.textSecondary, size: 40),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    empty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...items.map(
                (e) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  titleBuilder(e),
                  style: TextStyle(
                    color: (isActiveGetter != null && !isActiveGetter!(e))
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  subtitleBuilder(e),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActiveGetter != null && onToggle != null)
                      Switch(
                        value: isActiveGetter!(e),
                        activeColor: AppColors.success,
                        onChanged: (_) => onToggle!(e),
                      ),
                    if (onEdit != null)
                      IconButton(
                        tooltip: t.editTooltip,
                        icon: Icon(Icons.edit_outlined,
                            color: AppColors.primary),
                        onPressed: () => onEdit!(e),
                      ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: t.deleteButton,
                        icon: Icon(Icons.delete_outline_rounded,
                            color: AppColors.danger),
                        onPressed: () => onDelete!(e),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}