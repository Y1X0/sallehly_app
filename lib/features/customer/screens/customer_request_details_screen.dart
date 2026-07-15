import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/app_config.dart';
import '../../../core/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('طلب رقم ${request.id}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          RequestStatusChip(status: request.status),
          const SizedBox(height: 18),
          Text(
            request.service,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${request.city}${request.area == null || request.area!.isEmpty ? '' : ' - ${request.area}'}',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _Box(
            title: 'وصف المشكلة',
            child: Text(
              request.description,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
          if (request.problemImageUrl != null &&
              request.problemImageUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                '${AppConfig.baseUrl}${request.problemImageUrl}',
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) {
                  return const SizedBox();
                },
              ),
            ),
          ],
          const SizedBox(height: 22),
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
          if (!request.isCompleted && !request.isCancelled) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: provider.loading
                  ? null
                  : () async {
                await provider.cancelRequest(request.id);
                if (context.mounted) Navigator.pop(context);
              },
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}