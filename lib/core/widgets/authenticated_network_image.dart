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
    authHeadersForMediaUrl(widget.url).then((headers) {
      if (mounted) setState(() => _headers = headers);
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
