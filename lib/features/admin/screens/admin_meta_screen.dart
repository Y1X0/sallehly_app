import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../provider/admin_provider.dart';

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
    final name = TextEditingController();
    final icon = TextEditingController(text: '🔧');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('إضافة مهنة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المهنة')),
                const SizedBox(height: 10),
                TextField(controller: icon, decoration: const InputDecoration(labelText: 'الأيقونة')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
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
      showError(e.message);
    }
  }

  /// [FIX-SERVICES-03] تعديل اسم/أيقونة مهنة موجودة — نفس نمط addService()
  /// تماماً، مع تحميل القيم الحالية مسبقاً والتحقق قبل الحفظ.
  Future<void> editService(Map<String, dynamic> existing) async {
    final name = TextEditingController(text: '${existing['name'] ?? ''}');
    final icon = TextEditingController(text: '${existing['icon'] ?? '🔧'}');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('تعديل المهنة'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'اسم المهنة'),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'اسم المهنة قصير جداً'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: icon, decoration: const InputDecoration(labelText: 'الأيقونة')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
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
        const SnackBar(content: Text('تم تحديث المهنة بنجاح')),
      );
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر تعديل المهنة');
    }
  }

  Future<void> addPackage({Map<String, dynamic>? existing}) async {
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
          title: Text(isEdit ? 'تعديل باقة' : 'إضافة باقة'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الباقة')),
                const SizedBox(height: 10),
                TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'القيمة')),
                const SizedBox(height: 10),
                TextField(controller: bonus, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'البونص')),
                const SizedBox(height: 10),
                TextField(controller: commission, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عمولة الطلب')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(isEdit ? 'حفظ' : 'إضافة')),
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
      showError(e.message);
    }
  }

  Future<void> confirmDelete({
    required String title,
    required String name,
    required Future<void> Function() onConfirm,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Text('هل أنت متأكد من حذف "$name"؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف', style: TextStyle(color: AppColors.danger)),
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
        const SnackBar(content: Text('تم الحذف بنجاح')),
      );
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر الحذف');
    }
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.danger, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                Tab(text: 'المهن'),
                Tab(text: 'الباقات'),
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
              empty: 'لا توجد مهن',
              onAdd: addService,
              titleBuilder: (e) => '${e['icon'] ?? '🔧'}  ${e['name'] ?? ''}',
              subtitleBuilder: (e) => (e['is_active'] == 0)
                  ? 'معطّلة — لا تظهر بالتسجيل أو إنشاء الطلبات'
                  : 'مهنة متاحة في التطبيق',
              isActiveGetter: (e) => e['is_active'] != 0,
              onToggle: (e) => admin.toggleService(
                int.tryParse('${e['id']}') ?? 0,
                e['is_active'] == 0,
              ),
              onEdit: (e) => editService(e),
              onDelete: (e) => confirmDelete(
                title: 'حذف المهنة',
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
              empty: 'لا توجد باقات',
              onAdd: addPackage,
              titleBuilder: (e) => '${e['name'] ?? ''}',
              subtitleBuilder: (e) {
                final amount = double.tryParse('${e['amount'] ?? 0}') ?? 0;
                final bonus = double.tryParse('${e['bonus'] ?? 0}') ?? 0;
                final activeText = (e['is_active'] == 0)
                    ? 'معطّلة — لا تظهر بشاشة شحن الفنيين'
                    : '${amount.toStringAsFixed(2)} د.أ • بونص ${bonus.toStringAsFixed(2)}';
                return activeText;
              },
              isActiveGetter: (e) => e['is_active'] != 0,
              onToggle: (e) => admin.togglePackageActive(e),
              onEdit: (e) => addPackage(existing: e),
              onDelete: (e) => confirmDelete(
                title: 'حذف الباقة',
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة جديد'),
        ),
        const SizedBox(height: 16),
        if (loading && items.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 120),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (error != null && items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 120),
            child: Column(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: AppColors.danger, size: 46),
                const SizedBox(height: 12),
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
                    label: const Text('إعادة المحاولة'),
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
              child: Text(empty, style: TextStyle(color: AppColors.textSecondary)),
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
                        icon: Icon(Icons.edit_outlined,
                            color: AppColors.primary),
                        onPressed: () => onEdit!(e),
                      ),
                    if (onDelete != null)
                      IconButton(
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