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
    return Chip(
      label: Text(status),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
      ),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }
}