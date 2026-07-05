class SupportTicketModel {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String body;
  final String status;
  final String? userName;
  final String? userRole;
  final String? email;
  final DateTime? createdAt;

  const SupportTicketModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.status,
    this.userName,
    this.userRole,
    this.email,
    this.createdAt,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      userId: int.tryParse('${json['user_id'] ?? 0}') ?? 0,
      type: '${json['type'] ?? 'عام'}',
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      status: '${json['status'] ?? 'open'}',
      userName: json['user_name']?.toString(),
      userRole: json['user_role']?.toString(),
      email: json['email']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }

  bool get isOpen => status == 'open';
}