import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../config/app_config.dart';
import 'socket_events.dart';

class SocketService {
  io.Socket? _socket;

  io.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;

  void connect({required String token}) {
    if (kDebugMode) {
      debugPrint('SOCKET TRY CONNECT => ${AppConfig.baseUrl}');
      debugPrint('SOCKET TOKEN EXISTS => ${token.isNotEmpty}');
    }

    if (_socket != null) {
      disconnect();
    }

    _socket = io.io(
      AppConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(9999)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(8000)
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          // [FIX-SOCKET-01] بدون هذا، حزمة socket_io_client تعيد استخدام نفس
          // الـ Manager الأول الذي أُنشئ في حياة العملية (تخزّنه مفتاحاً
          // بعنوان السيرفر فقط)، فيبقى التوكن القديم فعّالاً في السوكت حتى
          // بعد تسجيل خروج/دخول جديد بتوكن صالح — enableForceNew() يضمن
          // Manager جديد فعلياً بالتوكن الحالي في كل مرة.
          .enableForceNew()
          .build(),
    );

    _socket!.on(SocketEvents.connect, (_) {
      if (kDebugMode) debugPrint('✅ SOCKET CONNECTED: ${_socket?.id}');
    });

    _socket!.on(SocketEvents.disconnect, (reason) {
      if (kDebugMode) debugPrint('❌ SOCKET DISCONNECTED: $reason');
    });

    _socket!.on(SocketEvents.connectError, (error) {
      if (kDebugMode) debugPrint('🚨 SOCKET CONNECT ERROR: $error');
    });

    _socket!.onAny((event, data) {
      if (kDebugMode) {
        debugPrint('📡 SOCKET EVENT => $event');
      }
    });

    _socket!.connect();
  }

  void joinRequest(int requestId) {
    if (kDebugMode) debugPrint('JOIN REQUEST ROOM => $requestId');
    _socket?.emit(SocketEvents.joinRequest, requestId);
  }

  void leaveRequest(int requestId) {
    if (kDebugMode) debugPrint('LEAVE REQUEST ROOM => $requestId');
    _socket?.emit(SocketEvents.leaveRequest, requestId);
  }

  /// [FIX-REALTIME-01] لا تمسح المستمعين الآخرين المسجَّلين لنفس اسم الحدث.
  ///
  /// كانت هذه الدالة تنفّذ `_socket?.off(event)` قبل كل تسجيل جديد — وهذا
  /// كان يمسح *كل* مستمع سابق لنفس اسم الحدث بغض النظر عن مصدره. بما إن
  /// حدث `support-message` (مثلاً) مسجَّل مرة مركزياً عند تسجيل الدخول
  /// (SocketProvider) ومرة ثانية محلياً داخل شاشة شات الدعم نفسها، فتح شاشة
  /// الشات كان يمسح المستمع المركزي نهائياً — وهذا هو سبب توقف التحديث
  /// اللحظي (Real-Time) لرسائل الدعم بشكل متقطع حسب ترتيب فتح الشاشات.
  ///
  /// Socket.IO Client يدعم أصلاً عدة مستمعين لنفس الحدث بدون أي تعارض
  /// (EventEmitter عادي) — فحذف `.off()` هنا كافٍ وآمن؛ إزالة مستمع واحد
  /// بعينه تبقى ممكنة عبر `off(event, callback)` بالأسفل، وهي الطريقة
  /// الصحيحة أصلاً (تُستخدم فعلاً بـ `dispose()` بشاشات الشات).
  void on(String event, Function(dynamic data) callback) {
    _socket?.on(event, callback);
  }

  void off(String event, [Function(dynamic data)? callback]) {
    if (callback != null) {
      _socket?.off(event, callback);
    } else {
      _socket?.off(event);
    }
  }

  void disconnect() {
    if (kDebugMode) debugPrint('SOCKET MANUAL DISCONNECT');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}