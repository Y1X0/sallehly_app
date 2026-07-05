class OfferModel {
  final int id;
  final int requestId;
  final int technicianId;
  final double price;
  final String duration;
  final String? note;
  final String status;
  final String? technicianName;
  final String? technicianCity;
  final String? avatarUrl;
  final double ratingAvg;
  final int ratingCount;
  final int completedJobs;

  const OfferModel({
    required this.id,
    required this.requestId,
    required this.technicianId,
    required this.price,
    required this.duration,
    this.note,
    required this.status,
    this.technicianName,
    this.technicianCity,
    this.avatarUrl,
    required this.ratingAvg,
    required this.ratingCount,
    required this.completedJobs,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      requestId: int.tryParse('${json['request_id'] ?? 0}') ?? 0,
      technicianId: int.tryParse('${json['technician_id'] ?? 0}') ?? 0,
      price: double.tryParse('${json['price'] ?? 0}') ?? 0,
      duration: '${json['duration'] ?? ''}',
      note: json['note']?.toString(),
      status: '${json['status'] ?? ''}',
      technicianName: json['technician_name']?.toString(),
      technicianCity: json['technician_city']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      ratingAvg: double.tryParse('${json['rating_avg'] ?? 0}') ?? 0,
      ratingCount: int.tryParse('${json['rating_count'] ?? 0}') ?? 0,
      completedJobs: int.tryParse('${json['completed_jobs'] ?? 0}') ?? 0,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
}