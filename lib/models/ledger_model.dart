class LedgerModel {
  final int id;
  final int userId;
  final String type;
  final double amount;
  final double balanceAfter;
  final String? note;
  final DateTime? createdAt;

  const LedgerModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.note,
    this.createdAt,
  });

  factory LedgerModel.fromJson(Map<String, dynamic> json) {
    return LedgerModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      userId: int.tryParse('${json['user_id'] ?? 0}') ?? 0,
      type: '${json['type'] ?? ''}',
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      balanceAfter: double.tryParse('${json['balance_after'] ?? 0}') ?? 0,
      note: json['note']?.toString(),
      createdAt: _toDate(json['created_at']),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  bool get isCredit => amount > 0;
  bool get isDebit => amount < 0;
}