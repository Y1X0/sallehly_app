class RequestModel {
  final int id;
  final int customerId;
  final int? technicianId;
  final String service;
  final String city;
  final String? area;
  final String description;
  final String? preferredTime;
  final String? problemImageUrl;
  final String status;
  final String? customerName;
  final String? technicianName;
  final double? offerPrice;
  final String? arrivalTime;
  final DateTime? createdAt;

  const RequestModel({
    required this.id,
    required this.customerId,
    this.technicianId,
    required this.service,
    required this.city,
    this.area,
    required this.description,
    this.preferredTime,
    this.problemImageUrl,
    required this.status,
    this.customerName,
    this.technicianName,
    this.offerPrice,
    this.arrivalTime,
    this.createdAt,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      customerId: int.tryParse('${json['customer_id'] ?? 0}') ?? 0,
      technicianId: json['technician_id'] == null
          ? null
          : int.tryParse('${json['technician_id']}'),
      service: '${json['service'] ?? ''}',
      city: '${json['city'] ?? ''}',
      area: json['area']?.toString(),
      description: '${json['description'] ?? ''}',
      preferredTime: json['preferred_time']?.toString(),
      problemImageUrl: json['problem_image_url']?.toString(),
      status: '${json['status'] ?? ''}',
      customerName: json['customer_name']?.toString(),
      technicianName: json['technician_name']?.toString(),
      offerPrice: json['offer_price'] == null
          ? null
          : double.tryParse('${json['offer_price']}'),
      arrivalTime: json['arrival_time']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }

  bool get hasOffers => status == 'وصلت عروض';
  bool get isWaiting => status == 'بانتظار العروض';
  bool get isCompleted => status == 'مكتمل';
  bool get isCancelled => status == 'ملغي';
}