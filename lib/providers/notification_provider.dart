import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api/api_client.dart';
import '../features/notifications/data/notifications_api.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';

class NotificationProvider extends ChangeNotifier {
  UserModel? currentUser;

  /// [NOTIF-FLUTTER-PHASE1] apiClient اختياري عمداً (وليس required كبقية
  /// الـProviders الأخرى بهذا الملف مثل SupportProvider) — عدة اختبارات
  /// حالية (test/models/new_requests_badge_test.dart،
  /// test/widgets/splash_dedup_test.dart، test/widgets/nav_chat_badge_test.dart)
  /// تبني `NotificationProvider()` بلا أي معامل. جعله اختيارياً يحافظ على كل
  /// هذه المسارات كما هي بلا أي تعديل، بينما app.dart (التطبيق الفعلي) يمرّره
  /// الآن فعلياً. بدون apiClient، الطرق الثلاث الجديدة أدناه لا تفعل شيئاً
  /// بصمت (نفس فلسفة "فشل الشبكة لا يُسقط التطبيق").
  final NotificationsApi? _api;

  NotificationProvider({ApiClient? apiClient})
      : _api = apiClient != null ? NotificationsApi(apiClient) : null;

  final List<NotificationModel> _items = [];

  List<NotificationModel> get items => List.unmodifiable(_items);

  List<NotificationModel> get requestItems {
    return _items.where((e) => !e.isChat).toList();
  }

  /// [FIX-NOTIF-03] منطق تضمين صريح بدل الاستثناء — هيك أي نوع إشعار جديد
  /// يُضاف مستقبلاً (زي 'service' أو 'topup' أو 'complaint') ما بيتسرّب لهالعداد
  /// إلا إذا أضفناه هون قصداً. هاد بالضبط كان سبب نفس الخلل يلي صلّحناه بتبويب
  /// "الشحن" بلوحة الأدمن، فتجنّبنا نفس النمط هون من جذوره.
  int get requestUnreadCount {
    return _items
        .where((e) => !e.read && (e.isRequest || e.isOffer || e.isWallet))
        .length;
  }

  /// [FIX-BADGE-01] اسم صريح لعدّاد جرس الإشعارات — نفس requestUnreadCount
  /// تماماً (مُبقى عليه لأن أماكن أخرى بالتطبيق ما زالت تستخدمه، مثل تبويب
  /// "طلباتي" للعميل)، لكن بجرس الإشعارات تحديداً نريد اسماً يوضّح أنه عدد
  /// الإشعارات غير المقروءة ولا علاقة له إطلاقاً بعدد الطلبات المتاحة للفني
  /// (ذاك مصدره RequestsProvider.availableNewRequestsCount، مستقل تماماً).
  int get unreadNotificationsCount => requestUnreadCount;

  int get chatUnreadCount {
    return _items.where((e) => !e.read && e.isChat).length;
  }

  /// عدد رسائل الدعم غير المقروءة (تظهر كرقم على أيقونة الدعم).
  int get supportUnreadCount {
    return _items.where((e) => !e.read && e.isSupport).length;
  }

  /// عدد طلبات الشحن غير المقروءة (تظهر كرقم على تبويب "الشحن" بلوحة الأدمن).
  /// [FIX-NOTIF-01] مفصولة عمداً عن requestUnreadCount حتى ما تختلط إشعارات
  /// الشحن مع إشعارات التذاكر/الطلبات/الشكاوى العامة.
  int get topupUnreadCount {
    return _items.where((e) => !e.read && e.isTopup).length;
  }

  void setCurrentUser(UserModel? user) {
    currentUser = user;
    notifyListeners();
  }

  void addNotification({
    required String title,
    required String body,
    required String type,
    int? requestId,
    bool sound = true,
  }) {
    _items.insert(
      0,
      NotificationModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: body,
        type: type,
        requestId: requestId,
        createdAt: DateTime.now(),
      ),
    );

    if (_items.length > 80) {
      _items.removeRange(80, _items.length);
    }

    if (sound) {
      SystemSound.play(SystemSoundType.alert);
    }

