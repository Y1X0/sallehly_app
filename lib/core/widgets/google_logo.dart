import 'package:flutter/material.dart';

/// [FEAT-GOOGLESIGNIN-01] شعار جوجل الرسمي (أربع ألوان) — مرسوم مباشرة عبر
/// Canvas بدل أصل صورة/SVG جديد (لا حزمة flutter_svg بالمشروع، ولا حاجة
/// لإضافتها لعنصر واحد). الإحداثيات منقولة حرفياً عن مسارات SVG الرسمية
/// لشعار جوجل (شبكة 18×18) بأربعة توجيهات Path منفصلة — كل Path بلونه
/// الرسمي الخاص به، مقاسة هنا لتلائم أي حجم مطلوب عبر [size].
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const double _viewBox = 18;

  static const Color _blue = Color(0xFF4285F4);
  static const Color _green = Color(0xFF34A853);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _viewBox;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = _blue;
    canvas.drawPath(_bluePath(), paint);

    paint.color = _green;
    canvas.drawPath(_greenPath(), paint);

    paint.color = _yellow;
    canvas.drawPath(_yellowPath(), paint);

    paint.color = _red;
    canvas.drawPath(_redPath(), paint);

    canvas.restore();
  }

  Path _bluePath() {
    return Path()
      ..moveTo(17.64, 9.20455)
      ..relativeCubicTo(0, -0.63864, -0.05727, -1.25182, -0.16409, -1.84091)
      ..lineTo(9, 7.36364)
      ..relativeLineTo(0, 3.48181)
      ..relativeLineTo(4.84364, 0)
      ..relativeCubicTo(-0.20864, 1.125, -0.84273, 2.07819, -1.79637, 2.71637)
      ..relativeLineTo(0, 2.25818)
      ..relativeLineTo(2.90864, 0)
      ..relativeCubicTo(1.70182, -1.56681, 2.68364, -3.87409, 2.68364, -6.61545)
      ..close();
  }

  Path _greenPath() {
    return Path()
      ..moveTo(9, 18)
      ..relativeCubicTo(2.43, 0, 4.46727, -0.80682, 5.95637, -2.18182)
      ..relativeLineTo(-2.90864, -2.25818)
      ..relativeCubicTo(-0.80682, 0.54, -1.83682, 0.85909, -3.04773, 0.85909)
      ..relativeCubicTo(-2.34409, 0, -4.32818, -1.58318, -5.03591, -3.70909)
      ..lineTo(0.95728, 10.70909)
      ..relativeLineTo(0, 2.33182)
      ..cubicTo(2.43819, 15.99273, 5.48001, 18, 9, 18)
      ..close();
  }

  Path _yellowPath() {
    return Path()
      ..moveTo(3.96409, 10.71)
      ..relativeCubicTo(-0.18, -0.54, -0.28227, -1.11682, -0.28227, -1.71)
      ..relativeCubicTo(0, -0.59318, 0.10227, -1.17, 0.28227, -1.71)
      ..lineTo(3.96409, 4.95818)
      ..lineTo(0.95727, 4.95818)
      ..cubicTo(0.34773, 6.17318, 0, 7.54773, 0, 9)
      ..relativeCubicTo(0, 1.45227, 0.34773, 2.82682, 0.95727, 4.04182)
      ..lineTo(3.96409, 10.71)
      ..close();
  }

  Path _redPath() {
    return Path()
      ..moveTo(9, 3.57955)
      ..relativeCubicTo(1.32136, 0, 2.50773, 0.45409, 3.44045, 1.34591)
      ..relativeLineTo(2.58182, -2.58182)
      ..cubicTo(13.46318, 0.891818, 11.42591, 0, 9, 0)
      ..cubicTo(5.48001, 0, 2.43819, 2.00727, 0.95728, 4.95818)
      ..lineTo(3.96409, 7.29)
      ..relativeCubicTo(0.70773, -2.12591, 2.69182, -3.71045, 5.03591, -3.71045)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
