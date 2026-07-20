import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/notification_model.dart';

/// [NOTIF-FLUTTER-PHASE1] نتيجة صفحة واحدة من GET /api/notifications —
/// نفس شكل رد الخادم (items/pagination/unreadCount) بالضبط.
class NotificationsPage {
  final List<NotificationModel> items;
  final int page;
  final int limit;
  final int total;
  final int unreadCount;

  const NotificationsPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.unreadCount,
  });
}

/// [NOTIF-FLUTTER-PHASE1] طبقة الوصول لـ /api/notifications — نفس نمط
/// SupportApi (lib/features/support/data/support_api.dart) تماماً: تلف
/// ApiClient، وأي فشل يُحوَّل عبر apiClient.handleError ثم يُرمى مجدداً
/// حتى تتعامل معه طبقة الـProvider.
class NotificationsApi {
  final ApiClient apiClient;

  NotificationsApi(this.apiClient);

  Future<NotificationsPage> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiEndpoints.notifications,
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = Map<String, dynamic>.from(response.data);
      final pagination = Map<String, dynamic>.from(
        data['pagination'] as Map? ?? {},
      );

      return NotificationsPage(
        items: (data['items'] as List? ?? [])
            .map((e) =>
                NotificationModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page: int.tryParse('${pagination['page'] ?? page}') ?? page,
        limit: int.tryParse('${pagination['limit'] ?? limit}') ?? limit,
        total: int.tryParse('${pagination['total'] ?? 0}') ?? 0,
        unreadCount: int.tryParse('${data['unreadCount'] ?? 0}') ?? 0,
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<NotificationModel> markRead(int id) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.notificationRead(id),
      );
      final data = Map<String, dynamic>.from(response.data);
      return NotificationModel.fromJson(
        Map<String, dynamic>.from(data['notification']),
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// يرجع عدد الإشعارات التي تم تعليمها كمقروءة.
  Future<int> markAllRead() async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.notificationsReadAll,
      );
      final data = Map<String, dynamic>.from(response.data);
      return int.tryParse('${data['updated'] ?? 0}') ?? 0;
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }
}
