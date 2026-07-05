class TopupModel {
  final int id;
  final int packageId;
  final double amount;
  final double bonus;
  final String? receiptUrl;
  final String status;
  final String? adminNote;
  final String? packageName;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const TopupModel({
    required this.id,
    required this.packageId,
    required this.amount,
    required this.bonus,
    this.receiptUrl,
    required this.status,
    this.adminNote,
    this.packageName,
    this.createdAt,
    this.reviewedAt,
  });

  factory TopupModel.fromJson(Map<String, dynamic> json) {
    return TopupModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      packageId: int.tryParse('${json['package_id'] ?? 0}') ?? 0,
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      bonus: double.tryParse('${json['bonus'] ?? 0}') ?? 0,
      receiptUrl: json['receipt_url']?.toString(),
      status: '${json['status'] ?? ''}',
      adminNote: json['admin_note']?.toString(),
      packageName: json['package_name']?.toString(),
      createdAt: _toDate(json['created_at']),
      reviewedAt: _toDate(json['reviewed_at']),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  double get total => amount + bonus;
}