import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool recording;
  final int recordingSeconds;
  final VoidCallback onSend;
  final VoidCallback onLocation;
  final VoidCallback onRecord;
  final VoidCallback onImage;

  const ChatInput({
    super.key,
    required this.controller,
    required this.sending,
    required this.recording,
    required this.recordingSeconds,
    required this.onSend,
    required this.onLocation,
    required this.onRecord,
    required this.onImage,
  });

  String get durationText {
    final m = (recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (recordingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void openPlusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SheetAction(
                  icon: Icons.image_rounded,
                  label: 'صورة',
                  color: AppColors.secondary,
                  onTap: () {
                    Navigator.pop(context);
                    onImage();
                  },
                ),
                _SheetAction(
                  icon: Icons.location_on_rounded,
                  label: 'موقع',
                  color: AppColors.success,
                  onTap: () {
                    Navigator.pop(context);
                    onLocation();
                  },
                ),
                _SheetAction(
                  icon:
                  recording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                  label: recording ? 'إيقاف' : 'صوت',
                  color: recording ? AppColors.danger : AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    onRecord();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'إضافة مرفق',
              onPressed: sending ? null : () => openPlusMenu(context),
              icon: Icon(
                Icons.add_circle_rounded,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: recording
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 13)
                    : EdgeInsets.zero,
                decoration: recording
                    ? BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.35),
                  ),
                )
                    : null,
                child: recording
                    ? Row(
                  children: [
                    Icon(
                      Icons.mic_rounded,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      durationText,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'جاري التسجيل...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
                    : TextField(
                  controller: controller,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالة...',
                    filled: true,
                    fillColor: AppColors.card,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: recording
                    ? LinearGradient(
                  colors: [AppColors.danger, AppColors.warning],
                )
                    : AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: recording ? 'إيقاف التسجيل وإرسال' : 'إرسال',
                onPressed: sending ? null : (recording ? onRecord : onSend),
                icon: sending
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(
                  recording ? Icons.stop_rounded : Icons.send_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}