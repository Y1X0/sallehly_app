// أداة تشخيصية مؤقتة (غير دائمة، تُحذف بعد استخلاص النتيجة) — الغرض الوحيد:
// إثبات هل فيضانات RenderFlex بشاشة CustomerDashboardScreen (بطاقة الهيرو
// وعنوان "خدمات صلّحلي") ناتجة فعلاً عن حجم نص عربي حقيقي، أم مجرد أثر خط
// الاختبار الافتراضي بفلَتّر (حروف بعرض ثابت مربّع أعرض غالباً من الخط
// العربي الحقيقي، ولا يطبّق أي دمج/تشكيل حروف عربي حقيقي).
//
// الآلية: عندما ThemeData.fontFamily == null (حال AppTheme فعلياً، وحال
// ThemeData الافتراضي المستخدَم هنا)، تفرض Typography الداخلية بفلَتّر اسم
// عائلة 'Roboto' ضمنياً لكل TextStyle (لأي منصّة غير Apple، بما فيها بيئة
// الاختبار). نحمّل هنا خطاً عربياً حقيقياً (Noto Naskh/Sans Arabic، مثبَّتاً
// بخطوة CI منفصلة عبر apt — ليس أصلاً بالمشروع ولا تعديلاً بـpubspec.yaml)
// تحت نفس اسم العائلة 'Roboto' عبر FontLoader، فيستبدل قياسات الخط الحقيقية
// (بما فيها التشكيل/الالتحام الصحيح للحروف العربية) قياسات خط الاختبار
// الوهمي — دون أي تعديل على أي ملف بـlib/.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/socket/socket_service.dart';
import 'package:sallehly_app/core/storage/app_storage.dart';
import 'package:sallehly_app/core/storage/token_storage.dart';
import 'package:sallehly_app/features/auth/data/auth_api.dart';
import 'package:sallehly_app/features/customer/screens/customer_dashboard_screen.dart';
import 'package:sallehly_app/features/chat/provider/chat_provider.dart';
import 'package:sallehly_app/l10n/app_localizations.dart';
import 'package:sallehly_app/providers/auth_provider.dart';
import 'package:sallehly_app/providers/locale_provider.dart';
import 'package:sallehly_app/providers/notification_provider.dart';
import 'package:sallehly_app/providers/socket_provider.dart';
import 'package:sallehly_app/providers/theme_controller.dart';
import 'package:sallehly_app/features/requests/provider/requests_provider.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockAppStorage extends Mock implements AppStorage {}

class MockApiClient extends Mock implements ApiClient {}

Future<void> _pumpAnimated(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// المسار يُمرَّر عبر متغيّر بيئة من خطوة CI (تثبيت apt)، لا كأصل بالمشروع.
Future<void> _loadRealArabicFontAsRoboto() async {
  final path = Platform.environment['REAL_ARABIC_FONT_PATH'] ?? '/tmp/real_fonts/arabic.ttf';
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      'خط عربي حقيقي غير موجود بالمسار $path — راجع خطوة تثبيت الخط بـCI.',
    );
  }
  final bytes = await file.readAsBytes();
  final loader = FontLoader('Roboto');
  loader.addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
  await loader.load();
  // ignore: avoid_print
  print('[FONT-DIAG] خط عربي حقيقي محمَّل من $path (${bytes.length} بايت) تحت العائلة Roboto.');
}

Widget _wrap(Locale locale) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(
        value: AuthProvider(
          tokenStorage: MockTokenStorage(),
          apiClient: MockApiClient(),
          appStorage: MockAppStorage(),
          authApiOverride: MockAuthApi(),
        ),
      ),
      ChangeNotifierProvider<RequestsProvider>.value(
        value: RequestsProvider(apiClient: MockApiClient()),
      ),
      ChangeNotifierProvider<ChatProvider>.value(
        value: ChatProvider(apiClient: MockApiClient()),
      ),
      ChangeNotifierProvider<NotificationProvider>.value(
        value: NotificationProvider(),
      ),
      ChangeNotifierProvider<SocketProvider>.value(
        value: SocketProvider(
          socketService: SocketService(),
          tokenStorage: MockTokenStorage(),
        ),
      ),
      ChangeNotifierProvider<ThemeController>.value(value: ThemeController()),
      ChangeNotifierProvider<LocaleProvider>.value(value: LocaleProvider()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CustomerDashboardScreen(),
    ),
  );
}

const List<Locale> _locales = [Locale('ar'), Locale('en')];

const Map<String, Size> _viewports = {
  'عادي 390dp': Size(390, 844),
  'ضيق 320dp': Size(320, 844),
};

void main() {
  setUpAll(_loadRealArabicFontAsRoboto);

  for (final locale in _locales) {
    for (final viewport in _viewports.entries) {
      testWidgets(
        '[FONT-DIAG] CustomerDashboardScreen — locale=${locale.languageCode} — '
        '${viewport.key} — بخط عربي حقيقي بدل خط الاختبار الافتراضي',
        (tester) async {
          tester.view.physicalSize = viewport.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_wrap(locale));
          await _pumpAnimated(tester);

          final exception = tester.takeException();
          // ignore: avoid_print
          print(
            '[FONT-DIAG] locale=${locale.languageCode} '
            '${viewport.value.width.toInt()}dp => '
            '${exception == null ? "بلا فيضان (NO OVERFLOW)" : "فيضان لا يزال قائماً (STILL OVERFLOWS): $exception"}',
          );
        },
      );
    }
  }
}
