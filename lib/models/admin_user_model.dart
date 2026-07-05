class AdminUserModel {
  final int id;
  final String role;
  final String name;
  final String email;
  final String phone;
  final String? city;
  final String? areas;
  final String? services;
  final double balance;
  final bool active;
  final double ratingAvg;
  final int ratingCount;
  final int completedJobs;

  const AdminUserModel({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    this.city,
    this.areas,
    this.services,
    required this.balance,
    required this.active,
    required this.ratingAvg,
    required this.ratingCount,
    required this.completedJobs,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    return AdminUserModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      role: '${json['role'] ?? ''}',
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      city: json['city']?.toString(),
      areas: json['areas']?.toString(),
      services: json['services']?.toString(),
      balance: double.tryParse('${json['balance'] ?? 0}') ?? 0,
      active: json['is_active'] == 1 || json['is_active'] == true,
      ratingAvg: double.tryParse('${json['rating_avg'] ?? 0}') ?? 0,
      ratingCount: int.tryParse('${json['rating_count'] ?? 0}') ?? 0,
      completedJobs: int.tryParse('${json['completed_jobs'] ?? 0}') ?? 0,
    );
  }

  bool get isCustomer => role == 'customer';
  bool get isTechnician => role == 'technician';
  bool get isAdmin => role == 'admin';

  String get roleAr {
    if (isCustomer) return 'عميل';
    if (isTechnician) return 'فني';
    if (isAdmin) return 'أدمن';
    return role;
  }
}