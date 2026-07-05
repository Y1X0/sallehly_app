import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/notification_model.dart';
import '../../../providers/notification_provider.dart';

class NotificationsScreen extends StatelessWidget {
  final VoidCallback? onOpenRequests;

  const NotificationsScreen({
    super.key,
    this.onOpenRequests,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final items = provider.requestItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          TextButton(
            onPressed: provider.markRequestNotificationsRead,
            child: const Text('قراءة الكل'),
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(
        child: Text(
          'لا توجد إشعارات طلبات حالياً',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _NotificationCard(
            item: items[index],
            onTap: () {
              provider.markRequestNotificationsRead();
              Navigator.pop(context);
              onOpenRequests?.call();
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = item.isOffer ? AppColors.success : AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.read
              ? AppColors.card
              : AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: item.read ? AppColors.border : AppColors.primary,
          ),
        ),
        child: Row(
          children: [
            Icon(
              item.isOffer
                  ? Icons.local_offer_rounded
                  : Icons.assignment_rounded,
              color: color,
              size: 32,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.read)
              const CircleAvatar(
                radius: 5,
                backgroundColor: AppColors.danger,
              ),
          ],
        ),
      ),
    );
  }
}