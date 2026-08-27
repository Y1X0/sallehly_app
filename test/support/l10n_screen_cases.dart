// جدول الشاشات/الـProviders المشترك بين اختبارَي الترجمة: فحص الدخان
// (l10n_screen_smoke_test.dart، يُثبت غياب أي استثناء) وملتقط لقطات الشاشة
// (l10n_screenshot_capture_test.dart، يُصدر PNG لكل حالة كـCI artifact).
// استُخرِج هنا لتفادي ازدواج نفس الجدول بملفين قد ينحرفان عن بعضهما لاحقاً
// (مثلاً: شاشة جديدة تُضاف لملف وتُنسى بالآخر).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/socket/socket_service.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/features/auth/screens/customer_register_screen.dart';
import 'package:sallehly_app/features/auth/screens/login_screen.dart';
import 'package:sallehly_app/features/auth/screens/technician_register_screen.dart';
import 'package:sallehly_app/features/chat/provider/chat_provider.dart';
import 'package:sallehly_app/features/chat/screens/chat_room_screen.dart';
import 'package:sallehly_app/features/chat/screens/chats_screen.dart';
import 'package:sallehly_app/features/customer/screens/customer_dashboard_screen.dart';
import 'package:sallehly_app/features/customer/screens/customer_request_details_screen.dart';
import 'package:sallehly_app/features/customer/screens/customer_requests_screen.dart';
import 'package:sallehly_app/features/requests/provider/requests_provider.dart';
import 'package:sallehly_app/features/settings/screens/edit_profile_screen.dart';
import 'package:sallehly_app/features/settings/screens/settings_screen.dart';
import 'package:sallehly_app/features/technician/screens/technician_dashboard_screen.dart';
import 'package:sallehly_app/features/technician/screens/technician_request_details_screen.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';
import 'package:sallehly_app/models/request_model.dart';
import 'package:sallehly_app/providers/auth_provider.dart';
import 'package:sallehly_app/providers/locale_provider.dart';
import 'package:sallehly_app/providers/notification_provider.dart';
import 'package:sallehly_app/providers/socket_provider.dart';
import 'package:sallehly_app/providers/theme_controller.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockAppStorage extends Mock implements AppStorage {}

class MockApiClient extends Mock implements ApiClient {}

/// طلب واقعي بنص وصف طويل نسبياً — يزيد احتمال ظهور مشاكل التفاف/فيضان
/// نصي لا تظهر مع نص قصير جداً.
final RequestModel sampleRequest = RequestModel(
  id: 1,
  customerId: 7,
  service: 'كهربائي',
  city: 'عمّان',
  area: 'جبل الحسين',
  description:
      'يوجد عطل متكرر في التمديدات الكهربائية بالمطبخ ويحتاج فحصاً عاجلاً '
      'قبل نهاية اليوم إن أمكن، الرجاء التواصل بأقرب وقت ممكن للتنسيق.',
  status: 'بانتظار العروض',
  createdAt: DateTime(2026, 1, 1),
);

/// كل الـProviders التي تحتاجها أي شاشة من الشاشات أدناه مجتمعة بشجرة واحدة
/// موحَّدة — أبسط من تخصيص شجرة مختلفة لكل شاشة، ولا ضرر من وجود Provider
/// غير مُستخدَم فعلياً من شاشة معيّنة.
class TestProviders {
  final AuthProvider auth;
  final RequestsProvider requests;
  final ChatProvider chat;
  final NotificationProvider notification;
  final SocketProvider socket;
  final ThemeController theme;
  final LocaleProvider locale;

  TestProviders()
      : auth = AuthProvider(
          tokenStorage: MockTokenStorage(),
          apiClient: MockApiClient(),
          appStorage: MockAppStorage(),
          authApiOverride: MockAuthApi(),
        ),
        requests = RequestsProvider(apiClient: MockApiClient()),
        chat = ChatProvider(apiClient: MockApiClient()),
        notification = NotificationProvider(),
        socket = SocketProvider(
          socketService: SocketService(),
          tokenStorage: MockTokenStorage(),
        ),
        theme = ThemeController(),
        locale = LocaleProvider();
}

Widget wrapScreen(Widget child, TestProviders p, Locale locale) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: p.auth),
      ChangeNotifierProvider<RequestsProvider>.value(value: p.requests),
      ChangeNotifierProvider<ChatProvider>.value(value: p.chat),
      ChangeNotifierProvider<NotificationProvider>.value(value: p.notification),
      ChangeNotifierProvider<SocketProvider>.value(value: p.socket),
      ChangeNotifierProvider<ThemeController>.value(value: p.theme),
      ChangeNotifierProvider<LocaleProvider>.value(value: p.locale),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

class ScreenCase {
  final String name;

  /// مُعرِّف ascii فقط (بلا عربي/مسافات) — يُستخدَم باسم ملف لقطة الشاشة.
  final String slug;
  final Widget Function() build;

