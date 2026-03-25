import 'dart:math' as math;
import 'dart:ui' as ui show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme-compatible premium splash visuals for "Medical Vault".
///
/// Timeline (0 -> 1):
/// 1) Theme-aware background + subtle center glow.
/// 2) SVG logo appears softly with blur.
/// 3) Logo scales with eased motion.
/// 4) Rounded-square loader forms around logo.
/// 5) Loader travels and reveals logo through sweep mask.
/// 6) Pulse passes through logo frame.
/// 7) Ambient particles/streaks animate around logo.
/// 8) Logo sharpens from blur to crisp.
/// 9) App title reveals with letter spacing.
/// 10) Smooth fade/scale handoff.
class PremiumSplashVisual extends StatelessWidget {
  const PremiumSplashVisual({
    super.key,
    required this.progress,
    required this.statusText,
    this.appName = 'Medical Vault',
    this.logoAssetPath = 'assets/icon/medical_vault_logo.svg',
  });

  final Animation<double> progress;
  final String statusText;
  final String appName;
  final String logoAssetPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    final backgroundTop =
        isDark ? const Color(0xFF0B0F1A) : const Color(0xFFF2F6FC);
    final backgroundMid =
        isDark ? const Color(0xFF121B2B) : const Color(0xFFE7EEF8);
    final backgroundBottom =
        isDark ? const Color(0xFF0B0F1A) : const Color(0xFFF6F9FE);
    final titleColor = isDark ? Colors.white : const Color(0xFF132B55);
    final statusColor = isDark
        ? Colors.white.withValues(alpha: 0.74)
        : const Color(0xFF415A7C).withValues(alpha: 0.86);

    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final phases = _SplashPhases.from(progress.value);

        return LayoutBuilder(
          builder: (context, constraints) {
            final shortestSide = constraints.biggest.shortestSide;
            final logoSize = (shortestSide * 0.33).clamp(118.0, 182.0);
            final frameSize = logoSize * 1.34;
            final titleSpacing =
                ui.lerpDouble(12.0, 1.2, phases.textReveal) ?? 1.2;

            return Transform.scale(
              scale: 1 + (0.024 * phases.outro),
              child: Opacity(
                opacity: (1 - (0.9 * phases.outro)).clamp(0.0, 1.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            backgroundTop,
                            backgroundMid,
                            backgroundBottom,
                          ],
                        ),
                      ),
                    ),

                    // Center glow activation.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: (0.08 + (0.28 * phases.centerGlow))
                              .clamp(0.0, 0.34),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0, -0.16),
                                radius: 0.78,
                                colors: [
                                  accent.withValues(
                                      alpha: isDark ? 0.30 : 0.22),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SafeArea(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: frameSize,
                              height: frameSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  IgnorePointer(
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        painter: _AmbientLogoParticlesPainter(
                                          timeline: phases.timeline,
                                          intensity: phases.particles,
                                          accent: accent,
                                        ),
                                      ),
                                    ),
                                  ),

                                  Opacity(
                                    opacity: (0.2 * phases.centerGlow)
                                        .clamp(0.0, 0.2),
                                    child: _PulseCardGlow(
                                      size: logoSize *
                                          (1 +
                                              0.08 *
                                                  phases.pulseWave *
                                                  phases.pulseStrength),
                                      color: accent,
                                    ),
                                  ),

                                  // Soft early logo.
                                  Opacity(
                                    opacity: phases.logoGhostOpacity,
                                    child: Transform.scale(
                                      scale: phases.logoScale *
                                          (0.985 +
                                              0.018 *
                                                  phases.pulseWave *
                                                  phases.pulseStrength),
                                      child: _LogoSvg(
                                        assetPath: logoAssetPath,
                                        size: logoSize,
                                        blurSigma: phases.logoBlur + 1.5,
                                      ),
                                    ),
                                  ),

