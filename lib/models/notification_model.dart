class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final int? requestId;
  final DateTime createdAt;
  bool read;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.requestId,
    required this.createdAt,
    this.read = false,
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
}