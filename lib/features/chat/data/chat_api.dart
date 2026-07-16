import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/chat_summary_model.dart';
import '../../../models/message_model.dart';

class ChatApi {
  final ApiClient apiClient;

  ChatApi(this.apiClient);

  /// [FIX-CHATUNREAD-01] قائمة كل المحادثات مع آخر رسالة وعدد غير المقروء لكل
  /// منها، كما يرجعها GET /chats (نفس المنطق الجاهز أصلاً بالسيرفر).
  Future<(List<ChatSummaryModel>, int)> getChats() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.chats);
      final data = Map<String, dynamic>.from(response.data);

      final chats = (data['chats'] as List? ?? [])
          .map((e) => ChatSummaryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final totalUnread = int.tryParse('${data['total_unread'] ?? 0}') ?? 0;

      return (chats, totalUnread);
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<MessageModel>> getMessages(int requestId) async {
    try {
      final response = await apiClient.dio.get(
        ApiEndpoints.requestMessages(requestId),
      );

      final data = Map<String, dynamic>.from(response.data);

      return (data['messages'] as List? ?? [])
          .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<MessageModel>> sendMessage({
    required int requestId,
    required String body,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.requestMessages(requestId),
        data: {'body': body.trim()},
      );

      final data = Map<String, dynamic>.from(response.data);

      return (data['messages'] as List? ?? [])
          .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<MessageModel>> sendLocation({
    required int requestId,
    required double lat,
    required double lng,
  }) {
    final safeLat = lat.toStringAsFixed(6);
    final safeLng = lng.toStringAsFixed(6);

    return sendMessage(
      requestId: requestId,
      body: '[location]$safeLat,$safeLng',
    );
  }

  Future<List<MessageModel>> sendAudio({
    required int requestId,
    required String audioPath,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.requestAudio(requestId),
        data: FormData.fromMap({
          'audio': await MultipartFile.fromFile(
            audioPath,
            filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.wav',
            contentType: DioMediaType('audio', 'wav'),
          ),
        }),
      );

      final data = Map<String, dynamic>.from(response.data);

      return (data['messages'] as List? ?? [])
          .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<MessageModel>> sendImage({
    required int requestId,
    required String imagePath,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.requestImages(requestId),
        data: FormData.fromMap({
          'image': await MultipartFile.fromFile(
            imagePath,
            filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        }),
      );

      final data = Map<String, dynamic>.from(response.data);

      return (data['messages'] as List? ?? [])
          .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// إبلاغ الإدارة عن رسالة (أو عن الطرف الآخر عموماً لو لم تُحدَّد رسالة).
  /// [FIX-UGC-01] متطلّب سياسة UGC بمنصّة Google Play.
  Future<String> reportMessage({
    required int requestId,
    int? messageId,
    required String reason,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.reportMessage(requestId),
        data: {
          if (messageId != null) 'messageId': messageId,
          'reason': reason,
        },
      );
      final data = Map<String, dynamic>.from(response.data);
      return data['message']?.toString() ?? 'تم إرسال البلاغ للإدارة';
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// حظر الطرف الآخر بهذا الطلب — يمنع التراسل بالاتجاهين فوراً.
  Future<void> blockUser(int requestId) async {
    try {
      await apiClient.dio.post(ApiEndpoints.requestBlock(requestId));
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// إلغاء حظر الطرف الآخر بهذا الطلب.
  Future<void> unblockUser(int requestId) async {
    try {
      await apiClient.dio.delete(ApiEndpoints.requestBlock(requestId));
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// حالة الحظر الحالية بين المستخدم والطرف الآخر بهذا الطلب.
  Future<BlockStatus> getBlockStatus(int requestId) async {
    try {
      final response = await apiClient.dio.get(
        ApiEndpoints.requestBlockStatus(requestId),
      );
      final data = Map<String, dynamic>.from(response.data);
      return BlockStatus(
        blockedByMe: data['blockedByMe'] == true,
        blockedMe: data['blockedMe'] == true,
        otherUserId: data['otherUserId'] == null
            ? null
            : int.tryParse('${data['otherUserId']}'),
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }
}

class BlockStatus {
  final bool blockedByMe;
  final bool blockedMe;
  final int? otherUserId;

  const BlockStatus({
    required this.blockedByMe,
    required this.blockedMe,
    required this.otherUserId,
  });

  /// ممنوع التراسل لو أي طرف حظر الآخر.
  bool get isChatBlocked => blockedByMe || blockedMe;
}