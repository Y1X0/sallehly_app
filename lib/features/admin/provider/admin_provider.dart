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
    AdminApi? apiOverride,
  }) {
    api = apiOverride ?? AdminApi(apiClient);
  }

  bool loading = false;
  bool actionLoading = false;

  // [SEC-FIX-ADMINDOUBLESUBMIT-02] راجع DECISIONS.md — يخلف
  // SEC-FIX-ADMINDOUBLESUBMIT-01 (كانت تحرس فقط reviewTopup/adjustUserBalance
  // بحارسين مخصَّصين منفصلين، وتترك الـ15 دالة كتابة الأخرى بلا حارس). كل
  // الـ17 دالة كتابة بهذا الملف تمرّ الآن إجبارياً عبر _runGuarded أدناه —
  // ليس فقط لسدّ الفجوة، بل لجعلها بنيوية: دالة كتابة جديدة تُضاف لاحقاً بلا
  // المرور عبر _runGuarded تكون شاذّة بصرياً مقارنة بكل نظيراتها، لا فجوة
  // صامتة يكتشفها أحد بالصدفة لاحقاً (نفس فئة "تعطيل الزر بالواجهة يبدو
  // حماية لكنه ليس كذلك دائماً" الأصلية — الحل هنا حارس واحد لا نسخ متكرّرة
  // منه). `_inFlightActions` مجموعة (لا حارس منفصل بكل دالة) لأن أكثر من
  // إجراء *مختلف* قد يعمل بشكل مشروع بنفس اللحظة (مثال: تعديل رصيد مستخدم
  // بينما مراجعة شحن منفصلة قيد التنفيذ) — actionKey فريد لكل دالة يمنع فقط
  // تكرار *نفس* الدالة، لا يمنع دالتين مختلفتين من العمل معاً.
  final Set<String> _inFlightActions = {};

  Future<void> _runGuarded(String actionKey, Future<void> Function() action) async {
    if (_inFlightActions.contains(actionKey)) return;
    _inFlightActions.add(actionKey);
    actionLoading = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _inFlightActions.remove(actionKey);
      // actionLoading يعكس "أي إجراء لا يزال قيد التنفيذ"، لا مجرد "هذا
      // الإجراء انتهى" — بدون هذا، إجراءان مختلفان متداخلان زمنياً كانا
      // يجعلان actionLoading يعود false بمجرد انتهاء الأسرع منهما، بينما
      // الآخر لا يزال قيد التنفيذ فعلياً (يُصلِح خللاً كامناً كان موجوداً
      // أصلاً بالكود القديم، لا يُدخِل جديداً).
      actionLoading = _inFlightActions.isNotEmpty;
      notifyListeners();
    }
  }
  // [L10N-TODO] كل رسائل fallback الفشل بهذا الملف (طبقة provider، بلا
  // BuildContext) عربية ثابتة حالياً — 24 رسالة مختلفة عبر كل دوال هذا
  // الملف، يستهلك `error` منها عدد كبير من شاشات الأدمن (بعضها مُهاجَر
  // بالفعل وترك admin.error! نفسه مؤجَّلاً بنفس الاتفاقية: admin_support_
  // screen.dart #36، admin_topups_screen.dart #55، admin_audit_screen.dart
  // #34، admin_ledger_screen.dart #26). `userDetailError` كذلك بلا تغيير.
  // لا تغيير وظيفي هنا.
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
  // [FIX-ADMINPAGINATION-01] راجع تعليق ledgerLoadingMore أعلاه — نفس المشكلة
  // ونفس الحل تماماً لسجل عمليات الأدمن.
  bool auditLoadingMore = false;
  String _auditSearch = '';

  List<Map<String, dynamic>> allRequests = [];
  bool requestsLoading = false;

  List<Map<String, dynamic>> violations = [];
  List<Map<String, dynamic>> complaints = [];
  // [FIX-UGC-01] بلاغات الرسائل (سياسة UGC)
  List<Map<String, dynamic>> messageReports = [];
  bool moderationLoading = false;

  // [FIX-ADMINPROFILE-01] بروفايل مستخدم واحد كامل بشاشته الخاصة.
  Map<String, dynamic>? userDetail;
  bool userDetailLoading = false;
  String? userDetailError;

  // [FEAT-ADMINREQUESTDETAIL-01] راجع DECISIONS.md — صورة كاملة لطلب واحد
  // (الطلب + العروض + المحادثة) بشاشته الخاصة، نفس نمط userDetail أعلاه تماماً.
  Map<String, dynamic>? requestDetail;
  bool requestDetailLoading = false;
  String? requestDetailError;

  // [FIX-LEDGER-01] دفتر الحساب الشامل بلوحة الأدمن.
  List<Map<String, dynamic>> ledgerEntries = [];
  int ledgerTotal = 0;
  bool ledgerLoading = false;
  // [FIX-ADMINPAGINATION-01] راجع DECISIONS.md — كان الحد الأقصى 100 صفاً
  // ثابتاً بلا أي تصفّح لما بعده رغم أن الخادم يدعم limit/offset كاملاً
  // (routes/admin.routes.js) والعميل نفسه يحمل معامل offset جاهزاً
  // (AdminApi.getLedger) بلا أي استخدام. _ledgerUserId يُحفَظ من آخر
  // loadLedger() صريح حتى تستخدم loadMoreLedger() نفس الفلتر بلا الحاجة
  // لتمريره يدوياً بكل استدعاء.
  bool ledgerLoadingMore = false;
  int? _ledgerUserId;
  static const _adminPageSize = 100;

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

  Future<void> toggleUser(int id, {String? reason}) {
    return _runGuarded('toggleUser', () async {
      try {
        await api.toggleUser(id, reason: reason);
        users = await api.getUsers();
        stats = await api.getStats();
        error = null;
      } catch (e) {
        error = e is ApiException ? e.message : 'تعذر تحديث المستخدم';
        rethrow;
      }
    });
  }

  /// [FIX-ADMINPROFILE-01] يُحمَّل عند فتح شاشة تفاصيل مستخدم واحد.
  Future<void> loadUserDetail(int id) async {
    userDetailLoading = true;
    userDetailError = null;
    notifyListeners();

    try {
      userDetail = await api.getUserDetail(id);
      userDetailError = null;
    } catch (e) {
      userDetailError = e is ApiException ? e.message : 'تعذر تحميل بيانات المستخدم';
    } finally {
      userDetailLoading = false;
      notifyListeners();
    }
  }

  void clearUserDetail() {
    userDetail = null;
    userDetailError = null;
  }

  /// [FEAT-ADMINREQUESTDETAIL-01] يُحمَّل عند فتح شاشة تفاصيل طلب واحد.
  Future<void> loadRequestDetail(int id) async {
    requestDetailLoading = true;
    requestDetailError = null;
    notifyListeners();

    try {
      requestDetail = await api.getRequestDetail(id);
      requestDetailError = null;
    } catch (e) {
      requestDetailError = e is ApiException ? e.message : 'تعذر تحميل تفاصيل الطلب';
    } finally {
      requestDetailLoading = false;
      notifyListeners();
    }
  }

  void clearRequestDetail() {
    requestDetail = null;
    requestDetailError = null;
  }

  /// [SEC-FIX-CHATCLEAR-01] راجع DECISIONS.md — يُستدعى عند تسجيل الخروج
  /// (app.dart's authProvider.onLoggedOut). بدونها، بيانات حسّاسة لمستخدمي
  /// المنصة كلهم (قائمة مستخدمين، سجل تدقيق، بلاغات، شكاوى، دفتر حساب) تبقى
  /// بالذاكرة حتى دخول حساب أدمن تالٍ على نفس الجهاز. `services`/`packages`
  /// مُستثناتان عمداً — قوائم مرجعية عامة (نفسها لكل الأدمنز)، لا بيانات
  /// خاصة بحساب مُعيَّن، فتنظيفها فقط يهدر استدعاء شبكة إضافي بلا فائدة أمنية.
  /// [FEAT-ADMINREQUESTDETAIL-01] `requestDetail` أخطر ما يُمسَح هنا فعلياً —
  /// يحمل محادثة خاصة كاملة بين عميل وفني (راجع GET /admin/requests/:id)،
  /// لا مجرد بيانات بروفايل.
  void clear() {
    stats = AdminStatsModel.empty;
    users = [];
    topups = [];
    tickets = [];
    auditLogs = [];
    auditTotal = 0;
    allRequests = [];
    violations = [];
    complaints = [];
    messageReports = [];
    userDetail = null;
    userDetailError = null;
    requestDetail = null;
    requestDetailError = null;
    ledgerEntries = [];
    ledgerTotal = 0;
    _ledgerUserId = null;
    error = null;
    notifyListeners();
  }

  /// [FIX-ROLECHANGE-01] تحويل دور مستخدم (super admin فقط — السيرفر يرفض
  /// غير ذلك بـ403 بغض النظر عمّا تعرضه الواجهة).
  Future<void> changeUserRole({
    required int id,
    required String role,
    String? nationalNumber,
    String? services,
    String? areas,
  }) {
    return _runGuarded('changeUserRole', () async {
      try {
        await api.changeUserRole(
          id: id,
          role: role,
          nationalNumber: nationalNumber,
          services: services,
          areas: areas,
        );
        users = await api.getUsers();
        if (userDetail != null) await loadUserDetail(id);
        error = null;
      } catch (e) {
        error = e is ApiException ? e.message : 'تعذر تحويل دور المستخدم';
        rethrow;
      }
    });
  }

  /// [FIX-VERIFY-01] توثيق فني.
  Future<void> verifyTechnician(int id) {
    return _runGuarded('verifyTechnician', () async {
      try {
        await api.verifyTechnician(id);
        users = await api.getUsers();
        error = null;
      } catch (e) {
        error = e is ApiException ? e.message : 'تعذر توثيق الفني';
        rethrow;
      }
    });
  }

  /// [FIX-LEDGER-01] دفتر الحساب الشامل — اختياري الفلترة حسب مستخدم واحد.
  Future<void> loadLedger({int? userId}) async {
    _ledgerUserId = userId;
    ledgerLoading = true;
    notifyListeners();
    try {
      final result = await api.getLedger(userId: userId, limit: _adminPageSize);
      ledgerEntries = result['entries'] as List<Map<String, dynamic>>;
      ledgerTotal = result['total'] is int ? result['total'] as int : 0;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل دفتر الحساب';
    } finally {
      ledgerLoading = false;
      notifyListeners();
    }
  }

  /// [FIX-ADMINPAGINATION-01] الصفحة التالية بنفس فلتر آخر loadLedger() —
  /// لا شيء يحدث لو تحميل صفحة بالفعل قيد التنفيذ، أو لو كل الصفوف محمَّلة أصلاً.
  Future<void> loadMoreLedger() async {
    if (ledgerLoading || ledgerLoadingMore) return;
    if (ledgerEntries.length >= ledgerTotal) return;
    ledgerLoadingMore = true;
    notifyListeners();
    try {
      final result = await api.getLedger(
        userId: _ledgerUserId,
        limit: _adminPageSize,
        offset: ledgerEntries.length,
      );
      ledgerEntries = [
        ...ledgerEntries,
        ...result['entries'] as List<Map<String, dynamic>>,
      ];
      ledgerTotal = result['total'] is int ? result['total'] as int : ledgerTotal;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل دفتر الحساب';
    } finally {
      ledgerLoadingMore = false;
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
  }) {
    return _runGuarded('reviewTopup', () async {
      try {
        await api.reviewTopup(id: id, status: status, note: note);
        topups = await api.getTopups();
        stats = await api.getStats();
        error = null;
      } catch (e) {
        error = e is ApiException ? e.message : 'تعذر مراجعة الشحن';
        rethrow;
      }
    });
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
  }) {
    return _runGuarded('updateSupportStatus', () async {
      try {
        await api.updateSupportStatus(ticketId: ticketId, status: status);
        tickets = await api.getSupportTickets();
        error = null;
      } catch (e) {
        error = e is ApiException ? e.message : 'تعذر تحديث التذكرة';
        rethrow;
      }
    });
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
  Future<void> toggleService(int id, bool isActive) {
    return _runGuarded('toggleService', () async {
      await api.toggleService(id, isActive);
      await loadMeta();
    });
  }

  /// [FIX-SERVICES-03] تعديل اسم/أيقونة مهنة موجودة.
  Future<void> updateService({
    required int id,
    required String name,
    required String icon,
  }) {
    return _runGuarded('updateService', () async {
      await api.updateService(id: id, name: name, icon: icon);
      await loadMeta();
    });
  }

  Future<void> createService({
    required String name,
    required String icon,
  }) {
    return _runGuarded('createService', () async {
      await api.createService(name: name, icon: icon);
      await loadMeta();
    });
  }

  Future<void> deleteService(int id) {
    return _runGuarded('deleteService', () async {
      await api.deleteService(id);
      await loadMeta();
    });
  }

  Future<void> deletePackage(int id) {
    return _runGuarded('deletePackage', () async {
      await api.deletePackage(id);
      await loadMeta();
    });
  }

  Future<void> createPackage({
    required String name,
    required double amount,
    required double bonus,
    required double commissionPerOrder,
  }) {
    return _runGuarded('createPackage', () async {
      await api.createPackage(
        name: name,
        amount: amount,
        bonus: bonus,
        commissionPerOrder: commissionPerOrder,
      );
      await loadMeta();
    });
  }

  Future<void> loadAuditLogs({String search = ''}) async {
    _auditSearch = search;
    auditLoading = true;
    notifyListeners();

    try {
      final result = await api.getAuditLogs(search: search, limit: _adminPageSize);
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

  /// [FIX-ADMINPAGINATION-01] الصفحة التالية بنفس بحث آخر loadAuditLogs().
  Future<void> loadMoreAuditLogs() async {
    if (auditLoading || auditLoadingMore) return;
    if (auditLogs.length >= auditTotal) return;
    auditLoadingMore = true;
    notifyListeners();
    try {
      final result = await api.getAuditLogs(
        search: _auditSearch,
        limit: _adminPageSize,
        offset: auditLogs.length,
      );
      auditLogs = [
        ...auditLogs,
        ...(result['logs'] as List).map((e) => Map<String, dynamic>.from(e)),
      ];
      auditTotal = result['total'] is int ? result['total'] as int : auditTotal;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل سجل العمليات';
    } finally {
      auditLoadingMore = false;
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

  Future<void> cancelRequest({required int id, String reason = ''}) {
    return _runGuarded('cancelRequest', () async {
      try {
        await api.cancelRequest(id: id, reason: reason);
        allRequests = await api.getAllRequests();
        error = null;
      } catch (e) {
        error = e is ApiException ? e.message : 'تعذر إلغاء الطلب';
        rethrow;
      }
    });
  }

  Future<void> changeRequestStatus({
    required int id,
    required String status,
  }) {
    return _runGuarded('changeRequestStatus', () async {
      try {
        await api.changeRequestStatus(id: id, status: status);
        allRequests = await api.getAllRequests();
        error = null;
      } catch (e) {
        error = e is ApiException ? e.message : 'تعذر تغيير حالة الطلب';
        rethrow;
      }
    });
  }

  Future<void> updateUserProfile({
    required int id,
    required String name,
    required String city,
  }) {
    return _runGuarded('updateUserProfile', () async {
      try {
        await api.updateUserProfile(id: id, name: name, city: city);
        users = await api.getUsers();
        error = null;
      } catch (e) {
        error = e is ApiException ? e.message : 'تعذر تعديل البيانات';
        rethrow;
      }
    });
  }

  Future<void> adjustUserBalance({
    required int id,
    required double amount,
    required String reason,
  }) {
    return _runGuarded('adjustUserBalance', () async {
      try {
        await api.adjustUserBalance(id: id, amount: amount, reason: reason);
        users = await api.getUsers();
        error = null;
      } catch (e) {
        error = e is ApiException ? e.message : 'تعذر تعديل الرصيد';
        rethrow;
      }
    });
  }

  Future<void> deleteUser(int id) {
    return _runGuarded('deleteUser', () async {
      try {
        await api.deleteUser(id);
        users = await api.getUsers();
        stats = await api.getStats();
        error = null;
      } catch (e) {
        error = e is ApiException ? e.message : 'تعذر حذف المستخدم';
        rethrow;
      }
    });
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

  /// [FIX-MODERATION-01] تحديث حالة متابعة مخالفة شات — نفس نمط
  /// updateComplaintStatus تماماً (تحديث محلي فوري بدل إعادة تحميل كامل).
  Future<void> updateViolationStatus({required int id, required String status}) async {
    try {
      await api.updateViolationStatus(id: id, status: status);
      final index = violations.indexWhere((v) => v['id'] == id);
      if (index != -1) {
        violations[index] = {...violations[index], 'status': status};
        notifyListeners();
      }
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحديث حالة المخالفة';
      rethrow;
    }
  }

  Future<void> updateMessageReportStatus({required int id, required String status}) async {
    try {
      await api.updateMessageReportStatus(id: id, status: status);
      final index = messageReports.indexWhere((r) => r['id'] == id);
      if (index != -1) {
        messageReports[index] = {...messageReports[index], 'status': status};
        notifyListeners();
      }
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحديث حالة البلاغ';
      rethrow;
    }
  }

  Future<void> updatePackage({
    required int id,
    required String name,
    required double amount,
    required double bonus,
    required double commissionPerOrder,
    bool? isActive,
  }) {
    return _runGuarded('updatePackage', () async {
      try {
        await api.updatePackage(
          id: id,
          name: name,
          amount: amount,
          bonus: bonus,
          commissionPerOrder: commissionPerOrder,
          isActive: isActive,
        );
        await loadMeta();
      } catch (e) {
        error = e is ApiException ? e.message : 'تعذر تعديل الباقة';
        rethrow;
      }
    });
  }

  /// [FIX-PACKAGEACTIVE-01] تفعيل/تعطيل باقة بدون تغيير بقية بياناتها.
  Future<void> togglePackageActive(Map<String, dynamic> package) async {
    await updatePackage(
      id: int.tryParse('${package['id']}') ?? 0,
      name: '${package['name'] ?? ''}',
      amount: double.tryParse('${package['amount'] ?? 0}') ?? 0,
      bonus: double.tryParse('${package['bonus'] ?? 0}') ?? 0,
      commissionPerOrder: double.tryParse('${package['commission_per_order'] ?? 2}') ?? 2,
      isActive: package['is_active'] == 0,
    );
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