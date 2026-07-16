import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../models/chat_summary_model.dart';
import '../../../models/request_model.dart';
import '../../requests/provider/requests_provider.dart';
import '../provider/chat_provider.dart';
import 'chat_room_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      context.read<RequestsProvider>().loadRequests();
      context.read<ChatProvider>().loadChats();
    });
  }

  bool _isChatRequest(RequestModel request) {
    return request.status != 'بانتظار العروض' &&
        request.status != 'وصلت عروض' &&
        request.status != 'ملغي';
  }

  Future<void> _refresh(BuildContext context) async {
    await Future.wait([
      context.read<RequestsProvider>().loadRequests(),
      context.read<ChatProvider>().loadChats(),
    ]);
  }

  /// [FIX-CHATUNREAD-01] يرتّب المحادثات حسب آخر رسالة (الأحدث أولاً)، مثل
  /// أي تطبيق مراسلة — بدل ترتيب الطلبات الافتراضي غير المرتبط بالمحادثة.
  List<RequestModel> _sortByLastMessage(
    List<RequestModel> requests,
    Map<int, ChatSummaryModel> summaries,
  ) {
    final sorted = [...requests];
    sorted.sort((a, b) {
      final aTime = summaries[a.id]?.lastAt ?? a.createdAt;
      final bTime = summaries[b.id]?.lastAt ?? b.createdAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestsProvider>();
    final chatProvider = context.watch<ChatProvider>();

    final summaries = {
      for (final c in chatProvider.chats) c.requestId: c,
    };

    final chats = _sortByLastMessage(
      provider.requests.where(_isChatRequest).toList(),
      summaries,
    );

    return Scaffold(
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _refresh(context),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
              children: [
                _HeaderCard(count: chats.length, totalUnread: chatProvider.totalUnread),
                const SizedBox(height: 22),
                const SectionTitle(
                  title: 'المحادثات',
                  subtitle: 'كل محادثات الطلبات المقبولة في مكان واحد',
                ),
                const SizedBox(height: 14),
                if (provider.loading && chats.isEmpty)
                  SizedBox(
                    height: 280,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (provider.error != null && chats.isEmpty)
                  _ChatsErrorState(
                    message: provider.error!,
                    onRetry: provider.loadRequests,
                  )
                else if (chats.isEmpty)
                  const _EmptyChats()
                else
                  ...chats.map((request) {
                    final summary = summaries[request.id];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ChatCard(
                        request: request,
                        summary: summary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomScreen(request: request),
                            ),
                          ).then((_) {
                            // [FIX-CHATUNREAD-01] غادر المستخدم غرفة المحادثة
                            // (فُتحت الرسائل وتم تعليمها كمقروءة بالسيرفر) —
                            // حدّث القائمة فوراً لتصفير شارتها هنا أيضاً، دون
                            // الانتظار لحدث سوكت قد يتأخر أو يُفقد.
                            if (context.mounted) {
                              context.read<ChatProvider>().loadChats(silent: true);
                            }
                          });
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int count;
  final int totalUnread;

  const _HeaderCard({
    required this.count,
    this.totalUnread = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 30,
      gradient: AppColors.primaryGradient,
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Positioned(
            left: -24,
            top: -30,
            child: Icon(
              Icons.forum_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.chat_rounded,
                color: Colors.white,
                size: 38,
              ),
              const SizedBox(height: 18),
              Text(
                count == 0 ? 'لا توجد محادثات' : '$count محادثة نشطة',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                totalUnread > 0
                    ? 'لديك $totalUnread رسالة غير مقروءة'
                    : 'تواصل بأمان داخل التطبيق بدون مشاركة أرقام الهاتف.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final RequestModel request;
  final ChatSummaryModel? summary;
  final VoidCallback onTap;

  const _ChatCard({
    required this.request,
    required this.onTap,
    this.summary,
  });

  /// [FIX-CHATUNREAD-01] معاينة آخر رسالة — تحوّل حمولات الصورة/الصوت/الموقع
  /// الداخلية إلى نص عربي مفهوم بدل عرض الرابط الخام.
  String _previewText(String? lastBody) {
    final body = (lastBody ?? '').trim();
    if (body.isEmpty) return 'ابدأ المحادثة الآن';
    if (body.startsWith('[image]')) return '📷 صورة';
    if (body.startsWith('[audio]')) return '🎤 رسالة صوتية${_audioDurationSuffix(body)}';
    if (body.startsWith('[location]')) return '📍 موقع';
    return body;
  }

  /// [FIX-AUDIODUR-01] '[audio]url|42' → ' (00:42)'؛ بلا لاحقة إن كانت الرسالة
  /// قديمة أو المدة غير مخزَّنة.
  String _audioDurationSuffix(String body) {
    final pipeIndex = body.indexOf('|');
    if (pipeIndex == -1) return '';
    final seconds = int.tryParse(body.substring(pipeIndex + 1));
    if (seconds == null || seconds <= 0) return '';
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return ' ($minutes:$secs)';
  }

  String _formatTime(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
    if (sameDay) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final location =
        '${request.city}${request.area == null || request.area!.isEmpty ? '' : ' - ${request.area}'}';
    final unreadCount = summary?.unreadCount ?? 0;
    final hasUnread = unreadCount > 0;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      radius: 24,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.handyman_rounded,
                  color: Colors.white,
                ),
              ),
              if (hasUnread)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 20),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        request.service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (summary?.lastAt != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(summary?.lastAt),
                        style: TextStyle(
                          color: hasUnread ? AppColors.primary : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: hasUnread ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _previewText(summary?.lastBody),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: hasUnread ? FontWeight.w800 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Text(
                    'محادثة آمنة',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.textMuted,
            size: 17,
          ),
        ],
      ),
    );
  }
}

class _ChatsErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ChatsErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'تعذّر تحميل المحادثات',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد محادثات حالياً',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'بعد قبول عرض أو بدء طلب، ستظهر المحادثة هنا.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}