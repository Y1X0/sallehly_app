// ConnectivityProvider بلا أي اختبار سابق رغم أنه المصدر الوحيد لبانر "لا يوجد
// اتصال"/"الخادم بطيء" بكل الشاشات — منطق حالة نقي (online/offline/serverSlow)
// بلا أي اعتماد خارجي، يستحق تغطية مباشرة كاملة.
import 'package:flutter_test/flutter_test.dart';
import 'package:sallehly_app/providers/connectivity_provider.dart';

void main() {
  late ConnectivityProvider provider;

  setUp(() => provider = ConnectivityProvider());

  test('الحالة الافتراضية: متصل، بلا بطء بالخادم', () {
    expect(provider.online, isTrue);
    expect(provider.offline, isFalse);
    expect(provider.serverSlow, isFalse);
  });

  test('markOffline() من حالة متصلة: يتحول لغير متصل ويُبلّغ المستمعين', () {
    var notified = 0;
    provider.addListener(() => notified++);
    provider.markOffline();
    expect(provider.online, isFalse);
    expect(provider.offline, isTrue);
    expect(notified, 1);
  });

  test('markOffline() مرتين متتاليتين: الثانية لا تُبلّغ المستمعين (لا تغيير فعلي)', () {
    provider.markOffline();
    var notified = 0;
    provider.addListener(() => notified++);
    provider.markOffline();
    expect(notified, 0);
  });

  test('markServerSlow() من حالة متصلة: serverSlow=true بلا التأثير على online', () {
    provider.markServerSlow();
    expect(provider.online, isTrue);
    expect(provider.serverSlow, isTrue);
  });

  test('[FIX-CONNECTIVITY-02] markServerSlow() تعمل حتى بعد انقطاع فعلي سابق (بلا شرط online)', () {
    provider.markOffline();
    provider.markServerSlow();
    expect(provider.serverSlow, isTrue);
  });

  test('markOffline() بينما serverSlow=true: الانقطاع الفعلي يطغى، serverSlow تُصفَّر', () {
    provider.markServerSlow();
    provider.markOffline();
    expect(provider.offline, isTrue);
    expect(provider.serverSlow, isFalse);
  });

  test('markOnline() تمسح offline و serverSlow معاً دفعة واحدة', () {
    provider.markOffline();
    provider.markServerSlow(); // يُفعَّل الآن فعلياً (offline لا يمنع تفعيله لاحقاً، فقط يصفّره هو عند حدوثه)
    var notified = 0;
    provider.addListener(() => notified++);
    provider.markOnline();
    expect(provider.online, isTrue);
    expect(provider.serverSlow, isFalse);
    expect(notified, 1);
  });

  test('markOnline() من حالة متصلة أصلاً بلا أي بطء: لا تُبلّغ المستمعين (لا تغيير)', () {
    var notified = 0;
    provider.addListener(() => notified++);
    provider.markOnline();
    expect(notified, 0);
  });
}
