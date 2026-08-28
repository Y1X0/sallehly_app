import 'package:flutter/widgets.dart' show Locale;

/// [FIX-ERRCODE-01] نسخة من اللغة الحالية للواجهة قابلة للقراءة من كود Dart
/// صرف بلا BuildContext — تحديداً ApiClient.handleError()، الذي يبني
/// ApiException قبل وصول الاستجابة لأي شاشة، فلا يملك وصولاً لشجرة الودجت.
///
/// يُحدَّثها LocaleProvider (providers/locale_provider.dart) مع كل تغيير
/// فعلي للغة (loadSaved()/setLocale())، ويقرأها resolveApiErrorCode() عبر
/// lookupAppLocalizations(currentAppLocale) — دالة مولَّدة من flutter gen-l10n
/// لا تحتاج BuildContext هي الأخرى. القيمة الابتدائية هنا (قبل تحميل أي
/// تفضيل محفوظ) تطابق LocaleProvider.fallbackLocale عمداً.
///
/// نفس فكرة rootNavigatorKey/rootScaffoldMessengerKey بـ app.dart تماماً،
/// لنفس السبب بالضبط: طبقة بيانات صرفة تحتاج شيئاً من شجرة الودجت مؤقتاً.
Locale currentAppLocale = const Locale('ar');
