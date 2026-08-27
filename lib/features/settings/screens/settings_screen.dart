import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/directional_icons.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/bidi_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/theme_controller.dart';
import '../../auth/screens/login_screen.dart';
import '../../support/screens/support_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String roleLabel(AppLocalizations t, String? role) {
    if (role == 'customer') return t.customerFallbackName;
    if (role == 'technician') return t.technicianFallbackName;
    if (role == 'admin') return t.adminRoleLabel;
    return t.genericUserRoleLabel;
  }

  IconData roleIcon(String? role) {
    if (role == 'technician') return Icons.engineering_rounded;
    if (role == 'admin') return Icons.admin_panel_settings_rounded;
    return Icons.person_rounded;
  }

  Future<void> logout(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(t.logoutTitle),
        content: Text(t.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancelButton),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(t.logoutButton),
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
    final t = AppLocalizations.of(context)!;
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
              title: Text(
                t.deleteAccountPermanentlyTitle,
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
                          t.actionIsPermanentWarning,
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        t.deleteAccountWillDeleteIntro,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DeleteChecklistItem(t.deleteChecklistNameEmailPhone),
                      _DeleteChecklistItem(t.deleteChecklistPasswordCredentials),
                      _DeleteChecklistItem(t.deleteChecklistProfilePhoto),
                      _DeleteChecklistItem(t.deleteChecklistDeviceToken),
                      const SizedBox(height: 4),
                      Text(
                        t.deleteAccountChatRetentionNote,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        t.enterCurrentPasswordToConfirmMessage,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscure,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: t.currentPasswordFieldLabel,
                          suffixIcon: IconButton(
                            tooltip: obscure ? t.showPasswordTooltip : t.hidePasswordTooltip,
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
                            (v == null || v.isEmpty) ? t.passwordRequiredValidation : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(t.cancelButton),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    Navigator.pop(dialogContext, true);
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                  child: Text(t.deleteForeverPermanentlyButton),
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
          content: Text(t.deleteAccountFailedMessage),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
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
                t.navSettings,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _ProfileHero(
                userId: user?.id ?? 0,
                name: user?.name ?? t.sallehlyUserFallbackName,
                email: user?.email ?? '-',
                role: roleLabel(t, user?.role),
                icon: roleIcon(user?.role),
                rating: user?.rating ?? 0,
                balance: user?.balance ?? 0,
                isTechnician: isTech,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: t.accountInfoSectionTitle,
                children: [
                  _InfoTile(Icons.person_outline_rounded, t.nameFieldLabel, user?.name ?? '-'),
                  _InfoTile(Icons.email_outlined, t.emailFieldLabel, user?.email ?? '-'),
                  _InfoTile(Icons.phone_outlined, t.phoneLabel, user?.phone ?? '-'),
                  _InfoTile(Icons.location_city_outlined, t.cityLabel, user?.city ?? '-', bidi: true),
                  _InfoTile(Icons.place_outlined, t.areaDropdownLabel, user?.area ?? '-', bidi: true),
                ],
              ),
              if (isTech) ...[
                const SizedBox(height: 14),
                _SectionCard(
                  title: t.technicianInfoSectionTitle,
                  children: [
                    _InfoTile(Icons.handyman_outlined, t.serviceLabel, user?.serviceName ?? t.maintenanceTechnicianFallback),
                    _InfoTile(Icons.badge_outlined, t.nationalNumberFieldLabel, user?.nationalNumber ?? '-'),
                    _InfoTile(Icons.star_outline_rounded, t.ratingLabel, '${(user?.rating ?? 0).toStringAsFixed(1)} ⭐'),
                    _InfoTile(Icons.account_balance_wallet_outlined, t.balanceButtonLabel, formatJod(context, user?.balance ?? 0)),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              _SectionCard(
                title: t.accountAndPrivacySectionTitle,
                children: [
                  _ActionTile(
                    Icons.edit_outlined,
                    t.editProfileActionTitle,
                    isTech
                        ? t.editProfileWithPhotoSubtitle
                        : t.editProfileWithoutPhotoSubtitle,
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
                    t.changePasswordActionTitle,
                    t.changePasswordActionSubtitle,
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
                    t.privacyPolicyTitle,
                    t.privacyPolicyActionSubtitle,
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
                    t.logoutTitle,
                    t.logoutActionSubtitle,
                    () => logout(context),
                    danger: true,
                  ),
                  _DeleteAccountTile(onTap: () => deleteAccountFlow(context)),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: t.appSectionTitle,
                children: [
                  const _ThemeModeTile(),
                  const _LanguageTile(),
                  _ActionTile(Icons.support_agent_rounded, t.supportScreenTitle, t.supportActionSubtitle, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportScreen(),
                      ),
                    );
                  }),
                  _ActionTile(Icons.info_outline_rounded, t.aboutSallehlyTitle, t.maintenancePlatformInJordanTagline, () {
                    showAboutDialog(
                      context: context,
                      applicationName: t.appWordmark,
                      applicationVersion: '1.0.0',
                      applicationLegalese: t.maintenancePlatformInJordanTagline,
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
              if (isTechnician) _HeroChip(Icons.wallet_rounded, formatJod(context, balance)),
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
              alignment: AlignmentDirectional.centerStart,
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
  // [FIX-BIDI-01] true فقط للقيم اللي تبقى عربية بغضّ النظر عن اللغة (مدينة/
  // منطقة من app_constants.dart) — راجع L10N_PROGRESS.md §3. باقي القيم
  // (الاسم/البريد/الهاتف/الخدمة...) ليست مشمولة حالياً، فتبقى false افتراضياً.
  final bool bidi;

  const _InfoTile(this.icon, this.title, this.value, {this.bidi = false});

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w800,
    );
    final displayValue = value.isEmpty ? '-' : value;
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
            child: bidi
                ? BidiText(
                    displayValue,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  )
                : Text(
                    displayValue,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
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
            Icon(DirectionalIcons.forwardIosStyle(context), size: 16, color: danger ? AppColors.danger.withValues(alpha: 0.6) : AppColors.textMuted),
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
    final t = AppLocalizations.of(context)!;

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
                  t.lightModeLabel,
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  isLight ? t.lightModeOnSubtitle : t.darkModeOnSubtitle,
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

/// [FIX-L10N-01] مفتاح تبديل لغة الواجهة (عربي/إنجليزي) — بنفس بنية
/// _ThemeModeTile أعلاه تماماً: يعرض الحالة الحالية ويستدعي
/// LocaleProvider.setLocale عند الضغط، فتتحدّث كل شاشات التطبيق فوراً (بما في
/// ذلك اتجاه الكتابة RTL/LTR المُشتقّ تلقائياً من اللغة الجديدة) وتُحفظ رغبة
/// المستخدم محلياً للمرات القادمة.
class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LocaleProvider>().isEnglish;
    final t = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _IconBox(Icons.language_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.settingsLanguageTitle,
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  isEnglish
                      ? t.settingsLanguageSubtitleEnglish
                      : t.settingsLanguageSubtitleArabic,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnglish,
            activeThumbColor: AppColors.primary,
            onChanged: (value) => context.read<LocaleProvider>().setLocale(
                  value ? LocaleProvider.englishLocale : LocaleProvider.fallbackLocale,
                ),
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
                      AppLocalizations.of(context)!.deleteAccountPermanentlyTitle,
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.permanentIrreversibleActionSubtitle,
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