                                  // Main reveal with sweep mask.
                                  Opacity(
                                    opacity: phases.logoRevealOpacity,
                                    child: Transform.scale(
                                      scale: phases.logoScale *
                                          (1 +
                                              0.015 *
                                                  phases.pulseWave *
                                                  phases.pulseStrength),
                                      child: _SweepRevealMask(
                                        revealProgress: phases.loaderReveal,
                                        travel: phases.loaderTravel,
                                        child: _LogoSvg(
                                          assetPath: logoAssetPath,
                                          size: logoSize,
                                          blurSigma: phases.logoBlur,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Rounded-square loader matches square logo canvas.
                                  Opacity(
                                    opacity: phases.loaderOpacity,
                                    child: SizedBox(
                                      width: logoSize * 1.12,
                                      height: logoSize * 1.12,
                                      child: RepaintBoundary(
                                        child: CustomPaint(
                                          painter: _RoundedSquareLoaderPainter(
                                            accent: secondary,
                                            reveal: phases.loaderReveal,
                                            travel: phases.loaderTravel,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Title reveal with spacing animation.
                            Opacity(
                              opacity: phases.textReveal,
                              child: Transform.translate(
                                offset: Offset(0, (1 - phases.textReveal) * 18),
                                child: Text(
                                  appName,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    color: titleColor,
                                    fontSize: 31,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: titleSpacing,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Opacity(
                              opacity: phases.statusReveal,
                              child: Text(
                                statusText,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  color: statusColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Static fallback splash with the same SVG logo and theme compatibility.
class StaticPremiumSplashFallback extends StatelessWidget {
  const StaticPremiumSplashFallback({
    super.key,
    required this.statusText,
    this.appName = 'Medical Vault',
    this.logoAssetPath = 'assets/icon/medical_vault_logo.svg',
  });

  final String statusText;
  final String appName;
  final String logoAssetPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF0B0F1A),
                  Color(0xFF121B2B),
                  Color(0xFF0B0F1A),
                ]
              : const [
                  Color(0xFFF2F6FC),
                  Color(0xFFE7EEF8),
                  Color(0xFFF6F9FE),
                ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 172,
              height: 172,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: isDark ? 0.26 : 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: _LogoSvg(
                  assetPath: logoAssetPath,
                  size: 132,
                  blurSigma: 0,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              appName,
              style: GoogleFonts.manrope(
                color: isDark ? Colors.white : const Color(0xFF132B55),
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              statusText,
              style: GoogleFonts.manrope(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.76)
                    : const Color(0xFF415A7C).withValues(alpha: 0.86),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoSvg extends StatelessWidget {
  const _LogoSvg({
    required this.assetPath,
    required this.size,
    required this.blurSigma,
  });

  final String assetPath;
  final double size;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final logo = SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => SizedBox(
        width: size,
        height: size,
      ),
    );

    if (blurSigma <= 0.05) {
      return logo;
    }

    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(
        sigmaX: blurSigma,
        sigmaY: blurSigma,
      ),
      child: logo,
    );
  }
}

class _SweepRevealMask extends StatelessWidget {
  const _SweepRevealMask({
    required this.revealProgress,
    required this.travel,
    required this.child,
  });

  final double revealProgress;
  final double travel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reveal = revealProgress.clamp(0.0, 1.0);
    final edge = (reveal + 0.08).clamp(0.0, 1.0);

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return SweepGradient(
          transform: GradientRotation((travel * math.pi * 2) - (math.pi / 2)),
          colors: const [
            Colors.white,
            Colors.white,
            Colors.transparent,
            Colors.transparent,
          ],
          stops: [0, reveal, edge, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

class _PulseCardGlow extends StatelessWidget {
  const _PulseCardGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.25),
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.03),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _RoundedSquareLoaderPainter extends CustomPainter {
  const _RoundedSquareLoaderPainter({
    required this.accent,
    required this.reveal,
    required this.travel,
  });

  final Color accent;
  final double reveal;
  final double travel;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = 3.5;
    if (size.width <= inset * 2 || size.height <= inset * 2) {
      return;
    }

    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - (inset * 2),
      size.height - (inset * 2),
    );
    final rRect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.shortestSide * 0.22),
    );

    final basePath = Path()..addRRect(rRect);
    final metricIterator = basePath.computeMetrics().iterator;
    if (!metricIterator.moveNext()) return;
    final metric = metricIterator.current;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..isAntiAlias = true
      ..color = accent.withValues(alpha: 0.22);
    canvas.drawPath(basePath, basePaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = accent.withValues(alpha: 0.95);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = accent.withValues(alpha: 0.18);

    final totalLen = metric.length;
    if (totalLen <= 0) return;

    final safeReveal =
        (reveal.isFinite ? reveal.clamp(0.0, 1.0) : 0.0).toDouble();
    final safeTravel =
        (travel.isFinite ? (travel % 1.0) : 0.0).toDouble();

    final segmentLen = totalLen * (0.18 + (0.44 * safeReveal));
    final start = (totalLen * safeTravel) % totalLen;
    final end = start + segmentLen;

    void drawSegment(double from, double to) {
      if (to <= from) return;
      final path = metric.extractPath(from, to);
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);
    }

    if (end <= totalLen) {
      drawSegment(start, end);
    } else {
      drawSegment(start, totalLen);
      drawSegment(0, end - totalLen);
    }
  }

  @override
  bool shouldRepaint(covariant _RoundedSquareLoaderPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.reveal != reveal ||
        oldDelegate.travel != travel;
  }
}

class _AmbientLogoParticlesPainter extends CustomPainter {
  const _AmbientLogoParticlesPainter({
    required this.timeline,
    required this.intensity,
    required this.accent,
  });

  final double timeline;
  final double intensity;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseOrbit = size.shortestSide * 0.34;
    const particleCount = 20;

    for (var i = 0; i < particleCount; i++) {
      final seed = i / particleCount;
      final angle = (seed * math.pi * 2) + (timeline * math.pi * 0.72);
      final orbit = baseOrbit + (math.sin((timeline * 6) + i) * 10);
      final x = center.dx + (math.cos(angle) * orbit);
      final y = center.dy + (math.sin(angle) * orbit * 0.7);

      final alpha =
          ((0.05 + (0.06 * ((math.sin((timeline * 8) + i) + 1) / 2))) *
                  intensity)
              .clamp(0.0, 0.14);

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..color = accent.withValues(alpha: alpha);

      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * 0.75, paint);
    }

    final streakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.15
      ..color = accent.withValues(alpha: (0.07 * intensity).clamp(0.0, 0.07));

    for (var i = 0; i < 3; i++) {
      final start = (timeline * 0.9 + (i * 0.22)) % 1;
      final theta = (start * math.pi * 2) - (math.pi / 2);
      final r1 = baseOrbit * (0.86 + 0.08 * i);
      final p1 = Offset(
        center.dx + math.cos(theta) * r1,
        center.dy + math.sin(theta) * r1,
      );
      final p2 = Offset(
        center.dx + math.cos(theta + 0.22) * (r1 + 10),
        center.dy + math.sin(theta + 0.22) * (r1 + 10),
      );
      canvas.drawLine(p1, p2, streakPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientLogoParticlesPainter oldDelegate) {
    return oldDelegate.timeline != timeline ||
        oldDelegate.intensity != intensity ||
        oldDelegate.accent != accent;
  }
}

class _SplashPhases {
  const _SplashPhases({
    required this.timeline,
    required this.centerGlow,
    required this.logoGhostOpacity,
    required this.logoRevealOpacity,
    required this.logoScale,
    required this.logoBlur,
    required this.loaderOpacity,
    required this.loaderReveal,
    required this.loaderTravel,
    required this.pulseStrength,
    required this.pulseWave,
    required this.particles,
    required this.textReveal,
    required this.statusReveal,
    required this.outro,
  });

  factory _SplashPhases.from(double t) {
    double phase(double start, double end, Curve curve) {
      return curve.transform(_segment(t, start, end));
    }

    return _SplashPhases(
      timeline: t,
      centerGlow: phase(0.0, 0.24, Curves.easeOutCubic),
      logoGhostOpacity: ui.lerpDouble(
            0,
            0.24,
            phase(0.08, 0.34, Curves.easeOutCubic),
          ) ??
          0,
      logoRevealOpacity: phase(0.24, 0.84, Curves.easeInOutCubic),
      logoScale: ui.lerpDouble(
            0.84,
            1.02,
            phase(0.12, 0.72, Curves.easeInOutCubic),
          ) ??
          1,
      logoBlur: ui.lerpDouble(
            8.8,
            0,
            phase(0.18, 0.86, Curves.easeInOutCubic),
          ) ??
          0,
      loaderOpacity: (phase(0.2, 0.52, Curves.easeOutCubic) *
              (1 - phase(0.88, 1.0, Curves.easeInCubic)))
          .clamp(0.0, 1.0),
      loaderReveal: phase(0.28, 0.78, Curves.easeInOutCubic),
      loaderTravel: (t * 1.34) % 1,
      pulseStrength: phase(0.52, 0.88, Curves.easeInOutCubic),
      pulseWave: (math.sin((t * math.pi * 7.2) - (math.pi / 2)) + 1) / 2,
      particles: phase(0.34, 0.98, Curves.easeOut),
      textReveal: phase(0.58, 0.92, Curves.easeOutCubic),
      statusReveal: phase(0.65, 0.96, Curves.easeOutCubic),
      outro: phase(0.9, 1.0, Curves.easeInOutCubic),
    );
  }

  final double timeline;
  final double centerGlow;
  final double logoGhostOpacity;
  final double logoRevealOpacity;
  final double logoScale;
  final double logoBlur;
  final double loaderOpacity;
  final double loaderReveal;
  final double loaderTravel;
  final double pulseStrength;
  final double pulseWave;
  final double particles;
  final double textReveal;
  final double statusReveal;
  final double outro;
}

double _segment(double value, double start, double end) {
  if (value <= start) return 0;
  if (value >= end) return 1;
  return (value - start) / (end - start);
}
