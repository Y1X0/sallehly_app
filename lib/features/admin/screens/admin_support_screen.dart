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

    return Scaffold(
      appBar: AppBar(
        title: const Text('تذاكر الدعم'),
      ),
      body: RefreshIndicator(
        onRefresh: admin.loadSupport,
        child: admin.loading && tickets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : admin.error != null && tickets.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 180),
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 70,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          admin.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
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
                    children: const [
                      SizedBox(height: 200),
                      Center(
                        child: Text(
                          'لا توجد تذاكر دعم حالياً',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOpen
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
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
                      fontWeight: FontWeight.bold,
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
                        ? Colors.green.withValues(alpha: 0.18)
                        : Colors.grey.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOpen ? 'مفتوحة' : 'مغلقة',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOpen ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
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
                color: Colors.white.withValues(alpha: 0.7),
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
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${ticket.userName ?? 'مستخدم'} · ${ticket.type}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.55),
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
