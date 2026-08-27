import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/directional_icons.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/app_localizations.dart';
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
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: AppBackground(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
        // [FIX-RESPONSIVE-01] كانت Column بلا أي غلاف تمرير — على شاشات قصيرة
        // أو مع إعدادات تكبير خط الوصولية، يفيض المحتوى بلا أي طريقة للوصول
        // لما تحته (RenderFlex overflow). كل شاشة أخرى بالتطبيق فيها محتوى
        // مشابه تستخدم SingleChildScrollView؛ هذا يوحّد السلوك بلا أي تغيير
        // بصري عندما يكون المحتوى أصلاً أصغر من ارتفاع الشاشة.
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: t.backButtonTooltip,
                onPressed: () => Navigator.pop(context),
                icon: Icon(DirectionalIcons.back(context)),
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
                t.registerChooseAccountType,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.registerChooseAccountTypeSubtitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              _RoleCard(
                title: t.registerCustomerRoleTitle,
                subtitle: t.registerCustomerRoleSubtitle,
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
                title: t.registerTechnicianRoleTitle,
                subtitle: t.registerTechnicianRoleSubtitle,
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
          Icon(
            DirectionalIcons.forwardIosStyle(context),
            color: Colors.white,
            size: 18,
          ),
        ],
      ),
    );
  }
}