import 'package:flutter/foundation.dart';

/// يتتبّع حالة الاتصال بالخادم اعتماداً على نتائج طلبات الـ API.
/// لا يحتاج أي مكتبة خارجية — يُحدّث من api_client عند نجاح/فشل الطلبات.
///
/// [FIX-CONNECTIVITY-01] كانت هذه الفئة تمتلك حالة واحدة فقط (online/offline)
/// وتصنّف أي خطأ شبكة — بما فيه بطء استجابة الخادم نفسه (مثلاً استيقاظ خادم
/// Render المجاني بعد فترة خمول، الذي قد يستغرق 50 ثانية أو أكثر حسب تنبيه
/// Render نفسه) — على أنه "لا يوجد اتصال بالإنترنت". هذه رسالة خاطئة تماماً:
/// إنترنت المستخدم يعمل فعلاً، الخادم فقط بطيء بالرد. الآن نفصل الحالتين.
class ConnectivityProvider extends ChangeNotifier {
  bool _online = true;
  // [FIX-CONNECTIVITY-01] حالة جديدة منفصلة تماماً عن انقطاع الإنترنت الفعلي.
  bool _serverSlow = false;

  bool get online => _online;
  bool get offline => !_online;
  bool get serverSlow => _serverSlow;

  /// يُستدعى عند نجاح أي طلب — نحن متصلون والخادم يستجيب، امسح أي حالة سابقة.
  void markOnline() {
    var changed = false;
    if (!_online) {
      _online = true;
      changed = true;
    }
    if (_serverSlow) {
      _serverSlow = false;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// يُستدعى فقط عند خطأ شبكة حقيقي (لا يوجد مسار اتصال إطلاقاً — انقطاع
  /// إنترنت فعلي، فشل DNS، وضع الطيران...). هذا الخطأ من جهاز المستخدم نفسه.
  void markOffline() {
    var changed = false;
    if (_online) {
      _online = false;
      changed = true;
    }
    if (_serverSlow) {
      // انقطاع فعلي أهم من مجرد بطء — لا داعي لإظهار الاثنين معاً.
      _serverSlow = false;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// [FIX-CONNECTIVITY-02] أُزيل شرط `_online` من هنا (كان يمنع هذه الدالة من
  /// العمل لو وصل خطأ Timeout مباشرة بعد حالة انقطاع حقيقي سابق، قبل أي طلب
  /// ناجح يُعيد _online إلى true) — الآن تعمل بشكل صحيح دائماً بمجرد وصول
  /// خطأ Timeout، بغض النظر عن الحالة السابقة.
  void markServerSlow() {
    if (!_serverSlow) {
      _serverSlow = true;
      notifyListeners();
    }
  }
}
