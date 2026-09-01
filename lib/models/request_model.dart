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

  // [FIX-L10N-03] الأدنى تشغيلياً وليس نص عرض: السيرفر يرسل status كسلسلة
  // عربية حرفية (قيمة سلكية wire value)، وهذه المقارنات تطابقها كما هي. لا
  // تُترجم أو تُستبدل هذه الحرفيات أبداً — ذلك سيكسر كل منطق الحالة هنا فوراً
  // بغض النظر عن لغة الواجهة المعروضة. [L10N-PHASE3] جزء العرض المترجَم
  // (models/request_status.dart: تعداد RequestStatus + fromWire() + جدول
  // تسميات) أُنجز ويُستخدَم بـrequest_status_chip.dart فقط — هذه المقارنات
  // هنا تبقى عمداً على القيمة السلكية الخام، غير مرتبطة بذلك التعداد.
  bool get hasOffers => status == 'وصلت عروض';
  bool get isWaiting => status == 'بانتظار العروض';
  bool get isCompleted => status == 'مكتمل';
  bool get isCancelled => status == 'ملغي';

  // [FEAT-DEDUP-01] راجع DECISIONS.md — أُضيفتا بعد أن لاحظ صاحب المنتج أن
  // customer_request_details_screen.dart كانت تقارن هاتين الحالتين حرفياً
  // بجوار استخدام صحيح لـhasOffers بنفس الودجت — بالضبط الشكل "نصف المحمي"
  // (بعض المقارنات على getters، وبعضها الآخر حرفي بنفس الملف) الذي أُزيل من
  // AdminProvider سابقاً. لا حاجة فعلية لغيرها من الاستهلاك الحالي، لكن أي
  // موضع جديد يقارن نفس الحالتين يجب أن يستخدمهما بدل تكرار النص.
  bool get isOfferAccepted => status == 'تم اختيار عرض';
  bool get isInProgress => status == 'قيد التنفيذ';
  bool get isAwaitingPaymentConfirmation => status == 'بانتظار تأكيد الدفع';

  /// [FIX-CUSTDELETE-01] يطابق تماماً الحالات التي يسمح بها السيرفر بالإلغاء
  /// (DELETE /requests/:id) — بعد قبول عرض فني (تم اختيار عرض/قيد التنفيذ/
  /// بانتظار تأكيد الدفع) أو اكتمال الطلب، السيرفر يرفض الإلغاء دائماً. عرض
  /// الزر فقط بهذه الحالات يمنع المستخدم من الوصول لخطأ متوقّع مسبقاً.
  bool get isCancellable => status == 'بانتظار العروض' || status == 'وصلت عروض';

  RequestModel copyWith({
    String? status,
    int? technicianId,
    String? technicianName,
    double? offerPrice,
    String? arrivalTime,
  }) {
    return RequestModel(
      id: id,
      customerId: customerId,
      technicianId: technicianId ?? this.technicianId,
      service: service,
      city: city,
      area: area,
      description: description,
      preferredTime: preferredTime,
      problemImageUrl: problemImageUrl,
      status: status ?? this.status,
      customerName: customerName,
      technicianName: technicianName ?? this.technicianName,
      offerPrice: offerPrice ?? this.offerPrice,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      createdAt: createdAt,
    );
  }
}