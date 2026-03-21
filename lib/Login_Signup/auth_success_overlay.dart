import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<void> showAuthSuccessAnimation(
  BuildContext context, {
  required String title,
  required String subtitle,
  Duration duration = const Duration(milliseconds: 1900),
}) async {
  if (!context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  await navigator.push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) {
        return _AuthSuccessRoutePage(
          title: title,
          subtitle: subtitle,
          duration: duration,
        );
      },
    ),
  );
}

class _AuthSuccessRoutePage extends StatefulWidget {
  const _AuthSuccessRoutePage({
    required this.title,
    required this.subtitle,
    required this.duration,
  });

  final String title;
  final String subtitle;
  final Duration duration;

  @override
  State<_AuthSuccessRoutePage> createState() => _AuthSuccessRoutePageState();
}

class _AuthSuccessRoutePageState extends State<_AuthSuccessRoutePage> {
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _closeTimer = Timer(widget.duration, () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AuthSuccessOverlay(
            title: widget.title,
            subtitle: widget.subtitle,
          ),
        ),
      ),
    );
  }
}

class AuthSuccessOverlay extends StatefulWidget {
  const AuthSuccessOverlay({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<AuthSuccessOverlay> createState() => _AuthSuccessOverlayState();
}

class _AuthSuccessOverlayState extends State<AuthSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  )..forward();

  static const List<double> _confettiAngles = <double>[
    -1.25,
    -0.95,
    -0.67,
    -0.38,
    -0.12,
    0.18,
    0.48,
    0.76,
    1.04,
    1.33,
    1.62,
    1.94,
    2.22,
    2.54,
    2.82,
    3.12,
    3.42,
    3.72,
    4.02,
    4.32,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _segment(double start, double end) {
    final value = _controller.value;
    if (value <= start) return 0;
    if (value >= end) return 1;
    return (value - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final cardPop = Curves.easeOutBack.transform(_segment(0.0, 0.35));
          final contentFade = Curves.easeOut.transform(_segment(0.12, 0.55));
          final badgePop = Curves.elasticOut.transform(_segment(0.18, 0.60));
          final ringOne = Curves.easeOut.transform(_segment(0.20, 0.78));
          final ringTwo = Curves.easeOut.transform(_segment(0.30, 0.90));
          final checkDraw =
              Curves.easeInOutCubic.transform(_segment(0.38, 0.72));
          final confetti = Curves.easeOutCubic.transform(_segment(0.36, 0.95));

          return Transform.scale(
            scale: 0.86 + (cardPop * 0.14),
            child: Opacity(
              opacity: contentFade,
              child: Container(
                width: 320,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.surface,
                      colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.96),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.28),
                    width: 1.3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 148,
                      height: 148,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (ringOne > 0)
                            Transform.scale(
                              scale: 0.82 + (ringOne * 0.86),
                              child: Opacity(
                                opacity: (1 - ringOne).clamp(0.0, 1.0),
                                child: Container(
                                  width: 108,
                                  height: 108,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colorScheme.secondary
                                          .withValues(alpha: 0.6),
                                      width: 2.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (ringTwo > 0)
                            Transform.scale(
                              scale: 0.78 + (ringTwo * 1.08),
                              child: Opacity(
                                opacity: (0.95 - ringTwo).clamp(0.0, 1.0),
                                child: Container(
                                  width: 108,
                                  height: 108,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.5),
                                      width: 1.8,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          CustomPaint(
                            size: const Size(148, 148),
                            painter: _ConfettiPainter(
                              progress: confetti,
                              primary: colorScheme.primary,
                              secondary: colorScheme.secondary,
                              angles: _confettiAngles,
                            ),
                          ),
                          Transform.scale(
                            scale: 0.74 + (badgePop * 0.26),
                            child: Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.secondary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.38),
                                    blurRadius: 22,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CustomPaint(
                                    painter: _AnimatedCheckPainter(
                                      progress: checkDraw,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: colorScheme.primary.withValues(alpha: 0.12),
                      ),
                      child: Text(
                        'Payment-like Success',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary.withValues(alpha: 0.96),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.75),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedCheckPainter extends CustomPainter {
  const _AnimatedCheckPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final start = Offset(size.width * 0.20, size.height * 0.56);
    final mid = Offset(size.width * 0.42, size.height * 0.76);
    final end = Offset(size.width * 0.80, size.height * 0.34);

    final first = (mid - start).distance;
    final second = (end - mid).distance;
    final total = first + second;
    final drawLength = total * progress.clamp(0.0, 1.0);

    final path = Path()..moveTo(start.dx, start.dy);

    if (drawLength <= first) {
      final t = drawLength / first;
      final p = Offset.lerp(start, mid, t)!;
      path.lineTo(p.dx, p.dy);
    } else {
      path.lineTo(mid.dx, mid.dy);
      final remaining = (drawLength - first).clamp(0.0, second);
      final t = remaining / second;
      final p = Offset.lerp(mid, end, t)!;
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedCheckPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.angles,
  });

  final double progress;
  final Color primary;
  final Color secondary;
  final List<double> angles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = size.center(Offset.zero);
    final fade = (1 - (progress * 1.05)).clamp(0.0, 1.0);

    for (var i = 0; i < angles.length; i++) {
      final angle = angles[i];
      final travel = (20 + ((i % 4) * 4)) + (progress * (30 + (i % 3) * 8));
      final dx = math.cos(angle) * travel;
      final dy = math.sin(angle) * travel + (progress * progress * 8);
      final point = center + Offset(dx, dy);

      final color = (i.isEven ? primary : secondary).withValues(
        alpha: 0.88 * fade,
      );

      final paint = Paint()..color = color;
      final radius = ((i % 3 == 0) ? 4.1 : 3.0) * (1 - (progress * 0.35));
      canvas.drawCircle(point, radius.clamp(1.1, 4.8), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.angles != angles;
  }
}
