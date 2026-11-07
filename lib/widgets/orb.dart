import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class EmoOrb extends StatefulWidget {
  const EmoOrb({
    super.key,
    this.size = 236,
    this.listening = false,
    this.thinking = false,
    this.onTap,
  });

  final double size;
  final bool listening;
  final bool thinking;
  final VoidCallback? onTap;

  @override
  State<EmoOrb> createState() => _EmoOrbState();
}

class _EmoOrbState extends State<EmoOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void didUpdateWidget(covariant EmoOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.listening || widget.thinking
        ? const Duration(milliseconds: 1400)
        : const Duration(milliseconds: 2800);
    if (_controller.duration != target) {
      _controller.duration = target;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
            return SizedBox(
              width: s * 1.5,
              height: s * 1.5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: s * 1.52,
                    height: s * 1.52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          EmoColors.blue.withValues(alpha: widget.listening ? 0.22 : 0.14),
                          EmoColors.sky.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                        stops: const [0.35, 0.62, 1.0],
                      ),
                    ),
                  ),
                  if (widget.listening || widget.thinking) ...[
                    _pulseRing(s, (t + 0.0) % 1.0, 0.55),
                    _pulseRing(s, (t + 0.5) % 1.0, 0.4),
                  ],
                  Container(
                    width: s * 0.98,
                    height: s * 0.98,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.35),
                          EmoColors.sky.withValues(alpha: 0.10),
                        ],
                        stops: const [0.62, 0.82, 1.0],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 1,
                      ),
                    ),
                  ),
                  CustomPaint(
                    size: Size(s * 0.84, s * 0.84),
                    painter: _OrbitPainter(
                      angle: t * math.pi * 2,
                      active: widget.listening,
                    ),
                  ),
                  Transform.scale(
                    scale: 1 + pulse * 0.018,
                    child: Container(
                      width: s * 0.62,
                      height: s * 0.62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-0.38, -0.44),
                          radius: 1.05,
                          colors: [
                            Color(0xFFE8F5FF),
                            Color(0xFF9FD2FF),
                            Color(0xFF4C93FF),
                            Color(0xFF1B55F5),
                            Color(0xFF0E3AA8),
                          ],
                          stops: [0.0, 0.22, 0.52, 0.82, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: EmoColors.blue.withValues(alpha: 0.35),
                            blurRadius: 44,
                            spreadRadius: 2,
                            offset: const Offset(0, 16),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.55),
                            blurRadius: 18,
                            offset: const Offset(-6, -8),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: s * 0.075,
                            left: s * 0.095,
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Container(
                                width: s * 0.16,
                                height: s * 0.085,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(100),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.85),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _Waveform(
                            phase: t,
                            listening: widget.listening,
                            thinking: widget.thinking,
                            height: s * 0.155,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _orbitDot(s, t, -1),
                  _orbitDot(s, (t + 0.35) % 1.0, 1),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _pulseRing(double s, double progress, double maxOpacity) {
    final size = s * (0.64 + progress * 0.75);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: EmoColors.blue.withValues(alpha: maxOpacity * (1 - progress)),
          width: 1.6,
        ),
      ),
    );
  }

  Widget _orbitDot(double s, double t, int direction) {
    final radius = s * 0.42;
    final angle = t * math.pi * 2 * direction;
    final dotSize = 5.5 + 1.8 * math.sin(t * math.pi * 2);
    return Transform.translate(
      offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius * 0.94),
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Colors.white, EmoColors.sky],
          ),
          boxShadow: [
            BoxShadow(
              color: EmoColors.blue.withValues(alpha: 0.5),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.phase,
    required this.listening,
    required this.thinking,
    required this.height,
  });

  final double phase;
  final bool listening;
  final bool thinking;
  final double height;

  @override
  Widget build(BuildContext context) {
    const count = 7;
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(count, (i) {
          final center = (count - 1) / 2;
          final distance = (i - center).abs() / center;
          final base = 0.28 + (1 - distance) * 0.42;
          final wave = 0.5 + 0.5 * math.sin(phase * math.pi * 2 + i * 0.8);
          final amplitude = listening ? 0.55 : (thinking ? 0.35 : 0.16);
          final value = (base + wave * amplitude).clamp(0.14, 1.0);
          return Container(
            width: 4,
            height: height * value,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.25),
                  blurRadius: 6,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.angle, required this.active});

  final double angle;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    for (var i = 0; i < 3; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = i == 0 ? 1.5 : 1.0
        ..color = EmoColors.blue.withValues(alpha: active ? 0.42 - i * 0.1 : 0.26 - i * 0.06);
      final start = (i * 2.1) + 0.3;
      final sweep = 0.9 - i * 0.14;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius - i * 6),
        start,
        sweep,
        false,
        paint,
      );
    }
    canvas.restore();

    final tickPaint = Paint()
      ..color = EmoColors.blue.withValues(alpha: 0.22)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 24; i++) {
      final a = (i / 24) * math.pi * 2 + math.pi / 24;
      final inner = radius - 2;
      final outer = radius + (i % 6 == 0 ? 5.0 : 2.0);
      canvas.drawLine(
        center + Offset(math.cos(a) * inner, math.sin(a) * inner),
        center + Offset(math.cos(a) * outer, math.sin(a) * outer),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.active != active;
}
