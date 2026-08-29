import '../../config/app_config.dart';
import '../storage/token_storage.dart';

/// [SEC-FIX-UPLOADS-01] راجع DECISIONS.md (backend) — بعض ملفات /uploads
/// أصبحت وراء مصادقة حقيقية بدل express.static العام. هذا الملف يوفّر
/// الآلية المشتركة لإرفاق هيدر Authorization مع Image.network وغيره من طلبات
/// الوسائط — كانت مكتوبة أصلاً بـchat_bubble.dart فقط (لصور الشات)، استُخرجت
/// هون لإعادة استخدامها بأي مكان يعرض وسائط من نفس الخادم.

/// هل هذا الرابط يشير لخادمنا نفسه (نفس host الخاص بـbaseUrl)؟ [image]/[audio]
/// بالشات مصدرها جسم رسالة نصية يُخزَّن كما هو — لو أُرسِل رابط خارجي (مثلاً
/// بعد استغلال ثغرة انتحال صيغة الوسائط) فلا يجوز إطلاقاً إرفاق هيدر
/// Authorization معه؛ هذا يُسرّب توكن جلسة المستخدم لأي خادم خارجي يتحكم به
/// المهاجم بمجرد فتح الصورة كاملة الحجم.
bool isFirstPartyMediaUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasAuthority) return false;
  return uri.host == Uri.parse(AppConfig.baseUrl).host;
}

/// يجلب هيدر المصادقة (التوكن) لاستخدامه مع Image.network — فقط لو كان
/// الرابط المستهدَف يعود فعلاً لخادم API الخاص بنا. أي رابط خارجي (host
/// مختلف) يُعامَل كرابط عادي بلا أي هيدر مصادقة إطلاقاً.
Future<Map<String, String>> authHeadersForMediaUrl(String url) async {
  if (!isFirstPartyMediaUrl(url)) return {};

  final token = await TokenStorage().getToken();
  if (token != null && token.isNotEmpty) {
    return {'Authorization': 'Bearer $token'};
  }

  return {};
}
