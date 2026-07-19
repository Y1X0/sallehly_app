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
  });

  bool get isChat => type == 'chat';
  bool get isRequest => type == 'request';
  bool get isOffer => type == 'offer';
  bool get isAdmin => type == 'admin';
  bool get isSupport => type == 'support';
  bool get isTopup => type == 'topup';
  bool get isComplaint => type == 'complaint';
  bool get isWallet => type == 'wallet';
  bool get isService => type == 'service';

  /// [NOTIF-FLUTTER-PHASE1] يحوّل استجابة GET /api/notifications (أو نتيجة
  /// POST /:id/read) إلى NotificationModel. id الخادم رقمي — يُحوَّل لنص
  /// حتى يتوافق مع نوع الحقل الحالي (id محلياً نص دائماً، مصدره أصلاً
  /// microsecondsSinceEpoch.toString() بالإشعارات اللحظية)، بلا أي تغيير
  /// على شكل الحقل العام لهذا الصنف.
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawRequestId = json['request_id'];
    final rawTicketId = json['ticket_id'];
    final rawData = json['data'];

    return NotificationModel(
      id: '${json['id'] ?? ''}',
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
    );
  }
}
