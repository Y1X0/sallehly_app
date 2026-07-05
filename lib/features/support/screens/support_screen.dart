import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
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
    final support = context.watch<SupportProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدعم الفني'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openNewTicket,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'تذكرة جديدة',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
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
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : support.tickets.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(28),
                          children: const [
                            SizedBox(height: 120),
                            Icon(
                              Icons.support_agent_rounded,
                              color: AppColors.primary,
                              size: 80,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'لا توجد تذاكر دعم بعد',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'اضغط "تذكرة جديدة" للتواصل مع فريق الدعم',
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

class _TicketCard extends StatelessWidget {
  final SupportTicketModel ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                const Icon(Icons.confirmation_number_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ticket.title,
                    style: const TextStyle(
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
                    ticket.isOpen ? 'مفتوحة' : 'مغلقة',
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
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ticket.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 15, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'فتح المحادثة',
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

    final support = context.read<SupportProvider>();

    try {
      await support.createTicket(
        type: type,
        title: titleController.text,
        body: bodyController.text,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.danger, content: Text(e.message)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('تعذر إنشاء التذكرة'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const Center(
              child: Text(
                'تذكرة دعم جديدة',
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
              decoration: const InputDecoration(
                labelText: 'نوع المشكلة',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (value) {
                setState(() => type = value ?? 'عام');
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (value) {
                final t = value?.trim() ?? '';
                if (t.length < 3) return 'أدخل عنواناً واضحاً';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: bodyController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'تفاصيل المشكلة',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                final b = value?.trim() ?? '';
                if (b.length < 10) return 'اكتب تفاصيل أوضح (10 أحرف على الأقل)';
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
                label: const Text('إرسال التذكرة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
