class ApiEndpoints {
  ApiEndpoints._();

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String verifyOtp = '/auth/verify-otp';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String logout = '/auth/logout';
  static const String me = '/me';
  static const String meProfile = '/me/profile';
  static const String mePassword = '/me/password';

  static const String meta = '/meta';
  static const String paymentMethods = '/payment-methods';

  static const String requests = '/requests';

  static String requestById(int id) => '/requests/$id';
  static String requestOffers(int id) => '/requests/$id/offers';
  static String createOffer(int id) => '/requests/$id/offer';
  static String offerDecision(int id) => '/offers/$id/decision';
  static String requestMessages(int id) => '/requests/$id/messages';
  static String requestAudio(int id) => '/requests/$id/audio';
  static String requestImages(int id) => '/requests/$id/images';
  static String reportMessage(int id) => '/requests/$id/report-message';
  static String requestBlock(int id) => '/requests/$id/block';
  static String requestBlockStatus(int id) => '/requests/$id/block-status';
  static String requestStatus(int id) => '/requests/$id/status';
  static String requestRate(int id) => '/requests/$id/rate';
  static const String complaints = '/complaints';
  static String technicianProfile(int id) => '/technicians/$id/profile';

  static const String topups = '/topups';
  static const String ledger = '/ledger';

  static const String chats = '/chats';
  static const String support = '/support';
  static const String supportMy = '/support/my';
  static String supportMessages(int id) => '/support/$id/messages';

  static const String adminStats = '/admin/stats';
  static const String adminUsers = '/admin/users';
  static String adminToggleUser(int id) => '/admin/users/$id/toggle';
  static String adminUserProfile(int id) => '/admin/users/$id/profile';
  static String adminUserBalance(int id) => '/admin/users/$id/balance';
  static String adminDeleteUser(int id) => '/admin/users/$id';

  static String adminReviewTopup(int id) => '/admin/topups/$id/review';

  static const String adminPackages = '/admin/packages';
  static const String adminServices = '/admin/services';
  static String adminPackageDelete(int id) => '/admin/packages/$id';
  static String adminServiceDelete(int id) => '/admin/services/$id';

  static const String adminAuditLogs = '/admin/audit-logs';

  static const String adminViolations = '/chat-violations';
  static const String adminComplaints = '/complaints';
  static const String adminMessageReports = '/message-reports';
  static String complaintStatus(int id) => '/complaints/$id/status';
  static String adminUpdatePackage(int id) => '/admin/packages/$id';

  // [FIX-SUPERADMIN-01]
  static String adminUserDetail(int id) => '/admin/users/$id';
  static String adminUserRole(int id) => '/admin/users/$id/role';
  static String adminUserVerify(int id) => '/admin/users/$id/verify';
  static const String adminLedger = '/admin/ledger';
  static String chatViolationStatus(int id) => '/chat-violations/$id/status';
  static String messageReportStatus(int id) => '/message-reports/$id/status';

  static const String adminRequests = '/requests';
  static String adminCancelRequest(int id) => '/admin/requests/$id/cancel';
  static String adminRequestStatus(int id) => '/requests/$id/status';

  static String supportStatus(int id) => '/support/$id/status';

  // [NOTIF-FLUTTER-PHASE1]
  static const String notifications = '/notifications';
  static String notificationRead(int id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';
}