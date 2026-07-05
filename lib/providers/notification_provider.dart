import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/notification_model.dart';
import '../models/user_model.dart';

class NotificationProvider extends ChangeNotifier {
  UserModel? currentUser;

  final List<NotificationModel> _items = [];

  List<NotificationModel> get items => List.unmodifiable(_items);

  List<NotificationModel> get requestItems {
    return _items.where((e) => !e.isChat).toList();
  }

  int get requestUnreadCount {
    return _items.where((e) => !e.read && !e.isChat && !e.isSupport).length;
  }

  int get chatUnreadCount {
    return _items.where((e) => !e.read && e.isChat).length;
  }

  /// عدد رسائل الدعم غير المقروءة (تظهر كرقم على أيقونة الدعم).
  int get supportUnreadCount {
    return _items.where((e) => !e.read && e.isSupport).length;
  }

  void setCurrentUser(UserModel? user) {
    currentUser = user;
    notifyListeners();
  }

  void addNotification({
    required String title,
    required String body,
    required String type,
    int? requestId,
    bool sound = true,
  }) {
    _items.insert(
      0,
      NotificationModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: body,
        type: type,
        requestId: requestId,
        createdAt: DateTime.now(),
      ),
    );

    if (_items.length > 80) {
      _items.removeRange(80, _items.length);
    }

    if (sound) {
      SystemSound.play(SystemSoundType.alert);
    }

