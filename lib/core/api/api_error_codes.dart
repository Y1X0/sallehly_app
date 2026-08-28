import '../../l10n/app_localizations.dart';

/// [FIX-ERRCODE-01] يحوّل `code` القادم من الخادم (راجع server.js، كل موقع
/// خطأ فيه يرسل الآن code ثابتاً بجانب نص error العربي) إلى نص مترجَم عبر
/// ARB — بدل عرض نص الخادم العربي دائماً بغضّ النظر عن لغة الواجهة.
///
/// يُستدعى من ApiClient.handleError() فقط، قبل بناء ApiException. لا شاشة
/// بالتطبيق تستدعيه مباشرة، وأي شاشة من الـ32 التي تعرض ApiException.message
/// كما هي لم تتغيّر ولا تحتاج أن تتغيّر — القرار مركزي بهذه الدالة وحدها.
///
/// يُرجع null عندما:
/// - الرمز غير معروف (لم يُضَف بعد لهذه القائمة، أو خادم أقدم/أحدث يرسل رمزاً
///   لم يُبنَ التطبيق ليعرفه بعد)
/// - الرمز معروف لكنه يحتاج params (حالياً OFFER_ACTIVE_REQUEST_EXISTS فقط)
///   ولم تصل بيانات params صالحة (غير موجودة، ليست Map، أو الحقول المطلوبة
///   مفقودة/من نوع خاطئ)
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
    case 'AUTH_ACCOUNT_SUSPENDED':
      return t.apiErrorAuthAccountSuspended;
    case 'AUTH_FORBIDDEN':
      return t.apiErrorAuthForbidden;
    case 'AUTH_INVALID_CREDENTIALS':
      return t.apiErrorAuthInvalidCredentials;
    case 'FORBIDDEN_GENERIC':
      return t.apiErrorForbiddenGeneric;
    case 'REGISTER_INVALID_ROLE':
      return t.apiErrorRegisterInvalidRole;
    case 'REGISTER_NAME_REQUIRED':
      return t.apiErrorRegisterNameRequired;
    case 'REGISTER_TECH_AVATAR_REQUIRED':
      return t.apiErrorRegisterTechAvatarRequired;
    case 'REGISTER_INVALID_EMAIL':
      return t.apiErrorRegisterInvalidEmail;
    case 'REGISTER_INVALID_PHONE':
      return t.apiErrorRegisterInvalidPhone;
    case 'REGISTER_INVALID_NATIONAL_NUMBER':
      return t.apiErrorRegisterInvalidNationalNumber;
    case 'REGISTER_EMAIL_OR_PHONE_TAKEN':
      return t.apiErrorRegisterEmailOrPhoneTaken;
    case 'REGISTER_NATIONAL_NUMBER_TAKEN':
      return t.apiErrorRegisterNationalNumberTaken;
    case 'REGISTER_DUPLICATE':
      return t.apiErrorRegisterDuplicate;
    case 'ACCOUNT_CREATE_FAILED':
      return t.apiErrorAccountCreateFailed;
    case 'ACCOUNT_ALREADY_EXISTS':
      return t.apiErrorAccountAlreadyExists;
    case 'OTP_MISSING_FIELDS':
      return t.apiErrorOtpMissingFields;
    case 'OTP_NOT_FOUND':
      return t.apiErrorOtpNotFound;
    case 'OTP_EXPIRED':
      return t.apiErrorOtpExpired;
    case 'OTP_INVALID':
      return t.apiErrorOtpInvalid;
    case 'OTP_REGISTRATION_MISSING':
      return t.apiErrorOtpRegistrationMissing;
    case 'OTP_RESEND_NO_PENDING':
      return t.apiErrorOtpResendNoPending;
    case 'PASSWORD_TOO_SHORT':
      return t.apiErrorPasswordTooShort;
    case 'PASSWORD_CURRENT_INCORRECT':
      return t.apiErrorPasswordCurrentIncorrect;
    case 'REQUEST_INVALID_FIELDS':
      return t.apiErrorRequestInvalidFields;
    case 'REQUEST_NOT_FOUND':
      return t.apiErrorRequestNotFound;
    case 'REQUEST_CANNOT_DELETE_COMPLETED':
      return t.apiErrorRequestCannotDeleteCompleted;
    case 'REQUEST_NOT_ACCEPTING_OFFERS':
      return t.apiErrorRequestNotAcceptingOffers;
    case 'REQUEST_INVALID_STATUS':
      return t.apiErrorRequestInvalidStatus;
    case 'REQUEST_COMPLETE_CUSTOMER_ONLY':
      return t.apiErrorRequestCompleteCustomerOnly;
    case 'OFFER_ACTIVE_REQUEST_EXISTS':
      final rawId = params?['id'];
      final service = params?['service'];
      final id = rawId is num ? rawId.toInt() : null;
      if (id == null || service is! String || service.isEmpty) return null;
      return t.apiErrorOfferActiveRequestExists(id, service);
    case 'OFFER_INVALID_PRICE':
      return t.apiErrorOfferInvalidPrice;
    case 'OFFER_DURATION_REQUIRED':
      return t.apiErrorOfferDurationRequired;
    case 'OFFER_NOT_FOUND':
      return t.apiErrorOfferNotFound;
    case 'OFFER_NOT_YOURS':
      return t.apiErrorOfferNotYours;
    case 'OFFER_TECHNICIAN_BUSY':
      return t.apiErrorOfferTechnicianBusy;
    case 'DECISION_INVALID':
      return t.apiErrorDecisionInvalid;
    case 'CHAT_BLOCKED_CONTACT_INFO':
      return t.apiErrorChatBlockedContactInfo;
    case 'MESSAGE_EMPTY':
      return t.apiErrorMessageEmpty;
    case 'AUDIO_FILE_MISSING':
      return t.apiErrorAudioFileMissing;
    case 'RATING_NOT_ALLOWED':
      return t.apiErrorRatingNotAllowed;
    case 'RATING_STARS_INVALID':
      return t.apiErrorRatingStarsInvalid;
    case 'RATING_ALREADY_EXISTS':
      return t.apiErrorRatingAlreadyExists;
    case 'PACKAGE_NOT_FOUND':
      return t.apiErrorPackageNotFound;
    case 'TOPUP_RECEIPT_REQUIRED':
      return t.apiErrorTopupReceiptRequired;
    case 'TOPUP_INVALID':
      return t.apiErrorTopupInvalid;
    case 'TECHNICIAN_BALANCE_INSUFFICIENT':
      return t.apiErrorTechnicianBalanceInsufficient;
    case 'PROFILE_NAME_TOO_SHORT':
      return t.apiErrorProfileNameTooShort;
    case 'PROFILE_PHONE_INVALID':
      return t.apiErrorProfilePhoneInvalid;
    case 'SERVICE_NAME_TOO_SHORT':
      return t.apiErrorServiceNameTooShort;
    case 'SERVICE_ALREADY_EXISTS':
      return t.apiErrorServiceAlreadyExists;
    case 'SERVICE_CREATE_FAILED':
      return t.apiErrorServiceCreateFailed;
    case 'SUPPORT_INVALID_FIELDS':
      return t.apiErrorSupportInvalidFields;
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
