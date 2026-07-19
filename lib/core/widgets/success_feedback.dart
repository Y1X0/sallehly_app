import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// أيقونة نجاح صغيرة "تنبض للداخل" (bounce-in) — تُستخدم داخل SnackBar
/// النجاح لإعطاء إحساس احتفالي خفيف عند اكتمال عملية مهمة (إنشاء طلب، قبول
/// عرض، اعتماد شحن رصيد)، دون حجب أي إجراء تالٍ للمستخدم.
class _SuccessCheckmark extends StatefulWidget {
  const _SuccessCheckmark();

  @override
  State<_SuccessCheckmark> createState() => _SuccessCheckmarkState();
}

class _SuccessCheckmarkState extends State<_SuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) return;
    _started = true;

    // احترام "تقليل الحركة" على مستوى النظام: أظهر الأيقونة مباشرة بلا حركة.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const Icon(
        Icons.check_circle_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

/// يعرض SnackBar نجاح موحّد بأيقونة صح متحركة (bounce-in) بجانب [message].
/// غير حاجب أبداً (SnackBar لا يوقف تنفيذ الكود) ويختفي تلقائياً خلال
/// مدة قصيرة، فلا يمنع أي تنقّل يتبعه مباشرة (مثل فتح شاشة المحادثة بعد
/// قبول عرض).
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppColors.success,
      duration: const Duration(milliseconds: 1600),
      content: Row(
        children: [
          const _SuccessCheckmark(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
