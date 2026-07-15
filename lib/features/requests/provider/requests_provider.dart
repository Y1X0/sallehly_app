import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../models/meta_model.dart';
import '../../../models/offer_model.dart';
import '../../../models/request_model.dart';
import '../data/requests_api.dart';

class RequestsProvider extends ChangeNotifier {
  late final RequestsApi api;

  // [FIX-TEST-01] معامل اختياري جديد يسمح بحقن RequestsApi جاهز (Mock)
  // للاختبار، بدون أي تأثير على app.dart الذي لا يمرره إطلاقاً.
  RequestsProvider({
    required ApiClient apiClient,
    RequestsApi? apiOverride,
  }) {
    api = apiOverride ?? RequestsApi(apiClient);
  }

  bool loading = false;
  String? error;

  MetaModel? meta;
  List<RequestModel> requests = [];
  List<OfferModel> offers = [];

  // [FIX-BADGE-01] الحالات التي تعني أن الطلب ما زال متاحاً فعلياً لعروض
  // الفنيين (لم يُقبل عرض عليه بعد ولم يُلغَ). مصدر وحيد يُستخدم في كل مكان
  // (تبويب "جديدة"، شاشة الطلبات الجديدة، لوحة الفني الرئيسية) بدل تكرار
  // نفس شرط الحالة في عدة ملفات.
  static const List<String> _availableStatuses = ['بانتظار العروض', 'وصلت عروض'];

  /// الطلبات المتاحة فعلياً حالياً لعروض الفني (تستثني المقبولة/الجارية/
  /// المكتملة/الملغاة/غير المتاحة). لا علاقة لهذا بعدد الإشعارات غير المقروءة.
  List<RequestModel> get availableNewRequests {
    return requests.where((r) => _availableStatuses.contains(r.status)).toList();
  }

  int get availableNewRequestsCount => availableNewRequests.length;

  // دمج تحديثات Socket المتقاربة في طلب واحد بدل تشغيل عدة GET متزامنة.
  bool _requestsRefreshRunning = false;
  bool _requestsRefreshPending = false;

  Future<void> loadMeta({bool force = false}) async {
    try {
      // [FIX-SERVICES-01] force=true يُستخدم عند وصول حدث services-updated
      // عبر Socket.IO، لإعادة الجلب رغم وجود نسخة مخبَّأة سابقاً.
      if (force || meta == null) meta = await api.getMeta();
      notifyListeners();
    } catch (e) {
      error = e is ApiException ? e.message : 'حدث خطأ';
      notifyListeners();
    }
  }

  Future<void> loadRequests({bool silent = false}) async {
    if (_requestsRefreshRunning) {
      _requestsRefreshPending = true;
      return;
    }

    _requestsRefreshRunning = true;
    if (!silent) _setLoading(true);

    try {
      do {
        _requestsRefreshPending = false;
        requests = await api.getRequests();
        error = null;
        if (silent) notifyListeners();
      } while (_requestsRefreshPending);
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل الطلبات';
      if (silent) notifyListeners();
    } finally {
      _requestsRefreshRunning = false;
      if (!silent) _setLoading(false);
    }
  }

  /// [FIX-BADGE-01] تحديث محلي فوري لحالة طلب واحد فور وصول حدث Socket.IO
  /// (requests-updated / offer-accepted)، دون انتظار رحلة شبكة كاملة. هذا ما
  /// يجعل الطلب يختفي فوراً من "الطلبات الجديدة" وينخفض العداد مباشرة عند
  /// قبول عرضه، بدل أن يبقى العداد "عالقاً" لحين اكتمال التحديث الصامت
  /// (الذي ما زال يُستدعى بعدها للتأكد من مطابقة حالة الخادم).
  void applyRequestStatusUpdate({
    required int requestId,
    required String status,
    int? technicianId,
  }) {
    final index = requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;

    final current = requests[index];
    if (current.status == status &&
        (technicianId == null || current.technicianId == technicianId)) {
      return;
    }

    requests[index] = current.copyWith(status: status, technicianId: technicianId);
    notifyListeners();
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