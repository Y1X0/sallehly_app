import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../provider/admin_provider.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  String _filter = 'الكل';

  static const List<String> _statuses = [
    'الكل',
    'بانتظار العروض',
    'وصلت عروض',
    'تم اختيار عرض',
    'قيد التنفيذ',
    'بانتظار تأكيد الدفع',
    'مكتمل',
    'ملغي',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminProvider>().loadAllRequests();
    });
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> all) {
    if (_filter == 'الكل') return all;
    return all.where((r) => '${r['status']}' == _filter).toList();
  }

  Future<void> _confirmCancel(Map<String, dynamic> req) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            'إلغاء الطلب إدارياً',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سيتم إلغاء الطلب رقم ${req['id']}. هذا الإجراء يُسجَّل في سجل العمليات.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLength: 300,
                decoration: InputDecoration(
                  hintText: 'سبب الإلغاء (اختياري)',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    try {
      await context.read<AdminProvider>().cancelRequest(
            id: req['id'] as int,
            reason: reasonController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الطلب')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  // [FIX-REQSTATUS-01] كان changeRequestStatus موجوداً بـAdminProvider/AdminApi
  // بلا أي شاشة تستدعيه — "تعديل حالة الطلب عند الضرورة" (مطلوب صراحة) لم يكن
  // متاحاً فعلياً رغم وجود كل البنية التحتية له.
  Future<void> _changeStatus(Map<String, dynamic> req, String status) async {
    try {
      await context.read<AdminProvider>().changeRequestStatus(id: req['id'] as int, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تغيير الحالة إلى: $status')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final filtered = _applyFilter(admin.allRequests);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'إدارة الطلبات',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 66),
            child: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final s = _statuses[index];
                final selected = s == _filter;
                return ChoiceChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = s),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: AppColors.card,
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => context.read<AdminProvider>().loadAllRequests(),
              child: admin.requestsLoading
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  // نتحقق من admin.allRequests (لا filtered) — قائمة فارغة بسبب
                  // فلتر الحالة المختار ليست خطأً، فقط لا نتائج مطابقة.
                  : admin.error != null && admin.allRequests.isEmpty
                      ? _RequestsErrorState(
                          message: admin.error!,
                          onRetry: () =>
                              context.read<AdminProvider>().loadAllRequests(),
                        )
                      : filtered.isEmpty
                      ? const _EmptyRequestsState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _RequestCard(
                              req: filtered[index],
                              onCancel: () => _confirmCancel(filtered[index]),
                              onChangeStatus: (status) => _changeStatus(filtered[index], status),
                            );
                          },
                        ),
            ),
          ),
        ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRequestsState extends StatelessWidget {
  const _EmptyRequestsState();

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
              child: Icon(
                Icons.assignment_outlined,
                color: AppColors.textSecondary,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'لا توجد طلبات',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RequestsErrorState({
    required this.message,
    required this.onRetry,
  });

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
              child: Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'تعذّر تحميل الطلبات',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
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

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> req;
  final VoidCallback onCancel;
  final ValueChanged<String> onChangeStatus;

  // [FIX-REQSTATUS-01] نفس القيم المسموحة صراحة بـPOST /requests/:id/status
  // بالسيرفر (routes/requests.routes.js) عدا 'ملغي' — لها زر إلغاء مستقل
  // بسبب إلزامي أصلاً.
  static const _statusOptions = ['قيد التنفيذ', 'بانتظار تأكيد الدفع', 'مكتمل'];

  const _RequestCard({required this.req, required this.onCancel, required this.onChangeStatus});

  Color _statusColor(String status) {
    switch (status) {
      case 'مكتمل':
        return Colors.green;
      case 'ملغي':
        return Colors.red;
      case 'قيد التنفيذ':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = '${req['status'] ?? ''}';
    final canCancel = status != 'مكتمل' && status != 'ملغي';

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
            children: [
              Text(
                '#${req['id']}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${req['service'] ?? ''}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(Icons.person_rounded, 'العميل', '${req['customer_name'] ?? '-'}'),
          if (req['technician_name'] != null)
            _infoRow(Icons.engineering_rounded, 'الفني',
                '${req['technician_name']}'),
          _infoRow(Icons.location_on_rounded, 'المدينة',
              '${req['city'] ?? '-'}${req['area'] != null ? ' - ${req['area']}' : ''}'),
          if (canCancel) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PopupMenuButton<String>(
                    tooltip: 'تغيير حالة الطلب',
                    onSelected: onChangeStatus,
                    itemBuilder: (context) => _statusOptions
                        .where((s) => s != status)
                        .map((s) => PopupMenuItem<String>(value: s, child: Text(s)))
                        .toList(),
                    child: IgnorePointer(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.sync_alt_rounded, size: 18),
                        label: const Text('تغيير الحالة'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_rounded, size: 18),
                    label: const Text('إلغاء الطلب'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
