class ServiceModel {
  final int id;
  final String name;
  final String? icon;
  final bool isActive;

  const ServiceModel({
    required this.id,
    required this.name,
    this.icon,
    this.isActive = true,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: '${json['name'] ?? ''}',
      icon: json['icon']?.toString(),
      isActive: json['is_active'] == null
          ? true
          : (json['is_active'] == 1 || json['is_active'] == true),
    );
  }
}