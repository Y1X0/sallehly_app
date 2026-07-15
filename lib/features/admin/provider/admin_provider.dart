import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../models/admin_stats_model.dart';
import '../../../models/admin_user_model.dart';
import '../../../models/support_ticket_model.dart';
import '../data/admin_api.dart';

class AdminProvider extends ChangeNotifier {
  late final AdminApi api;

  AdminProvider({
    required ApiClient apiClient,
  }) {
    api = AdminApi(apiClient);
  }

  bool loading = false;
  bool actionLoading = false;
  String? error;

  AdminStatsModel stats = AdminStatsModel.empty;
  List<AdminUserModel> users = [];
  List<Map<String, dynamic>> topups = [];
  List<SupportTicketModel> tickets = [];
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> packages = [];

  List<Map<String, dynamic>> auditLogs = [];
  int auditTotal = 0;
  bool auditLoading = false;

  List<Map<String, dynamic>> allRequests = [];
  bool requestsLoading = false;

  List<Map<String, dynamic>> violations = [];
  List<Map<String, dynamic>> complaints = [];
  // [FIX-UGC-01] بلاغات الرسائل (سياسة UGC)
  List<Map<String, dynamic>> messageReports = [];
  bool moderationLoading = false;

  Future<void> loadDashboard() async {
    _setLoading(true);

    try {
      stats = await api.getStats();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل الإحصائيات';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadUsers() async {
    _setLoading(true);

    try {
      users = await api.getUsers();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل المستخدمين';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleUser(int id) async {
    actionLoading = true;
    notifyListeners();

    try {
      await api.toggleUser(id);
      users = await api.getUsers();
      stats = await api.getStats();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحديث المستخدم';
      rethrow;
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTopups() async {
    _setLoading(true);

    try {
      topups = await api.getTopups();
      stats = await api.getStats();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل الشحن';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reviewTopup({
    required int id,
    required String status,
    String? note,
  }) async {
    actionLoading = true;
    notifyListeners();

    try {
      await api.reviewTopup(id: id, status: status, note: note);
      topups = await api.getTopups();
      stats = await api.getStats();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر مراجعة الشحن';
      rethrow;
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSupport() async {
    _setLoading(true);

    try {
      tickets = await api.getSupportTickets();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل الدعم';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateSupportStatus({
    required int ticketId,
    required String status,
  }) async {
    actionLoading = true;
    notifyListeners();

    try {
      await api.updateSupportStatus(ticketId: ticketId, status: status);
      tickets = await api.getSupportTickets();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحديث التذكرة';
      rethrow;
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMeta() async {
    _setLoading(true);

    try {
      final meta = await api.getMeta();

      // [FIX-SERVICES-01] /meta العام أصبح يُظهر المهن الفعّالة فقط — شاشة
      // إدارة الأدمن تحتاج رؤية كل المهن (فعّالة وغير فعّالة) لتقدر تُفعّل
      // مهنة معطّلة لاحقاً، فتُجلب من endpoint مخصص للأدمن بدلاً من /meta.
      services = await api.getAllServices();

      packages = (meta['packages'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل الإعدادات';
    } finally {
      _setLoading(false);
    }
  }

  /// [FIX-SERVICES-01] تفعيل/تعطيل مهنة بدل حذفها نهائياً.
  Future<void> toggleService(int id, bool isActive) async {
    actionLoading = true;
    notifyListeners();

    try {
      await api.toggleService(id, isActive);
      await loadMeta();
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  /// [FIX-SERVICES-03] تعديل اسم/أيقونة مهنة موجودة.
  Future<void> updateService({
    required int id,
    required String name,
    required String icon,
  }) async {
    actionLoading = true;
    notifyListeners();

    try {
      await api.updateService(id: id, name: name, icon: icon);
      await loadMeta();
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> createService({
    required String name,
    required String icon,
  }) async {
    actionLoading = true;
    notifyListeners();

    try {
      await api.createService(name: name, icon: icon);
      await loadMeta();
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteService(int id) async {
    actionLoading = true;
    notifyListeners();

    try {
      await api.deleteService(id);
      await loadMeta();
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> deletePackage(int id) async {
    actionLoading = true;
    notifyListeners();

    try {
      await api.deletePackage(id);
      await loadMeta();
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> createPackage({
    required String name,
    required double amount,
    required double bonus,
    required double commissionPerOrder,
  }) async {
    actionLoading = true;
    notifyListeners();

    try {
      await api.createPackage(
        name: name,
        amount: amount,
        bonus: bonus,
        commissionPerOrder: commissionPerOrder,
      );
      await loadMeta();
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAuditLogs({String search = ''}) async {
    auditLoading = true;
    notifyListeners();

    try {
      final result = await api.getAuditLogs(search: search, limit: 100);
      auditLogs = (result['logs'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      auditTotal = result['total'] is int ? result['total'] as int : 0;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل سجل العمليات';
    } finally {
      auditLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAllRequests() async {
    requestsLoading = true;
    notifyListeners();

    try {
      allRequests = await api.getAllRequests();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل الطلبات';
    } finally {
      requestsLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelRequest({required int id, String reason = ''}) async {
    actionLoading = true;
    notifyListeners();

    try {
      await api.cancelRequest(id: id, reason: reason);
      allRequests = await api.getAllRequests();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر إلغاء الطلب';
      rethrow;
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> changeRequestStatus({
    required int id,
    required String status,
  }) async {
    actionLoading = true;
    notifyListeners();

    try {
      await api.changeRequestStatus(id: id, status: status);
      allRequests = await api.getAllRequests();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تغيير حالة الطلب';
      rethrow;
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserProfile({
    required int id,
    required String name,
    required String city,
  }) async {
    actionLoading = true;
    notifyListeners();
    try {
      await api.updateUserProfile(id: id, name: name, city: city);
      users = await api.getUsers();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تعديل البيانات';
      rethrow;
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> adjustUserBalance({
    required int id,
    required double amount,
    required String reason,
  }) async {
    actionLoading = true;
    notifyListeners();
    try {
      await api.adjustUserBalance(id: id, amount: amount, reason: reason);
      users = await api.getUsers();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تعديل الرصيد';
      rethrow;
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteUser(int id) async {
    actionLoading = true;
    notifyListeners();
    try {
      await api.deleteUser(id);
      users = await api.getUsers();
      stats = await api.getStats();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر حذف المستخدم';
      rethrow;
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadModeration() async {
    moderationLoading = true;
    notifyListeners();
    try {
      violations = await api.getViolations();
      complaints = await api.getComplaints();
      messageReports = await api.getMessageReports();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل بيانات المراقبة';
    } finally {
      moderationLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateComplaintStatus({
    required int id,
    required String status,
  }) async {
    try {
      await api.updateComplaintStatus(id: id, status: status);
      // تحديث محلي فوري بدل انتظار إعادة تحميل كامل القائمة من السيرفر
      final index = complaints.indexWhere((c) => c['id'] == id);
      if (index != -1) {
        complaints[index] = {...complaints[index], 'status': status};
        notifyListeners();
      }
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحديث حالة الشكوى';
      rethrow;
    }
  }

  Future<void> updatePackage({
    required int id,
    required String name,
    required double amount,
    required double bonus,
    required double commissionPerOrder,
  }) async {
    actionLoading = true;
    notifyListeners();
    try {
      await api.updatePackage(
        id: id,
        name: name,
        amount: amount,
        bonus: bonus,
        commissionPerOrder: commissionPerOrder,
      );
      await loadMeta();
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تعديل الباقة';
      rethrow;
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  // ─────────────── تحديثات لحظية صامتة (عبر السوكت) ───────────────
  // تُحدّث القوائم في الخلفية دون مؤشّر تحميل، فقط إذا سبق تحميلها.

  Future<void> refreshRequestsSilent() async {
    try {
      allRequests = await api.getAllRequests();
      stats = await api.getStats();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshTopupsSilent() async {
    try {
      topups = await api.getTopups();
      stats = await api.getStats();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshSupportSilent() async {
    try {
      tickets = await api.getSupportTickets();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshModerationSilent() async {
    try {
      violations = await api.getViolations();
      complaints = await api.getComplaints();
      messageReports = await api.getMessageReports();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshUsersSilent() async {
    try {
      users = await api.getUsers();
      stats = await api.getStats();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshStatsSilent() async {
    try {
      stats = await api.getStats();
      notifyListeners();
    } catch (_) {}
  }

  void _setLoading(bool value) {
    loading = value;
    notifyListeners();
  }
}