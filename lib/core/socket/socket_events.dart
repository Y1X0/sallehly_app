class SocketEvents {
  SocketEvents._();

  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String connectError = 'connect_error';

  static const String joinRequest = 'join-request';
  static const String leaveRequest = 'leave-request';

  static const String newRequestCreated = 'new-request-created';
  static const String offerCreated = 'offer-created';
  static const String offerAccepted = 'offer-accepted';

  static const String requestsUpdated = 'requests-updated';
  static const String requestStatusUpdated = 'request-status-updated';

  static const String messagesUpdated = 'messages-updated';
  static const String chatMessageNotify = 'chat-message-notify';
  static const String chatBadgesUpdated = 'chat-badges-updated';

  static const String topupCreated = 'topup-created';
  static const String balanceUpdated = 'balance-updated';

  static const String supportCreated = 'support-created';
  static const String supportMessage = 'support-message';
  static const String supportMessageRefresh = 'support-message-refresh';
  static const String supportStatusUpdated = 'support-status-updated';
  static const String newComplaint = 'new-complaint';
  // [FIX-UGC-01] بلاغ رسالة جديد (سياسة UGC)
  static const String newMessageReport = 'new-message-report';
  // [FIX-SERVICES-01] بث عام (لكل المستخدمين) عند إضافة/تعديل/حذف مهنة
  static const String servicesUpdated = 'services-updated';
}
