import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../requests/provider/requests_provider.dart';

/// نافذة منبثقة لتقديم شكوى على طلب (تذهب لإدارة المنصّة).
/// تُعيد true إذا تم الإرسال بنجاح.
class ComplaintSheet extends StatefulWidget {
  final int requestId;
  final String? technicianName;

  const ComplaintSheet({
    super.key,
    required this.requestId,
    this.technicianName,
  });

  @override
  State<ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends State<ComplaintSheet> {
  final bodyController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    bodyController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    final provider = context.read<RequestsProvider>();

    try {
      await provider.submitComplaint(
        requestId: widget.requestId,
        body: bodyController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الشكوى للإدارة، سيتم مراجعتها قريباً'),
        ),
      );

      Navigator.pop(context, true);
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر إرسال الشكوى');
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.danger, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<RequestsProvider>().loading;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(
                Icons.report_problem_rounded,
                color: AppColors.warning,
                size: 46,
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'تقديم شكوى',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                widget.technicianName != null
                    ? 'بخصوص الفني: ${widget.technicianName}'
                    : 'بخصوص هذا الطلب',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: bodyController,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'تفاصيل الشكوى',
                alignLabelWithHint: true,
                hintText: 'اشرح المشكلة التي واجهتها بوضوح...',
              ),
              validator: (value) {
                final b = value?.trim() ?? '';
                if (b.length < 10) {
                  return 'اكتب تفاصيل أوضح (10 أحرف على الأقل)';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'إرسال الشكوى',
              icon: Icons.send_rounded,
              loading: loading,
              onPressed: loading ? null : submit,
            ),
          ],
        ),
      ),
    );
  }
}
