import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_logo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../routes/route_guard.dart';
import '../auth/screens/landing_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  // [FIX-AUTH-02] لا مزيد من "انتظر للأبد" ولا "خمّن وانتقل خطأً" — حالة
  // ثالثة صريحة: تعذّر التحقق خلال مهلة معقولة، فنعرض ذلك بوضوح مع خيار
  // إعادة المحاولة، بدل الانتقال لأي شاشة بافتراض غير مؤكد.
  bool _showRetry = false;

  // [FIX-AUTH-04] Future.timeout() لا يُلغي العملية الأصلية، فقط يتوقف عن
  // الانتظار لها — auth.loadMe() تستمر فعلياً بالخلفية (وقد تُعاد إرسالها
  // تلقائياً عبر منطق إعادة المحاولة بـApiClient حتى ~40 ثانية إضافية) حتى
  // بعد ظهور شاشة "تعذّر الاتصال". بدون هذا المرجع، ضغط زر "إعادة المحاولة"
  // كان يُصدر طلب /me ثانياً متزامناً مع الأول الذي ما زال قيد التنفيذ فعلاً
  // — يضاعف الحمل على الخادم في أضعف لحظة له (خادم يستيقظ من الخمول).
  Future<void>? _loadMeFuture;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 600), checkAuth);
  }

  Future<void> checkAuth() async {
    final auth = context.read<AuthProvider>();

    if (mounted && _showRetry) {
      setState(() => _showRetry = false);
    }

    // [FIX-AUTH-02] كانت المهلة السابقة (8 ثوانٍ) تقود لقرار خاطئ: عند
    // انتهائها كانت الشاشة تنتقل فوراً لـLandingScreen بافتراض عدم وجود
    // مستخدم، بينما loadMe() تستمر فعلياً بالخلفية وقد تُسجّل المستخدم
    // (بجلسة صالحة 100%) على شاشة أخرى لا تراقب AuthProvider إطلاقاً.
    // الحل ليس إزالة المهلة نهائياً (فقد ينقطع الإنترنت فعلاً/DNS معطّل،
    // ونبقى بشاشة البداية للأبد)، بل مهلة أطول وواقعية (25 ثانية — أطول
    // قليلاً من مهلة Dio الأساسية 20 ثانية لإتمام محاولة واحدة كاملة دون
    // قطعها ظلماً) + عند تجاوزها: لا تخمين ولا انتقال، فقط حالة صريحة
    // "تعذّر الاتصال" مع زر إعادة محاولة يعيد استدعاء نفس الفحص من جديد.
    // [FIX-AUTH-04] أعد استخدام نفس العملية قيد التنفيذ فعلاً إن وُجدت، بدل
    // إصدار طلب /me جديد كل مرة يُستدعى فيها checkAuth() (إقلاع أول أو إعادة
    // محاولة يدوية) — يُصفَّر المرجع فقط عند اكتمال العملية الحقيقية فعلاً،
    // وليس عند انتهاء مهلة الانتظار الظاهرة أدناه.
    final loadMeFuture = _loadMeFuture ??= auth.loadMe().whenComplete(() {
      _loadMeFuture = null;
    });

    try {
      await loadMeFuture.timeout(const Duration(seconds: 25));
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _showRetry = true);
      return;
    } catch (_) {
      // أي خطأ آخر متبقٍّ هنا غير متعلق بحالة الجلسة (auth.loadMe() تتعامل
      // مع 401 الحقيقي داخلياً) — نتابع بالاعتماد على auth.user أدناه.
    }

    if (!mounted) return;

    final user = auth.user;

    if (user != null) {
      context.read<NotificationProvider>().setCurrentUser(user);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => user == null
            ? const LandingScreen()
            : RouteGuard.homeForUser(user),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        safeArea: false,
        child: Center(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return Transform.scale(
                scale: 1 + controller.value * 0.05,
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(
                  size: 92,
                  showText: false,
                ),
                const SizedBox(height: 22),
                Text(
                  'صلّحلي',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'منصة خدمات الصيانة في الأردن',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 38),
                if (_showRetry)
                  _RetryButton(onPressed: checkAuth)
                else
                  Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.7,
                      color: AppColors.secondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [FIX-AUTH-02] تظهر فقط بعد تجاوز مهلة الاتصال الفعلية (25 ثانية) دون رد —
/// بديل صريح وواضح عن الانتظار للأبد أو التخمين والانتقال لشاشة قد تكون خاطئة.
class _RetryButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RetryButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_rounded,
          color: AppColors.textSecondary,
          size: 32,
        ),
        const SizedBox(height: 10),
        Text(
          'تعذّر الاتصال بالخادم',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }
}