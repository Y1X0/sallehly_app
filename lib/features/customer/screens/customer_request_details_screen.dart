import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/app_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../models/request_model.dart';
import '../../requests/provider/requests_provider.dart';
import '../../requests/widgets/request_status_chip.dart';
import '../widgets/complaint_sheet.dart';
import '../widgets/rate_technician_sheet.dart';
import 'offers_screen.dart';

class CustomerRequestDetailsScreen extends StatelessWidget {
  final RequestModel request;

  const CustomerRequestDetailsScreen({
    super.key,
    required this.request,
  });

  /// [FIX-CUSTDELETE-01] تأكيد صريح قبل إلغاء الطلب — إجراء لا يمكن التراجع
  /// عنه (السيرفر يرفض الطلبات المعلَّمة "ملغي" لاحقاً)، فلا يجوز تنفيذه
  /// بضغطة واحدة عرضية.
  Future<void> _confirmAndCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء الطلب؟'),
        content: const Text(
          'سيتم إلغاء هذا الطلب نهائياً ولن يتمكن أي فني من التقدّم بعروض عليه بعد الآن. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، ألغِ الطلب'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final provider = context.read<RequestsProvider>();

    try {
      await provider.cancelRequest(request.id);
      if (context.mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.danger, content: Text(e.message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.danger, content: Text('تعذر إلغاء الطلب')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestsProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('طلب رقم ${request.id}'),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 66, 20, 20),
        children: [
          Hero(
            tag: 'customer-request-status-${request.id}',
            child: RequestStatusChip(status: request.status),
          ),
          const SizedBox(height: 18),
          FadeIn(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'customer-request-image-${request.id}',
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      Icons.handyman_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.service,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${request.city}${request.area == null || request.area!.isEmpty ? '' : ' - ${request.area}'}',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FadeIn(
            delay: const Duration(milliseconds: 70),
            child: _Box(
              title: 'وصف المشكلة',
              child: Text(
                request.description,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ),
          if (request.problemImageUrl != null &&
              request.problemImageUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            FadeIn(
              delay: const Duration(milliseconds: 140),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  '${AppConfig.baseUrl}${request.problemImageUrl}',
                  // [RESPONSIVE-02] نفس المبدأ الموثّق بـ create_request_screen.dart —
                  // ارتفاع متناسب مع عرض الشاشة بدل قيمة ثابتة، بدون تغيير على
                  // الهواتف العادية (العرض المرجعي 390).
                  height: MediaQuery.of(context).size.width * (220 / 390),
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) {
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          FadeIn(
            delay: const Duration(milliseconds: 210),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (request.hasOffers || request.status == 'تم اختيار عرض')
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OffersScreen(request: request),
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_offer_outlined),
                    label: const Text('عرض عروض الفنيين'),
                  ),
                if (request.isCancellable) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger),
                    ),
                    onPressed: provider.loading ? null : () => _confirmAndCancel(context),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('إلغاء الطلب'),
                  ),
                ],
                if (request.status == 'قيد التنفيذ' ||
                    request.status == 'بانتظار تأكيد الدفع') ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: provider.loading
                        ? null
                        : () async {
                      await provider.completeRequest(request.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('إنهاء الطلب'),
                  ),
                ],
                if (request.status == 'مكتمل' && request.technicianId != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: const Color(0xFF1A1200),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.surface,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        builder: (_) => RateTechnicianSheet(
                          requestId: request.id,
                          technicianName: request.technicianName,
                        ),
                      );
                    },
                    icon: const Icon(Icons.star_rounded),
                    label: const Text('قيّم الفني'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.surface,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        builder: (_) => ComplaintSheet(
                          requestId: request.id,
                          technicianName: request.technicianName,
                        ),
                      );
                    },
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('تقديم شكوى'),
                  ),
                ],
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

class _Box extends StatelessWidget {
  final String title;
  final Widget child;

  const _Box({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}