import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../models/chat_summary_model.dart';
import '../../../models/message_model.dart';
import '../data/chat_api.dart';

class ChatProvider extends ChangeNotifier {
  late final ChatApi api;

  ChatProvider({
    required ApiClient apiClient,
    ChatApi? apiOverride,
  }) {
    api = apiOverride ?? ChatApi(apiClient);
  }

  bool loading = false;
  bool sending = false;
  // [L10N-TODO] كل رسائل fallback الفشل بهذا الملف (طبقة provider، بلا
  // BuildContext) عربية ثابتة حالياً. `error` الوحيد له مستهلِك فعلي حالياً:
  // chat_room_screen.dart (#76) — يُحلّ عند الوصول لذلك الملف. `chatsError`
  // بلا أي مستهلِك بالواجهة حالياً (chats_screen.dart يعرض RequestsProvider
  // .error، لا ChatProvider.chatsError) — يُترَك كما هو حتى يُستخدَم فعلياً.
  String? error;

  final Map<int, List<MessageModel>> _messagesByRequest = {};
  // يمنع تشغيل أكثر من GET للرسائل لنفس الطلب في الوقت نفسه.
  final Set<int> _loadingRequestIds = {};

  // [FEAT-CHATPAGINATION-01] راجع DECISIONS.md — حجم الصفحة لتحميل رسائل
  // الشات (التحميل الأول و"تحميل أقدم" عند التمرير). يطابق limit الافتراضي
  // بطرف الخادم (routes/chat.routes.js، حد أقصى 200).
  static const int pageSize = 50;
  final Map<int, bool> _hasMoreByRequest = {};
  final Set<int> _loadingOlderRequestIds = {};
  // [FIX-UGC-01] حالة الحظر لكل طلب (يُحمَّل عند فتح شاشة الشات).
  final Map<int, BlockStatus> _blockStatusByRequest = {};

  // [FIX-CHATUNREAD-01] ملخّص كل المحادثات (آخر رسالة + عدد غير المقروء)،
  // مصدره GET /chats — يُحدَّث عند فتح شاشة المحادثات وعند وصول
  // chat-badges-updated عبر السوكت (انظر SocketProvider).
  List<ChatSummaryModel> chats = [];
  int totalUnread = 0;
  bool chatsLoading = false;
  String? chatsError;
  bool _loadingChats = false;

  // [SEC-FIX-CHATCLEAR-01] راجع DECISIONS.md — عدّاد جيل، نفس نمط
  // NotificationProvider._generation (HIGH-FIX-STALEGEN-01) بالضبط: يُلتقَط
  // قبل await بكل دالة تدمج رداً بالحالة المشتركة، فلو حصل clear() (تسجيل
  // خروج/دخول لحساب آخر) أثناء الانتظار، يختلف الجيل الملتقَط عن الحالي بعد
  // العودة، فيُهمَل الرد كاملاً بدل دمج بيانات حساب سابق بحساب حالي مختلف.
  int _generation = 0;

  int unreadCountFor(int requestId) {
    for (final c in chats) {
      if (c.requestId == requestId) return c.unreadCount;
    }
    return 0;
  }

  /// [SEC-FIX-CHATCLEAR-01] راجع DECISIONS.md — يُستدعى عند تسجيل الخروج
  /// (app.dart's authProvider.onLoggedOut). بدونها، رسائل الشات الفعلية
  /// (عناوين، أرقام، تفاوض سعر) لحساب سابق تبقى بالذاكرة (_messagesByRequest)
  /// حتى لحظة دخول مستخدم تالٍ على نفس الجهاز — ChatRoomScreen.build() يقرأ
  /// messagesFor() بشكل متزامن قبل اكتمال أي تحميل جديد، فقد تُعرَض فوراً لو
  /// تطابق معرّف الطلب صدفةً. نفس فلسفة NotificationProvider.clear() تماماً.
  void clear() {
    _generation++;
    _messagesByRequest.clear();
    _blockStatusByRequest.clear();
    _loadingRequestIds.clear();
    _hasMoreByRequest.clear();
    _loadingOlderRequestIds.clear();
    chats = [];
    totalUnread = 0;
    error = null;
    chatsError = null;
    notifyListeners();
  }

