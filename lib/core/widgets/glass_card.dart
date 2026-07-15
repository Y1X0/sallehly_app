import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 26,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // [FIX-THEME-01] المظهر الزجاجي (شفافية بيضاء + ظل أسود قوي) كان مصمّم
    // خصيصاً للخلفية الداكنة، وفوق الوايت مود كان يطلع كضباب رمادي حول
    // الكرت بدل مظهر نظيف. بالوضع الداكن الشكل ما تغيّر ولا بكسل — فقط
    // بالوضع الفاتح صرنا نستخدم كرت أبيض نظيف بحدّ وظل ناعمين، بنفس الأداء
    // (بدون BackdropFilter).
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ??
            (AppColors.isLight
                ? AppColors.cardGradient
                : LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.white.withValues(alpha: 0.09),
                      Colors.white.withValues(alpha: 0.025),
                    ],
                  )),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.isLight
              ? AppColors.border
              : Colors.white.withValues(alpha: 0.14),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.isLight
                ? Colors.black.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.26),
            blurRadius: AppColors.isLight ? 18 : 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Pressable(
      onTap: onTap,
      child: card,
    );
  }
}

