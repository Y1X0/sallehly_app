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

  // ─────────────── [NOTIF-FLUTTER-PHASE2B] منع تكرار الإشعارات ───────────────
  // الأنواع التالية فقط لها نظير دائم بالخادم (راجع notify() بـ
  // routes/support.routes.js، routes/requests.routes.js، routes/offers.routes.js،
  // routes/topups.routes.js) — 'chat'/'topup'/'service' لحظية بحتة (لا يوجد
  // أي صف خادم لها إطلاقاً)، فمنطق منع التكرار أدناه لا يمسّها نهائياً؛ تبقى
  // تُدرَج دائماً كما كانت قبل هذه المرحلة بالضبط.
  static const Set<String> _persistedTypes = {
    'request',
    'offer',
    'wallet',
    'support',
    'complaint',
  };

  // نافذة زمنية ضيقة عمداً — الهدف الوحيد التقاط سباق التوقيت الحقيقي (وصول
  // Socket.IO ثم تحميل الخادم لنفس الحدث، أو العكس، خلال ثوانٍ قليلة)، وليس
  // منع حدثين مختلفين فعلياً بنفس النوع (مثلاً عرضان منفصلان من فنيين
  // مختلفين على نفس الطلب) من الظهور كلاهما.
  static const Duration _dedupWindow = Duration(seconds: 30);

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
    // [NOTIF-FLUTTER-PHASE2B] لو كان الخادم أرسل بالفعل (بتحميل سابق) إشعاراً
    // دائماً لنفس هذا الحدث تحديداً — سباق توقيت واقعي: استئناف التطبيق
    // يُطلق loadNotifications() في نفس اللحظة تقريباً التي يصل فيها حدث
    // Socket.IO اللحظي لنفس الحدث — لا تُنشئ نسخة ثانية هنا. مقصورة على
    // الأنواع التي لها نظير خادم فعلاً (_persistedTypes)؛ 'chat'/'topup'/
    // 'service' غير متأثرة إطلاقاً وتستمر بالسلوك القديم بالضبط.
    if (_hasRecentPersistedMatch(type: type, requestId: requestId)) return;

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

  /// [NOTIF-FLUTTER-PHASE2B] هل توجد بالقائمة (من أي مصدر) نسخة حديثة جداً
  /// (خلال _dedupWindow) بنفس type — ونفس requestId لو توفّر على الطرفين —
  /// تمثّل على الأرجح نفس الحدث؟ راجع _findUnpersistedMatchIndex للاتجاه
  /// المقابل (خادم يصل بعد إشعار لحظي موجود مسبقاً).
  bool _hasRecentPersistedMatch({required String type, int? requestId}) {
    if (!_persistedTypes.contains(type)) return false;

    final now = DateTime.now();
    for (final item in _items) {
      if (item.type != type) continue;
      if (now.difference(item.createdAt).abs() > _dedupWindow) continue;

      if (requestId != null && item.requestId != null) {
        if (item.requestId != requestId) continue;
      }

      return true;
    }

    return false;
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
  /// [HIGH-FIX-READSYNC-01] الحالة المحلية تُحدَّث فوراً (نفس السلوك السابق
  /// بالضبط — الواجهة لا تنتظر الشبكة إطلاقاً)، ثم يُطلَق مزامنة الخادم
  /// بالخلفية دون انتظارها هنا (fire-and-forget) فقط لو للعنصر serverId
  /// فعلي (أي أنه إشعار له نظير دائم بالخادم — راجع _persistedTypes/
  /// NotificationModel.serverId). إشعارات محلية بحتة (chat/topup/service)
  /// ليس لها serverId إطلاقاً فتبقى محلية فقط كما كانت دائماً.
  void markNotificationRead(String notificationId) {
    final index = _items.indexWhere((item) => item.id == notificationId);
    if (index == -1 || _items[index].read) return;

    _items[index].read = true;
    notifyListeners();

    final serverId = _items[index].serverId;
    if (serverId != null) _syncReadToServer(serverId);
  }

  /// [HIGH-FIX-READSYNC-01] نفس المنطق: الحالة المحلية تتغيّر فوراً (كما كانت
  /// قبل هذا الإصلاح تماماً)، ثم مزامنة الخادم بالخلفية. مزامنة "قراءة الكل"
  /// بالخادم (POST /notifications/read-all) تشمل فقط الأنواع الدائمة أصلاً
  /// (request/offer/wallet/support/complaint — راجع notify() بالخادم)، وهي
  /// تماماً الأنواع غير-chat التي تُعلَّم هنا محلياً؛ لا تعارض مع chat/topup/
  /// service المحلية البحتة التي لا نظير لها بالخادم أساساً.
  void markRequestNotificationsRead() {
    var changed = false;
    for (final item in _items) {
      if (!item.isChat && !item.read) {
        item.read = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
    _syncAllReadToServer();
  }

  /// [HIGH-FIX-READSYNC-01] استدعاء خادم بالخلفية فقط — لا يُغيّر أي حالة
  /// محلية (تلك غُيِّرت مسبقاً بالمستدعي أعلاه قبل استدعاء هذه الدالة). فشل
  /// الشبكة (offline، انقطاع مؤقت...) يُمتَص بصمت هنا تماماً بنفس فلسفة
  /// loadNotifications/markNotificationReadOnServer أعلاه — لا يرمي، ولا
  /// يُسقط التطبيق، ولا يراجع الحالة المحلية (تبقى "مقروء" كما قرّر المستخدم
  /// بجهازه حتى لو تعذّر إبلاغ الخادم هذه المرة).
  Future<void> _syncReadToServer(int serverId) async {
    if (_api == null) return;
    try {
      await _api.markRead(serverId);
    } catch (_) {
      // فشل الشبكة لا يُسقط التطبيق ولا يراجع الحالة المحلية.
    }
  }

  /// [HIGH-FIX-READSYNC-01] نظير markAllRead بنفس فلسفة _syncReadToServer
  /// أعلاه تماماً — بالخلفية، لا يُغيّر حالة محلية، يمتص فشل الشبكة بصمت.
  Future<void> _syncAllReadToServer() async {
    if (_api == null) return;
    try {
      await _api.markAllRead();
    } catch (_) {
      // فشل الشبكة لا يُسقط التطبيق ولا يراجع الحالة المحلية.
    }
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

  /// يجلب الإشعارات الدائمة من الخادم (صفحة واحدة، الأحدث أولاً) ويدمجها مع
  /// القائمة المحلية الحالية (راجع _mergeServerItems) بدل استبدالها بالكامل —
  /// [NOTIF-FLUTTER-PHASE2B] الاستبدال الكامل كان يمسح بصمت أي إشعار لحظي
  /// (Socket.IO) من نوع لا نظير له بالخادم (chat/topup/service) وصل بين
  /// تحميلين. فشل الشبكة يُمتَص بصمت — لا يُسقط التطبيق ولا يمسح أي إشعار
  /// محلي موجود مسبقاً.
  Future<void> loadNotifications({int page = 1, int limit = 20}) async {
    if (_api == null) return;

    try {
      final result = await _api.getNotifications(page: page, limit: limit);

      if (page <= 1) {
        _mergeServerItems(result.items);
      } else {
        // صفحات لاحقة (تمرير للخلف بالتاريخ) — عناصر أقدم بالتعريف، لا يمكن
        // أن تكون موجودة محلياً كإشعار لحظي (تلك تكون دائماً حديثة). إضافة
        // بسيطة فقط، مع حماية ضد ازدواج غير محتمل عبر serverId.
        for (final serverItem in result.items) {
          final alreadyKnown = serverItem.serverId != null &&
              _items.any((i) => i.serverId == serverItem.serverId);
          if (!alreadyKnown) _items.add(serverItem);
        }
      }

      notifyListeners();
    } catch (_) {
      // فشل الشبكة لا يُسقط التطبيق — القائمة المحلية الحالية تبقى كما هي.
    }
  }

  /// [NOTIF-FLUTTER-PHASE2B] يدمج صفحة إشعارات من الخادم (الأحدث أولاً) مع
  /// _items الحالية دون فقدان أي عنصر محلي غير متعلّق (chat/topup/service،
  /// أو إشعار لحظي أقدم من نافذة الدمج). لكل عنصر خادم:
  ///  1) لو له صف مطابق بالقائمة مسبقاً (نفس serverId — تحميل سابق) → حدّث
  ///     حالة "مقروء" فقط (OR منطقي، لا يُرجع "غير مقروء" شيئاً قرأه المستخدم).
  ///  2) وإلا لو يوجد إشعار لحظي محلي (serverId==null) يمثّل على الأرجح نفس
  ///     الحدث (نفس type، ونفس requestId لو توفّر، ضمن _dedupWindow) →
  ///     استبدله بالنسخة الرسمية من الخادم في نفس موضعه (لا نسخة ثانية).
  ///  3) وإلا فهو عنصر جديد كلياً → يُدرَج بالمقدمة (الأحدث أولاً، بنفس منطق
  ///     addNotification).
  void _mergeServerItems(List<NotificationModel> serverItems) {
    // نمرّ من الأقدم للأحدث وندرج كل عنصر جديد بالمقدمة (index 0) — بنهاية
    // الحلقة يكون الأحدث هو آخر ما أُدرِج، فيستقر بالمقدمة فعلياً كما يجب.
    for (final serverItem in serverItems.reversed) {
      final existingIndex = serverItem.serverId == null
          ? -1
          : _items.indexWhere((i) => i.serverId == serverItem.serverId);

      if (existingIndex != -1) {
        _items[existingIndex].read =
            _items[existingIndex].read || serverItem.read;
        continue;
      }

      final localMatchIndex = _findUnpersistedMatchIndex(serverItem);
      if (localMatchIndex != -1) {
        serverItem.read = serverItem.read || _items[localMatchIndex].read;
        _items[localMatchIndex] = serverItem;
        continue;
      }

      _items.insert(0, serverItem);
    }

    if (_items.length > 80) {
      _items.removeRange(80, _items.length);
    }
  }

  /// [NOTIF-FLUTTER-PHASE2B] يبحث عن إشعار لحظي محلي (serverId == null) غير
  /// مرتبط بعد بأي صف خادم، يمثّل على الأرجح نفس الحدث الذي يمثّله serverItem.
  /// راجع تعليق _dedupWindow/_persistedTypes أعلاه لتفسير حدود هذه المطابقة.
  int _findUnpersistedMatchIndex(NotificationModel serverItem) {
    for (var i = 0; i < _items.length; i++) {
      final local = _items[i];
      if (local.serverId != null) continue;
      if (local.type != serverItem.type) continue;

      final timeDiff = serverItem.createdAt.difference(local.createdAt).abs();
      if (timeDiff > _dedupWindow) continue;

      if (serverItem.requestId != null && local.requestId != null) {
        if (serverItem.requestId != local.requestId) continue;
      }

      return i;
    }

    return -1;
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