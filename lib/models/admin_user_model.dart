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
  // [FIX-SUPERADMIN-01] حقول جديدة — كلها اختيارية بقيمة افتراضية آمنة، حتى
  // لا تكسر أي استدعاء قديم لهذا الـconstructor لم يُحدَّث بعد.
  final String verificationStatus;
  final String? suspensionReason;
  final DateTime? suspendedAt;
  final bool isSuperAdmin;

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
    this.verificationStatus = 'verified',
    this.suspensionReason,
    this.suspendedAt,
    this.isSuperAdmin = false,
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
      verificationStatus: '${json['verification_status'] ?? 'verified'}',
      suspensionReason: json['suspension_reason']?.toString(),
      suspendedAt: json['suspended_at'] == null
          ? null
          : DateTime.tryParse(json['suspended_at'].toString()),
      isSuperAdmin: json['is_super_admin'] == 1 || json['is_super_admin'] == true,
    );
  }

  bool get isCustomer => role == 'customer';
  bool get isTechnician => role == 'technician';
  bool get isAdmin => role == 'admin';
  bool get isPendingVerification => isTechnician && verificationStatus == 'pending';

  String get roleAr {
    if (isCustomer) return 'عميل';
    if (isTechnician) return 'فني';
    if (isAdmin) return 'أدمن';
    return role;
  }
}