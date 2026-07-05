import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/ledger_model.dart';
import '../../../models/package_model.dart';
import '../../../models/payment_method_model.dart';
import '../../../models/topup_model.dart';

class WalletApi {
  final ApiClient apiClient;

  WalletApi(this.apiClient);

  Future<List<PackageModel>> getPackages() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.meta);
      final data = Map<String, dynamic>.from(response.data);

      return (data['packages'] as List? ?? [])
          .map((e) => PackageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.paymentMethods);
      final data = Map<String, dynamic>.from(response.data);

      return (data['paymentMethods'] as List? ?? [])
          .map(
            (e) => PaymentMethodModel.fromJson(Map<String, dynamic>.from(e)),
      )
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<TopupModel>> getTopups() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.topups);
      final data = Map<String, dynamic>.from(response.data);

      return (data['topups'] as List? ?? [])
          .map((e) => TopupModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<LedgerModel>> getLedger() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.ledger);
      final data = Map<String, dynamic>.from(response.data);

      return (data['ledger'] as List? ?? [])
          .map((e) => LedgerModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<TopupModel> createTopup({
    required int packageId,
    required String receiptPath,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.topups,
        data: FormData.fromMap({
          'package_id': packageId,
          'receipt': await MultipartFile.fromFile(receiptPath),
        }),
      );

      final data = Map<String, dynamic>.from(response.data);

      return TopupModel.fromJson(
        Map<String, dynamic>.from(data['topup']),
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }
}