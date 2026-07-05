import 'package:flutter/material.dart';

import '../core/socket/socket_events.dart';
import '../core/socket/socket_service.dart';
import '../core/storage/token_storage.dart';
import '../features/admin/provider/admin_provider.dart';
import '../features/chat/provider/chat_provider.dart';
import '../features/requests/provider/requests_provider.dart';
import '../features/support/provider/support_provider.dart';
import '../features/wallet/provider/wallet_provider.dart';
import '../models/message_model.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';

class SocketProvider extends ChangeNotifier {
  final SocketService socketService;
  final TokenStorage tokenStorage;

  SocketProvider({
    required this.socketService,
    required this.tokenStorage,
  });

  bool connected = false;

  // مراجع الـproviders — تُحقن مرة واحدة من الـbootstrapper.
  RequestsProvider? _requestsProvider;
  ChatProvider? _chatProvider;
  NotificationProvider? _notificationProvider;
  AuthProvider? _authProvider;
  AdminProvider? _adminProvider;
  WalletProvider? _walletProvider;
  SupportProvider? _supportProvider;

  bool _listenersBound = false;

  // حماية ضد تكرار تحديثات الدعم (نفس الحدث قد يصل أكثر من مرة بسرعة).
  DateTime _lastSupportRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  bool _supportRefreshAllowed() {
    final now = DateTime.now();
    if (now.difference(_lastSupportRefresh).inMilliseconds < 500) return false;
    _lastSupportRefresh = now;
    return true;
  }

  /// تُستدعى مرة واحدة عند إقلاع التطبيق لتسجيل كل الـproviders.
  void bindProviders({
    required RequestsProvider requestsProvider,
    required ChatProvider chatProvider,
    required NotificationProvider notificationProvider,
    required AuthProvider authProvider,
    required AdminProvider adminProvider,
    required WalletProvider walletProvider,
    required SupportProvider supportProvider,
  }) {
    _requestsProvider = requestsProvider;
    _chatProvider = chatProvider;
    _notificationProvider = notificationProvider;
    _authProvider = authProvider;
    _adminProvider = adminProvider;
    _walletProvider = walletProvider;
    _supportProvider = supportProvider;
  }

  /// يُستدعى بعد تسجيل الدخول / استعادة الجلسة. يتصل بالسوكت ويسجّل المستمعين.
  Future<void> connect() async {
    final token = await tokenStorage.getToken();
    if (token == null || token.trim().isEmpty) return;

    socketService.connect(token: token.trim());
    _bindSocketListeners();
  }

  /// إعادة الاتصال بتوكن جديد (تُستخدم عند تبديل المستخدم).
  Future<void> reconnect() async {
    socketService.disconnect();
    _listenersBound = false;
    connected = false;
    await connect();
  }

