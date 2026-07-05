import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../models/request_model.dart';
import '../../requests/provider/requests_provider.dart';
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
    });
  }

  bool _isChatRequest(RequestModel request) {
    return request.status != 'بانتظار العروض' &&
        request.status != 'وصلت عروض' &&
        request.status != 'ملغي';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestsProvider>();
    final chats = provider.requests.where(_isChatRequest).toList();

    return Scaffold(
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: provider.loadRequests,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
              children: [
                _HeaderCard(count: chats.length),
                const SizedBox(height: 22),
                const SectionTitle(
                  title: 'المحادثات',
                  subtitle: 'كل محادثات الطلبات المقبولة في مكان واحد',
                ),
                const SizedBox(height: 14),
                if (provider.loading && chats.isEmpty)
                  const SizedBox(
                    height: 280,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (chats.isEmpty)
                  const _EmptyChats()
                else
                  ...chats.map((request) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ChatCard(
                        request: request,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomScreen(request: request),
                            ),
                          );
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

  const _HeaderCard({
    required this.count,
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
                'تواصل بأمان داخل التطبيق بدون مشاركة أرقام الهاتف.',
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
  final VoidCallback onTap;

  const _ChatCard({
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final location =
        '${request.city}${request.area == null || request.area!.isEmpty ? '' : ' - ${request.area}'}';

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      radius: 24,
      child: Row(
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.service,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
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
                  child: const Text(
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
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.textMuted,
            size: 17,
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
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'لا توجد محادثات حالياً',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
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