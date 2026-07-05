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

    // لا تُعلّق المستخدم على شاشة البداية إن كان الخادم بطيئاً/نائماً.
    // امنح loadMe مهلة قصوى ثم تابع بأي حال.
    try {
      await auth.loadMe().timeout(const Duration(seconds: 8));
    } catch (_) {
      // انتهت المهلة أو فشل — نتابع؛ سيُعاد التوجيه حسب وجود جلسة محفوظة.
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
                const Text(
                  'صلّحلي',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'منصة خدمات الصيانة في الأردن',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 38),
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const CircularProgressIndicator(
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