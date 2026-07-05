import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../support/screens/support_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String roleLabel(String? role) {
    if (role == 'customer') return 'عميل';
    if (role == 'technician') return 'فني';
    if (role == 'admin') return 'أدمن';
    return 'مستخدم';
  }

  IconData roleIcon(String? role) {
    if (role == 'technician') return Icons.engineering_rounded;
    if (role == 'admin') return Icons.admin_panel_settings_rounded;
    return Icons.person_rounded;
  }

  Future<void> logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    await auth.logout();

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  void _showPrivacy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(22),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Icon(
                      Icons.privacy_tip_rounded,
                      size: 54,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'سياسة الخصوصية',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(height: 18),
                  _PrivacySection(
                    title: 'البيانات التي نجمعها',
                    body:
                        'نجمع البيانات اللازمة لتشغيل الخدمة فقط: الاسم، البريد الإلكتروني، رقم الهاتف، المدينة والمنطقة، والصورة الشخصية للفنيين. كما نستخدم موقعك الجغرافي عند طلبك ذلك لتحديد الفنيين الأقرب إليك.',
                  ),
                  _PrivacySection(
                    title: 'كيف نستخدم بياناتك',
                    body:
                        'تُستخدم بياناتك لربط العملاء بالفنيين، وإدارة الطلبات والعروض والمحادثات، وإرسال الإشعارات المتعلقة بطلباتك. لا نبيع بياناتك أو نشاركها مع جهات إعلانية.',
                  ),
                  _PrivacySection(
                    title: 'المحادثات والأمان',
                    body:
                        'المحادثة بين العميل والفني مرتبطة بالطلب وتخضع لمراجعة الإدارة للحفاظ على سلامة المستخدمين. يُمنع مشاركة أرقام التواصل الخارجية داخل المحادثة.',
                  ),
                  _PrivacySection(
                    title: 'حماية البيانات',
                    body:
                        'كلمات المرور محفوظة بشكل مشفّر، والاتصال بالخادم مؤمّن. لا يطّلع أحد على كلمة مرورك، ويمكنك تغييرها في أي وقت من إعدادات الحساب.',
                  ),
                  _PrivacySection(
                    title: 'حقوقك',
                    body:
                        'يمكنك تعديل بياناتك أو تغيير كلمة مرورك في أي وقت. لحذف حسابك أو الاستفسار عن بياناتك، تواصل معنا عبر الدعم الفني داخل التطبيق.',
                  ),
                  SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isTech = user?.role == 'technician';

    return Scaffold(
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            children: [
              const Text(
                'الإعدادات',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _ProfileHero(
                name: user?.name ?? 'مستخدم صلّحلي',
                email: user?.email ?? '-',
                role: roleLabel(user?.role),
                icon: roleIcon(user?.role),
                rating: user?.rating ?? 0,
                balance: user?.balance ?? 0,
                isTechnician: isTech,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'معلومات الحساب',
                children: [
                  _InfoTile(Icons.person_outline_rounded, 'الاسم', user?.name ?? '-'),
                  _InfoTile(Icons.email_outlined, 'البريد الإلكتروني', user?.email ?? '-'),
                  _InfoTile(Icons.phone_outlined, 'الهاتف', user?.phone ?? '-'),
                  _InfoTile(Icons.location_city_outlined, 'المدينة', user?.city ?? '-'),
                  _InfoTile(Icons.place_outlined, 'المنطقة', user?.area ?? '-'),
                ],
              ),
              if (isTech) ...[
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'معلومات الفني',
                  children: [
                    _InfoTile(Icons.handyman_outlined, 'الخدمة', user?.serviceName ?? 'فني صيانة'),
                    _InfoTile(Icons.badge_outlined, 'الرقم الوطني', user?.nationalNumber ?? '-'),
                    _InfoTile(Icons.star_outline_rounded, 'التقييم', '${(user?.rating ?? 0).toStringAsFixed(1)} ⭐'),
                    _InfoTile(Icons.account_balance_wallet_outlined, 'الرصيد', '${(user?.balance ?? 0).toStringAsFixed(2)} د.أ'),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              _SectionCard(
                title: 'إدارة الحساب',
                children: [
                  _ActionTile(
                    Icons.edit_outlined,
                    'تعديل الملف الشخصي',
                    isTech
                        ? 'الاسم، الهاتف، المنطقة، والصورة'
                        : 'الاسم، الهاتف، المنطقة',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                  _ActionTile(
                    Icons.password_rounded,
                    'تغيير كلمة المرور',
                    'حدّث كلمة المرور الخاصة بحسابك',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'التطبيق',
                children: [
                  _ActionTile(Icons.support_agent_rounded, 'الدعم الفني', 'تواصل معنا عند وجود مشكلة', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportScreen(),
                      ),
                    );
                  }),
                  _ActionTile(Icons.privacy_tip_outlined, 'سياسة الخصوصية', 'طريقة حماية بياناتك داخل صلّحلي', () => _showPrivacy(context)),
                  _ActionTile(Icons.info_outline_rounded, 'حول صلّحلي', 'منصة خدمات الصيانة في الأردن', () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'صلّحلي',
                      applicationVersion: '1.0.0',
                      applicationLegalese: 'منصة خدمات الصيانة في الأردن',
                    );
                  }),
                ],
              ),
              const SizedBox(height: 14),
              _DangerButton(onTap: () => logout(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final IconData icon;
  final double rating;
  final double balance;
  final bool isTechnician;

  const _ProfileHero({
    required this.name,
    required this.email,
    required this.role,
    required this.icon,
    required this.rating,
    required this.balance,
    required this.isTechnician,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _HeroChip(Icons.verified_user_rounded, role),
              if (isTechnician) _HeroChip(Icons.star_rounded, rating.toStringAsFixed(1)),
              if (isTechnician) _HeroChip(Icons.wallet_rounded, '${balance.toStringAsFixed(1)} د.أ'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _HeroChip(this.icon, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile(this.icon, this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _IconBox(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile(this.icon, this.title, this.subtitle, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            _IconBox(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;

  const _IconBox(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: AppColors.primary, size: 22),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DangerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.28)),
        ),
        child: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.danger),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final String body;

  const _PrivacySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}