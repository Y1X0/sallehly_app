import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/notification_provider.dart';
import '../screens/notifications_screen.dart';

class NotificationBell extends StatelessWidget {
  final VoidCallback? onOpenRequests;

  const NotificationBell({
    super.key,
    this.onOpenRequests,
  });

  @override
  Widget build(BuildContext context) {
    final count = context.watch<NotificationProvider>().unreadNotificationsCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'الإشعارات',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(
                  onOpenRequests: onOpenRequests,
                ),
              ),
            );
          },
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}