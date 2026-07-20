import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'skeleton_box.dart';

/// عنصر نائب بشكل بطاقة طلب أثناء التحميل الأول — يُستخدم بعدد محدود
/// (3 بطاقات كحد أقصى) بدل مؤشر تحميل مجرّد، ولا يُستخدم أبداً لعرض القائمة
/// الحقيقية الكاملة.
class RequestCardSkeleton extends StatelessWidget {
  const RequestCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBox(
            width: 84,
            height: 24,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          const SizedBox(height: 14),
          SkeletonBox(width: 160, height: 18),
          const SizedBox(height: 10),
          SkeletonBox(width: 110, height: 14),
          const SizedBox(height: 10),
          SkeletonBox(width: double.infinity, height: 14),
        ],
      ),
    );
  }
}
