import '../../l10n/app_localizations.dart';

/// [FIX-ERRCODE-02] يحوّل `code` القادم من الخادم (master، راجع server.js) إلى
/// نص مترجَم عبر ARB — بدل عرض نص الخادم العربي دائماً بغضّ النظر عن لغة
/// الواجهة. يُستدعى من ApiClient.handleError() فقط، قبل بناء ApiException.
/// لا شاشة بالتطبيق تستدعيه مباشرة، وأي شاشة من التي تعرض
/// ApiException.message كما هي لم تتغيّر ولا تحتاج أن تتغيّر — القرار مركزي
/// بهذه الدالة وحدها.
///
/// [FIX-ERRCODE-02] هذه النسخة تُطابق القائمة الفعلية الحيّة على master (127
/// رمزاً) — ليس main (الفرع غير المستخدَم بالإنتاج الذي بُنيت عليه نسخة
/// سابقة بـ57 رمزاً فقط). أي رمز جديد يُضاف مستقبلاً على master يجب أن
/// يُضاف هنا أيضاً بنفس الجولة، لا كمهمة منفصلة لاحقة.
///
/// يُرجع null عندما:
/// - الرمز غير معروف (خادم أحدث يرسل رمزاً لم يُبنَ التطبيق ليعرفه بعد)
/// - الرمز معروف لكنه يحتاج params ولم تصل بيانات صالحة (غير موجودة، ليست
///   Map، أو الحقول المطلوبة مفقودة/من نوع خاطئ)
///
/// في الحالتين، على المستدعي (handleError()) العودة لاستخدام نص الخادم الخام
/// كما كان يفعل قبل هذا التغيير تماماً — لا فرق سلوكي، لا استثناء، ولا نص
/// فارغ أو مكسور بفراغات مكان placeholders غير محلولة.
String? resolveApiErrorCode(
  AppLocalizations t,
  String code, {
  Map<String, dynamic>? params,
}) {
  switch (code) {
    case 'AUTH_REQUIRED':
      return t.apiErrorAuthRequired;
    case 'AUTH_SESSION_INVALID':
      return t.apiErrorAuthSessionInvalid;
    case 'AUTH_TOKEN_INVALID':
      return t.apiErrorAuthTokenInvalid;
    case 'AUTH_ACCOUNT_SUSPENDED':
      return t.apiErrorAuthAccountSuspended;
    case 'AUTH_FORBIDDEN':
      return t.apiErrorAuthForbidden;
    case 'AUTH_SUPERADMIN_REQUIRED':
      return t.apiErrorAuthSuperadminRequired;
    case 'AUTH_INVALID_CREDENTIALS':
      return t.apiErrorAuthInvalidCredentials;
    case 'FORBIDDEN_GENERIC':
      return t.apiErrorForbiddenGeneric;
    case 'CSRF_REJECTED':
      return t.apiErrorCsrfRejected;
    case 'INVALID_ID':
      return t.apiErrorInvalidId;
    case 'STATUS_INVALID':
      return t.apiErrorStatusInvalid;
    case 'RATE_LIMIT_LOGIN':
      return t.apiErrorRateLimitLogin;
    case 'RATE_LIMIT_REGISTER':
      return t.apiErrorRateLimitRegister;
    case 'RATE_LIMIT_PASSWORD_RESET':
      return t.apiErrorRateLimitPasswordReset;
    case 'RATE_LIMIT_MESSAGE':
      return t.apiErrorRateLimitMessage;
    case 'RATE_LIMIT_OFFER':
      return t.apiErrorRateLimitOffer;
    case 'REGISTER_INVALID_ROLE':
      return t.apiErrorRegisterInvalidRole;
    case 'REGISTER_NAME_TOO_SHORT':
      return t.apiErrorRegisterNameTooShort;
    case 'CITY_TOO_LONG':
      return t.apiErrorCityTooLong;
    case 'REGISTER_TECH_AVATAR_REQUIRED':
      return t.apiErrorRegisterTechAvatarRequired;
    case 'EMAIL_INVALID':
      return t.apiErrorEmailInvalid;
    case 'REGISTER_EMAIL_TOO_LONG':
      return t.apiErrorRegisterEmailTooLong;
    case 'PHONE_INVALID_FORMAT':
      return t.apiErrorPhoneInvalidFormat;
    case 'PASSWORD_NEW_TOO_SHORT':
      return t.apiErrorPasswordNewTooShort;
    case 'REGISTER_INVALID_NATIONAL_NUMBER':
      return t.apiErrorRegisterInvalidNationalNumber;
    case 'REGISTER_SERVICES_TOO_LONG':
      return t.apiErrorRegisterServicesTooLong;
    case 'REGISTER_AREAS_TOO_LONG':
      return t.apiErrorRegisterAreasTooLong;
    case 'REGISTER_EMAIL_TAKEN':
      return t.apiErrorRegisterEmailTaken;
    case 'REGISTER_PHONE_TAKEN':
      return t.apiErrorRegisterPhoneTaken;
    case 'EMAIL_SEND_FAILED':
      return t.apiErrorEmailSendFailed;
    case 'REGISTER_FAILED':
      return t.apiErrorRegisterFailed;
    case 'OTP_NO_PENDING_REGISTER':
      return t.apiErrorOtpNoPendingRegister;
    case 'OTP_EXPIRED_REGISTER':
      return t.apiErrorOtpExpiredRegister;
    case 'OTP_TOO_MANY_ATTEMPTS_REGISTER':
      return t.apiErrorOtpTooManyAttemptsRegister;
    case 'OTP_INCORRECT':
      final rawLeft = params?['left'];
      final left = rawLeft is num ? rawLeft.toInt() : null;
      if (left == null) return null;
      return t.apiErrorOtpIncorrect(left);
    case 'REGISTER_DUPLICATE':
      return t.apiErrorRegisterDuplicate;
    case 'ACCOUNT_CREATE_FAILED':
      return t.apiErrorAccountCreateFailed;
    case 'LOGIN_FAILED':
      return t.apiErrorLoginFailed;
    case 'FORGOT_PASSWORD_INVALID_EMAIL':
      return t.apiErrorForgotPasswordInvalidEmail;
    case 'RESET_NO_PENDING':
      return t.apiErrorResetNoPending;
    case 'RESET_OTP_EXPIRED':
      return t.apiErrorResetOtpExpired;
    case 'RESET_TOO_MANY_ATTEMPTS':
      return t.apiErrorResetTooManyAttempts;
    case 'RESET_INVALID_REQUEST_TYPE':
      return t.apiErrorResetInvalidRequestType;
    case 'RESET_UPDATE_FAILED':
      return t.apiErrorResetUpdateFailed;
    case 'RESET_PASSWORD_TOO_LONG':
      return t.apiErrorResetPasswordTooLong;
    case 'PROFILE_NAME_TOO_SHORT':
      return t.apiErrorProfileNameTooShort;
    case 'PROFILE_AREAS_TOO_LONG':
      return t.apiErrorProfileAreasTooLong;
    case 'PROFILE_SERVICES_TOO_LONG':
      return t.apiErrorProfileServicesTooLong;
    case 'PASSWORD_CURRENT_INCORRECT':
      return t.apiErrorPasswordCurrentIncorrect;
    case 'PASSWORD_CHANGE_FAILED':
      return t.apiErrorPasswordChangeFailed;
    case 'DELETE_ACCOUNT_NOT_FOUND':
      return t.apiErrorDeleteAccountNotFound;
    case 'DELETE_ACCOUNT_WRONG_PASSWORD':
      return t.apiErrorDeleteAccountWrongPassword;
    case 'DELETE_ACCOUNT_ACTIVE_REQUEST':
      final rawId = params?['id'];
      final id = rawId is num ? rawId.toInt() : null;
      if (id == null) return null;
      return t.apiErrorDeleteAccountActiveRequest(id);
    case 'DELETE_ACCOUNT_BALANCE_REMAINING':
      final rawBalance = params?['balance'];
      final balance = rawBalance is num ? rawBalance : null;
      if (balance == null) return null;
      return t.apiErrorDeleteAccountBalanceRemaining(balance);
    case 'DELETE_ACCOUNT_FAILED':
      return t.apiErrorDeleteAccountFailed;
    case 'REQUEST_INVALID_FIELDS':
      return t.apiErrorRequestInvalidFields;
    case 'REQUEST_DESCRIPTION_TOO_LONG':
      return t.apiErrorRequestDescriptionTooLong;
    case 'REQUEST_SERVICE_TOO_LONG':
      return t.apiErrorRequestServiceTooLong;
    case 'REQUEST_CITY_TOO_LONG':
      return t.apiErrorRequestCityTooLong;
    case 'REQUEST_AREA_TOO_LONG':
      return t.apiErrorRequestAreaTooLong;
    case 'REQUEST_INVALID_COORDINATES':
      return t.apiErrorRequestInvalidCoordinates;
    case 'REQUEST_PREFERRED_TIME_TOO_LONG':
      return t.apiErrorRequestPreferredTimeTooLong;
    case 'REQUEST_TECHNICIAN_UNAVAILABLE':
      return t.apiErrorRequestTechnicianUnavailable;
    case 'REQUEST_NOT_FOUND':
      return t.apiErrorRequestNotFound;
    case 'REQUEST_CANNOT_DELETE_COMPLETED':
      return t.apiErrorRequestCannotDeleteCompleted;
    case 'REQUEST_CANNOT_CANCEL_AFTER_OFFER_ACCEPTED':
      return t.apiErrorRequestCannotCancelAfterOfferAccepted;
    case 'REQUEST_NOT_ACCEPTING_OFFERS':
      return t.apiErrorRequestNotAcceptingOffers;
    case 'REQUEST_ALREADY_CLOSED':
      return t.apiErrorRequestAlreadyClosed;
    case 'REQUEST_CANCEL_FORBIDDEN':
      return t.apiErrorRequestCancelForbidden;
    case 'REQUEST_COMPLETE_CUSTOMER_ONLY':
      return t.apiErrorRequestCompleteCustomerOnly;
    case 'TECHNICIAN_BALANCE_INSUFFICIENT':
      return t.apiErrorTechnicianBalanceInsufficient;
    case 'RATING_NOT_ALLOWED':
      return t.apiErrorRatingNotAllowed;
    case 'RATING_STARS_INVALID':
      return t.apiErrorRatingStarsInvalid;
    case 'RATING_COMMENT_TOO_LONG':
      return t.apiErrorRatingCommentTooLong;
    case 'RATING_ALREADY_EXISTS':
      return t.apiErrorRatingAlreadyExists;
    case 'REQUEST_DIRECT_TO_OTHER_TECHNICIAN':
      return t.apiErrorRequestDirectToOtherTechnician;
    case 'OFFER_ACTIVE_REQUEST_EXISTS':
      final rawId = params?['id'];
      final service = params?['service'];
      final id = rawId is num ? rawId.toInt() : null;
      if (id == null || service is! String || service.isEmpty) return null;
      return t.apiErrorOfferActiveRequestExists(id, service);
    case 'OFFER_SERVICE_NOT_REGISTERED':
      return t.apiErrorOfferServiceNotRegistered;
    case 'INSUFFICIENT_BALANCE':
      final rawRequired = params?['required_balance'];
      final required = rawRequired is num ? rawRequired : null;
      if (required == null) return null;
      return t.apiErrorInsufficientBalance(required);
    case 'OFFER_INVALID_PRICE':
      return t.apiErrorOfferInvalidPrice;
    case 'OFFER_PRICE_TOO_HIGH':
      return t.apiErrorOfferPriceTooHigh;
    case 'OFFER_DURATION_REQUIRED':
      return t.apiErrorOfferDurationRequired;
    case 'OFFER_DURATION_TOO_LONG':
      return t.apiErrorOfferDurationTooLong;
    case 'OFFER_NOTE_TOO_LONG':
      return t.apiErrorOfferNoteTooLong;
    case 'OFFER_NOT_FOUND':
      return t.apiErrorOfferNotFound;
    case 'OFFER_NOT_YOURS':
      return t.apiErrorOfferNotYours;
    case 'DECISION_INVALID':
      return t.apiErrorDecisionInvalid;
    case 'OFFER_DECISION_ALREADY_MADE':
      return t.apiErrorOfferDecisionAlreadyMade;
    case 'OFFER_TECHNICIAN_BUSY':
      return t.apiErrorOfferTechnicianBusy;
    case 'OFFER_CANNOT_WITHDRAW_DECIDED':
      return t.apiErrorOfferCannotWithdrawDecided;
    case 'OFFER_CANNOT_WITHDRAW_AFTER_SELECTION':
      return t.apiErrorOfferCannotWithdrawAfterSelection;
    case 'CHAT_MESSAGE_BLOCKED':
      return t.apiErrorChatMessageBlocked;
    case 'CHAT_MESSAGE_EMPTY':
      return t.apiErrorChatMessageEmpty;
    case 'CHAT_MESSAGE_TOO_LONG':
      return t.apiErrorChatMessageTooLong;
    case 'CHAT_SPOOFED_MEDIA':
      return t.apiErrorChatSpoofedMedia;
    case 'CHAT_ON_CLOSED_REQUEST':
      return t.apiErrorChatOnClosedRequest;
    case 'CHAT_BLOCKED_BY_USER':
      return t.apiErrorChatBlockedByUser;
    case 'CHAT_AUDIO_NOT_RECEIVED':
      return t.apiErrorChatAudioNotReceived;
    case 'CHAT_IMAGE_NOT_RECEIVED':
      return t.apiErrorChatImageNotReceived;
    case 'REPORT_REASON_REQUIRED':
      return t.apiErrorReportReasonRequired;
    case 'REPORT_REASON_TOO_LONG':
      return t.apiErrorReportReasonTooLong;
    case 'CHAT_NO_OTHER_PARTY':
      return t.apiErrorChatNoOtherParty;
    case 'VIOLATION_NOT_FOUND':
      return t.apiErrorViolationNotFound;
    case 'REPORT_NOT_FOUND':
      return t.apiErrorReportNotFound;
    case 'SUPPORT_INVALID_FIELDS':
      return t.apiErrorSupportInvalidFields;
    case 'SUPPORT_INVALID_TYPE':
      final ticketType = params?['ticketType'];
      if (ticketType is! String || ticketType.isEmpty) return null;
      return t.apiErrorSupportInvalidType(ticketType);
    case 'SUPPORT_TICKET_ALREADY_OPEN':
      return t.apiErrorSupportTicketAlreadyOpen;
    case 'SUPPORT_STATUS_INVALID':
      return t.apiErrorSupportStatusInvalid;
    case 'FCM_TOKEN_REQUIRED':
      return t.apiErrorFcmTokenRequired;
    case 'COMPLAINT_EMPTY':
      return t.apiErrorComplaintEmpty;
    case 'COMPLAINT_TOO_LONG':
      return t.apiErrorComplaintTooLong;
    case 'COMPLAINT_NOT_FOUND':
      return t.apiErrorComplaintNotFound;
    case 'SUPPORT_TICKET_NOT_FOUND':
      return t.apiErrorSupportTicketNotFound;
    case 'SUPPORT_CHAT_CLOSED':
      return t.apiErrorSupportChatClosed;
    case 'SUPPORT_MESSAGE_EMPTY':
      return t.apiErrorSupportMessageEmpty;
    case 'TECHNICIAN_NOT_FOUND':
      return t.apiErrorTechnicianNotFound;
    case 'TECHNICIAN_ACCOUNT_UNAVAILABLE':
      return t.apiErrorTechnicianAccountUnavailable;
    case 'PACKAGE_NOT_FOUND':
      return t.apiErrorPackageNotFound;
    case 'TOPUP_TOO_MANY_PENDING':
      return t.apiErrorTopupTooManyPending;
    case 'TOPUP_RECEIPT_REQUIRED':
      return t.apiErrorTopupReceiptRequired;
    case 'TOPUP_INVALID':
      return t.apiErrorTopupInvalid;
    case 'TOPUP_NOTE_TOO_LONG':
      return t.apiErrorTopupNoteTooLong;
    case 'LEDGER_INVALID_USER_ID':
      return t.apiErrorLedgerInvalidUserId;
    case 'NOTIFICATION_NOT_FOUND':
      return t.apiErrorNotificationNotFound;
    case 'FILE_TOO_LARGE':
      return t.apiErrorFileTooLarge;
    case 'FILE_TYPE_NOT_ALLOWED':
      return t.apiErrorFileTypeNotAllowed;
    case 'AUDIO_TYPE_NOT_ALLOWED':
      return t.apiErrorAudioTypeNotAllowed;
    default:
      return null;
  }
}
