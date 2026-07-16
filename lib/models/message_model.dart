class MessageModel {
  final int id;
  final int requestId;
  final int senderId;
  final String? senderName;
  final String body;
  final DateTime? createdAt;
  final bool seen;

  MessageModel({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.body,
    this.senderName,
    this.createdAt,
    this.seen = false,
  });

  bool get isAudio => body.startsWith('[audio]');
  bool get isLocation => body.startsWith('[location]');
  bool get isImage => body.startsWith('[image]');

  /// [FIX-AUDIODUR-01] الجسم بصيغة '[audio]/uploads/audios/x.wav' أو
  /// '[audio]/uploads/audios/x.wav|42' (42 = المدة بالثواني، اختيارية —
  /// رسائل قديمة من قبل هذا التغيير لا تحمل اللاحقة إطلاقاً).
  String get audioUrl {
    if (!isAudio) return '';
    final raw = body.replaceFirst('[audio]', '').trim();
    final pipeIndex = raw.indexOf('|');
    return pipeIndex == -1 ? raw : raw.substring(0, pipeIndex);
  }

  /// المدة المخزَّنة من السيرفر وقت الرفع، أو null لرسائل قديمة/بلا مدة —
  /// عندها تبقى الواجهة تعتمد على مدة مشغّل الصوت الفعلية بعد بدء التشغيل.
  int? get audioDurationSeconds {
    if (!isAudio) return null;
    final raw = body.replaceFirst('[audio]', '').trim();
    final pipeIndex = raw.indexOf('|');
    if (pipeIndex == -1) return null;
    return int.tryParse(raw.substring(pipeIndex + 1));
  }

  String get locationPayload {
    if (!isLocation) return '';
    return body.replaceFirst('[location]', '').trim();
  }

  String get imageUrl {
    if (!isImage) return '';
    return body.replaceFirst('[image]', '').trim();
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: _toInt(json['id']),
      requestId: _toInt(json['request_id'] ?? json['requestId']),
      senderId: _toInt(json['sender_id'] ?? json['senderId']),
      senderName: json['sender_name']?.toString() ??
          json['senderName']?.toString() ??
          json['name']?.toString(),
      body: (json['body'] ?? json['message'] ?? '').toString(),
      createdAt: _toDate(json['created_at'] ?? json['createdAt']),
      seen: json['seen'] == 1 || json['seen'] == true,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}