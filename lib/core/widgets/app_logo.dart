import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool compact;

  const AppLogo({
    super.key,
    this.size = 52,
    this.showText = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(
        'assets/images/logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            child: Icon(
              Icons.handyman_rounded,
              color: Colors.white,
              size: size * 0.52,
            ),
          );
        },
      ),
    );

    if (!showText) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        SizedBox(width: compact ? 8 : 12),
        Text(
          'صلّحلي',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: compact ? 20 : 28,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}