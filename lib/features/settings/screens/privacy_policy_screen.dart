import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            children: const [
              _PrivacyIntro(),
              SizedBox(height: 18),
              _PrivacySection(
                icon: Icons.checklist_rounded,
                title: 'البيانات التي نجمعها ولماذا',
                child: _DataTable(),
              ),
              _PrivacySection(
                icon: Icons.lock_outline_rounded,
                title: 'أين تُخزَّن بياناتك وكيف تُحمى',
                body:
                    'تُخزَّن بياناتك على خوادمنا، ويكون كل اتصال بين التطبيق '
                    'والخادم مشفّراً عبر HTTPS. كلمة مرورك تُحفظ بصيغة مشفّرة '
                    '(Hash) لا يمكن لأحد بمن فيهم فريقنا استرجاعها. رسائل '
                    'المحادثة محفوظة بقاعدة بياناتنا لعرضها لك ولطرف المحادثة '
                    'الآخر، ويُراجعها فريق الإدارة فقط عند وجود شكوى أو '
                    'مخالفة تستدعي ذلك.',
              ),
              _PrivacySection(
                icon: Icons.handshake_outlined,
                title: 'مشاركة البيانات مع أطراف ثالثة',
                body:
                    'لا نبيع بياناتك ولا نشاركها مع أي جهة إعلانية. الاستثناء '
                    'الوحيد هو خدمة Firebase Cloud Messaging (التابعة لـ '
                    'Google) التي نستخدمها حصراً لإرسال الإشعارات لجهازك، '
                    'وهذا يتطلب مشاركة معرّف جهاز الإشعارات معها فقط، دون أي '
                    'بيانات أخرى.',
              ),
              _PrivacySection(
                icon: Icons.vpn_key_outlined,
                title: 'صلاحيات التطبيق ولماذا نطلبها',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PermissionRow(
                      icon: Icons.location_on_outlined,
                      title: 'الموقع الجغرافي',
                      body:
                          'فقط عند ضغطك زر "مشاركة الموقع" داخل محادثة طلب — '
                          'لن يُستخدم بأي وقت آخر ولا بالخلفية.',
                    ),
                    _PermissionRow(
                      icon: Icons.mic_none_rounded,
                      title: 'الميكروفون',
                      body: 'فقط عند تسجيلك رسالة صوتية داخل محادثة طلب.',
                    ),
                    _PermissionRow(
                      icon: Icons.camera_alt_outlined,
                      title: 'الكاميرا / معرض الصور',
                      body:
                          'فقط عند اختيارك إرفاق صورة (صورتك الشخصية، أو صورة '
                          'توضّح المشكلة الفنية).',
                    ),
                    _PermissionRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'الإشعارات',
                      body:
                          'لتنبيهك بعروض جديدة، رسائل، وتحديثات طلباتك فوراً.',
                    ),
                  ],
                ),
              ),
              _PrivacySection(
                icon: Icons.verified_user_outlined,
                title: 'حقوقك',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BulletLine('الاطلاع على بياناتك وتعديلها في أي وقت من الإعدادات.'),
                    _BulletLine('تغيير كلمة مرورك في أي وقت.'),
                    _BulletLine('طلب حذف حسابك وبياناتك بالكامل من نفس صفحة الإعدادات.'),
                  ],
                ),
              ),
              _PrivacySection(
                icon: Icons.folder_delete_outlined,
                title: 'الاحتفاظ بالبيانات',
                body:
                    'نحتفظ ببياناتك طالما حسابك فعّال. عند حذف حسابك، تُحذف '
                    'بياناتك الشخصية نهائياً من قاعدة بياناتنا فوراً (باستثناء '
                    'حالات وجود طلب نشط أو رصيد غير مصفّى، والتي تمنع الحذف '
                    'حتى تُسوَّى أولاً).',
              ),
              _PrivacySection(
                icon: Icons.mail_outline_rounded,
                title: 'تواصل معنا',
                body:
                    'لأي استفسار بخصوص هذه السياسة أو بياناتك، تواصل معنا عبر '
                    'الدعم الفني داخل التطبيق.',
              ),
              SizedBox(height: 6),
              _LastUpdated(),
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
      child: const Row(
        children: [
          Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 34),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'هذه الصفحة توضّح كيف تجمع منصة صلّحلي بياناتك وتستخدمها '
              'وتحميها.',
              style: TextStyle(
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
  const _LastUpdated();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'آخر تحديث: 2026',
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
            padding: EdgeInsets.only(top: 6),
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

  static const _rows = [
    ('الاسم، البريد، رقم الهاتف', 'إنشاء الحساب والتواصل بخصوص طلباتك', true),
    ('كلمة المرور', 'حماية حسابك (مشفّرة، لا يمكن استرجاعها)', true),
    ('المدينة والمنطقة', 'ربطك بأقرب فني متاح', true),
    ('الرقم الوطني (فنيين)', 'التحقق من هوية الفني الحقيقية قبل تفعيل حسابه، لبناء ثقة العملاء', true),
    ('الصورة الشخصية (فنيين)', 'بناء الثقة بين العميل والفني', true),
    ('الموقع الجغرافي', 'فقط عند مشاركته داخل محادثة طلب', false),
    ('صور/صوت المحادثة', 'توضيح المشكلة الفنية', false),
    ('معرّف إشعارات الجهاز', 'إرسال إشعارات فورية', false),
    ('معاملات المحفظة', 'إدارة رصيد الفني (للفنيين فقط)', true),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _rows.map((row) {
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
                  required ? 'إلزامية' : 'اختيارية',
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
