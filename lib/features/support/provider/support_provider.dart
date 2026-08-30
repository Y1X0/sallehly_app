import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../models/support_message_model.dart';
import '../../../models/support_ticket_model.dart';
import '../data/support_api.dart';

class SupportProvider extends ChangeNotifier {
  late final SupportApi api;

  // [FIX-TEST-01] معامل اختياري يسمح بحقن SupportApi جاهز (Mock) للاختبار —
  // بنفس نمط ChatProvider/AdminProvider/RequestsProvider أصلاً بهذا المشروع.
  // بلا أي تأثير على app.dart الذي لا يمرره إطلاقاً.
  SupportProvider({required ApiClient apiClient, SupportApi? apiOverride}) {
    api = apiOverride ?? SupportApi(apiClient);
  }

  bool loading = false;
  bool sending = false;
  String? error;

  List<SupportTicketModel> tickets = [];
  List<SupportMessageModel> messages = [];

  /// هل لدى المستخدم تذكرة دعم مفتوحة حالياً؟
  bool get hasOpenTicket => tickets.any((t) => t.isOpen);

  /// أحدث تذكرة مفتوحة (للوصول السريع من الشريط السفلي).
  SupportTicketModel? get openTicket {
    for (final t in tickets) {
      if (t.isOpen) return t;
    }
    return null;
  }

  Future<void> loadMyTickets({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      tickets = await api.getMyTickets();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
            // [L10N-WIRE-UI] رسالة احتياطية تُعرض عبر banner مؤجَّل (راجع L10N_PROGRESS.md — قرار البانرات الـ16 المؤجَّلة بمرحلة BidiText)؛ لا BuildContext بطبقة provider لعرضها مترجَمة.
      error = 'تعذر تحميل تذاكر الدعم';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<SupportTicketModel?> createTicket({
    required String type,
    required String title,
    required String body,
  }) async {
    // [SEC-FIX-DOUBLESUBMIT-01] راجع DECISIONS.md — بلا هذا الحارس، ضغطتان
    // متقاربتان جداً كانتا ترسلان تذكرتَي دعم حقيقيتين منفصلتين.
    if (sending) return null;
    sending = true;
    notifyListeners();

    try {
      final ticket = await api.createTicket(
        type: type,
        title: title,
        body: body,
      );
      await loadMyTickets(silent: true);
      error = null;
      return ticket;
    } on ApiException catch (e) {
      error = e.message;
      rethrow;
    } catch (_) {
            // [L10N-WIRE-UI] رسالة احتياطية تُعرض عبر banner مؤجَّل (راجع L10N_PROGRESS.md — قرار البانرات الـ16 المؤجَّلة بمرحلة BidiText)؛ لا BuildContext بطبقة provider لعرضها مترجَمة.
      error = 'تعذر إنشاء التذكرة';
      rethrow;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(int ticketId, {bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    try {
      messages = await api.getMessages(ticketId);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
            // [L10N-WIRE-UI] رسالة احتياطية تُعرض عبر banner مؤجَّل (راجع L10N_PROGRESS.md — قرار البانرات الـ16 المؤجَّلة بمرحلة BidiText)؛ لا BuildContext بطبقة provider لعرضها مترجَمة.
      error = 'تعذر تحميل الرسائل';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage({
    required int ticketId,
    required String body,
  }) async {
    // [SEC-FIX-DOUBLESUBMIT-01] نفس الحارس أعلاه — يمنع إرسال نفس الرسالة
    // مرتين لضغطة مزدوجة سريعة.
    if (sending) return;
    sending = true;
    notifyListeners();

    try {
      await api.sendMessage(ticketId: ticketId, body: body);
      await loadMessages(ticketId, silent: true);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
      rethrow;
    } catch (_) {
            // [L10N-WIRE-UI] رسالة احتياطية تُعرض عبر banner مؤجَّل (راجع L10N_PROGRESS.md — قرار البانرات الـ16 المؤجَّلة بمرحلة BidiText)؛ لا BuildContext بطبقة provider لعرضها مترجَمة.
      error = 'تعذر إرسال الرسالة';
      rethrow;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    messages = [];
  }

  /// [SEC-FIX-CHATCLEAR-01] راجع DECISIONS.md — يُستدعى عند تسجيل الخروج
  /// (app.dart's authProvider.onLoggedOut). بدونها، محتوى تذاكر/رسائل دعم
  /// حساب سابق (قد تتضمن شكاوى شخصية) يبقى بالذاكرة حتى دخول مستخدم تالٍ
  /// على نفس الجهاز.
  void clear() {
    tickets = [];
    messages = [];
    error = null;
    notifyListeners();
  }
}
