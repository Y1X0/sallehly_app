import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../models/request_model.dart';
import '../../../providers/auth_provider.dart';
import '../../requests/provider/requests_provider.dart';
import '../../wallet/screens/packages_screen.dart';

class SendOfferScreen extends StatefulWidget {
  final RequestModel request;

  const SendOfferScreen({
    super.key,
    required this.request,
  });

  @override
  State<SendOfferScreen> createState() => _SendOfferScreenState();
}

class _SendOfferScreenState extends State<SendOfferScreen> {
  final formKey = GlobalKey<FormState>();

  final priceController = TextEditingController();
  final durationController = TextEditingController();
  final noteController = TextEditingController();

  @override
  void dispose() {
    priceController.dispose();
    durationController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    final provider = context.read<RequestsProvider>();

    try {
      await provider.sendOffer(
        requestId: widget.request.id,
        price: double.parse(priceController.text.trim()),
        duration: durationController.text.trim(),
        note: noteController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال العرض بنجاح'),
        ),
      );

      Navigator.pop(context);
      Navigator.pop(context);
    } on ApiException catch (e) {
      // [FIX-OFFERQUOTA-01] استُهلكت الفرصتان المجانيتان والرصيد غير كافٍ —
      // نوجّه الفني مباشرة لشاشة شراء الباقات بدل رسالة خطأ عامة لا يعرف
      // بعدها ماذا يفعل.
      if (e.code == 'INSUFFICIENT_BALANCE') {
        showInsufficientBalanceDialog(e.message);
      } else {
        showError(e.message);
      }
    } catch (_) {
      showError('تعذر إرسال العرض');
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(message),
      ),
    );
  }

  Future<void> showInsufficientBalanceDialog(String message) async {
    if (!mounted) return;

    final shouldTopUp = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('استُهلكت فرصتاك المجانيتان'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('شحن الرصيد'),
          ),
        ],
      ),
    );

    if (shouldTopUp == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PackagesScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<RequestsProvider>().loading;
    final freeOffersRemaining =
        context.watch<AuthProvider>().user?.freeOffersRemaining ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('تقديم عرض'),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 66, 22, 22),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                Icon(
                  Icons.local_offer_rounded,
                  color: AppColors.primary,
                  size: 76,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.request.service,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.request.city} - ${widget.request.area ?? ''}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                // [FIX-OFFERQUOTA-01] عدد الفرص المجانية المتبقية — مرئي دائماً
                // قبل الإرسال بدل مفاجأة الفني برفض 402 بلا سياق مسبق.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: (freeOffersRemaining > 0 ? AppColors.primary : AppColors.danger)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    freeOffersRemaining > 0
                        ? 'لديك $freeOffersRemaining من العروض المجانية متبقية'
                        : 'استُهلكت فرصتاك المجانيتان — هذا العرض يحتاج رصيداً كافياً',
                    style: TextStyle(
                      color: freeOffersRemaining > 0 ? AppColors.primary : AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'السعر بالدينار',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final price = double.tryParse(value ?? '');

                    if (price == null || price < 1) {
                      return 'أدخل سعر صحيح';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'مدة الوصول أو التنفيذ',
                    prefixIcon: Icon(Icons.access_time),
                    hintText: 'مثلاً: خلال ساعة',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'أدخل مدة الوصول أو التنفيذ';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة اختيارية',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const CircularProgressIndicator(
                    color: Colors.black,
                  )
                      : const Text(
                    'إرسال العرض',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}