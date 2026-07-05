class TopServiceModel {
  final String service;
  final int count;

  const TopServiceModel({required this.service, required this.count});

  factory TopServiceModel.fromJson(Map<String, dynamic> json) {
    return TopServiceModel(
      service: '${json['service'] ?? ''}',
      count: int.tryParse('${json['cnt'] ?? 0}') ?? 0,
    );
  }
}

class TopTechnicianModel {
  final String name;
  final int completedJobs;
  final double ratingAvg;

  const TopTechnicianModel({
    required this.name,
    required this.completedJobs,
    required this.ratingAvg,
  });

  factory TopTechnicianModel.fromJson(Map<String, dynamic> json) {
    return TopTechnicianModel(
      name: '${json['name'] ?? ''}',
      completedJobs: int.tryParse('${json['completed_jobs'] ?? 0}') ?? 0,
      ratingAvg: double.tryParse('${json['rating_avg'] ?? 0}') ?? 0,
    );
  }
}

class AdminStatsModel {
  final int customers;
  final int technicians;
  final int requests;
  final int pendingTopups;
  final int completed;
  // ── الحقول التالية يرسلها الباك إند أصلاً بـ /admin/stats لكنها كانت مفقودة هون بالكامل ──
  final int cancelled;
  final double cancelRate;
  final double revenue;
  final List<TopServiceModel> topServices;
  final List<TopTechnicianModel> topTechs;

  const AdminStatsModel({
    required this.customers,
    required this.technicians,
    required this.requests,
    required this.pendingTopups,
    required this.completed,
    this.cancelled = 0,
    this.cancelRate = 0,
    this.revenue = 0,
    this.topServices = const [],
    this.topTechs = const [],
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatsModel(
      customers: int.tryParse('${json['customers'] ?? 0}') ?? 0,
      technicians: int.tryParse('${json['technicians'] ?? 0}') ?? 0,
      requests: int.tryParse('${json['requests'] ?? 0}') ?? 0,
      pendingTopups: int.tryParse('${json['pendingTopups'] ?? 0}') ?? 0,
      completed: int.tryParse('${json['completed'] ?? 0}') ?? 0,
      cancelled: int.tryParse('${json['cancelled'] ?? 0}') ?? 0,
      // السيرفر يرسل cancelRate وrevenue كنص (toFixed) وليس رقماً — لازم tryParse وليس قراءة مباشرة
      cancelRate: double.tryParse('${json['cancelRate'] ?? 0}') ?? 0,
      revenue: double.tryParse('${json['revenue'] ?? 0}') ?? 0,
      topServices: (json['topServices'] as List? ?? [])
          .map((e) => TopServiceModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      topTechs: (json['topTechs'] as List? ?? [])
          .map((e) => TopTechnicianModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static const empty = AdminStatsModel(
    customers: 0,
    technicians: 0,
    requests: 0,
    pendingTopups: 0,
    completed: 0,
  );
}