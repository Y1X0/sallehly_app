import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/topup_model.dart';

class TopupCard extends StatelessWidget {
  final TopupModel topup;

  const TopupCard({
    super.key,
    required this.topup,
  });

  @override
  Widget build(BuildContext context) {
    final color = topup.isApproved
        ? AppColors.success
        : topup.isRejected
        ? AppColors.danger
        : AppColors.primary;

    final label = topup.isApproved
        ? 'تمت الموافقة'
        : topup.isRejected
        ? 'مرفوض'
        : 'قيد المراجعة';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              topup.isApproved
                  ? Icons.check_circle_rounded
                  : topup.isRejected
                  ? Icons.cancel_rounded
                  : Icons.hourglass_top_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topup.packageName ?? 'طلب شحن',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${topup.total.toStringAsFixed(2)} د.أ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}