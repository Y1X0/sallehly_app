import 'package:flutter/material.dart';

import '../utils/authenticated_media.dart';

/// [SEC-FIX-UPLOADS-01] راجع DECISIONS.md (backend) — صورة شبكة ترفق هيدر
/// Authorization تلقائياً لو كان الرابط يعود فعلاً لخادمنا (راجع
/// core/utils/authenticated_media.dart). الهيدرز تُجلَب مرة واحدة فقط
/// بـinitState وتُخزَّن بالـstate — نفس نمط _ImageMessage
/// (features/chat/widgets/chat_bubble.dart) بالضبط، يتجنّب عمداً FutureBuilder
/// جديد بكل build() (كان يُلغي ImageCache ويعيد التحميل من الصفر مع كل إعادة
/// بناء — راجع [FIX-CHATIMG-03] بذاك الملف).
class AuthenticatedNetworkImage extends StatefulWidget {
  final String url;
  final double? height;
  final BoxFit fit;

  const AuthenticatedNetworkImage({
    super.key,
    required this.url,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<AuthenticatedNetworkImage> createState() =>
      _AuthenticatedNetworkImageState();
}

class _AuthenticatedNetworkImageState
    extends State<AuthenticatedNetworkImage> {
  Map<String, String>? _headers;

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  // [SEC-FIX-IMGHEADERCACHE-01] راجع DECISIONS.md — بدون didUpdateWidget، لو
  // أعاد Flutter استخدام نفس الـState لودجت بـwidget.url مختلف (مثلاً هذا
  // الودجت داخل عنصر قائمة بلا ValueKey ثابت — لا يحدث اليوم بأي موقع استخدام
  // فعلي، لكن لا ضمانة مستقبلية)، تبقى _headers محمَّلة برابط الحساب/الطلب
  // *القديم* وتُرفَق مع طلب الصورة *الجديد* — تسريب هيدر Authorization لرابط
  // مختلف تماماً عن الذي أُصدر التوكن لأجله أصلاً، بنفس فئة الخطر التي
  // isFirstPartyMediaUrl() (core/utils/authenticated_media.dart) صُمِّمت أصلاً
  // لمنعها. إعادة الجلب عند تغيّر url فقط (لا كل rebuild) يغلق هذا نهائياً.
  @override
  void didUpdateWidget(AuthenticatedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _headers = null;
      _loadHeaders();
    }
  }

  void _loadHeaders() {
    final requestedUrl = widget.url;
    authHeadersForMediaUrl(requestedUrl).then((headers) {
      // لو تغيّر widget.url مجدداً أثناء الانتظار (سلسلة تحديثات سريعة)، هذا
      // الرد أصبح قديماً — تجاهله كي لا يُطبّق هيدر رابط سابق على الحالي.
      if (mounted && widget.url == requestedUrl) setState(() => _headers = headers);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_headers == null) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Image.network(
      widget.url,
      headers: _headers,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => const SizedBox(),
    );
  }
}
