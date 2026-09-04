import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../l10n/app_localizations.dart';

/// شاشة سياسة الخصوصية داخل التطبيق — بديل عن الـ Bottom Sheet السابق، بنفس
/// لغة تصميم التطبيق تماماً (AppColors، Material 3، نفس الخطوط والمسافات
/// المستخدمة بباقي الشاشات)، بدون أي لون أو نمط جديد غريب عن المشروع.
///
/// ملاحظة: هذا التطبيق لا يملك "وضع فاتح/داكن" فعلياً — يوجد نمط واحد ثابت
/// (AppTheme.darkTheme) يُستخدم دائماً بكل شاشة بالتطبيق، فاستخدام AppColors
/// هنا يجعل هذه الشاشة متّسقة تلقائياً مع كل شاشة أخرى بالتطبيق.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.privacyPolicyTitle)),
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            children: [
              const _PrivacyIntro(),
              const SizedBox(height: 18),
              _PrivacySection(
                icon: Icons.checklist_rounded,
                title: t.dataWeCollectSectionTitle,
                child: const _DataTable(),
              ),
              _PrivacySection(
                icon: Icons.lock_outline_rounded,
                title: t.dataStorageSectionTitle,
                body: t.dataStorageSectionBody,
              ),
              _PrivacySection(
                icon: Icons.handshake_outlined,
                title: t.thirdPartySharingSectionTitle,
                body: t.thirdPartySharingSectionBody,
              ),
              _PrivacySection(
                icon: Icons.vpn_key_outlined,
                title: t.appPermissionsSectionTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PermissionRow(
                      icon: Icons.location_on_outlined,
                      title: t.permissionLocationTitle,
                      body: t.permissionLocationBody,
                    ),
                    _PermissionRow(
                      icon: Icons.mic_none_rounded,
                      title: t.permissionMicTitle,
                      body: t.permissionMicBody,
                    ),
                    _PermissionRow(
                      icon: Icons.camera_alt_outlined,
                      title: t.permissionCameraTitle,
                      body: t.permissionCameraBody,
                    ),
                    _PermissionRow(
                      icon: Icons.notifications_none_rounded,
                      title: t.permissionNotificationsTitle,
                      body: t.permissionNotificationsBody,
                    ),
                  ],
                ),
              ),
              _PrivacySection(
                icon: Icons.verified_user_outlined,
                title: t.yourRightsSectionTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BulletLine(t.rightsBulletAccessData),
                    _BulletLine(t.rightsBulletChangePassword),
                    _BulletLine(t.rightsBulletDeleteAccount),
                  ],
                ),
              ),
              _PrivacySection(
                icon: Icons.folder_delete_outlined,
                title: t.dataRetentionSectionTitle,
                body: t.dataRetentionSectionBody,
              ),
              _PrivacySection(
                icon: Icons.mail_outline_rounded,
                title: t.contactUsSectionTitle,
                body: t.contactUsSectionBody,
              ),
              const SizedBox(height: 6),
              _LastUpdated(text: t.privacyLastUpdatedLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyIntro extends StatelessWidget {
  const _PrivacyIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.privacyIntroText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LastUpdated extends StatelessWidget {
  final String text;

  const _LastUpdated({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? child;

  const _PrivacySection({
    required this.icon,
    required this.title,
    this.body,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          if (body != null)
            Text(
              body!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.8,
              ),
            ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;

  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: AppColors.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataTable extends StatelessWidget {
  const _DataTable();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    // [PRIVACY-AUDIT-01] راجع DECISIONS.md — الترتيب والصفوف مطابقة الآن
    // لـsallehly/public/privacy.html (نفس المصدر المُدخَل بـPlay Console)
    // بعد مقارنة ثلاثية (سكيما قاعدة البيانات + ما يُرسَل فعلياً من
    // العميل + جدول السياسة): أربعة صفوف جديدة (صورة المشكلة عند إنشاء
    // الطلب، سجل الإشعارات، قائمة خدمات الفني، نص التقييمات) كانت بيانات
    // حقيقية تُجمَع ولا صف لها؛ صف الموقع الجغرافي عُدِّل ليعكس سلوك نسخة
    // الموقع الإلكتروني أيضاً (لا التطبيق فقط)؛ صف الدعم وُسِّع ليشمل
    // الشكاوى (ComplaintSheet، آلية منفصلة بالخادم بنفس الغرض تقريباً).
    final rows = [
      (t.dataTableNameLabel, t.dataTableNameReason, true),
      (t.dataTablePasswordLabel, t.dataTablePasswordReason, true),
      (t.dataTableCityAreaLabel, t.dataTableCityAreaReason, true),
      (t.dataTableNationalNumberLabel, t.dataTableNationalNumberReason, true),
      (t.dataTableProfilePhotoLabel, t.dataTableProfilePhotoReason, true),
      (t.dataTableLocationLabel, t.dataTableLocationReason, false),
      (t.dataTableChatMediaLabel, t.dataTableChatMediaReason, false),
      (t.dataTableProblemImageLabel, t.dataTableProblemImageReason, false),
      (t.dataTableDeviceTokenLabel, t.dataTableDeviceTokenReason, false),
      (t.dataTableNotificationRecordLabel, t.dataTableNotificationRecordReason, false),
      (t.dataTableTechnicianServicesLabel, t.dataTableTechnicianServicesReason, true),
      (t.dataTableWalletLabel, t.dataTableWalletReason, true),
      (t.dataTableReceiptLabel, t.dataTableReceiptReason, true),
      (t.dataTableRatingsLabel, t.dataTableRatingsReason, false),
      (t.dataTableSupportLabel, t.dataTableSupportReason, false),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.map((row) {
        final (label, reason, required) = row;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reason,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (required ? AppColors.warning : AppColors.success)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  required ? t.requiredBadgeLabel : t.optionalBadgeLabel,
                  style: TextStyle(
                    color: required ? AppColors.warning : AppColors.success,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
