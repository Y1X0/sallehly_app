// [BUG-FIX-DEEPLINKRACE-01] راجع DECISIONS.md. bindAuthLifecycleCallbacks
// (app.dart) — سابقاً إغلاق onAuthenticated inline — كانت تمسح
// FirebaseNotificationService.pendingDeepLink فور تسجيل الدخول/استعادة
// الجلسة. main.dart يستدعي FirebaseNotificationService.init() (يملأ
// pendingDeepLink من getInitialMessage() عند إقلاع بارد بضغطة إشعار) قبل
// runApp()، وonAuthenticated يُطلَق أثناء استعادة الجلسة — قبل بناء أي شاشة
// Layout بحسب الدور، وقبل أن يصل أي مستهلك حقيقي (مستمع Layout المُرفَق
// لاحقاً، أو postFrameCallback الخاص به) لهذه القيمة. النتيجة: كل إقلاع بارد
// من ضغطة إشعار مع جلسة محفوظة يفقد هدف التنقّل بصمت، ١٠٠٪ من الوقت.
//
// هذا الاختبار يستدعي bindAuthLifecycleCallbacks الحقيقية (لا نسخة معاد
// كتابتها) بمزوّدات وهمية، يضبط pendingDeepLink كما يفعل main.dart فعلياً
// قبل استدعاء onAuthenticated، ثم يثبت أن القيمة تبقى موجودة بعدها — أي أن
// أي مستهلك يُرفَق لاحقاً (مثل Layout) سيجدها. يثبت أيضاً أن onLoggedOut
// وحدها من تمسحها.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/app.dart';
import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/notifications/firebase_notification_service.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/socket/socket_service.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/admin/provider/admin_provider.dart';
import 'package:sallehly_app/features/chat/data/chat_api.dart';
import 'package:sallehly_app/features/chat/provider/chat_provider.dart';
import 'package:sallehly_app/features/requests/provider/requests_provider.dart';
import 'package:sallehly_app/features/support/provider/support_provider.dart';
import 'package:sallehly_app/features/wallet/provider/wallet_provider.dart';
import 'package:sallehly_app/providers/auth_provider.dart';
import 'package:sallehly_app/providers/notification_provider.dart';
import 'package:sallehly_app/providers/socket_provider.dart';
import 'package:sallehly_app/models/chat_summary_model.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockChatApi extends Mock implements ChatApi {}

class MockSocketService extends Mock implements SocketService {}

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late AuthProvider authProvider;
  late SocketProvider socketProvider;
  late NotificationProvider notificationProvider;
  late ChatProvider chatProvider;
  late RequestsProvider requestsProvider;
  late WalletProvider walletProvider;
  late AdminProvider adminProvider;
  late SupportProvider supportProvider;
  late MockChatApi mockChatApi;
  late MockSocketService mockSocketService;
  late MockTokenStorage mockTokenStorage;

  setUp(() {
    mockChatApi = MockChatApi();
    mockSocketService = MockSocketService();
    mockTokenStorage = MockTokenStorage();

    when(() => mockChatApi.getChats()).thenAnswer((_) async => (<ChatSummaryModel>[], 0));
    when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'tok');
    when(() => mockSocketService.connect(token: any(named: 'token'))).thenReturn(null);
    when(() => mockSocketService.disconnect()).thenReturn(null);
    when(() => mockSocketService.on(any(), any())).thenReturn(null);

    authProvider = AuthProvider(
      tokenStorage: MockTokenStorage(),
      apiClient: MockApiClient(),
      appStorage: MockAppStorage(),
    );
    socketProvider = SocketProvider(socketService: mockSocketService, tokenStorage: mockTokenStorage);
    // لا apiClient — loadNotifications() تصير no-op صامتة (راجع notification_provider.dart).
    notificationProvider = NotificationProvider();
    chatProvider = ChatProvider(apiClient: MockApiClient(), apiOverride: mockChatApi);
    requestsProvider = RequestsProvider(apiClient: MockApiClient());
    walletProvider = WalletProvider(apiClient: MockApiClient());
    adminProvider = AdminProvider(apiClient: MockApiClient());
    supportProvider = SupportProvider(apiClient: MockApiClient());

    bindAuthLifecycleCallbacks(
      authProvider: authProvider,
      socketProvider: socketProvider,
      notificationProvider: notificationProvider,
      chatProvider: chatProvider,
      requestsProvider: requestsProvider,
      walletProvider: walletProvider,
      adminProvider: adminProvider,
      supportProvider: supportProvider,
    );
  });

  tearDown(() {
    FirebaseNotificationService.pendingDeepLink.value = null;
  });

  test(
    '[BUG-FIX-DEEPLINKRACE-01] onAuthenticated لا تمسح pendingDeepLink — يبقى متاحاً لمستهلك لاحق (مثل Layout)',
    () async {
      // بالضبط كما يفعل main.dart: init() يملأ القيمة من getInitialMessage()
      // قبل runApp()، أي قبل أن يُطلَق onAuthenticated بلحظات أثناء استعادة الجلسة.
      FirebaseNotificationService.pendingDeepLink.value = {'type': 'request', 'requestId': '7'};

      await authProvider.onAuthenticated!();

      expect(
        FirebaseNotificationService.pendingDeepLink.value,
        equals({'type': 'request', 'requestId': '7'}),
        reason: 'onAuthenticated مسحت هدف التنقّل قبل أن يصل أي Layout لاستهلاكه',
      );
    },
  );

  test(
    '[SEC-FIX-DEEPLINKCLEAR-01] onLoggedOut تمسح pendingDeepLink — يمنع تسريب هدف تنقّل لحساب لاحق على نفس الجهاز',
    () {
      FirebaseNotificationService.pendingDeepLink.value = {'type': 'chat', 'requestId': '1'};

      authProvider.onLoggedOut!();

      expect(FirebaseNotificationService.pendingDeepLink.value, isNull);
    },
  );
}

/// AppStorage الحقيقي يتطلب SharedPreferences (قناة platform) — بما أن
/// onAuthenticated/onLoggedOut هنا لا يستدعيان أي طريقة من appStorage إطلاقاً
/// (المسح المدفوع بتسجيل الدخول يحدث داخل AuthProvider.login()/verifyOtp()
/// نفسها، لا هنا)، Mock فارغ بلا أي `when()` يكفي تماماً.
class MockAppStorage extends Mock implements AppStorage {}
