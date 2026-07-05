class ServiceModel {
  final int id;
  final String name;
  final String? icon;

  const ServiceModel({
    required this.id,
    required this.name,
    this.icon,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: '${json['name'] ?? ''}',
      icon: json['icon']?.toString(),
    );
  }
}