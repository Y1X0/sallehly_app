class ReviewModel {
  final int stars;
  final String? comment;
  final String? customerName;
  final DateTime? createdAt;

  const ReviewModel({
    required this.stars,
    this.comment,
    this.customerName,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      stars: int.tryParse('${json['stars'] ?? 0}') ?? 0,
      comment: json['comment']?.toString(),
      customerName: json['customer_name']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}
