class SupportMessageModel {
  final int id;
  final int ticketId;
  final int senderId;
  final String body;
  final String? senderName;
  final String? senderRole;
  final DateTime? createdAt;

  const SupportMessageModel({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.body,
    this.senderName,
    this.senderRole,
    this.createdAt,
  });

  bool get isAdmin => senderRole == 'admin';

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      ticketId: int.tryParse('${json['ticket_id'] ?? 0}') ?? 0,
      senderId: int.tryParse('${json['sender_id'] ?? 0}') ?? 0,
      body: '${json['body'] ?? ''}',
      senderName: json['sender_name']?.toString(),
      senderRole: json['sender_role']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}
