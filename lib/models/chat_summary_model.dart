/// [FIX-CHATUNREAD-01] ملخّص محادثة واحدة كما يرجعه GET /chats — يحمل فقط ما
/// يلزم لعرض قائمة المحادثات (آخر رسالة، عدد غير المقروء) بعكس RequestModel
/// الكامل المستخدم للتنقل وعرض تفاصيل الطلب.
class ChatSummaryModel {
  final int requestId;
  final String service;
  final String status;
  final String? otherName;
  final String? lastBody;
  final DateTime? lastAt;
  final int unreadCount;

  const ChatSummaryModel({
    required this.requestId,
    required this.service,
    required this.status,
    this.otherName,
    this.lastBody,
    this.lastAt,
    this.unreadCount = 0,
  });

  bool get hasUnread => unreadCount > 0;

  factory ChatSummaryModel.fromJson(Map<String, dynamic> json) {
    return ChatSummaryModel(
      requestId: int.tryParse('${json['request_id'] ?? 0}') ?? 0,
      service: '${json['service'] ?? ''}',
      status: '${json['status'] ?? ''}',
      otherName: json['other_name']?.toString(),
      lastBody: json['last_body']?.toString(),
      lastAt: json['last_at'] == null
          ? null
          : DateTime.tryParse(json['last_at'].toString()),
      unreadCount: int.tryParse('${json['unread_count'] ?? 0}') ?? 0,
    );
  }
}
