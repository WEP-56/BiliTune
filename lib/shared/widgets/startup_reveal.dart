import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class StartupReveal extends StatefulWidget {
  const StartupReveal({super.key});

  @override
  State<StartupReveal> createState() => _StartupRevealState();
}

class _StartupRevealState extends State<StartupReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _dismissTimer;
  bool _dismissed = false;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..forward();
    _dismissTimer = Timer(const Duration(milliseconds: 2050), _dismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted || _dismissed) return;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_removed) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: _dismissed ? 0 : 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      onEnd: () {
        if (_dismissed && mounted) {
          setState(() => _removed = true);
        }
      },
      child: IgnorePointer(
        ignoring: _dismissed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismiss,
          onPanDown: (_) => _dismiss(),
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _StartupRevealPainter(
                    progress: _controller.value,
                    colors: BiliColors.dark,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupRevealPainter extends CustomPainter {
  const _StartupRevealPainter({required this.progress, required this.colors});

  final double progress;
  final BiliColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _paintBackground(canvas, size);
    _paintSpectrumField(canvas, size);
    _paintMark(canvas, size);
    _paintWordmark(canvas, size);
    _paintProgressRail(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          [
            const Color(0xFF050507),
            colors.bgBase,
            Color.lerp(colors.bgBase, colors.brandDark, 0.18)!,
          ],
          const [0, 0.62, 1],
        ),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.52, size.height * 0.42),
          math.max(size.width, size.height) * 0.62,
          [
            colors.brand.withValues(alpha: 0.16),
            colors.accent.withValues(alpha: 0.055),
            Colors.transparent,
          ],
          const [0, 0.42, 1],
        ),
    );
  }

  void _paintSpectrumField(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.50);
    final width = math.min(size.width * 0.68, 760.0);
    final count = size.width < 720 ? 42 : 68;
    final reveal = _interval(0.06, 0.72);
    final settle = _interval(0.62, 1.0);
    final gap = width / count;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.0, gap * 0.18);

    for (var i = 0; i < count; i++) {
      final t = i / (count - 1);
      final localReveal = ((reveal * 1.18) - (t - 0.5).abs() * 0.36).clamp(
        0.0,
        1.0,
      );
      final envelope = math.sin(t * math.pi);
      final wave =
          math.sin(i * 0.54 + progress * math.pi * 8) * 0.54 +
          math.sin(i * 0.18 + progress * math.pi * 4) * 0.46;
      final height =
          (10 + wave.abs() * 52 * envelope) * localReveal * (1 - settle * 0.42);
      final x = center.dx - width / 2 + i * gap;
      final alpha = (0.12 + localReveal * 0.54) * (1 - settle * 0.18);
      paint.color = Color.lerp(
        colors.accent,
        colors.brand,
        t,
      )!.withValues(alpha: alpha);
      canvas.drawLine(
        Offset(x, center.dy - height),
        Offset(x, center.dy + height),
        paint,
      );
    }

    final linePaint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.16 + reveal * 0.20);
    canvas.drawLine(
      Offset(center.dx - width / 2, center.dy),
      Offset(center.dx + width / 2, center.dy),
      linePaint,
    );
  }

  void _paintMark(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 - 118, size.height * 0.40);
    final scale = size.width < 720 ? 0.82 : 1.0;
    final appear = _interval(0.18, 0.70);
    final pulse = math.sin(progress * math.pi * 6) * 0.5 + 0.5;
    final radius = 31.0 * scale;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(0.82 + appear * 0.18);
    canvas.drawCircle(
      Offset.zero,
      radius + pulse * 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = colors.brand.withValues(alpha: 0.18 + appear * 0.34),
    );
    canvas.drawCircle(
      Offset.zero,
      radius * 0.54,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: 0.13 + appear * 0.20),
    );
    final playPath = Path()
      ..moveTo(-6 * scale, -12 * scale)
      ..lineTo(14 * scale, 0)
      ..lineTo(-6 * scale, 12 * scale)
      ..close();
    canvas.drawPath(
      playPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(-12 * scale, -12 * scale),
          Offset(16 * scale, 14 * scale),
          [
            colors.brand.withValues(alpha: appear),
            colors.accent.withValues(alpha: appear * 0.86),
          ],
        ),
    );
    canvas.restore();
  }

  void _paintWordmark(Canvas canvas, Size size) {
    final appear = _interval(0.28, 0.76);
    final scan = _interval(0.40, 0.90);
    final center = Offset(size.width / 2, size.height * 0.40);
    final style = AppTypography.hero.copyWith(
      color: Colors.white.withValues(alpha: 0.20 + appear * 0.76),
      fontSize: size.width < 720 ? 38 : 52,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      shadows: [
        Shadow(
          color: colors.brand.withValues(alpha: appear * 0.28),
          blurRadius: 28,
        ),
      ],
    );
    final painter = TextPainter(
      text: TextSpan(text: 'BiliTune', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final offset = Offset(
      center.dx - painter.width / 2 + 28,
      center.dy - painter.height / 2,
    );
    painter.paint(canvas, offset);

    final scanX = offset.dx + painter.width * scan;
    canvas.drawLine(
      Offset(scanX, offset.dy + 4),
      Offset(scanX, offset.dy + painter.height - 4),
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = colors.accent.withValues(
          alpha: (1 - (scan - 0.55).abs()).clamp(0.0, 1.0) * 0.58,
        ),
    );
  }

  void _paintProgressRail(Canvas canvas, Size size) {
    final width = math.min(size.width * 0.48, 420.0);
    final left = size.width / 2 - width / 2;
    final y = size.height * (size.width < 720 ? 0.68 : 0.66);
    final railProgress = _interval(0.10, 0.92);
    final textProgress = _interval(0.42, 0.90);
    canvas.drawLine(
      Offset(left, y),
      Offset(left + width, y),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.10),
    );
    canvas.drawLine(
      Offset(left, y),
      Offset(left + width * railProgress, y),
      Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = colors.brand.withValues(alpha: 0.72),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: 'AUDIO SESSION',
        style: AppTypography.overline.copyWith(
          color: colors.textSecondary.withValues(
            alpha: 0.16 + textProgress * 0.42,
          ),
          letterSpacing: 2.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, Offset(size.width / 2 - painter.width / 2, y + 18));
  }

  double _interval(double begin, double end) {
    return Curves.easeOutCubic.transform(
      ((progress - begin) / (end - begin)).clamp(0.0, 1.0),
    );
  }

  @override
  bool shouldRepaint(covariant _StartupRevealPainter oldDelegate) {
    return progress != oldDelegate.progress || colors != oldDelegate.colors;
  }
}
