import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class RequestStatusChip extends StatelessWidget {
  final String status;

  const RequestStatusChip({
    super.key,
    required this.status,
  });

  Color get color {
    if (status == 'مكتمل') return AppColors.success;
    if (status == 'ملغي') return AppColors.danger;
    if (status == 'وصلت عروض') return AppColors.warning;
    if (status == 'قيد التنفيذ') return AppColors.secondary;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12.5,
        ),
      ),
    );
  }
}