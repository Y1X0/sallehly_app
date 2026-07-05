import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/message_model.dart';

class ChatApi {
  final ApiClient apiClient;

  ChatApi(this.apiClient);

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
}