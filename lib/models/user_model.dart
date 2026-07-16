class UserModel {
  final int id;
  final String role;
  final String name;
  final String email;
  final String phone;
  final String? city;
  final String? area;
  final String? nationalNumber;
  final String? avatar;
  final String? serviceName;

  /// [FIX-TECH-SERVICES-01] السيرفر يخزّن خدمات الفني كنص مفصول بفواصل
  /// ("كهربائي,سباك,نجار") — هاد الـ getter يحوّلها لقائمة نظيفة (بدون فراغات
  /// أو عناصر فاضية) عشان تُعرض وتُعدَّل كخدمات متعددة فعلية بالواجهة.
  List<String> get services => (serviceName ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final double rating;
  final double balance;
  final bool active;

  /// [FIX-OFFERQUOTA-01] عدد "محاولات تقديم عرض" التي استهلكها الفني من أصل
  /// فرصتيه المجانيتين — عدّاد دائم لا يتأثر بسحب عرض لاحقاً. السيرفر يرسله
  /// فقط للفنيين؛ يبقى صفراً لأي دور آخر (لا معنى له لعميل أو أدمن).
  final int freeOffersUsed;
  final int freeOffersRemaining;

  /// [FIX-SUPERADMIN-01] صحيحة فقط لحساب الإدارة الوحيد المُهيَّأ من .env —
  /// تتحكم بظهور القدرات الأشد حساسية (تغيير دور مستخدم) بواجهة الأدمن.
  final bool isSuperAdmin;

  const UserModel({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    this.city,
    this.area,
    this.nationalNumber,
    this.avatar,
    this.serviceName,
    required this.rating,
    required this.balance,
    required this.active,
    this.freeOffersUsed = 0,
    this.freeOffersRemaining = 0,
    this.isSuperAdmin = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: int.tryParse('${json['id']}') ?? 0,
      role: '${json['role'] ?? ''}',
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      city: json['city']?.toString(),
      // السيرفر يخزّن المناطق في حقل areas (جمع)
      area: json['areas']?.toString() ?? json['area']?.toString(),
      nationalNumber: json['national_number']?.toString(),
      // السيرفر يرجع avatar_url وليس avatar
      avatar: json['avatar_url']?.toString() ?? json['avatar']?.toString(),
      // السيرفر يرجع services (جمع)؛ نُبقي service_name/profession كبدائل احتياطية
      serviceName: json['services']?.toString() ??
          json['service_name']?.toString() ??
          json['profession']?.toString(),
      // السيرفر يرجع rating_avg
      rating: double.tryParse(
          '${json['rating_avg'] ?? json['rating'] ?? 0}') ??
          0,
      balance: double.tryParse('${json['balance'] ?? 0}') ?? 0,
      active: json['is_active'] == 1 ||
          json['is_active'] == true ||
          json['active'] == 1 ||
          json['active'] == true,
      freeOffersUsed: int.tryParse('${json['free_offers_used'] ?? 0}') ?? 0,
      freeOffersRemaining:
          int.tryParse('${json['free_offers_remaining'] ?? 0}') ?? 0,
      isSuperAdmin: json['is_super_admin'] == 1 || json['is_super_admin'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'name': name,
      'email': email,
      'phone': phone,
      'city': city,
      'area': area,
      'national_number': nationalNumber,
      'avatar': avatar,
      'service_name': serviceName,
      'rating': rating,
      'balance': balance,
      'active': active,
      'free_offers_used': freeOffersUsed,
      'free_offers_remaining': freeOffersRemaining,
    };
  }

  bool get isCustomer => role == 'customer';
  bool get isTechnician => role == 'technician';
  bool get isAdmin => role == 'admin';
}