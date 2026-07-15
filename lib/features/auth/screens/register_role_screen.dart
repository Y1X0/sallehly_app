import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/glass_card.dart';
import 'customer_register_screen.dart';
import 'technician_register_screen.dart';

class RegisterRoleScreen extends StatelessWidget {
  const RegisterRoleScreen({super.key});

  void goTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(height: 12),
            const Center(
              child: AppLogo(
                size: 64,
                showText: false,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'اختر نوع الحساب',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أنشئ حسابك كعميل لطلب الخدمات أو كفني لاستقبال الطلبات.',
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            _RoleCard(
              title: 'حساب عميل',
              subtitle: 'اطلب خدمة صيانة واستقبل عروض الفنيين',
              icon: Icons.home_repair_service_rounded,
              gradient: AppColors.primaryGradient,
              onTap: () {
                goTo(
                  context,
                  const CustomerRegisterScreen(),
                );
              },
            ),
            const SizedBox(height: 16),
            _RoleCard(
              title: 'حساب فني',
              subtitle: 'استقبل طلبات العملاء وقدّم عروضك',
              icon: Icons.engineering_rounded,
              gradient: LinearGradient(
                colors: [
                  AppColors.card2,
                  AppColors.surface,
                ],
              ),
              onTap: () {
                goTo(
                  context,
                  const TechnicianRegisterScreen(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      gradient: gradient,
      padding: const EdgeInsets.all(20),
      radius: 28,
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
        ],
      ),
    );
  }
}