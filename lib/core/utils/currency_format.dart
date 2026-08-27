import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// [L10N-04] يهيّئ مبلغاً بالدينار الأردني عبر `NumberFormat` (فواصل آلاف
/// صحيحة حسب اللغة الحالية) بدل `toStringAsFixed(2)` يدوياً، مع رمز العملة
/// المترجَم (`currencySymbolJod`: "د.أ" عربي / "JD" إنجليزي) بدل تكراره
/// كنص ثابت بكل موقع عرض (14 ملفاً تستخدم هذا الرمز حالياً).
String formatJod(BuildContext context, num amount) {
  final locale = Localizations.localeOf(context).toString();
  final number = NumberFormat('#,##0.00', locale).format(amount);
  return '$number ${AppLocalizations.of(context)!.currencySymbolJod}';
}
