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
  String? error;

  final Map<int, List<MessageModel>> _messagesByRequest = {};
  // يمنع تشغيل أكثر من GET للرسائل لنفس الطلب في الوقت نفسه.
  final Set<int> _loadingRequestIds = {};
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

  int unreadCountFor(int requestId) {
    for (final c in chats) {
      if (c.requestId == requestId) return c.unreadCount;
    }
    return 0;
  }

  Future<void> loadChats({bool silent = false}) async {
    if (_loadingChats) return;
    _loadingChats = true;

    if (!silent) {
      chatsLoading = true;
      chatsError = null;
      notifyListeners();
    }

    try {
      final (result, total) = await api.getChats();
      chats = result;
      totalUnread = total;
      chatsError = null;
    } catch (e) {
      chatsError = e is ApiException ? e.message : 'تعذر تحميل المحادثات';
    } finally {
      _loadingChats = false;
      if (!silent) chatsLoading = false;
      notifyListeners();
    }
  }

  List<MessageModel> messagesFor(int requestId) {
    return _messagesByRequest[requestId] ?? [];
  }

  void setMessages(int requestId, List<MessageModel> messages) {
    _messagesByRequest[requestId] = messages;
    notifyListeners();
  }

  Future<void> loadMessages(int requestId, {bool silent = false}) async {
    if (_loadingRequestIds.contains(requestId)) return;
    _loadingRequestIds.add(requestId);

    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final messages = await api.getMessages(requestId);
      _messagesByRequest[requestId] = messages;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل الرسائل';
    } finally {
      _loadingRequestIds.remove(requestId);
      if (!silent) loading = false;
      notifyListeners();
    }
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