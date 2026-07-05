import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../provider/admin_provider.dart';

class AdminTopupsScreen extends StatefulWidget {
  const AdminTopupsScreen({super.key});

  @override
  State<AdminTopupsScreen> createState() => _AdminTopupsScreenState();
}

class _AdminTopupsScreenState extends State<AdminTopupsScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminProvider>().loadTopups();
    });
  }

  Future<void> review({
    required int id,
    required String status,
  }) async {
    final controller = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(status == 'approved' ? 'موافقة على الشحن' : 'رفض الشحن'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ملاحظة اختيارية',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      await context.read<AdminProvider>().reviewTopup(
        id: id,
        status: status,
        note: controller.text,
      );
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر مراجعة الطلب');
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'طلبات الشحن',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: admin.loadTopups,
        child: admin.loading && admin.topups.isEmpty
            ? const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        )
            : admin.topups.isEmpty
            ? ListView(
          padding: const EdgeInsets.all(28),
          children: const [
            SizedBox(height: 180),
            Icon(
              Icons.receipt_long_outlined,
              color: AppColors.primary,
              size: 76,
            ),
            SizedBox(height: 16),
            Text(
              'لا توجد طلبات شحن',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        )
            : ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: admin.topups.length,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final topup = admin.topups[index];
            final id = int.tryParse('${topup['id'] ?? 0}') ?? 0;
            final status = '${topup['status'] ?? ''}';
            final pending = status == 'pending';

            return _TopupCard(
              topup: topup,
              pending: pending,
              loading: admin.actionLoading,
              onApprove: () => review(id: id, status: 'approved'),
              onReject: () => review(id: id, status: 'rejected'),
            );
          },
        ),
      ),
    );
  }
}

class _TopupCard extends StatelessWidget {
  final Map<String, dynamic> topup;
  final bool pending;
  final bool loading;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _TopupCard({
    required this.topup,
    required this.pending,
    required this.loading,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse('${topup['amount'] ?? 0}') ?? 0;
    final bonus = double.tryParse('${topup['bonus'] ?? 0}') ?? 0;
    final status = '${topup['status'] ?? ''}';

    final color = status == 'approved'
        ? AppColors.success
        : status == 'rejected'
        ? AppColors.danger
        : AppColors.primary;

    final label = status == 'approved'
        ? 'مقبول'
        : status == 'rejected'
        ? 'مرفوض'
        : 'قيد المراجعة';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${topup['technician_name'] ?? 'فني'}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${topup['package_name'] ?? 'باقة'} • ${(amount + bonus).toStringAsFixed(2)} د.أ',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (pending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('موافقة'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('رفض'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}