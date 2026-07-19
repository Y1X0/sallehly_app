import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_controller.dart';
import '../../auth/screens/login_screen.dart';
import '../../support/screens/support_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_policy_screen.dart';

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

  /// حذف الحساب نهائياً (متطلّب سياسة Google Play لحذف الحساب).
  /// يطلب كلمة السر الحالية للتأكيد، ثم يستدعي AuthProvider.deleteAccount().
  Future<void> deleteAccountFlow(BuildContext context) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              icon: Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: 36,
              ),
              title: const Text(
                'حذف الحساب نهائياً',
                textAlign: TextAlign.center,
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          'هذا الإجراء نهائي ولا يمكن التراجع عنه إطلاقاً.',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'عند التأكيد، سيتم حذف التالي فوراً ونهائياً:',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _DeleteChecklistItem('اسمك، بريدك، ورقم هاتفك'),
                      const _DeleteChecklistItem('كلمة المرور وبيانات الدخول'),
                      const _DeleteChecklistItem('صورتك الشخصية'),
                      const _DeleteChecklistItem('معرّف إشعارات جهازك'),
                      const SizedBox(height: 4),
                      Text(
                        'محادثات الشات القديمة تبقى ظاهرة للطرف الآخر (بدون اسمك) '
                        'للحفاظ على سجل الطلب، لكن دون أي بيانات تعرّف بك.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'أدخل كلمة مرورك الحالية لتأكيد أن هذا الطلب منك:',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscure,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور الحالية',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                            onPressed: () =>
                                setDialogState(() => obscure = !obscure),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'أدخل كلمة المرور' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    Navigator.pop(dialogContext, true);
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                  child: const Text('حذف نهائياً'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await auth.deleteAccount(password: passwordController.text);
      if (!context.mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('تعذر حذف الحساب، حاول مرة أخرى'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
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
              Text(
                'الإعدادات',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _ProfileHero(
                userId: user?.id ?? 0,
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
                title: 'الحساب والخصوصية',
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
                  _ActionTile(
                    Icons.privacy_tip_outlined,
                    'سياسة الخصوصية',
                    'كيف نجمع بياناتك ونحميها',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                  // [FIX-UX-02] فاصل بصري قبل الإجراءات الحساسة — يفصل
                  // "تسجيل الخروج" (قابل للتراجع) عن "حذف الحساب" (نهائي)
                  // عن باقي إجراءات الحساب العادية، حسب توصيات Material Design
                  // لتجميع الإجراءات الهدّامة بأسفل القائمة مع تمييزها لوناً.
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 26),
                  ),
                  _ActionTile(
                    Icons.logout_rounded,
                    'تسجيل الخروج',
                    'يمكنك الدخول مرة أخرى بنفس بياناتك',
                    () => logout(context),
                    danger: true,
                  ),
                  _DeleteAccountTile(onTap: () => deleteAccountFlow(context)),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'التطبيق',
                children: [
                  const _ThemeModeTile(),
                  _ActionTile(Icons.support_agent_rounded, 'الدعم الفني', 'تواصل معنا عند وجود مشكلة', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportScreen(),
                      ),
                    );
                  }),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// عنصر قائمة صغير يُستخدم داخل حوار تأكيد حذف الحساب لعرض ما سيُحذف بالضبط.
class _DeleteChecklistItem extends StatelessWidget {
  final String text;

  const _DeleteChecklistItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(Icons.close_rounded, size: 15, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final int userId;
  final String name;
  final String email;
  final String role;
  final IconData icon;
  final double rating;
  final double balance;
  final bool isTechnician;

  const _ProfileHero({
    required this.userId,
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
          Hero(
            tag: 'profile-avatar-$userId',
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: Colors.white, size: 44),
            ),
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
                style: TextStyle(
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
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
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
  final bool danger;

  const _ActionTile(
    this.icon,
    this.title,
    this.subtitle,
    this.onTap, {
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            _IconBox(icon, color: danger ? AppColors.danger : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: danger ? AppColors.danger.withValues(alpha: 0.6) : AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// [FIX-THEME-01] مفتاح تبديل "الوايت مود" — يعرض الحالة الحالية (فاتح/داكن)
/// ويستدعي ThemeController.setLight عند الضغط، فيتحدّث شكل التطبيق بالكامل
/// فوراً وتُحفظ رغبة المستخدم محلياً للمرات القادمة.
class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile();

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeController>().isLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _IconBox(isLight ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الوضع الفاتح',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  isLight ? 'خلفية بيضاء لكل الشاشات' : 'مفعّل حالياً الوضع الداكن',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: isLight,
            activeColor: AppColors.primary,
            onChanged: (value) => context.read<ThemeController>().setLight(value),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color? color;

  const _IconBox(this.icon, {this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: tint, size: 22),
    );
  }
}

/// [FIX-UX-02] صف حذف الحساب — أقوى تمييزاً بصرياً من أي إجراء آخر بالقائمة
/// (خلفية محمّرة + حدود + نص عريض) لأنه الإجراء الوحيد الهدّام واللارجعة فيه،
/// لكنه يبقى ضمن نفس بطاقة "الحساب والخصوصية" بدل صفحة/زر منفصل يكتشفه
/// المستخدم بالصدفة.
class _DeleteAccountTile extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteAccountTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.delete_forever_rounded, color: AppColors.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حذف الحساب نهائياً',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'إجراء نهائي لا يمكن التراجع عنه',
                      style: TextStyle(
                        color: AppColors.danger.withValues(alpha: 0.75),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}