    notifyListeners();
  }

  void handleNewRequest(dynamic data) {
    final user = currentUser;
    if (user == null) return;
    if (!user.isTechnician && !user.isAdmin) return;

    final request = data?['request'];
    final requestId = int.tryParse('${request?['id'] ?? 0}') ?? 0;
    final service = '${request?['service'] ?? 'طلب جديد'}';
    final city = '${request?['city'] ?? ''}';

    addNotification(
      title: user.isAdmin ? 'طلب جديد على المنصة' : 'طلب جديد قريب منك',
      body: '$service ${city.isEmpty ? '' : 'في $city'}',
      type: 'request',
      requestId: requestId,
    );
  }

  void handleOfferCreated(dynamic data) {
    final user = currentUser;
    if (user == null) return;
    if (!user.isCustomer && !user.isAdmin) return;

    final requestId = int.tryParse('${data?['requestId'] ?? 0}') ?? 0;

    addNotification(
      title: user.isAdmin ? 'عرض جديد على طلب' : 'تم تقديم عرض جديد',
      body: user.isAdmin
          ? 'فني أرسل عرضاً على طلب رقم $requestId'
          : 'افتح طلبك لمشاهدة عرض الفني',
      type: 'offer',
      requestId: requestId,
    );
  }

  void handleRequestStatus(dynamic data) {
    final request = data?['request'];
    final requestId = int.tryParse('${request?['id'] ?? 0}') ?? 0;
    final status = '${request?['status'] ?? ''}';

    if (status.isEmpty) return;

    addNotification(
      title: 'تحديث على الطلب',
      body: 'حالة الطلب أصبحت: $status',
      type: 'request',
      requestId: requestId,
    );
  }

  /// رقم الطلب المفتوح حالياً في شاشة الدردشة (لمنع إشعار وأنت داخل الغرفة).
  int? activeChatRequestId;

  void setActiveChat(int? requestId) {
    activeChatRequestId = requestId;
  }

  void handleChatNotify(dynamic data) {
    final user = currentUser;
    if (user == null) return;

    final senderId = int.tryParse('${data?['senderId'] ?? 0}') ?? -1;

    // لا تُشعر المُرسِل نفسه إطلاقاً.
    if (senderId == user.id) return;

    final requestId = int.tryParse('${data?['requestId'] ?? 0}') ?? 0;

    // إذا كنت فاتح نفس المحادثة، لا داعي لإشعار — الرسالة ظاهرة أمامك.
    if (requestId != 0 && requestId == activeChatRequestId) return;

    addNotification(
      title: 'رسالة جديدة',
      body: 'وصلتك رسالة جديدة',
      type: 'chat',
      requestId: requestId,
    );
  }

  void handleBalanceUpdated(dynamic data) {
    final status = '${data?['status'] ?? ''}';
    if (status == 'approved') {
      addNotification(
        title: 'تمت الموافقة على الشحن ✅',
        body: 'تم تحديث رصيدك، يمكنك الآن تقديم العروض',
        type: 'wallet',
      );
    } else if (status == 'rejected') {
      addNotification(
        title: 'طلب الشحن مرفوض',
        body: 'لم تتم الموافقة على طلب الشحن، راجع الدعم للمزيد',
        type: 'wallet',
      );
    }
  }

  void handleTopupCreated(dynamic data) {
    final user = currentUser;
    if (user == null || !user.isAdmin) return;

    addNotification(
      title: 'طلب شحن جديد',
      body: 'فني أرسل طلب شحن بانتظار المراجعة',
      type: 'topup',
    );
  }

  void handleSupportCreated(dynamic data) {
    final user = currentUser;
    if (user == null || !user.isAdmin) return;

    addNotification(
      title: 'تذكرة دعم جديدة',
      body: 'يوجد طلب دعم جديد',
      type: 'support',
    );
  }

  /// رقم تذكرة الدعم المفتوحة حالياً على الشاشة (لمنع الإشعار وأنت داخلها).
  int? activeSupportTicketId;

  void setActiveSupportTicket(int? ticketId) {
    activeSupportTicketId = ticketId;
  }

  /// يصل للفني عندما يرسل له الأدمن رسالة دعم. يزيد العدّاد (1، 2، 3...).
  void handleSupportMessage(dynamic data) {
    final user = currentUser;
    if (user == null) return;

    // المُرسِل نفسه لا يُشعَر.
    final senderId = int.tryParse('${data?['senderId'] ?? 0}') ?? -1;
    if (senderId == user.id) return;

    final ticketId = int.tryParse(
      '${data?['ticketId'] ?? data?['ticket_id'] ?? 0}',
    ) ??
        0;

    // إذا كان الفني فاتح نفس التذكرة، لا داعي لإشعار — الرسالة أمامه.
    if (ticketId != 0 && ticketId == activeSupportTicketId) return;

    addNotification(
      title: 'رسالة من الدعم',
      body: '${data?['body'] ?? 'وصلتك رسالة جديدة من الدعم'}',
      type: 'support',
      requestId: ticketId,
    );
  }

  void handleOfferAccepted(dynamic data) {
    final user = currentUser;
    if (user == null) return;
    // يصل هذا الحدث للفني صاحب العرض المقبول.
    if (!user.isTechnician) return;

    final requestId = int.tryParse('${data?['requestId'] ?? 0}') ?? 0;

    addNotification(
      title: 'تم قبول عرضك 🎉',
      body: 'وافق العميل على عرضك، تواصل معه لإتمام الخدمة',
      type: 'offer',
      requestId: requestId,
    );
  }

  void handleChatBadges(dynamic data) {
    // تحديث شارة الرسائل غير المقروءة في القوائم دون صوت/إشعار مرئي.
    notifyListeners();
  }

  /// [FIX-NOTIF-04] بث "خدمة جديدة" لكل المستخدمين (عملاء وفنيين) — بعكس بقية
  /// المعالجات هون، هاي ما بتفلتر حسب الدور لأنها معنية بكل الناس. تصل هالحدث
  /// من الباك إند لكل المتصلين (io.emit بدون تحديد غرفة) لأي تعديل على الخدمات
  /// (created/toggled/edited/deleted)، فنكتفي بحالة 'created' فقط — إضافة خدمة
  /// جديدة فعلاً — لأنه هاد يلي طالبه المستخدم تحديداً، وتجنّباً لإزعاج الكل
  /// بإشعار في كل مرة الأدمن يعدّل أو يعطّل خدمة موجودة أصلاً.
  void handleServiceAdded(dynamic data) {
    final user = currentUser;
    if (user == null) return;

    final type = '${data?['type'] ?? ''}';
    if (type != 'created') return;

    final name = '${data?['name'] ?? ''}';
    if (name.isEmpty) return;

    addNotification(
      title: 'خدمة جديدة 🛠️',
      body: 'تمت إضافة خدمة "$name" — يمكنك الاستفادة منها الآن',
      type: 'service',
    );
  }

  void handleNewComplaint(dynamic data) {
    final user = currentUser;
    if (user == null || !user.isAdmin) return;

    addNotification(
      title: '⚠️ شكوى جديدة',
      body: 'قدّم أحد العملاء شكوى بانتظار المراجعة',
      type: 'complaint',
    );
  }

  /// يعلّم إشعاراً واحداً فقط كمقروء.
  /// عند الضغط على إشعار واحد ينقص العداد بمقدار 1 فقط،
  /// ولا تتأثر بقية الإشعارات غير المقروءة.
  void markNotificationRead(String notificationId) {
    final index = _items.indexWhere((item) => item.id == notificationId);
    if (index == -1 || _items[index].read) return;

    _items[index].read = true;
    notifyListeners();
  }

  void markRequestNotificationsRead() {
    var changed = false;
    for (final item in _items) {
      if (!item.isChat && !item.read) {
        item.read = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void markChatNotificationsRead() {
    for (final item in _items) {
      if (item.isChat) {
        item.read = true;
      }
    }
    notifyListeners();
  }

  /// [FIX-NOTIF-02] تصفير إشعارات محادثة معيّنة فقط (وليس كل المحادثات) — تُستدعى
  /// فور فتح شات معيّن، فينقص عدّاد الجرس ديناميكياً بمقدار إشعارات هالمحادثة بس،
  /// وتبقى إشعارات باقي المحادثات الأخرى غير المقروءة كما هي.
  void markChatNotificationsReadForRequest(int requestId) {
    var changed = false;
    for (final item in _items) {
      if (item.isChat && item.requestId == requestId && !item.read) {
        item.read = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// تُستدعى عند فتح شاشة الدعم → تصفّر عدّاد رسائل الدعم.
  void markSupportNotificationsRead() {
    for (final item in _items) {
      if (item.isSupport) {
        item.read = true;
      }
    }
    notifyListeners();
  }

  /// [FIX-NOTIF-02] تصفير إشعارات تذكرة دعم معيّنة فقط — نفس فكرة الشات تمامًا،
  /// تُستدعى فور فتح تذكرة دعم محددة بدل ما تنتظر تصفير كل التذاكر مع بعض.
  void markSupportNotificationsReadForTicket(int ticketId) {
    var changed = false;
    for (final item in _items) {
      if (item.isSupport && item.requestId == ticketId && !item.read) {
        item.read = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// [FIX-NOTIF-05] تُستدعى عند فتح شاشة "الشحن" بلوحة الأدمن → تصفّر عدّاد
  /// طلبات الشحن غير المقروءة تحديداً (بدون التأثير على عدّادات الدعم/الطلبات).
  void markTopupNotificationsRead() {
    for (final item in _items) {
      if (item.isTopup) {
        item.read = true;
      }
    }
    notifyListeners();
  }

  // ─────────────── [NOTIF-FLUTTER-PHASE1] طبقة الخادم الدائمة ───────────────
  // الطرق الثلاث أدناه تضيف قدرة على الاتصال بـ GET/POST /api/notifications
  // (راجع notifications_api.dart) دون أي تعديل على السلوك المحلي اللحظي
  // القائم على Socket.IO أعلاه (addNotification/handleX/mark...Read) —
  // لا شيء يستدعيها بعد بهذه المرحلة (لا شاشة ولا مستمع socket)، فهي إضافة
  // معزولة بالكامل حالياً، تمهيداً لربطها لاحقاً.

  /// يجلب الإشعارات الدائمة من الخادم (صفحة واحدة، الأحدث أولاً) ويملأ بها
  /// القائمة المحلية. فشل الشبكة يُمتَص بصمت — لا يُسقط التطبيق ولا يمسح أي
  /// إشعار محلي موجود مسبقاً.
  Future<void> loadNotifications({int page = 1, int limit = 20}) async {
    if (_api == null) return;

    try {
      final result = await _api.getNotifications(page: page, limit: limit);

      if (page <= 1) {
        _items
          ..clear()
          ..addAll(result.items);
      } else {
        _items.addAll(result.items);
      }

      notifyListeners();
    } catch (_) {
      // فشل الشبكة لا يُسقط التطبيق — القائمة المحلية الحالية تبقى كما هي.
    }
  }

  /// يعلّم إشعاراً دائماً واحداً كمقروء على الخادم، ثم يحدّث نسخته المحلية
  /// إن كانت موجودة بالقائمة. اسم مختلف عمداً عن markNotificationRead(String)
  /// الحالية أعلاه (تعمل محلياً فقط بمعرّف نصي مُولَّد لحظياً) — Dart لا يسمح
  /// بوجود دالتين بنفس الاسم بمعاملين مختلفي النوع بنفس الصنف، وmarkNotificationRead
  /// الحالية مستخدَمة فعلياً بشاشة الإشعارات (notifications_screen.dart)
  /// ويجب أن تبقى كما هي بالضبط (لا تعديل على الشاشة بهذه المرحلة).
  Future<void> markNotificationReadOnServer(int id) async {
    if (_api == null) return;

    try {
      final updated = await _api.markRead(id);
      final index = _items.indexWhere((item) => item.id == updated.id);
      if (index != -1) {
        _items[index].read = true;
      }
      notifyListeners();
    } catch (_) {
      // فشل الشبكة لا يُسقط التطبيق.
    }
  }

  /// يعلّم كل إشعارات المستخدم الدائمة كمقروءة على الخادم، ثم يعكس نفس
  /// الأثر محلياً على كل عناصر القائمة الحالية.
  Future<void> markAllNotificationsRead() async {
    if (_api == null) return;

    try {
      await _api.markAllRead();
      for (final item in _items) {
        item.read = true;
      }
      notifyListeners();
    } catch (_) {
      // فشل الشبكة لا يُسقط التطبيق.
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}