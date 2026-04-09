import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api_service.dart';
import '../BottomNavigationBar/dashboard1.dart';
import '../providers/dashboard_prefetch_provider.dart';
import '../providers/timezone_provider.dart';

class LoginSuccessScreen extends StatefulWidget {
  const LoginSuccessScreen({
    super.key,
    required this.userData,
    this.title = 'Login Successful',
    this.subtitle = 'Preparing your dashboard...',
    this.clearStackOnComplete = false,
  });

  final Map<String, dynamic> userData;
  final String title;
  final String subtitle;
  final bool clearStackOnComplete;

  @override
  State<LoginSuccessScreen> createState() => _LoginSuccessScreenState();
}

class _LoginSuccessScreenState extends State<LoginSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  bool _minimumAnimationDone = false;
  bool _prefetchDone = false;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _triggerSuccessHaptics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_runSuccessFlow());
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _triggerSuccessHaptics() async {
    try {
      await Future.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 170));
      if (!mounted) return;
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Haptics are optional.
    }
  }

  Future<void> _runSuccessFlow() async {
    try {
      await context.read<TimezoneProvider>().applyUserTimeZone(
            widget.userData,
            fallbackToDefault: true,
          );
      final provider = context.read<DashboardPrefetchProvider>();

      final prefetchFuture = provider
          .prefetchDashboardData(
              userData: Map<String, dynamic>.from(widget.userData))
          .then((data) {
        if (mounted) {
          setState(() {
            _prefetchDone = true;
          });
        }
        return data;
      });

      final minimumAnimationFuture =
          Future<void>.delayed(const Duration(milliseconds: 2600)).then((_) {
        if (mounted) {
          setState(() {
            _minimumAnimationDone = true;
          });
        }
      });

      DashboardPrefetchData prefetched;
      try {
        prefetched = await prefetchFuture;
      } catch (_) {
        prefetched = await _fallbackPrefetch(widget.userData);
        if (mounted) {
          setState(() {
            _prefetchDone = true;
          });
        }
      }

      await minimumAnimationFuture;
      if (!mounted || _didNavigate) return;
      _navigateToDashboard(prefetched);
    } catch (_) {
      if (!mounted || _didNavigate) return;
      final fallback = await _fallbackPrefetch(widget.userData);
      _navigateToDashboard(fallback);
    }
  }

  Future<DashboardPrefetchData> _fallbackPrefetch(
    Map<String, dynamic> userData,
  ) async {
    final userId =
        (userData['id']?.toString() ?? userData['_id']?.toString() ?? '')
            .trim();
    final cachedGrouped = userId.isNotEmpty
        ? await ApiService.getCachedGroupedDocs(userId)
        : null;
    final countsRaw = cachedGrouped?['counts'];
    final documentCounts = <String, int>{
      'Reports': _asInt(countsRaw is Map ? countsRaw['reports'] : null),
      'Prescription':
          _asInt(countsRaw is Map ? countsRaw['prescriptions'] : null),
      'Bill': _asInt(countsRaw is Map ? countsRaw['bills'] : null),
      'Insurance': _asInt(countsRaw is Map ? countsRaw['insurance'] : null),
    };

    return DashboardPrefetchData(
      userData: Map<String, dynamic>.from(userData),
      documentCounts: documentCounts,
      linkedProfiles: const <Map<String, dynamic>>[],
      topDoctors: const <Map<String, dynamic>>[],
      dashboardAds: const <Map<String, dynamic>>[],
      dashboardCards: const <Map<String, dynamic>>[],
      dashboardAlerts: const <Map<String, dynamic>>[],
      notifications: const <dynamic>[],
      recentActivity: const <dynamic>[],
      qrData: null,
      fetchedAt: DateTime.now(),
      partial: true,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _navigateToDashboard(DashboardPrefetchData prefetched) {
    if (_didNavigate || !mounted) return;
    _didNavigate = true;

    final route = PageRouteBuilder(
      settings: const RouteSettings(name: '/dashboard'),
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => Dashboard1(
        userData: prefetched.userData,
        prefetchedData: prefetched,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (widget.clearStackOnComplete) {
      Navigator.of(context).pushAndRemoveUntil(route, (_) => false);
    } else {
      Navigator.of(context).pushReplacement(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark ? const Color(0xFF0A1223) : const Color(0xFFEFF6FF),
              isDark ? const Color(0xFF111F3B) : const Color(0xFFDDEEFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RepaintBoundary(
                    child: SuccessAnimationWidget(
                      controller: _animationController,
                      accent: colorScheme.primary,
                      secondary: colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.74),
                        ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedOpacity(
                    opacity: _minimumAnimationDone && !_prefetchDone ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SuccessAnimationWidget extends StatelessWidget {
  const SuccessAnimationWidget({
    super.key,
    required this.controller,
    required this.accent,
    required this.secondary,
  });

  final AnimationController controller;
  final Color accent;
  final Color secondary;

  double _segment(double value, double start, double end) {
    if (value <= start) return 0;
    if (value >= end) return 1;
    return (value - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = controller.value;

        final fadeIn = Curves.easeOut.transform(_segment(value, 0.0, 0.2));
        final circleExpand =
            Curves.easeOutBack.transform(_segment(value, 0.14, 0.52));
        final checkPop =
            Curves.elasticOut.transform(_segment(value, 0.36, 0.76));
        final checkDraw =
            Curves.easeInOutCubic.transform(_segment(value, 0.40, 0.74));
        final glowPulse = 0.92 + (math.sin(value * math.pi * 4) * 0.08);

        return Opacity(
          opacity: fadeIn,
          child: SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: 0.84 + (circleExpand * 0.9),
                  child: Opacity(
                    opacity: (1 - circleExpand).clamp(0.0, 1.0),
                    child: Container(
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.46),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: glowPulse,
                  child: Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.72 + (checkPop * 0.28),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [accent, secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 50,
                        height: 50,
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
        );
      },
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
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final start = Offset(size.width * 0.20, size.height * 0.56);
    final mid = Offset(size.width * 0.43, size.height * 0.76);
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