  Future<void> loadChats({bool silent = false}) async {
    if (_loadingChats) return;
    _loadingChats = true;
    final capturedGeneration = _generation;

    if (!silent) {
      chatsLoading = true;
      chatsError = null;
      notifyListeners();
    }

    try {
      final (result, total) = await api.getChats();
      if (capturedGeneration != _generation) return;
      chats = result;
      totalUnread = total;
      chatsError = null;
    } catch (e) {
      if (capturedGeneration != _generation) return;
      chatsError = e is ApiException ? e.message : 'تعذر تحميل المحادثات';
    } finally {
      _loadingChats = false;
      if (!silent) chatsLoading = false;
      if (capturedGeneration == _generation) notifyListeners();
    }
  }

  List<MessageModel> messagesFor(int requestId) {
    return _messagesByRequest[requestId] ?? [];
  }

  void setMessages(int requestId, List<MessageModel> messages) {
    _messagesByRequest[requestId] = messages;
    notifyListeners();
  }

  /// [FEAT-CHATPAGINATION-01] هل توجد رسائل أقدم لم تُحمَّل بعد لهذا الطلب؟
  bool hasMoreFor(int requestId) => _hasMoreByRequest[requestId] ?? false;

  bool isLoadingOlderFor(int requestId) => _loadingOlderRequestIds.contains(requestId);

