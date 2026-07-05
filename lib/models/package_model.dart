class PackageModel {
  final int id;
  final String name;
  final double amount;
  final double bonus;
  final double commissionPerOrder;

  const PackageModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.bonus,
    required this.commissionPerOrder,
  });

  factory PackageModel.fromJson(Map<String, dynamic> json) {
    return PackageModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: '${json['name'] ?? ''}',
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      bonus: double.tryParse('${json['bonus'] ?? 0}') ?? 0,
      commissionPerOrder:
      double.tryParse('${json['commission_per_order'] ?? 2}') ?? 2,
    );
  }

  double get total => amount + bonus;
}