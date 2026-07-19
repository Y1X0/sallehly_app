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
import 'send_offer_screen.dart';

class TechnicianRequestDetailsScreen extends StatelessWidget {
  final RequestModel request;
  final bool canSendOffer;

  const TechnicianRequestDetailsScreen({
    super.key,
    required this.request,
    required this.canSendOffer,
  });

  Future<void> updateStatus(
      BuildContext context,
      String status,
      ) async {
    final provider = context.read<RequestsProvider>();

    try {
      await provider.updateRequestStatus(
        requestId: request.id,
        status: status,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث الحالة إلى $status'),
        ),
      );

      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(e.message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<RequestsProvider>().loading;

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
            tag: 'technician-request-status-${request.id}',
            child: RequestStatusChip(status: request.status),
          ),
          const SizedBox(height: 18),
          FadeIn(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'technician-request-image-${request.id}',
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
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
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
            child: _InfoBox(
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
            const SizedBox(height: 16),
            FadeIn(
              delay: const Duration(milliseconds: 140),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  '${AppConfig.baseUrl}${request.problemImageUrl}',
                  // [RESPONSIVE-02] نفس المبدأ الموثّق بـ create_request_screen.dart —
                  // ارتفاع متناسب مع عرض الشاشة بدل قيمة ثابتة، بدون تغيير على
                  // الهواتف العادية (العرض المرجعي 390).
                  height: MediaQuery.of(context).size.width * (220 / 390),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
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
                if (canSendOffer)
                  ElevatedButton.icon(
                    onPressed: loading
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SendOfferScreen(
                            request: request,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_offer_outlined),
                    label: const Text('تقديم عرض سعر'),
                  ),
                if (!canSendOffer &&
                    request.status != 'مكتمل' &&
                    request.status != 'ملغي') ...[
                  ElevatedButton.icon(
                    onPressed: loading
                        ? null
                        : () {
                      updateStatus(context, 'قيد التنفيذ');
                    },
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('بدء التنفيذ'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () {
                      updateStatus(context, 'بانتظار تأكيد الدفع');
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('بانتظار تأكيد الدفع'),
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

class _InfoBox extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoBox({
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