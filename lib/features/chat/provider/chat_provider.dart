import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../models/message_model.dart';
import '../data/chat_api.dart';

class ChatProvider extends ChangeNotifier {
  late final ChatApi api;

  ChatProvider({
    required ApiClient apiClient,
  }) {
    api = ChatApi(apiClient);
  }

  bool loading = false;
  bool sending = false;
  String? error;

  final Map<int, List<MessageModel>> _messagesByRequest = {};

  List<MessageModel> messagesFor(int requestId) {
    return _messagesByRequest[requestId] ?? [];
  }

  void setMessages(int requestId, List<MessageModel> messages) {
    _messagesByRequest[requestId] = messages;
    notifyListeners();
  }

  Future<void> loadMessages(int requestId, {bool silent = false}) async {
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
      loading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage({
    required int requestId,
    required String body,
  }) async {
    if (body.trim().isEmpty) return;

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
  }) async {
    sending = true;
    error = null;
    notifyListeners();

    try {
      final messages = await api.sendAudio(
        requestId: requestId,
        audioPath: audioPath,
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
}