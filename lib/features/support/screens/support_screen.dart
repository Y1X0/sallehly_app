import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/bidi_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/support_ticket_model.dart';
import '../provider/support_provider.dart';
import 'support_chat_screen.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<SupportProvider>().loadMyTickets();
    });
  }

  Future<void> openNewTicket() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _NewTicketSheet(),
    );

    if (created == true && mounted) {
      context.read<SupportProvider>().loadMyTickets();
    }
  }

  void openTicket(SupportTicketModel ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportChatScreen(ticket: ticket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final support = context.watch<SupportProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(t.supportScreenTitle),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openNewTicket,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          t.newTicketButton,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 50),
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: support.loadMyTickets,
              child: support.loading && support.tickets.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : support.error != null && support.tickets.isEmpty
                      ? _SupportErrorState(
                          message: support.error!,
                          onRetry: support.loadMyTickets,
                        )
                      : support.tickets.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(28),
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Icon(
                                  Icons.support_agent_rounded,
                                  color: AppColors.primary,
                                  size: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              t.noSupportTicketsYetTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t.noSupportTicketsYetSubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          itemCount: support.tickets.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final ticket = support.tickets[index];
                            return _TicketCard(
                              ticket: ticket,
                              onTap: () => openTicket(ticket),
                            );
                          },
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _SupportErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t.adminSupportLoadFailedTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(t.retryButton),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicketModel ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final color = ticket.isOpen ? AppColors.primary : AppColors.success;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.confirmation_number_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: BidiText(
                    ticket.title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    ticket.isOpen ? t.adminSupportTicketOpenLabel : t.adminSupportTicketClosedLabel,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket.type,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            BidiText(
              ticket.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  t.openChatLabel,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet();

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  // [L10N-TODO] قيمة سلكية تُرسَل للخادم كما هي (SupportTicketModel.type)،
  // بنفس نمط RequestModel.status المؤجَّل لـPhase 3 — النص المعروض هنا هو
  // نفسه القيمة المخزَّنة، فلا يمكن ترجمة العرض بمعزل عن القيمة بدون تنسيق
  // مع الخادم. غير مُترجَم عمداً، لا تغيير وظيفي.
  String type = 'عام';

  static const types = [
    'عام',
    'مشكلة طلب',
    'مشكلة حساب',
    'مشكلة دفع أو رصيد',
    'مشكلة في الموقع',
    'اقتراح تحسين',
  ];

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    final t = AppLocalizations.of(context)!;
    final support = context.read<SupportProvider>();
    // [SEC-FIX-CTXAWAIT-01] راجع DECISIONS.md — ScaffoldMessenger.of(context)
    // كانت تُستدعى خام بعد await بلا أي فحص mounted (الفرق عن نجاح الإرسال
    // أعلاه، المحمي بـif(!mounted) بالفعل). التقاطه هنا أيضاً، قبل الـawait،
    // يجعل استخدامه لاحقاً آمناً بغضّ النظر عن حالة تثبيت الودجت وقتها.
    final messenger = ScaffoldMessenger.of(context);

    try {
      await support.createTicket(
        type: type,
        title: titleController.text,
        body: bodyController.text,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(backgroundColor: AppColors.danger, content: Text(e.message)),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(t.ticketCreateFailedMessage),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final sending = context.watch<SupportProvider>().sending;

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
            Center(
              child: Text(
                t.newSupportTicketTitle,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: type,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t.issueTypeFieldLabel,
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              items: types
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) {
                setState(() => type = value ?? 'عام');
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: t.titleFieldLabel,
                prefixIcon: const Icon(Icons.title_rounded),
              ),
              validator: (value) {
                final title = value?.trim() ?? '';
                if (title.length < 3) return t.titleRequiredValidation;
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: bodyController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: t.issueDetailsFieldLabel,
                alignLabelWithHint: true,
              ),
              validator: (value) {
                final b = value?.trim() ?? '';
                if (b.length < 10) return t.complaintSheetBodyValidationError;
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: sending ? null : submit,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(t.submitTicketButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
