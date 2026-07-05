import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/gradient_button.dart';
import 'login_screen.dart';
import 'register_role_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            children: [
              const Row(
                children: [
                  AppLogo(size: 46, compact: true),
                  Spacer(),
                  _MiniBadge(),
                ],
              ),
              const SizedBox(height: 30),
              const Text(
                'كل خدمات الصيانة\nفي مكان واحد',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'اطلب فني قريب منك، استقبل عروض، واحكِ مع الفني داخل التطبيق بأمان.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 22),
              const _HeroPreview(),
              const SizedBox(height: 20),
              const _ServicesRow(),
              const SizedBox(height: 26),
              GradientButton(
                label: 'تسجيل الدخول',
                icon: Icons.login_rounded,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterRoleScreen()),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('إنشاء حساب جديد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: const Text(
        'الأردن',
        style: TextStyle(
          color: AppColors.success,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _HeroPreview extends StatelessWidget {
  const _HeroPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Row(
            children: [
              Expanded(child: _MiniStat(title: 'طلب', value: '+120', icon: Icons.assignment_rounded)),
              SizedBox(width: 12),
              Expanded(child: _MiniStat(title: 'فني', value: '+50', icon: Icons.engineering_rounded)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniStat(title: 'محادثة', value: 'آمنة', icon: Icons.chat_rounded)),
              SizedBox(width: 12),
              Expanded(child: _MiniStat(title: 'موقعك', value: 'قريب', icon: Icons.location_on_rounded)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniStat({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.secondary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesRow extends StatelessWidget {
  const _ServicesRow();

  static const services = [
    ['كهربائي', Icons.electric_bolt_rounded],
    ['سباك', Icons.water_drop_rounded],
    ['تكييف', Icons.ac_unit_rounded],
    ['نجار', Icons.carpenter_rounded],
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: services.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item[1] as IconData, color: AppColors.accent, size: 18),
              const SizedBox(width: 6),
              Text(
                item[0] as String,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}