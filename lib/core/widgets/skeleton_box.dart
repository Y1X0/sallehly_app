import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// عنصر نائب متوهّج بلطف أثناء التحميل. يُستخدم بعدد محدود فقط (لا يجوز
/// استخدامه لعرض مئات العناصر دفعة واحدة) — كل [SkeletonBox] يحمل مؤقّته
/// الخاص فقط طوال بقائه على الشاشة، ويُتخلّص منه تلقائياً بمجرد استبداله
/// بالمحتوى الحقيقي.
class SkeletonBox extends StatefulWidget {
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
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}
