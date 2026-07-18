import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/socket/socket_events.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../models/support_message_model.dart';
import '../../../models/support_ticket_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/socket_provider.dart';
import '../../support/provider/support_provider.dart';

/// شاشة محادثة الدعم من جهة الأدمن: يقرأ رسائل التذكرة ويرد على
/// الفني/العميل مباشرة، ويمكنه إغلاق التذكرة.
class AdminSupportChatScreen extends StatefulWidget {
  final SupportTicketModel ticket;
  final Future<void> Function()? onToggleStatus;

  const AdminSupportChatScreen({
    super.key,
    required this.ticket,
    this.onToggleStatus,
  });

  @override
  State<AdminSupportChatScreen> createState() => _AdminSupportChatScreenState();
}

class _AdminSupportChatScreenState extends State<AdminSupportChatScreen> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();

  SocketProvider? _socketProvider;
  // مرجع مستمع السوكت الخاص بهذه الشاشة (لإزالته وحده عند الخروج).
  Function(dynamic)? _supportListener;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<SupportProvider>().loadMessages(widget.ticket.id);

      // [REALTIME] استمع لرسائل الدعم لحظياً: عند وصول رسالة لنفس التذكرة،
      // أعِد تحميل الرسائل وانزل لأسفل تلقائياً.
      _socketProvider = context.read<SocketProvider>();
      _supportListener = (data) async {
        if (!mounted) return;
        final ticketId = int.tryParse('${data?['ticketId'] ?? 0}') ?? 0;
        if (ticketId != widget.ticket.id) return;
        await context
            .read<SupportProvider>()
            .loadMessages(widget.ticket.id, silent: true);
        if (!mounted) return;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => scrollToBottom());
      };

      _socketProvider!.socketService.on(
        SocketEvents.supportMessage,
        _supportListener!,
      );
    });
  }

  @override
  void dispose() {
    // أزل مستمع هذه الشاشة فقط (لا تمسح المستمع العام للإشعارات).
    if (_supportListener != null) {
      _socketProvider?.socketService
          .off(SocketEvents.supportMessage, _supportListener);
    }
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void scrollToBottom() {
    if (!scrollController.hasClients) return;
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> send() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    final support = context.read<SupportProvider>();

    try {
      messageController.clear();
      await support.sendMessage(ticketId: widget.ticket.id, body: text);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر إرسال الرسالة');
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.danger, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final support = context.watch<SupportProvider>();
    final currentUserId = context.watch<AuthProvider>().user?.id ?? 0;
    final isOpen = widget.ticket.isOpen;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ticket.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
        actions: [
          if (widget.onToggleStatus != null)
            TextButton.icon(
              onPressed: () async {
                await widget.onToggleStatus!.call();
                if (mounted) Navigator.pop(context);
              },
              icon: Icon(
                isOpen ? Icons.check_circle_outline : Icons.lock_open_rounded,
                color: isOpen ? AppColors.success : AppColors.primary,
                size: 20,
              ),
              label: Text(
                isOpen ? 'إغلاق' : 'إعادة فتح',
                style: TextStyle(
                  color: isOpen ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 50),
              Expanded(
                child: support.loading && support.messages.isEmpty
                    ? Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      )
                    : support.error != null && support.messages.isEmpty
                    ? _errorState(support.error!, () => context
                        .read<SupportProvider>()
                        .loadMessages(widget.ticket.id))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: support.messages.length,
                        itemBuilder: (context, index) {
                          final msg = support.messages[index];
                          final isMine = msg.senderId == currentUserId;
                          return _Bubble(message: msg, isMine: isMine);
                        },
                      ),
              ),
              _inputBar(support.sending),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState(String message, Future<void> Function() onRetry) {
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
            child: Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'تعذّر تحميل الرسائل',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _inputBar(bool sending) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'اكتب رداً...',
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: sending ? null : send,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final SupportMessageModel message;
  final bool isMine;

  const _Bubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: isMine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName ?? 'المستخدم',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                color: isMine ? Colors.white : AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
