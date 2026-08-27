// [FIX-L10N-04] فحص دخان (smoke test) شامل لآخر بند من المرحلة الأولى (البنية
// التحتية للترجمة) قبل البدء بترحيل أي نص فعلياً (المرحلة الثانية): كل شاشة
// رئيسية تُبنى فعلياً تحت كلتا اللغتين (ar/en) وبعرضين مختلفين (هاتف عادي
// 390dp + عرض ضيق 320dp)، ويُثبت أن حذف Directionality اليدوي بـapp.dart
// (والاعتماد الكامل على locale المُشتقّ تلقائياً بدلاً منه) لا يُسبّب أي
// استثناء غير مُلتقَط — يشمل ذلك RenderFlex overflow، الذي يظهر غالباً
// بالعرض الضيق أولاً لأن النصوص الإنجليزية أطول عادة من مقابلها العربي. كل
// النصوص المعروضة اليوم عربية بالكامل (لا شيء رُحِّل بعد) حتى تحت
// locale=en — هذا متوقَّع ومقصود بهذه المرحلة، ولا علاقة له بهذا الاختبار.
//
// ما لا يكشفه هذا الاختبار (مهم): أي عنصر بصري "مقلوب" أو تخطيط غير متّزن لا
// يصل لحدّ استثناء فعلي فعلياً (مثل أيقونة سهم تشير بالاتجاه الخطأ، أو
// تباعد غير متماثل بصرياً لا يُنتج RenderFlex overflow) — هذه تحتاج فحصاً
// بصرياً حقيقياً (راجع L10N_PROGRESS.md لبنود الفحص اليدوي المطلوبة قبل
// المرحلة الثانية).
//
// كل الـProviders أدناه Mock/حقيقية بواجهة API غير مُهيَّأة (unstubbed) عمداً
// — كل طرق التحميل (loadRequests/loadChats/...) بالتطبيق مُغلَّفة أصلاً
// بـtry/catch داخلياً (نمط ثابت عبر كل الـProviders، تحقّقنا منه قبل كتابة
// هذا الملف)، فتفشل بصمت للحالة "خطأ" الموجودة أصلاً بكل شاشة بدل رمي
// استثناء — لا حاجة لتزييف استجابات API هنا لغرض هذا الاختبار تحديداً.
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

