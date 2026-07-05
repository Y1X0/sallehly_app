class PaymentMethodModel {
  final int id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String phone;
  final String? instructions;

  const PaymentMethodModel({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.phone,
    this.instructions,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      bankName: '${json['bank_name'] ?? ''}',
      accountName: '${json['account_name'] ?? ''}',
      accountNumber: '${json['account_number'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      instructions: json['instructions']?.toString(),
    );
  }
}