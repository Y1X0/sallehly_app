import 'package:flutter/foundation.dart';

/// يتتبّع حالة الاتصال بالخادم اعتماداً على نتائج طلبات الـ API.
/// لا يحتاج أي مكتبة خارجية — يُحدّث من api_client عند نجاح/فشل الطلبات.
class ConnectivityProvider extends ChangeNotifier {
  bool _online = true;

  bool get online => _online;
  bool get offline => !_online;

  /// يُستدعى عند نجاح أي طلب — نحن متصلون.
  void markOnline() {
    if (!_online) {
      _online = true;
      notifyListeners();
    }
  }

  /// يُستدعى عند فشل طلب بسبب الشبكة (وليس بسبب خطأ من الخادم).
  void markOffline() {
    if (_online) {
      _online = false;
      notifyListeners();
    }
  }
}