  void _bindSocketListeners() {
    if (_listenersBound) return;
    _listenersBound = true;

    socketService.on(SocketEvents.connect, (_) {
      connected = true;
      notifyListeners();
    });

    socketService.on(SocketEvents.disconnect, (_) {
      connected = false;
      notifyListeners();
    });

    // ─────────────── الطلبات والعروض ───────────────
    socketService.on(SocketEvents.newRequestCreated, (data) async {
      await _requestsProvider?.loadRequests(silent: true);
      await _adminProvider?.refreshRequestsSilent();
      _notificationProvider?.handleNewRequest(data);
    });

    socketService.on(SocketEvents.requestsUpdated, (_) async {
      await _requestsProvider?.loadRequests(silent: true);
      await _adminProvider?.refreshRequestsSilent();
    });

    socketService.on(SocketEvents.requestStatusUpdated, (data) async {
      await _requestsProvider?.loadRequests(silent: true);
      await _adminProvider?.refreshRequestsSilent();
      _notificationProvider?.handleRequestStatus(data);
    });

    socketService.on(SocketEvents.offerCreated, (data) async {
      await _requestsProvider?.loadRequests(silent: true);

      final requestId = int.tryParse('${data?['requestId'] ?? 0}') ?? 0;
      if (requestId > 0) {
        await _requestsProvider?.loadOffers(requestId, silent: true);
      }

      _notificationProvider?.handleOfferCreated(data);
    });

    socketService.on(SocketEvents.offerAccepted, (data) async {
      await _requestsProvider?.loadRequests(silent: true);
      _notificationProvider?.handleOfferAccepted(data);
    });

    // ─────────────── الدردشة ───────────────
    socketService.on(SocketEvents.chatMessageNotify, (data) {
      _notificationProvider?.handleChatNotify(data);
    });

    socketService.on(SocketEvents.chatBadgesUpdated, (data) {
      _notificationProvider?.handleChatBadges(data);
    });

    socketService.on(SocketEvents.messagesUpdated, (data) {
      final requestId = int.tryParse('${data?['requestId'] ?? 0}') ?? 0;
      final rawMessages = data?['messages'];

      if (requestId <= 0 || rawMessages is! List) return;

      final messages = rawMessages
          .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      _chatProvider?.setMessages(requestId, messages);
    });

    // ─────────────── المحفظة / الشحن ───────────────
    socketService.on(SocketEvents.topupCreated, (data) async {
      // للأدمن: حدّث قائمة الشحن. للفني: حدّث محفظته.
      await _adminProvider?.refreshTopupsSilent();
      await _walletProvider?.loadTopups(silent: true);
      _notificationProvider?.handleTopupCreated(data);
    });

    socketService.on(SocketEvents.balanceUpdated, (data) async {
      await _authProvider?.refreshUser();
      await _walletProvider?.refreshSilent();
      _notificationProvider?.handleBalanceUpdated(data);
    });

    // ─────────────── الدعم ───────────────
    socketService.on(SocketEvents.supportCreated, (data) async {
      await _adminProvider?.refreshSupportSilent();
      await _supportProvider?.loadMyTickets(silent: true);
      _notificationProvider?.handleSupportCreated(data);
    });

    // رسالة دعم جديدة (من الأدمن للفني أو العكس) → إشعار + عدّاد ريل تايم.
    socketService.on(SocketEvents.supportMessage, (data) async {
      // إشعار فوري بالعدّاد.
      _notificationProvider?.handleSupportMessage(data);

      // تحديث قوائم التذاكر/الرسائل (مع حماية ضد التكرار).
      if (!_supportRefreshAllowed()) return;
      await _supportProvider?.loadMyTickets(silent: true);
      await _adminProvider?.refreshSupportSilent();

      // إذا التذكرة مفتوحة على الشاشة، حدّث رسائلها مباشرة.
      final ticketId = int.tryParse(
            '${data?['ticketId'] ?? data?['ticket_id'] ?? 0}',
          ) ??
          0;
      if (ticketId > 0) {
        await _supportProvider?.loadMessages(ticketId, silent: true);
      }
    });

    socketService.on(SocketEvents.supportMessageRefresh, (data) async {
      // تحديث قائمة التذاكر (آخر رسالة/شارة غير مقروء) لكلا الطرفين.
      if (!_supportRefreshAllowed()) return;
      await _adminProvider?.refreshSupportSilent();
      await _supportProvider?.loadMyTickets(silent: true);
    });

    socketService.on(SocketEvents.supportStatusUpdated, (data) async {
      // تغيّرت حالة التذكرة (فتح/إغلاق) → حدّث القوائم ليظهر/يختفي اختصار الدعم.
      if (!_supportRefreshAllowed()) return;
      await _supportProvider?.loadMyTickets(silent: true);
      await _adminProvider?.refreshSupportSilent();
    });

    // ─────────────── المراقبة (شكاوى) ───────────────
    socketService.on(SocketEvents.newComplaint, (data) async {
      await _adminProvider?.refreshModerationSilent();
      _notificationProvider?.handleNewComplaint(data);
    });
  }

  void joinRequest(int requestId) {
    socketService.joinRequest(requestId);
  }

  void leaveRequest(int requestId) {
    socketService.leaveRequest(requestId);
  }

  void disconnect() {
    socketService.disconnect();
    _listenersBound = false;
    connected = false;
    notifyListeners();
  }
}