  Future<void> loadMessages(int requestId, {bool silent = false}) async {
    if (_loadingRequestIds.contains(requestId)) return;
    _loadingRequestIds.add(requestId);
    final capturedGeneration = _generation;

    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final (messages, hasMore) = await api.getMessages(requestId, limit: pageSize);
      if (capturedGeneration != _generation) return;
      _messagesByRequest[requestId] = messages;
      _hasMoreByRequest[requestId] = hasMore;
      error = null;
    } catch (e) {
      if (capturedGeneration != _generation) return;
      error = e is ApiException ? e.message : 'تعذر تحميل الرسائل';
    } finally {
      _loadingRequestIds.remove(requestId);
      if (!silent) loading = false;
      if (capturedGeneration == _generation) notifyListeners();
    }
  }

  /// [FEAT-CHATPAGINATION-01] راجع DECISIONS.md — يُستدعى عند التمرير لأعلى
  /// المحادثة (نحو الرسائل الأقدم). يُضيف الصفحة الجديدة في بداية القائمة
  /// المحلية بدل استبدال كل شيء — لا يمس الرسائل الأحدث المعروضة أصلاً.
  Future<void> loadOlderMessages(int requestId) async {
    if (_loadingOlderRequestIds.contains(requestId)) return;
    if (!hasMoreFor(requestId)) return;
    final existing = _messagesByRequest[requestId];
    if (existing == null || existing.isEmpty) return;

    _loadingOlderRequestIds.add(requestId);
    final capturedGeneration = _generation;
    notifyListeners();

    try {
      final oldestId = existing.first.id;
      final (older, hasMore) = await api.getMessages(
        requestId,
        limit: pageSize,
        beforeId: oldestId,
      );
      if (capturedGeneration != _generation) return;
      final current = _messagesByRequest[requestId] ?? [];
      _messagesByRequest[requestId] = [...older, ...current];
      _hasMoreByRequest[requestId] = hasMore;
    } catch (_) {
      // فشل صامت — المستخدم يقدر يعيد المحاولة بالتمرير مجدداً، لا داعي
      // لكسر شاشة الشات كلها لمجرد فشل تحميل صفحة رسائل أقدم.
    } finally {
      _loadingOlderRequestIds.remove(requestId);
      if (capturedGeneration == _generation) notifyListeners();
    }
  }

  /// [FEAT-CHATPAGINATION-01] راجع DECISIONS.md — استقبال حدث message-added
  /// اللحظي: رسالة واحدة جديدة تُضاف لنهاية القائمة المحلية بدل استبدال كل
  /// شيء. لا تأثير لو المحادثة غير مُحمَّلة أصلاً بهذا الجهاز الآن (لم تُفتَح
  /// بعد) أو لو الرسالة موجودة مسبقاً (منع تكرار عند وصول مزدوج محتمل).
  void addIncomingMessage(int requestId, MessageModel message) {
    final existing = _messagesByRequest[requestId];
    if (existing == null) return;
    if (existing.any((m) => m.id == message.id)) return;
    _messagesByRequest[requestId] = [...existing, message];
    notifyListeners();
  }

  /// [FEAT-CHATPAGINATION-01] راجع DECISIONS.md — استقبال حدث messages-seen
  /// اللحظي: يعلّم كل رسالة مُرسَلة من غير readerId، وبمعرّف ≤ upToMessageId،
  /// كـ"تمت مشاهدتها" — بلا إعادة بناء القائمة من الصفر.
  void markSeenUpTo(int requestId, int readerId, int upToMessageId) {
    final existing = _messagesByRequest[requestId];
    if (existing == null) return;
    var changed = false;
    final updated = existing.map((m) {
      if (!m.seen && m.senderId != readerId && m.id <= upToMessageId) {
        changed = true;
        return m.copyWith(seen: true);
      }
      return m;
    }).toList();
    if (!changed) return;
    _messagesByRequest[requestId] = updated;
    notifyListeners();
  }

  Future<void> sendMessage({
    required int requestId,
    required String body,
  }) async {
    if (body.trim().isEmpty || sending) return;

    sending = true;
    error = null;
    notifyListeners();

    try {
      final messages = await api.sendMessage(
        requestId: requestId,
        body: body.trim(),
      );

      _messagesByRequest[requestId] = messages;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر إرسال الرسالة';
      rethrow;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> sendLocation({
    required int requestId,
    required double lat,
    required double lng,
  }) async {
    if (sending) return;
    sending = true;
    error = null;
    notifyListeners();

    try {
      final messages = await api.sendLocation(
        requestId: requestId,
        lat: lat,
        lng: lng,
      );

      _messagesByRequest[requestId] = messages;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر إرسال الموقع';
      rethrow;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> sendAudio({
    required int requestId,
    required String audioPath,
    int? durationSeconds,
  }) async {
    if (sending) return;
    sending = true;
    error = null;
    notifyListeners();

    try {
      final messages = await api.sendAudio(
        requestId: requestId,
        audioPath: audioPath,
        durationSeconds: durationSeconds,
      );

      _messagesByRequest[requestId] = messages;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر إرسال التسجيل';
      rethrow;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> sendImage({
    required int requestId,
    required String imagePath,
  }) async {
    if (sending) return;
    sending = true;
    error = null;
    notifyListeners();

    try {
      final messages = await api.sendImage(
        requestId: requestId,
        imagePath: imagePath,
      );

      _messagesByRequest[requestId] = messages;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر إرسال الصورة';
      rethrow;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // [FIX-UGC-01] الإبلاغ عن رسالة، والحظر/إلغاء الحظر (سياسة UGC)
  // ─────────────────────────────────────────────────────────────

  /// حالة الحظر الحالية المحمَّلة لهذا الطلب (null إن لم تُحمَّل بعد).
  BlockStatus? blockStatusFor(int requestId) => _blockStatusByRequest[requestId];

  Future<void> loadBlockStatus(int requestId) async {
    try {
      final status = await api.getBlockStatus(requestId);
      _blockStatusByRequest[requestId] = status;
      notifyListeners();
    } catch (_) {
      // فشل صامت — لا نمنع فتح الشات لمجرد فشل تحميل حالة الحظر.
    }
  }

  Future<String> reportMessage({
    required int requestId,
    int? messageId,
    required String reason,
  }) async {
    try {
      return await api.reportMessage(
        requestId: requestId,
        messageId: messageId,
        reason: reason,
      );
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر إرسال البلاغ';
      rethrow;
    }
  }

  Future<void> blockUser(int requestId) async {
    try {
      await api.blockUser(requestId);
      await loadBlockStatus(requestId);
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تنفيذ الحظر';
      rethrow;
    }
  }

  Future<void> unblockUser(int requestId) async {
    try {
      await api.unblockUser(requestId);
      await loadBlockStatus(requestId);
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر إلغاء الحظر';
      rethrow;
    }
  }
}