  const ScreenCase(this.name, this.slug, this.build);
}

/// جدول الشاشات — إضافة شاشة جديدة لاحقاً = سطر واحد هنا فقط (يظهر تلقائياً
/// بكلا فحص الدخان وملتقط لقطات الشاشة).
final List<ScreenCase> screenCases = [
  ScreenCase('تسجيل الدخول (LoginScreen)', 'login_screen', () => const LoginScreen()),
  ScreenCase(
    'تسجيل عميل (CustomerRegisterScreen)',
    'customer_register_screen',
    () => const CustomerRegisterScreen(),
  ),
  ScreenCase(
    'تسجيل فني (TechnicianRegisterScreen)',
    'technician_register_screen',
    () => const TechnicianRegisterScreen(),
  ),
  ScreenCase(
    'الرئيسية-عميل (CustomerDashboardScreen)',
    'customer_dashboard_screen',
    () => const CustomerDashboardScreen(),
  ),
  ScreenCase(
    'الرئيسية-فني (TechnicianDashboardScreen)',
    'technician_dashboard_screen',
    () => const TechnicianDashboardScreen(),
  ),
  ScreenCase(
    'طلباتي (CustomerRequestsScreen)',
    'customer_requests_screen',
    () => const CustomerRequestsScreen(),
  ),
  ScreenCase(
    'تفاصيل طلب-عميل (CustomerRequestDetailsScreen)',
    'customer_request_details_screen',
    () => CustomerRequestDetailsScreen(request: sampleRequest),
  ),
  ScreenCase(
    'تفاصيل طلب-فني (TechnicianRequestDetailsScreen)',
    'technician_request_details_screen',
    () => TechnicianRequestDetailsScreen(request: sampleRequest, canSendOffer: true),
  ),
  ScreenCase('الدردشات (ChatsScreen)', 'chats_screen', () => const ChatsScreen()),
  ScreenCase(
    'غرفة المحادثة (ChatRoomScreen)',
    'chat_room_screen',
    () => ChatRoomScreen(request: sampleRequest),
  ),
  ScreenCase(
    'تعديل الملف الشخصي (EditProfileScreen)',
    'edit_profile_screen',
    () => const EditProfileScreen(),
  ),
  ScreenCase('الإعدادات (SettingsScreen)', 'settings_screen', () => const SettingsScreen()),
];

// الشاشات التالية لم تُدرَج بالجدول أعلاه — قُيِّمت وتُرِكت عمداً بدل إجبارها
// على العزل:
// - SplashScreen: تنفّذ فحص مصادقة حقيقياً (auth_provider.checkAuth + توجيه
//   تلقائي عبر Navigator خلال ثوانٍ معدودة) بمنطق مؤقّت (Timer/Future.delayed)
//   يصعب إيقافه بمعزل دون محاكاة توقيت دقيقة أو تعديل الشاشة نفسها — والتعليمات
//   صريحة بعدم تعديل كود التطبيق لجعل شاشة قابلة للاختبار.
// - أي شاشة Admin (admin_dashboard_screen وغيرها): تتطلّب AdminProvider ودور
//   "أدمن" محدَّد؛ غير مطلوبة ضمن القائمة المطلوبة صراحة بهذا الفحص
//   (login/register/dashboards/requests/chat/profile/settings)، فلم تُضَف
//   لتفادي تضخيم الجدول بما يتجاوز النطاق المطلوب.

const List<Locale> testLocales = [Locale('ar'), Locale('en')];

class TestViewport {
  /// عربي — يبقى مطابقاً لما استُخدِم سابقاً بمفاتيح _knownPreexistingOverflow
  /// (فحص الدخان) ولوصف الاختبار.
  final String label;

  /// ascii فقط — يُستخدَم باسم ملف لقطة الشاشة.
  final String slug;
  final Size size;

  const TestViewport(this.label, this.slug, this.size);
}

/// عرض هاتف عادي، وعرض ضيق (320dp) حيث تظهر مشاكل فيضان النص الإنجليزي
/// (أطول عادة من مقابله العربي) أولاً. الارتفاع ثابت وكبير بما يكفي لتفادي
/// خلط فيضان عمودي غير متعلّق بمشكلة RTL/LTR ضمن نفس هذا الفحص.
const List<TestViewport> testViewports = [
  TestViewport('عادي 390dp', '390dp', Size(390, 844)),
  TestViewport('ضيق 320dp', '320dp', Size(320, 844)),
];

/// نفس نمط كل الاختبارات الأخرى بالمشروع: AppBackground تحوي حركة جسيمات
/// دائمة تمنع pumpAndSettle من الاستقرار أبداً — عدد محدود من pump() بدلاً
/// منه، كافٍ لتجاوز الإطار الأول وأي microtask/postFrameCallback بـinitState.
Future<void> pumpAnimated(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}
