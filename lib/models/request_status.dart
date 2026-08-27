import '../l10n/app_localizations.dart';

/// [L10N-PHASE3] Typed wrapper around `RequestModel.status`'s raw wire value.
/// The backend sends `status` as a literal Arabic string (see the comment on
/// `RequestModel` itself) — `wireValue` below is exactly that string, never
/// translated, since it's also what's compared/sent back to the server
/// elsewhere in the app. This enum only affects *display*: existing wire
/// comparisons (`RequestModel.isCompleted`, `.isCancelled`, etc. and the
/// per-screen `status == '...'` checks) are untouched and keep comparing
/// against the raw Arabic string directly.
enum RequestStatus {
  waitingForOffers('بانتظار العروض'),
  offersReceived('وصلت عروض'),
  offerSelected('تم اختيار عرض'),
  inProgress('قيد التنفيذ'),
  awaitingPaymentConfirmation('بانتظار تأكيد الدفع'),
  completed('مكتمل'),
  cancelled('ملغي'),
  unknown(null);

  final String? wireValue;

  const RequestStatus(this.wireValue);

  /// Parses the server's raw `status` string into a known status, or
  /// [unknown] if the server sends something this enum doesn't recognize
  /// yet (a new status added server-side, a typo, etc.) — never throws.
  static RequestStatus fromWire(String wire) {
    for (final status in RequestStatus.values) {
      if (status.wireValue == wire) return status;
    }
    return RequestStatus.unknown;
  }

  /// Localized display label. For [unknown], `rawWire` (the original,
  /// unrecognized server string) is shown as-is instead of a generic
  /// placeholder — still meaningful to the user, and avoids hiding
  /// information the server actually sent.
  String label(AppLocalizations t, {String rawWire = ''}) {
    return switch (this) {
      RequestStatus.waitingForOffers => t.requestStatusWaitingForOffers,
      RequestStatus.offersReceived => t.requestStatusOffersReceived,
      RequestStatus.offerSelected => t.requestStatusOfferSelected,
      RequestStatus.inProgress => t.requestStatusInProgress,
      RequestStatus.awaitingPaymentConfirmation =>
        t.requestStatusAwaitingPaymentConfirmation,
      RequestStatus.completed => t.requestStatusCompleted,
      RequestStatus.cancelled => t.requestStatusCancelled,
      RequestStatus.unknown => rawWire,
    };
  }
}