    notifyListeners();
  }

  void handleNewRequest(dynamic data) {
    final user = currentUser;
    if (user == null) return;
    if (!user.isTechnician && !user.isAdmin) return;

    final request = data?['request'];
    final requestId = int.tryParse('${request?['id'] ?? 0}') ?? 0;
    final service = '${request?['service'] ?? 'طلب جديد'}';
    final city = '${request?['city'] ?? ''}';

    addNotification(
      title: user.isAdmin ? 'طلب جديد على المنصة' : 'طلب جديد قريب منك',
      body: '$service ${city.isEmpty ? '' : 'في $city'}',
      type: 'request',
      requestId: requestId,
    );
  }

  void handleOfferCreated(dynamic data) {
    final user = currentUser;
    if (user == null) return;
    if (!user.isCustomer && !user.isAdmin) return;

    final requestId = int.tryParse('${data?['requestId'] ?? 0}') ?? 0;

    addNotification(
      title: user.isAdmin ? 'عرض جديد على طلب' : 'تم تقديم عرض جديد',
      body: user.isAdmin
          ? 'فني أرسل عرضاً على طلب رقم $requestId'
          : 'افتح طلبك لمشاهدة عرض الفني',
      type: 'offer',
      requestId: requestId,
    );
  }

  void handleRequestStatus(dynamic data) {
    final request = data?['request'];
    final requestId = int.tryParse('${request?['id'] ?? 0}') ?? 0;
    final status = '${request?['status'] ?? ''}';

    if (status.isEmpty) return;

    addNotification(
      title: 'تحديث على الطلب',
      body: 'حالة الطلب أصبحت: $status',
      type: 'request',
      requestId: requestId,
    );
  }

  /// رقم الطلب المفتوح حالياً في شاشة الدردشة (لمنع إشعار وأنت داخل الغرفة).
  int? activeChatRequestId;

  void setActiveChat(int? requestId) {
    activeChatRequestId = requestId;
  }

  void handleChatNotify(dynamic data) {
    final user = currentUser;
    if (user == null) return;

    final senderId = int.tryParse('${data?['senderId'] ?? 0}') ?? -1;

    // لا تُشعر المُرسِل نفسه إطلاقاً.
    if (senderId == user.id) return;

    final requestId = int.tryParse('${data?['requestId'] ?? 0}') ?? 0;

    // إذا كنت فاتح نفس المحادثة، لا داعي لإشعار — الرسالة ظاهرة أمامك.
    if (requestId != 0 && requestId == activeChatRequestId) return;

    addNotification(
      title: 'رسالة جديدة',
      body: 'وصلتك رسالة جديدة',
      type: 'chat',
      requestId: requestId,
    );
  }

  void handleBalanceUpdated(dynamic data) {
    final status = '${data?['status'] ?? ''}';
    if (status == 'approved') {
      addNotification(
        title: 'تمت الموافقة على الشحن ✅',
        body: 'تم تحديث رصيدك، يمكنك الآن تقديم العروض',
        type: 'wallet',
      );
    } else if (status == 'rejected') {
      addNotification(
        title: 'طلب الشحن مرفوض',
        body: 'لم تتم الموافقة على طلب الشحن، راجع الدعم للمزيد',
        type: 'wallet',
      );
    }
  }

  void handleTopupCreated(dynamic data) {
    final user = currentUser;
    if (user == null || !user.isAdmin) return;

    addNotification(
      title: 'طلب شحن جديد',
      body: 'فني أرسل طلب شحن بانتظار المراجعة',
      type: 'admin',
    );
  }

  void handleSupportCreated(dynamic data) {
    final user = currentUser;
    if (user == null || !user.isAdmin) return;

    addNotification(
      title: 'تذكرة دعم جديدة',
      body: 'يوجد طلب دعم جديد',
      type: 'admin',
    );
  }

  /// رقم تذكرة الدعم المفتوحة حالياً على الشاشة (لمنع الإشعار وأنت داخلها).
  int? activeSupportTicketId;

  void setActiveSupportTicket(int? ticketId) {
    activeSupportTicketId = ticketId;
  }

  /// يصل للفني عندما يرسل له الأدمن رسالة دعم. يزيد العدّاد (1، 2، 3...).
  void handleSupportMessage(dynamic data) {
    final user = currentUser;
    if (user == null) return;

    // المُرسِل نفسه لا يُشعَر.
    final senderId = int.tryParse('${data?['senderId'] ?? 0}') ?? -1;
    if (senderId == user.id) return;

    final ticketId = int.tryParse(
          '${data?['ticketId'] ?? data?['ticket_id'] ?? 0}',
        ) ??
        0;

    // إذا كان الفني فاتح نفس التذكرة، لا داعي لإشعار — الرسالة أمامه.
    if (ticketId != 0 && ticketId == activeSupportTicketId) return;

    addNotification(
      title: 'رسالة من الدعم',
      body: '${data?['body'] ?? 'وصلتك رسالة جديدة من الدعم'}',
      type: 'support',
      requestId: ticketId,
    );
  }

  void handleOfferAccepted(dynamic data) {
    final user = currentUser;
    if (user == null) return;
    // يصل هذا الحدث للفني صاحب العرض المقبول.
    if (!user.isTechnician) return;

    final requestId = int.tryParse('${data?['requestId'] ?? 0}') ?? 0;

    addNotification(
      title: 'تم قبول عرضك 🎉',
      body: 'وافق العميل على عرضك، تواصل معه لإتمام الخدمة',
      type: 'offer',
      requestId: requestId,
    );
  }

  void handleChatBadges(dynamic data) {
    // تحديث شارة الرسائل غير المقروءة في القوائم دون صوت/إشعار مرئي.
    notifyListeners();
  }

  void handleNewComplaint(dynamic data) {
    final user = currentUser;
    if (user == null || !user.isAdmin) return;

    addNotification(
      title: '⚠️ شكوى جديدة',
      body: 'قدّم أحد العملاء شكوى بانتظار المراجعة',
      type: 'admin',
    );
  }

  void markRequestNotificationsRead() {
    for (final item in _items) {
      if (!item.isChat) {
        item.read = true;
      }
    }
    notifyListeners();
  }

  void markChatNotificationsRead() {
    for (final item in _items) {
      if (item.isChat) {
        item.read = true;
      }
    }
    notifyListeners();
  }

  /// تُستدعى عند فتح شاشة الدعم → تصفّر عدّاد رسائل الدعم.
  void markSupportNotificationsRead() {
    for (final item in _items) {
      if (item.isSupport) {
        item.read = true;
      }
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}