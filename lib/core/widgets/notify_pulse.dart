import 'package:flutter/material.dart';

/// يهزّ [child] بلطف (تكبير ثم عودة) فقط عند ازدياد [count] فعلياً (مثال:
/// وصول إشعار جديد) — لا يتحرك أبداً لمجرد إعادة بناء الأصل أو عند نقصان
/// العدّاد (تصفير القراءة). يبقى ثابتاً بحجمه الطبيعي طوال الوقت غير ذلك.
class NotifyPulse extends StatefulWidget {
  final int count;
  final Widget child;

  const NotifyPulse({
    super.key,
    required this.count,
    required this.child,
  });

  @override
  State<NotifyPulse> createState() => _NotifyPulseState();
}

class _NotifyPulseState extends State<NotifyPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 55),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant NotifyPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) {
      // احترام "تقليل الحركة": العدّاد يتحدّث فوراً بلا نبضة حركية.
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
