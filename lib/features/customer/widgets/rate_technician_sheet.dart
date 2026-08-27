import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../requests/provider/requests_provider.dart';

/// نافذة منبثقة لتقييم الفني بعد إكمال الطلب (1–5 نجوم + تعليق اختياري).
/// تُعيد true إذا تم إرسال التقييم بنجاح.
class RateTechnicianSheet extends StatefulWidget {
  final int requestId;
  final String? technicianName;

  const RateTechnicianSheet({
    super.key,
    required this.requestId,
    this.technicianName,
  });

  @override
  State<RateTechnicianSheet> createState() => _RateTechnicianSheetState();
}

class _RateTechnicianSheetState extends State<RateTechnicianSheet> {
  int stars = 0;
  final commentController = TextEditingController();

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  String get _hintForStars {
    final t = AppLocalizations.of(context)!;
    switch (stars) {
      case 1:
        return t.rating1StarHint;
      case 2:
        return t.rating2StarsHint;
      case 3:
        return t.rating3StarsHint;
      case 4:
        return t.rating4StarsHint;
      case 5:
        return t.rating5StarsHint;
      default:
        return t.tapStarsToRateHint;
    }
  }

  Future<void> submit() async {
    final t = AppLocalizations.of(context)!;

    if (stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          content: Text(t.selectStarsFirstMessage),
        ),
      );
      return;
    }

    final provider = context.read<RequestsProvider>();

    try {
      await provider.rateRequest(
        requestId: widget.requestId,
        rating: stars,
        comment: commentController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.ratingThankYouMessage)),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.danger, content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(t.ratingSubmitFailedMessage),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final loading = context.watch<RequestsProvider>().loading;

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 26,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            t.rateTechnicianTitle,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.technicianName != null
                ? t.rateTechnicianNamedSubtitle(widget.technicianName!)
                : t.rateTechnicianGenericSubtitle,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final value = index + 1;
              final active = value <= stars;
              return GestureDetector(
                onTap: () => setState(() => stars = value),
                child: AnimatedScale(
                  scale: active ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      active ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 44,
                      color: active ? AppColors.warning : AppColors.textMuted,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            _hintForStars,
            style: TextStyle(
              color: stars == 0 ? AppColors.textMuted : AppColors.warning,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: commentController,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: t.ratingCommentHint,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          GradientButton(
            label: t.submitRatingButton,
            icon: Icons.send_rounded,
            loading: loading,
            onPressed: loading ? null : submit,
          ),
        ],
      ),
    );
  }
}
