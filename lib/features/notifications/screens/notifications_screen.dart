import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('الإشعارات'),
        actions: [
          TextButton(
            onPressed: provider.markRequestNotificationsRead,
            child: const Text('قراءة الكل'),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 50),
            child: items.isEmpty
                ? const _EmptyNotifications()
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              itemCount: items.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _NotificationCard(
                  item: items[index],
                  onTap: () {
                    // اقرأ الإشعار المضغوط فقط، وليس كل الإشعارات.
                    provider.markNotificationRead(items[index].id);

                    // أغلق شاشة الإشعارات ثم افتح القسم المرتبط بالطلب.
                    Navigator.pop(context);
                    onOpenRequests?.call();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'لا توجد إشعارات حالياً',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ستصلك هنا آخر التحديثات على طلباتك وعروضك',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
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
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.body,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.read)
              CircleAvatar(
                radius: 5,
                backgroundColor: AppColors.danger,
              ),
          ],
        ),
      ),
    );
  }
}