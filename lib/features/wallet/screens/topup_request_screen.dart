import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/widgets/image_source_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/pressable.dart';
import '../../../models/package_model.dart';
import '../provider/wallet_provider.dart';

class TopupRequestScreen extends StatefulWidget {
  final PackageModel package;

  const TopupRequestScreen({
    super.key,
    required this.package,
  });

  @override
  State<TopupRequestScreen> createState() => _TopupRequestScreenState();
}

class _TopupRequestScreenState extends State<TopupRequestScreen> {
  String? receiptPath;

  Future<void> pickReceipt() async {
    final path = await ImageSourcePicker.pick(
      context,
      imageQuality: 80,
      maxWidth: 1400,
    );

    if (path == null) return;

    setState(() {
      receiptPath = path;
    });
  }

  Future<void> submit() async {
    if (receiptPath == null || receiptPath!.isEmpty) {
      showError('ارفع صورة إثبات الدفع أولاً');
      return;
    }

    final wallet = context.read<WalletProvider>();

    try {
      await wallet.submitTopup(
        packageId: widget.package.id,
        receiptPath: receiptPath!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب الشحن بنجاح، بانتظار مراجعة الإدارة'),
        ),
      );

      Navigator.pop(context);
      Navigator.pop(context);
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر إرسال طلب الشحن');
    }
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final method = wallet.firstPaymentMethod;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'طلب شحن رصيد',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 66, 20, 20),
            children: [
          _SelectedPackageCard(package: widget.package),
          const SizedBox(height: 16),
          if (method != null)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'معلومات التحويل',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InfoLine(title: 'البنك', value: method.bankName),
                  _InfoLine(title: 'اسم الحساب', value: method.accountName),
                  _InfoLine(title: 'رقم الحساب', value: method.accountNumber),
                  _InfoLine(title: 'هاتف', value: method.phone),
                  if (method.instructions != null &&
                      method.instructions!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      method.instructions!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          Pressable(
            onTap: wallet.submitting ? null : pickReceipt,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: receiptPath == null
                      ? AppColors.border
                      : AppColors.primary,
                ),
              ),
              child: receiptPath == null
                  ? Column(
                children: [
                  Icon(
                    Icons.upload_file_rounded,
                    color: AppColors.primary,
                    size: 56,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'ارفع صورة إثبات الدفع',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'صورة الوصل مطلوبة لمراجعة طلب الشحن',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  File(receiptPath!),
                  // [RESPONSIVE-02] نفس المبدأ الموثّق بـ create_request_screen.dart —
                  // ارتفاع متناسب مع عرض الشاشة بدل قيمة ثابتة، بدون تغيير على
                  // الهواتف العادية (العرض المرجعي 390).
                  height: MediaQuery.of(context).size.width * (220 / 390),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: wallet.submitting ? null : submit,
            child: wallet.submitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
              'إرسال طلب الشحن',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

class _SelectedPackageCard extends StatelessWidget {
  final PackageModel package;

  const _SelectedPackageCard({required this.package});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 14),
          Text(
            package.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قيمة الدفع: ${package.amount.toStringAsFixed(2)} د.أ',
            style: const TextStyle(color: Colors.white),
          ),
          if (package.bonus > 0) ...[
            const SizedBox(height: 5),
            Text(
              'بونص: ${package.bonus.toStringAsFixed(2)} د.أ',
              style: const TextStyle(color: Colors.white),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'الرصيد بعد الموافقة: ${package.total.toStringAsFixed(2)} د.أ',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String title;
  final String value;

  const _InfoLine({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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