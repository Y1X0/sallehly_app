import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/meta_model.dart';
import '../../../models/offer_model.dart';
import '../../../models/request_model.dart';

class RequestsApi {
  final ApiClient apiClient;

  RequestsApi(this.apiClient);

  Future<MetaModel> getMeta() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.meta);
      return MetaModel.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<RequestModel>> getRequests() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.requests);
      final data = Map<String, dynamic>.from(response.data);

      return (data['requests'] as List? ?? [])
          .map((e) => RequestModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<RequestModel> createRequest({
    required String service,
    required String city,
    required String area,
    required String description,
    String? preferredTime,
    String? imagePath,
  }) async {
    try {
      final map = <String, dynamic>{
        'service': service,
        'city': city,
        'area': area,
        'description': description,
        if (preferredTime != null && preferredTime.isNotEmpty)
          'preferred_time': preferredTime,
      };

      if (imagePath != null && imagePath.isNotEmpty) {
        map['problem_image'] = await MultipartFile.fromFile(imagePath);
      }

      final response = await apiClient.dio.post(
        ApiEndpoints.requests,
        data: FormData.fromMap(map),
      );

      final data = Map<String, dynamic>.from(response.data);

      return RequestModel.fromJson(
        Map<String, dynamic>.from(data['request']),
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> sendOffer({
    required int requestId,
    required double price,
    required String duration,
    String? note,
  }) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.createOffer(requestId),
        data: {
          'offer_price': price,
          'duration': duration,
          'note': note ?? '',
        },
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<OfferModel>> getOffers(int requestId) async {
    try {
      final response = await apiClient.dio.get(
        ApiEndpoints.requestOffers(requestId),
      );

      final data = Map<String, dynamic>.from(response.data);

      return (data['offers'] as List? ?? [])
          .map((e) => OfferModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<RequestModel> decideOffer({
    required int offerId,
    required String decision,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.offerDecision(offerId),
        data: {'decision': decision},
      );

      final data = Map<String, dynamic>.from(response.data);

      return RequestModel.fromJson(
        Map<String, dynamic>.from(data['request']),
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<RequestModel> updateStatus({
    required int requestId,
    required String status,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.requestStatus(requestId),
        data: {'status': status},
      );

      final data = Map<String, dynamic>.from(response.data);

      return RequestModel.fromJson(
        Map<String, dynamic>.from(data['request']),
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<RequestModel> cancelRequest(int id) async {
    try {
      final response = await apiClient.dio.delete(
        ApiEndpoints.requestById(id),
      );

      final data = Map<String, dynamic>.from(response.data);

      return RequestModel.fromJson(
        Map<String, dynamic>.from(data['request']),
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> rateRequest({
    required int requestId,
    required int rating,
    String? comment,
  }) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.requestRate(requestId),
        data: {
          'stars': rating,
          'comment': comment ?? '',
        },
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> submitComplaint({
    required int requestId,
    required String body,
  }) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.complaints,
        data: {
          'request_id': requestId,
          'body': body.trim(),
        },
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }
}