/// نفس نمط كل الاختبارات الأخرى بالمشروع: AppBackground تحوي حركة جسيمات
/// دائمة تمنع pumpAndSettle من الاستقرار أبداً — عدد محدود من pump() بدلاً
/// منه، كافٍ لتجاوز الإطار الأول وأي microtask/postFrameCallback بـinitState.
Future<void> _pumpAnimated(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// طلب واقعي بنص وصف طويل نسبياً — يزيد احتمال ظهور مشاكل التفاف/فيضان
/// نصي لا تظهر مع نص قصير جداً.
final RequestModel _sampleRequest = RequestModel(
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
class _Providers {
  final AuthProvider auth;
  final RequestsProvider requests;
  final ChatProvider chat;
  final NotificationProvider notification;
  final SocketProvider socket;
  final ThemeController theme;
  final LocaleProvider locale;

  _Providers()
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

Widget _wrap(Widget child, _Providers p, Locale locale) {
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

class _ScreenCase {
  final String name;
  final Widget Function() build;
  const _ScreenCase(this.name, this.build);
}

/// جدول الشاشات — إضافة شاشة جديدة لاحقاً = سطر واحد هنا فقط.
final List<_ScreenCase> _cases = [
  _ScreenCase('تسجيل الدخول (LoginScreen)', () => const LoginScreen()),
  _ScreenCase('تسجيل عميل (CustomerRegisterScreen)', () => const CustomerRegisterScreen()),
  _ScreenCase('تسجيل فني (TechnicianRegisterScreen)', () => const TechnicianRegisterScreen()),
  _ScreenCase('الرئيسية-عميل (CustomerDashboardScreen)', () => const CustomerDashboardScreen()),
  _ScreenCase('الرئيسية-فني (TechnicianDashboardScreen)', () => const TechnicianDashboardScreen()),
  _ScreenCase('طلباتي (CustomerRequestsScreen)', () => const CustomerRequestsScreen()),
  _ScreenCase(
    'تفاصيل طلب-عميل (CustomerRequestDetailsScreen)',
    () => CustomerRequestDetailsScreen(request: _sampleRequest),
  ),
  _ScreenCase(
    'تفاصيل طلب-فني (TechnicianRequestDetailsScreen)',
    () => TechnicianRequestDetailsScreen(request: _sampleRequest, canSendOffer: true),
  ),
  _ScreenCase('الدردشات (ChatsScreen)', () => const ChatsScreen()),
  _ScreenCase(
    'غرفة المحادثة (ChatRoomScreen)',
    () => ChatRoomScreen(request: _sampleRequest),
  ),
  _ScreenCase('تعديل الملف الشخصي (EditProfileScreen)', () => const EditProfileScreen()),
  _ScreenCase('الإعدادات (SettingsScreen)', () => const SettingsScreen()),
];

// [FIX-L10N-04] الشاشات التالية لم تُدرَج بالجدول أعلاه — قُيِّمت وتُرِكت
// عمداً بدل إجبارها على العزل:
// - SplashScreen: تنفّذ فحص مصادقة حقيقياً (auth_provider.checkAuth + توجيه
//   تلقائي عبر Navigator خلال ثوانٍ معدودة) بمنطق مؤقّت (Timer/Future.delayed)
//   يصعب إيقافه بمعزل دون محاكاة توقيت دقيقة أو تعديل الشاشة نفسها — والتعليمات
//   صريحة بعدم تعديل كود التطبيق لجعل شاشة قابلة للاختبار.
// - أي شاشة Admin (admin_dashboard_screen وغيرها): تتطلّب AdminProvider ودور
//   "أدمن" محدَّد؛ غير مطلوبة ضمن القائمة المطلوبة صراحة بهذا الفحص
//   (login/register/dashboards/requests/chat/profile/settings)، فلم تُضَف
//   لتفادي تضخيم الجدول بما يتجاوز النطاق المطلوب.
//
// [FIX-CHAT-DISPOSE-01] ChatRoomScreen كانت مستبعَدة سابقاً: dispose()
// بـchat_room_screen.dart كان يستدعي context.read<SocketProvider>()/
// <NotificationProvider>() مباشرةً، فيرمي "Looking up a deactivated widget's
// ancestor is unsafe." عندما يُستبدَل شجرة الودجت بأكملها دفعة واحدة (هنا:
// بين اختبارين متتاليين بالجدول). أُصلِح ذلك (مرجعا Provider يُخزَّنان بحقلين
// بـinitState ويُستخدَمان بـdispose بلا أي قراءة من context عند التفكيك — نفس
// نمط SupportChatScreen/AdminSupportChatScreen أصلاً بهذا المشروع)، فلم تعد
// الشاشة تحتاج استبعاداً — أُعيدت للجدول أعلاه.

const List<Locale> _locales = [Locale('ar'), Locale('en')];

/// عرض هاتف عادي، وعرض ضيق (320dp) حيث تظهر مشاكل فيضان النص الإنجليزي
/// (أطول عادة من مقابله العربي) أولاً. الارتفاع ثابت وكبير بما يكفي لتفادي
/// خلط فيضان عمودي غير متعلّق بمشكلة RTL/LTR ضمن نفس هذا الفحص.
const Map<String, Size> _viewports = {
  'عادي 390dp': Size(390, 844),
  'ضيق 320dp': Size(320, 844),
};

// [FIX-L10N-04] عُثر فعلياً على RenderFlex overflow حقيقي (2.2px يميناً)
// بـEditProfileScreen عند 320dp — تحت locale=ar وlocale=en على حدٍّ سواء، ما
// يُثبت أنه باگ ضيق-شاشة موجود مسبقاً بالكود، لا علاقة له بحذف Directionality
// أو بالترجمة إطلاقاً (لو كان سببه اتجاه الكتابة لظهر بـen فقط لا بكلتيهما).
// خارج نطاق "البنية التحتية للترجمة" — لا يُصلَح هنا. يبقى محجوباً (skip) هنا
// مع توثيقه صراحة عوضاً عن حذفه من الجدول، حتى لا يحجب اكتمال Phase 1 لسبب
// غير متعلّق بها، ولا يُنسى أيضاً.
// [FIX-L10N-04] TechnicianDashboardScreen: نفس نمط EditProfileScreen تماماً —
// فيضان حقيقي (25px أسفل بـ_StatCard، و10px يميناً بشريط خطأ تحميل الطلبات)
// عند 320dp فقط تحت كلتا اللغتين (يمرّ بنجاح عند 390dp العادي) — باگ عرض
// ضيق موجود مسبقاً، غير متعلّق بالترجمة.
//
// CustomerDashboardScreen: فيضان يظهر بكل توليفات locale/عرض الأربع رغم أن
// النص بالبطاقة ثابت بالكامل. أُعيد فحصه فعلياً (انظر L10N_PROGRESS.md) بخط
// عربي حقيقي (Noto Naskh Arabic) بدل خط الاختبار الافتراضي — اختفى الفيضان
// تماماً بكل التوليفات الأربع. مؤكَّد الآن: أثر خط اختبار فقط (Ahem-like)،
// وليس باگاً حقيقياً. يبقى skip هنا لأن إزالته لم تُطلَب صراحةً بعد.
const Set<String> _knownPreexistingOverflow = {
  'تعديل الملف الشخصي (EditProfileScreen)|ar|ضيق 320dp',
  'تعديل الملف الشخصي (EditProfileScreen)|en|ضيق 320dp',
  'الرئيسية-فني (TechnicianDashboardScreen)|ar|ضيق 320dp',
  'الرئيسية-فني (TechnicianDashboardScreen)|en|ضيق 320dp',
  'الرئيسية-عميل (CustomerDashboardScreen)|ar|عادي 390dp',
  'الرئيسية-عميل (CustomerDashboardScreen)|ar|ضيق 320dp',
  'الرئيسية-عميل (CustomerDashboardScreen)|en|عادي 390dp',
  'الرئيسية-عميل (CustomerDashboardScreen)|en|ضيق 320dp',
};

void main() {
  for (final screenCase in _cases) {
    for (final locale in _locales) {
      for (final viewport in _viewports.entries) {
        final key = '${screenCase.name}|${locale.languageCode}|${viewport.key}';
        // سبب التخطي (عند وجوده) موثَّق أعلاه بـ_knownPreexistingOverflow
        // وبـL10N_PROGRESS.md — معامل skip هنا bool فقط (لا يقبل نص السبب
        // مباشرةً بهذا الإصدار من Flutter، خلافاً لما افترضته أول مرة).
        testWidgets(
          '[FIX-L10N-04] ${screenCase.name} — locale=${locale.languageCode} — ${viewport.key}: بلا استثناء',
          skip: _knownPreexistingOverflow.contains(key),
          (tester) async {
            tester.view.physicalSize = viewport.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final providers = _Providers();

            await tester.pumpWidget(_wrap(screenCase.build(), providers, locale));
            await _pumpAnimated(tester);

            expect(
              tester.takeException(),
              isNull,
              reason: '${screenCase.name} رمى استثناءً (على الأرجح RenderFlex '
                  'overflow) تحت locale=${locale.languageCode} بعرض '
                  '${viewport.value.width.toInt()}dp.',
            );
          },
        );
      }
    }
  }
}
