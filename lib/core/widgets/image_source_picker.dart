import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// أداة موحّدة لاختيار صورة: تعرض خيارَي الكاميرا والمعرض،
/// وتُرجع مسار الصورة بعد التقاطها/اختيارها (مضغوطة).
///
/// تُستخدم في كل الشاشات بدل تكرار منطق ImagePicker.
class ImageSourcePicker {
  ImageSourcePicker._();

  /// يعرض ورقة سفلية لاختيار المصدر، ثم يُرجع مسار الصورة أو null إن أُلغيت.
  static Future<String?> pick(
    BuildContext context, {
    int imageQuality = 82,
    double maxWidth = 1400,
  }) async {
    final t = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  t.addPhotoTitle,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SourceOption(
                        icon: Icons.camera_alt_rounded,
                        label: t.cameraOptionLabel,
                        onTap: () =>
                            Navigator.pop(ctx, ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SourceOption(
                        icon: Icons.photo_library_rounded,
                        label: t.galleryOptionLabel,
                        onTap: () =>
                            Navigator.pop(ctx, ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return null;

    final picker = ImagePicker();

    try {
      final file = await picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
      );

      return file?.path;
    } on PlatformException catch (e) {
      // [FIX-PERM-02] لا نعتمد على تحليل نص رسالة الاستثناء (غير مستقر بين
      // أندرويد/iOS ونسخ الحزمة) لتحديد إن كان الرفض دائماً. بدلاً من ذلك
      // نستعلم صراحة عن الحالة الفعلية من نظام التشغيل عبر permission_handler
      // (استعلام قراءة فقط — لا يطلب صلاحية جديدة ولا يعرض أي حوار نظام).
      //
      // ملاحظة مهمة: هذا الاستعلام موثوق على iOS فقط، لأن NSCameraUsage/
      // NSPhotoLibraryUsageDescription معلنتان فعلياً بـInfo.plist وتُطبَّقان
      // من النظام. على أندرويد، هذا التطبيق لا يطلب صلاحية الكاميرا إطلاقاً
      // (تُفوَّض لتطبيق الكاميرا الافتراضي عبر intent) ولا صلاحية المعرض
      // (يُستخدم منتقي الصور الحديث من النظام على أندرويد 13+ الذي لا يحتاج
      // أي صلاحية) — permission_handler يتطلب إعلان الصلاحية بـ
      // AndroidManifest ليعطي نتيجة موثوقة، وإعلانها هنا كان سيُعيد صلاحيات
      // غير ضرورية أُزيلت عمداً. لذا على أندرويد نكتفي برسالة عربية عامة.
      //
      // إن لم يعد image_picker يرمي PlatformException مستقبلاً عند الرفض
      // (يعتمد على نسخة الحزمة)، فسيُعامَل الأمر كإلغاء عادي (path == null)
      // دون أي عطل — فقط برسالة أقل تفصيلاً للمستخدم.
      if (kDebugMode) debugPrint('[ImageSourcePicker] $e');

      if (!context.mounted) return null;

      if (!Platform.isIOS) {
        _showGenericError(context, source == ImageSource.camera);
        return null;
      }

      final permission =
          source == ImageSource.camera ? Permission.camera : Permission.photos;
      final status = await permission.status;

      if (!context.mounted) return null;

      if (status.isPermanentlyDenied) {
        await _showOpenSettingsDialog(context, source == ImageSource.camera);
      } else {
        _showGenericError(context, source == ImageSource.camera);
      }

      return null;
    }
  }

  static void _showGenericError(BuildContext context, bool isCamera) {
    final t = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(
          isCamera ? t.cameraAccessFailedMessage : t.galleryAccessFailedMessage,
        ),
      ),
    );
  }

  static Future<void> _showOpenSettingsDialog(
    BuildContext context,
    bool isCamera,
  ) async {
    final t = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        icon: Icon(
          isCamera ? Icons.camera_alt_rounded : Icons.photo_library_rounded,
          color: AppColors.danger,
          size: 32,
        ),
        title: Text(
          isCamera ? t.cameraPermissionDeniedTitle : t.galleryPermissionDeniedTitle,
          textAlign: TextAlign.center,
        ),
        content: Text(
          isCamera ? t.cameraPermissionDeniedMessage : t.galleryPermissionDeniedMessage,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancelButton),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: Text(t.openAppSettingsButton),
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 34),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
