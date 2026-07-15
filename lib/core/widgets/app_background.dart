import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppBackground extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool safeArea;

  const AppBackground({
    super.key,
    required this.child,
    this.padding,
    this.safeArea = true,
  });

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    // جزيئات تطفو ببطء في الخلفية
    final random = math.Random(7);
    _particles = List.generate(10, (_) {
      return _Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        radius: 1.2 + random.nextDouble() * 2.6,
        speed: 0.12 + random.nextDouble() * 0.35,
        drift: (random.nextDouble() - 0.5) * 0.4,
        opacity: 0.10 + random.nextDouble() * 0.22,
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        // التدرّج الأساسي
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
          ),
        ),
        // توهّج بنفسجي علوي
        Positioned(
          top: -110,
          right: -90,
          child: _Glow(
            size: 260,
            color: AppColors.primary.withValues(alpha: 0.22),
          ),
        ),
        // توهّج تركوازي سفلي
        Positioned(
          bottom: -130,
          left: -100,
          child: _Glow(
            size: 300,
            color: AppColors.secondary.withValues(alpha: 0.16),
          ),
        ),
        // توهّج سماوي وسط خفيف
        Positioned(
          top: 220,
          left: -60,
          child: _Glow(
            size: 180,
            color: AppColors.accent.withValues(alpha: 0.10),
          ),
        ),
        // الجزيئات المتحركة
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ParticlesPainter(
                    particles: _particles,
                    progress: _controller.value,
                  ),
                );
              },
            ),
          ),
        ),
        // المحتوى
        Padding(
          padding: widget.padding ?? EdgeInsets.zero,
          child: widget.child,
        ),
      ],
    );

    return widget.safeArea ? SafeArea(child: content) : content;
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double drift;
  final double opacity;

  const _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.drift,
    required this.opacity,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlesPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // الحركة الرأسية لأعلى مع لفّ عند الوصول للقمة
      final dy = (p.y - progress * p.speed) % 1.0;
      final y = dy * size.height;
      final x = (p.x + math.sin(progress * 2 * math.pi + p.x * 6) * p.drift) *
          size.width;

      final paint = Paint()
        ..color = AppColors.secondary.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), p.radius, paint);

      // هالة خفيفة حول النقطة الأكبر
      if (p.radius > 2.6) {
        final glow = Paint()
          ..color = AppColors.accent.withValues(alpha: p.opacity * 0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), p.radius * 2.4, glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
