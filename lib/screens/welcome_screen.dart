import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../Login_Signup/SignUp.dart';
import '../Login_Signup/loginScreen.dart';

class PremiumWelcomeScreen extends StatefulWidget {
  const PremiumWelcomeScreen({super.key});

  @override
  State<PremiumWelcomeScreen> createState() => _PremiumWelcomeScreenState();
}

class _PremiumWelcomeScreenState extends State<PremiumWelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();

  late final AnimationController _floatController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _entryController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _handleTapNavigate(Widget page, String routeName) async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        settings: RouteSettings(name: routeName),
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final greeting = _timeGreeting();

    final titleAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.18, 0.58, curve: Curves.easeOutCubic),
    );
    final subtitleAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.32, 0.72, curve: Curves.easeOutCubic),
    );
    final buttonsAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutBack),
    );

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F1F3B) : const Color(0xFFDDF0FF),
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isDark ? const Color(0xFF070F1F) : const Color(0xFFEFF7FF),
                    isDark ? const Color(0xFF0F1F3B) : const Color(0xFFDDF0FF),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final heroWidth =
                      math.min(constraints.maxWidth * 0.78, 360.0);
                  final bottomPadding =
                      constraints.maxHeight < 670 ? 10.0 : 22.0;

                  return Stack(
                    children: [
                      Positioned(
                        top: -80,
                        right: -60,
                        child: Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF45C6FF)
                                .withValues(alpha: isDark ? 0.16 : 0.24),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -90,
                        left: -40,
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1E90FF)
                                .withValues(alpha: isDark ? 0.10 : 0.18),
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(24, 14, 24, bottomPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: Colors.white.withValues(
                                        alpha: isDark ? 0.10 : 0.72),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(7),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        'assets/icon/app_icon.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Medical Vault',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        greeting,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.68),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 34),
                            RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: _floatController,
                                builder: (context, child) {
                                  final v = _floatController.value;
                                  final floatY = math.sin(v * math.pi * 2) * 8;
                                  final glow =
                                      0.92 + (math.cos(v * math.pi * 2) * 0.08);
                                  return Transform.translate(
                                    offset: Offset(0, floatY),
                                    child: Center(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Transform.scale(
                                            scale: glow,
                                            child: Container(
                                              width: heroWidth * 0.88,
                                              height: heroWidth * 0.58,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(36),
                                                color: const Color(0xFF67E8F9)
                                                    .withValues(
                                                        alpha: isDark
                                                            ? 0.12
                                                            : 0.18),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        const Color(0xFF3BA9F7)
                                                            .withValues(
                                                      alpha:
                                                          isDark ? 0.30 : 0.24,
                                                    ),
                                                    blurRadius: 26,
                                                    spreadRadius: 3,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: heroWidth,
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              color: Colors.white.withValues(
                                                  alpha: isDark ? 0.08 : 0.62),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.28),
                                              ),
                                            ),
                                            child: AspectRatio(
                                              aspectRatio: 1.24,
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                          colors: [
                                                            const Color(
                                                                    0xFF0EA5E9)
                                                                .withValues(
                                                                    alpha: isDark
                                                                        ? 0.42
                                                                        : 0.65),
                                                            const Color(
                                                                    0xFF10B981)
                                                                .withValues(
                                                                    alpha: isDark
                                                                        ? 0.38
                                                                        : 0.58),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    Opacity(
                                                      opacity:
                                                          isDark ? 0.20 : 0.26,
                                                      child: SvgPicture.asset(
                                                        'assets/NewWelcomeScreen.svg',
                                                        fit: BoxFit.cover,
                                                        placeholderBuilder:
                                                            (_) =>
                                                                const SizedBox
                                                                    .shrink(),
                                                      ),
                                                    ),
                                                    DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                          begin: Alignment
                                                              .topCenter,
                                                          end: Alignment
                                                              .bottomCenter,
                                                          colors: [
                                                            Colors.black
                                                                .withValues(
                                                                    alpha:
                                                                        0.04),
                                                            Colors.black
                                                                .withValues(
                                                                    alpha:
                                                                        0.26),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .fromLTRB(
                                                          16, 14, 16, 14),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 10,
                                                              vertical: 6,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                      alpha:
                                                                          0.18),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                              border:
                                                                  Border.all(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                        alpha:
                                                                            0.24),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Icon(
                                                                  Icons
                                                                      .verified_user_rounded,
                                                                  color: Colors
                                                                      .white,
                                                                  size: 14,
                                                                ),
                                                                const SizedBox(
                                                                    width: 6),
                                                                Text(
                                                                  'Vault Protected',
                                                                  style: theme
                                                                      .textTheme
                                                                      .labelMedium
                                                                      ?.copyWith(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const Spacer(),
                                                          Text(
                                                            'Everything health, one secure place.',
                                                            style: theme
                                                                .textTheme
                                                                .titleSmall
                                                                ?.copyWith(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 10),
                                                          Wrap(
                                                            spacing: 8,
                                                            runSpacing: 8,
                                                            children: const [
                                                              _HeroPill(
                                                                icon: Icons
                                                                    .auto_awesome_rounded,
                                                                label:
                                                                    'Smart Access',
                                                              ),
                                                              _HeroPill(
                                                                icon: Icons
                                                                    .groups_rounded,
                                                                label:
                                                                    'Family Profiles',
                                                              ),
                                                              _HeroPill(
                                                                icon: Icons
                                                                    .qr_code_2_rounded,
                                                                label:
                                                                    'Emergency QR',
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 30),
                            FadeTransition(
                              opacity: titleAnimation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.20),
                                  end: Offset.zero,
                                ).animate(titleAnimation),
                                child: Text(
                                  'Your Medical Data. Simplified.',
                                  textAlign: TextAlign.center,
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FadeTransition(
                              opacity: subtitleAnimation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.16),
                                  end: Offset.zero,
                                ).animate(subtitleAnimation),
                                child: Text(
                                  'Secure. Accessible. Always with you.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.72),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            ScaleTransition(
                              scale: buttonsAnimation,
                              child: Column(
                                children: [
                                  _PremiumCtaButton(
                                    label: 'Get Started',
                                    filled: true,
                                    onTap: () => _handleTapNavigate(
                                      const SignUpPage(),
                                      '/signup',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _PremiumCtaButton(
                                    label: 'Login',
                                    filled: false,
                                    onTap: () => _handleTapNavigate(
                                      const LoginScreen(),
                                      '/login',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumCtaButton extends StatefulWidget {
  const _PremiumCtaButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  State<_PremiumCtaButton> createState() => _PremiumCtaButtonState();
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCtaButtonState extends State<_PremiumCtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 110),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: widget.filled
                ? LinearGradient(
                    colors: [
                      primary,
                      theme.colorScheme.secondary,
                    ],
                  )
                : null,
            color:
                widget.filled ? null : theme.cardColor.withValues(alpha: 0.78),
            border: widget.filled
                ? null
                : Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.35),
                  ),
            boxShadow: [
              BoxShadow(
                color: (widget.filled ? primary : Colors.black)
                    .withValues(alpha: widget.filled ? 0.24 : 0.10),
                blurRadius: widget.filled ? 22 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white.withValues(alpha: 0.20),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            onHighlightChanged: (pressed) {
              if (_pressed == pressed) return;
              setState(() {
                _pressed = pressed;
              });
            },
            onTap: widget.onTap,
            child: Center(
              child: Text(
                widget.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: widget.filled
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
