import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/admin_stats_model.dart';
import '../../../models/admin_user_model.dart';
import '../../../models/support_ticket_model.dart';

class AdminApi {
  final ApiClient apiClient;

  AdminApi(this.apiClient);

  Future<AdminStatsModel> getStats() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.adminStats);
      final data = Map<String, dynamic>.from(response.data);
      return AdminStatsModel.fromJson(
        Map<String, dynamic>.from(data['stats'] ?? {}),
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<AdminUserModel>> getUsers() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.adminUsers);
      final data = Map<String, dynamic>.from(response.data);

      return (data['users'] as List? ?? [])
          .map((e) => AdminUserModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// [FIX-SUSPEND-01] reason اختياري — يُرسَل فقط عند وجوده، فلا يغيّر شكل
  /// الطلب لأي استدعاء قديم (تفعيل حساب مثلاً لا يحتاج سبباً).
  Future<void> toggleUser(int id, {String? reason}) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.adminToggleUser(id),
        data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// [FIX-ADMINPROFILE-01] بروفايل مستخدم كامل + تاريخه (طلبات/عروض/دفتر حساب).
  Future<Map<String, dynamic>> getUserDetail(int id) async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.adminUserDetail(id));
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// [FIX-ROLECHANGE-01] تحويل دور مستخدم (super admin فقط بالسيرفر). حقول
  /// الفني مطلوبة فقط عند التحويل *إلى* فني.
  Future<AdminUserModel> changeUserRole({
    required int id,
    required String role,
    String? nationalNumber,
    String? services,
    String? areas,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.adminUserRole(id),
        data: {
          'role': role,
          if (nationalNumber != null) 'national_number': nationalNumber.trim(),
          if (services != null) 'services': services.trim(),
          if (areas != null) 'areas': areas.trim(),
        },
      );
      final data = Map<String, dynamic>.from(response.data);
      return AdminUserModel.fromJson(Map<String, dynamic>.from(data['user']));
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// [FIX-VERIFY-01] توثيق فني.
  Future<void> verifyTechnician(int id) async {
    try {
      await apiClient.dio.post(ApiEndpoints.adminUserVerify(id));
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// [FIX-LEDGER-01] سجل حركات مالية عبر المنصة — مقصور على الأدمن.
  Future<Map<String, dynamic>> getLedger({
    int limit = 50,
    int offset = 0,
    int? userId,
    String? type,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiEndpoints.adminLedger,
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (userId != null) 'user_id': userId,
          if (type != null && type.isNotEmpty) 'type': type,
        },
      );
      final data = Map<String, dynamic>.from(response.data);
      return {
        'entries': (data['entries'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        'total': data['total'] ?? 0,
      };
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// [FIX-MODERATION-01] تحديث حالة متابعة مخالفة شات أو بلاغ رسالة.
  Future<void> updateViolationStatus({required int id, required String status}) async {
    try {
      await apiClient.dio.post(ApiEndpoints.chatViolationStatus(id), data: {'status': status});
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> updateMessageReportStatus({required int id, required String status}) async {
    try {
      await apiClient.dio.post(ApiEndpoints.messageReportStatus(id), data: {'status': status});
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTopups() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.topups);
      final data = Map<String, dynamic>.from(response.data);

      return (data['topups'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> reviewTopup({
    required int id,
    required String status,
    String? note,
  }) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.adminReviewTopup(id),
        data: {
          'status': status,
          'admin_note': note ?? '',
        },
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<SupportTicketModel>> getSupportTickets() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.support);
      final data = Map<String, dynamic>.from(response.data);

      return (data['tickets'] as List? ?? [])
          .map(
            (e) => SupportTicketModel.fromJson(Map<String, dynamic>.from(e)),
      )
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> updateSupportStatus({
    required int ticketId,
    required String status,
  }) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.supportStatus(ticketId),
        data: {'status': status},
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<Map<String, dynamic>> getMeta() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.meta);
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> createService({
    required String name,
    required String icon,
  }) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.adminServices,
        data: {
          'name': name.trim(),
          'icon': icon.trim().isEmpty ? '🔧' : icon.trim(),
        },
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// [FIX-SERVICES-01] كل المهن (فعّالة وغير فعّالة) — لشاشة إدارة الأدمن.
  Future<List<Map<String, dynamic>>> getAllServices() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.adminServices);
      final data = Map<String, dynamic>.from(response.data);
      return (data['services'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// [FIX-SERVICES-01] تفعيل/تعطيل مهنة — البديل الآمن للحذف النهائي.
  Future<void> toggleService(int id, bool isActive) async {
    try {
      await apiClient.dio.patch(
        ApiEndpoints.adminServiceDelete(id),
        data: {'is_active': isActive},
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// [FIX-SERVICES-03] تعديل اسم/أيقونة مهنة — نفس مسار PATCH المستخدم
  /// بالتفعيل/التعطيل، بدون أي endpoint إضافي مكرر.
  Future<void> updateService({
    required int id,
    required String name,
    required String icon,
  }) async {
    try {
      await apiClient.dio.patch(
        ApiEndpoints.adminServiceDelete(id),
        data: {'name': name.trim(), 'icon': icon.trim()},
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> createPackage({
    required String name,
    required double amount,
    required double bonus,
    required double commissionPerOrder,
  }) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.adminPackages,
        data: {
          'name': name.trim(),
          'amount': amount,
          'bonus': bonus,
          'commission_per_order': commissionPerOrder,
        },
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> deletePackage(int id) async {
    try {
      await apiClient.dio.delete(ApiEndpoints.adminPackageDelete(id));
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> deleteService(int id) async {
    try {
      await apiClient.dio.delete(ApiEndpoints.adminServiceDelete(id));
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAuditLogs({
    int limit = 50,
    int offset = 0,
    String search = '',
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiEndpoints.adminAuditLogs,
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final data = Map<String, dynamic>.from(response.data);
      return {
        'logs': (data['logs'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        'total': data['total'] ?? 0,
      };
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getAllRequests() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.adminRequests);
      final data = Map<String, dynamic>.from(response.data);
      return (data['requests'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> cancelRequest({required int id, String reason = ''}) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.adminCancelRequest(id),
        data: {'reason': reason.trim()},
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> changeRequestStatus({
    required int id,
    required String status,
  }) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.adminRequestStatus(id),
        data: {'status': status},
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> updateUserProfile({
    required int id,
    required String name,
    required String city,
  }) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.adminUserProfile(id),
        data: {'name': name.trim(), 'city': city.trim()},
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<double> adjustUserBalance({
    required int id,
    required double amount,
    required String reason,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.adminUserBalance(id),
        data: {'amount': amount, 'reason': reason.trim()},
      );
      final data = Map<String, dynamic>.from(response.data);
      return (data['balance'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      await apiClient.dio.delete(ApiEndpoints.adminDeleteUser(id));
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getViolations() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.adminViolations);
      final data = Map<String, dynamic>.from(response.data);
      return (data['violations'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getComplaints() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.adminComplaints);
      final data = Map<String, dynamic>.from(response.data);
      return (data['complaints'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  /// [FIX-UGC-01] بلاغات الرسائل المقدَّمة من المستخدمين (سياسة UGC).
  Future<List<Map<String, dynamic>>> getMessageReports() async {
    try {
      final response =
          await apiClient.dio.get(ApiEndpoints.adminMessageReports);
      final data = Map<String, dynamic>.from(response.data);
      return (data['reports'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> updateComplaintStatus({
    required int id,
    required String status,
  }) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.complaintStatus(id),
        data: {'status': status},
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> updatePackage({
    required int id,
    required String name,
    required double amount,
    required double bonus,
    required double commissionPerOrder,
    bool? isActive,
  }) async {
    try {
      await apiClient.dio.put(
        ApiEndpoints.adminUpdatePackage(id),
        data: {
          'name': name.trim(),
          'amount': amount,
          'bonus': bonus,
          'commission_per_order': commissionPerOrder,
          if (isActive != null) 'is_active': isActive,
        },
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }
}