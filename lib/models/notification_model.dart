class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final int? requestId;
  final DateTime createdAt;
  bool read;

  /// [NOTIF-FLUTTER-PHASE1] معرّف تذكرة الدعم إن وُجد — يصل فقط من إشعارات
  /// الخادم الدائمة (GET /api/notifications)، اختياري بالكامل حتى لا يكسر
  /// أي مُنشئ حالي للإشعارات المحلية اللحظية (Socket.IO) التي لا تملئه.
  final int? ticketId;

  /// [NOTIF-FLUTTER-PHASE1] الحمولة الإضافية الخام من الخادم (مثل
  /// offerId/complaintId/ticketId) — اختيارية بالكامل لنفس السبب أعلاه.
  final Map<String, dynamic>? data;

  /// [NOTIF-FLUTTER-PHASE2B] معرّف الصف الرقمي بجدول notifications بالخادم —
  /// null دائماً للإشعارات اللحظية المحلية (Socket.IO عبر addNotification)،
  /// ويُملأ فقط من fromJson. هذا هو الفارق الوحيد الموثوق بين "إشعار جاء من
  /// الخادم فعلاً" و"إشعار لحظي لم يُطابَق بعد بأي صف خادم" — id النصي وحده
  /// لا يكفي للتمييز لأن كليهما نص رقمي فعلياً (id اللحظي مصدره
  /// microsecondsSinceEpoch.toString()). يُستخدَم فقط لمنع التكرار عند الدمج
  /// (راجع NotificationProvider._mergeServerItems).
  final int? serverId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.requestId,
    required this.createdAt,
    this.read = false,
    this.ticketId,
    this.data,
    this.serverId,
  });

  /// [FIX-SUPPORTBADGE-01] معرّف "التذكرة/الطلب" الفعلي بغضّ النظر عن مصدر
  /// الإشعار — اللحظي (Socket.IO عبر handleSupportMessage) يخزّنه بـ[requestId]،
  /// بينما الدائم من الخادم (GET /api/notifications) يخزّنه بعمود منفصل
  /// ticket_id → [ticketId] (راجع notify() بـutils/notification.js: request_id
  /// وticket_id عمودان مختلفان). بدون هذا التوحيد، أي إشعار دعم وصل عبر
  /// التحميل الدائم (loadNotifications في app.dart) كان request_id فيه null
  /// دائماً، فتفشل مطابقته بـmarkSupportNotificationsReadForTicket (تقارن
  /// requestId فقط) ويبقى "غير مقروء" للأبد رغم فتح المحادثة فعلياً.
  int? get effectiveTicketId => requestId ?? ticketId;

  bool get isChat => type == 'chat';
  bool get isRequest => type == 'request';
  bool get isOffer => type == 'offer';
  bool get isAdmin => type == 'admin';
  bool get isSupport => type == 'support';
  bool get isTopup => type == 'topup';
  bool get isComplaint => type == 'complaint';
  bool get isWallet => type == 'wallet';
  bool get isService => type == 'service';
  bool get isRateRequest => type == 'rate_request';

  /// [NOTIF-FLUTTER-PHASE1] يحوّل استجابة GET /api/notifications (أو نتيجة
  /// POST /:id/read) إلى NotificationModel. id الخادم رقمي — يُحوَّل لنص
  /// حتى يتوافق مع نوع الحقل الحالي (id محلياً نص دائماً، مصدره أصلاً
  /// microsecondsSinceEpoch.toString() بالإشعارات اللحظية)، بلا أي تغيير
  /// على شكل الحقل العام لهذا الصنف.
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawRequestId = json['request_id'];
    final rawTicketId = json['ticket_id'];
    final rawData = json['data'];
    final rawId = json['id'];

    return NotificationModel(
      id: '${rawId ?? ''}',
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      type: '${json['type'] ?? ''}',
      requestId:
          rawRequestId == null ? null : int.tryParse('$rawRequestId'),
      ticketId: rawTicketId == null ? null : int.tryParse('$rawTicketId'),
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : null,
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
      read: json['is_read'] == true || json['is_read'] == 1,
      serverId: rawId == null ? null : int.tryParse('$rawId'),
    );
  }
}
