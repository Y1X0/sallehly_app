import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/support_ticket_model.dart';
import '../provider/admin_provider.dart';
import 'admin_support_chat_screen.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminProvider>().loadSupport();
    });
  }

  Future<void> _toggleStatus(SupportTicketModel ticket) async {
    final newStatus = ticket.isOpen ? 'closed' : 'open';

    try {
      await context.read<AdminProvider>().updateSupportStatus(
            ticketId: ticket.id,
            status: newStatus,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'closed' ? 'تم إغلاق التذكرة' : 'تم إعادة فتح التذكرة',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث التذكرة')),
      );
    }
  }

  void _openChat(SupportTicketModel ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminSupportChatScreen(
          ticket: ticket,
          onToggleStatus: () => _toggleStatus(ticket),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final tickets = admin.tickets;

    // [FIX-DUPLICATE-APPBAR-01] نفس السبب الموثّق بـ admin_dashboard_screen.dart
    // — إزالة الـ Scaffold/AppBar الداخلي المكرر فوق ذاك الموجود بـ AdminLayout.
    return RefreshIndicator(
        onRefresh: admin.loadSupport,
        child: admin.loading && tickets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : admin.error != null && tickets.isEmpty
                ? ListView(
                    padding: const EdgeInsets.only(bottom: 110),
                    children: [
                      const SizedBox(height: 180),
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
                            size: 40,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'تعذّر تحميل تذاكر الدعم',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          admin.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton.icon(
                          onPressed: admin.loadSupport,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary),
                        ),
                      ),
                    ],
                  )
                : tickets.isEmpty
                ? ListView(
                    padding: const EdgeInsets.only(bottom: 110),
                    children: [
                      const SizedBox(height: 200),
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
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'لا توجد تذاكر دعم حالياً',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
                    itemCount: tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final ticket = tickets[index];
                      return _TicketCard(
                        ticket: ticket,
                        onTap: () => _openChat(ticket),
                        onToggle: () => _toggleStatus(ticket),
                      );
                    },
                  ),
      );
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicketModel ticket;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _TicketCard({
    required this.ticket,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = ticket.isOpen;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isOpen
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.title.isEmpty ? 'تذكرة دعم' : ticket.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? AppColors.success.withValues(alpha: 0.18)
                        : AppColors.textSecondary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOpen ? 'مفتوحة' : 'مغلقة',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOpen ? AppColors.success : AppColors.textSecondary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ticket.body,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${ticket.userName ?? 'مستخدم'} · ${ticket.type}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: onToggle,
                  child: Text(isOpen ? 'إغلاق' : 'إعادة فتح'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
