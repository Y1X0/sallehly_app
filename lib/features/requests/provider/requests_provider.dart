import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../models/meta_model.dart';
import '../../../models/offer_model.dart';
import '../../../models/request_model.dart';
import '../data/requests_api.dart';

class RequestsProvider extends ChangeNotifier {
  late final RequestsApi api;

  RequestsProvider({
    required ApiClient apiClient,
  }) {
    api = RequestsApi(apiClient);
  }

  bool loading = false;
  String? error;

  MetaModel? meta;
  List<RequestModel> requests = [];
  List<OfferModel> offers = [];

  Future<void> loadMeta() async {
    try {
      meta ??= await api.getMeta();
      notifyListeners();
    } catch (e) {
      error = e is ApiException ? e.message : 'حدث خطأ';
      notifyListeners();
    }
  }

  Future<void> loadRequests({bool silent = false}) async {
    if (!silent) _setLoading(true);

    try {
      requests = await api.getRequests();
      error = null;
      if (silent) notifyListeners();
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل الطلبات';
      if (silent) notifyListeners();
    } finally {
      if (!silent) _setLoading(false);
    }
  }

  Future<void> createRequest({
    required String service,
    required String city,
    required String area,
    required String description,
    String? preferredTime,
    String? imagePath,
  }) async {
    _setLoading(true);

    try {
      await api.createRequest(
        service: service,
        city: city,
        area: area,
        description: description,
        preferredTime: preferredTime,
        imagePath: imagePath,
      );

      requests = await api.getRequests();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر إنشاء الطلب';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendOffer({
    required int requestId,
    required double price,
    required String duration,
    String? note,
  }) async {
    _setLoading(true);

    try {
      await api.sendOffer(
        requestId: requestId,
        price: price,
        duration: duration,
        note: note,
      );

      requests = await api.getRequests();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر إرسال العرض';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadOffers(int requestId, {bool silent = false}) async {
    if (!silent) _setLoading(true);

    try {
      offers = await api.getOffers(requestId);
      error = null;
      if (silent) notifyListeners();
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل العروض';
      if (silent) notifyListeners();
    } finally {
      if (!silent) _setLoading(false);
    }
  }

  Future<RequestModel?> acceptOffer({
    required int requestId,
    required int offerId,
  }) async {
    _setLoading(true);

    try {
      final result = await api.decideOffer(
        offerId: offerId,
        decision: 'accepted',
      );

      offers = await api.getOffers(requestId);
      requests = await api.getRequests();
      error = null;

      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> rejectOffer({
    required int requestId,
    required int offerId,
  }) async {
    _setLoading(true);

    try {
      await api.decideOffer(
        offerId: offerId,
        decision: 'rejected',
      );

      offers = await api.getOffers(requestId);
      requests = await api.getRequests();
      error = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateRequestStatus({
    required int requestId,
    required String status,
  }) async {
    _setLoading(true);

    try {
      await api.updateStatus(
        requestId: requestId,
        status: status,
      );

      requests = await api.getRequests();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحديث الحالة';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> completeRequest(int requestId) async {
    await updateRequestStatus(
      requestId: requestId,
      status: 'مكتمل',
    );
  }

  Future<void> rateRequest({
    required int requestId,
    required int rating,
    String? comment,
  }) async {
    _setLoading(true);
    try {
      await api.rateRequest(
        requestId: requestId,
        rating: rating,
        comment: comment,
      );
      // تحديث القائمة حتى يختفي زر التقييم بعد إتمامه
      requests = await api.getRequests();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
      rethrow;
    } catch (_) {
      error = 'تعذر إرسال التقييم';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> submitComplaint({
    required int requestId,
    required String body,
  }) async {
    _setLoading(true);
    try {
      await api.submitComplaint(requestId: requestId, body: body);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
      rethrow;
    } catch (_) {
      error = 'تعذر إرسال الشكوى';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> cancelRequest(int requestId) async {
    _setLoading(true);

    try {
      await api.cancelRequest(requestId);
      requests = await api.getRequests();
      error = null;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    loading = value;
    notifyListeners();
  }
}