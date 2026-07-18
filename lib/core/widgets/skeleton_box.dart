import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// عنصر نائب ثابت (بلا أي حركة) أثناء التحميل. يُستخدم بعدد محدود فقط (لا
/// يجوز استخدامه لعرض مئات العناصر دفعة واحدة) — لا يحمل أي مؤقّت أو حركة
/// مستمرة، فقط شكل بديل بلون البطاقة إلى حين استبداله بالمحتوى الحقيقي.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.55),
        borderRadius: borderRadius,
      ),
    );
  }
}
