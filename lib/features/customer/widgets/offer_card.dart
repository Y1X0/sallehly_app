import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/offer_model.dart';

class OfferCard extends StatelessWidget {
  final OfferModel offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool loading;

  const OfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.technicianName ?? 'فني',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'السعر: ${offer.price.toStringAsFixed(2)} د.أ',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'الوقت: ${offer.duration}',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          if (offer.note != null && offer.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              offer.note!,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          if (offer.isPending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : onAccept,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('قبول'),
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
            )
          else
            Text(
              offer.isAccepted ? 'تم قبول العرض' : 'تم رفض العرض',
              style: TextStyle(
                color: offer.isAccepted ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}