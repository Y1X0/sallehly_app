import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/bidi_text.dart';
import '../../../core/utils/currency_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/request_model.dart';
import '../../../providers/auth_provider.dart';
import '../../requests/provider/requests_provider.dart';
import '../../wallet/screens/packages_screen.dart';
import '../../../core/widgets/success_feedback.dart';

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

    final t = AppLocalizations.of(context)!;
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
        SnackBar(
          content: Text(t.offerSentSuccessMessage),
        ),
      );

      Navigator.pop(context);
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      // [FIX-OFFERQUOTA-01] استُهلكت الفرصتان المجانيتان والرصيد غير كافٍ —
      // نوجّه الفني مباشرة لشاشة شراء الباقات بدل رسالة خطأ عامة لا يعرف
      // بعدها ماذا يفعل.
      if (e.code == 'INSUFFICIENT_BALANCE') {
        showInsufficientBalanceDialog(e.message);
      } else {
        showErrorSnackBar(context, e.message);
      }
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.offerSendFailedMessage);
    }
  }

  Future<void> showInsufficientBalanceDialog(String message) async {
    if (!mounted) return;

    final t = AppLocalizations.of(context)!;
    final shouldTopUp = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.freeOffersExhaustedTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.laterButton),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.walletTopupActionTitle),
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
    final t = AppLocalizations.of(context)!;
    final loading = context.watch<RequestsProvider>().loading;
    final user = context.watch<AuthProvider>().user;
    final freeOffersRemaining = user?.freeOffersRemaining ?? 0;

    // [FIX-OFFERBALANCE-01] كانت هذه الشاشة تُظهر تحذيراً مخيفاً ("يحتاج
    // رصيداً كافياً") بمجرد انتهاء الفرصتين المجانيتين، بغضّ النظر عن الرصيد
    // الفعلي — فني رصيده 12 د.أ والعمولة المطلوبة 2 د.أ فقط كان يرى تحذيراً
    // مضلِّلاً رغم أن العرض سينجح فعلياً (والسيرفر يسمح به بحق، فرصيده كافٍ).
    // الآن نقارن الرصيد الحقيقي بالعمولة المطلوبة فعلياً، ونمنع الإرسال محلياً
    // (زر معطَّل + رسالة واحدة واضحة) فقط عندما يكون الرصيد فعلاً غير كافٍ،
    // بدل الاعتماد فقط على رفض السيرفر 402 بعد محاولة إرسال فعلية.
    // [FEAT-DEDUP-01] راجع DECISIONS.md — activeCommission قابلة لـnull الآن
    // (لا تخمين برقم قد لا يطابق العمولة الحقيقية لباقة هذا الفني). القيمة
    // غير معروفة محلياً لا تعني "امنع الإرسال" — الخادم هو الحكم الفعلي عند
    // محاولة الإرسال (نفس فلسفة رفض 402 المذكورة بالتعليق أعلاه، لهذه الحالة
    // تحديداً بدل الحالة العامة). لا نعرض رقماً مخموناً بالرسالة أيضاً.
    final requiredCommission = user?.activeCommission;
    final balance = user?.balance ?? 0;
    final hasSufficientBalance = freeOffersRemaining > 0 ||
        requiredCommission == null ||
        balance >= requiredCommission;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(t.submitOfferTitle),
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
                BidiText(
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
                    color: (hasSufficientBalance ? AppColors.primary : AppColors.danger)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    freeOffersRemaining > 0
                        ? t.freeOffersRemainingCount(freeOffersRemaining)
                        : requiredCommission == null
                            ? t.commissionUnknownMessage
                            : hasSufficientBalance
                                ? t.commissionWillBeDeductedMessage(formatJod(context, requiredCommission))
                                : t.insufficientBalanceMessage(
                                    formatJod(context, balance),
                                    formatJod(context, requiredCommission),
                                  ),
                    style: TextStyle(
                      color: hasSufficientBalance ? AppColors.primary : AppColors.danger,
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
                  decoration: InputDecoration(
                    labelText: t.priceFieldLabel,
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final price = double.tryParse(value ?? '');

                    if (price == null || price < 1) {
                      return t.validPriceValidation;
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: durationController,
                  decoration: InputDecoration(
                    labelText: t.durationFieldLabel,
                    prefixIcon: const Icon(Icons.access_time),
                    hintText: t.durationFieldHint,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return t.durationRequiredValidation;
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: t.optionalNoteLabel,
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (loading || !hasSufficientBalance) ? null : submit,
                  child: loading
                      ? const CircularProgressIndicator(
                    color: Colors.white,
                  )
                      : Text(
                    hasSufficientBalance ? t.submitOfferButton : t.insufficientBalanceButton,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!hasSufficientBalance) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PackagesScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: Text(t.walletTopupActionTitle),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}