import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/support_message_model.dart';
import '../../../models/support_ticket_model.dart';

class SupportApi {
  final ApiClient apiClient;

  SupportApi(this.apiClient);

  Future<List<SupportTicketModel>> getMyTickets() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.supportMy);
      final data = Map<String, dynamic>.from(response.data);

      return (data['tickets'] as List? ?? [])
          .map((e) => SupportTicketModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<SupportTicketModel> createTicket({
    required String type,
    required String title,
    required String body,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.support,
        data: {
          'type': type,
          'title': title.trim(),
          'body': body.trim(),
        },
      );

      final data = Map<String, dynamic>.from(response.data);
      return SupportTicketModel.fromJson(
        Map<String, dynamic>.from(data['ticket']),
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<SupportMessageModel>> getMessages(int ticketId) async {
    try {
      final response = await apiClient.dio.get(
        ApiEndpoints.supportMessages(ticketId),
      );
      final data = Map<String, dynamic>.from(response.data);

      return (data['messages'] as List? ?? [])
          .map((e) =>
              SupportMessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> sendMessage({
    required int ticketId,
    required String body,
  }) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.supportMessages(ticketId),
        data: {'body': body.trim()},
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }
}
