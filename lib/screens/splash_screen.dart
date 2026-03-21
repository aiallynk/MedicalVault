import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hello/Login_Signup/login_success_screen.dart';
import 'package:hello/Notifications/fcm_service.dart';
import 'package:hello/api_service.dart';
import 'package:hello/core/theme/status_bar_helper.dart';
import 'package:hello/localization/app_localizations.dart';
import 'package:hello/services/app_update_service.dart';
import 'package:hello/services/secure_token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _minSplashDuration = Duration(milliseconds: 2700);

  final AppUpdateService _appUpdateService = AppUpdateService();

  late final AnimationController _timelineController = AnimationController(
    vsync: this,
    duration: _minSplashDuration,
  )..forward();

  bool _isDisposed = false;
  bool _didNavigate = false;
  String _statusText = 'Preparing secure experience...';

  @override
  void initState() {
    super.initState();
    _startSplashFlow();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timelineController.dispose();
    super.dispose();
  }

  Future<void> _startSplashFlow() async {
    final minimumDurationFuture = Future<void>.delayed(_minSplashDuration);
    final bootstrapFuture = _bootstrapInParallel();
    final updateGateFuture = _handleUpdateGate();

    await minimumDurationFuture;

    final canContinue = await updateGateFuture;
    if (!canContinue || !mounted || _isDisposed || _didNavigate) {
      return;
    }

    _SplashBootstrapResult bootstrap;
    try {
      bootstrap = await bootstrapFuture.timeout(
        const Duration(milliseconds: 900),
        onTimeout: () => const _SplashBootstrapResult.unauthenticated(),
      );
    } catch (_) {
      bootstrap = const _SplashBootstrapResult.unauthenticated();
    }

    if (!mounted || _isDisposed || _didNavigate) {
      return;
    }

    if (bootstrap.isAuthenticated && bootstrap.userData != null) {
      _navigateToLoginSuccess(bootstrap.userData!);
    } else {
      _navigateToWelcome();
    }
  }

  Future<_SplashBootstrapResult> _bootstrapInParallel() async {
    final configFuture =
        ApiService.fetchUiConfig(forceRefresh: false).catchError((_) {
      return null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = await SecureTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        await configFuture;
        return const _SplashBootstrapResult.unauthenticated();
      }

      _setStatus('Validating secure session...');

      final userData = await ApiService.me().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );

      await configFuture;

      if (userData == null || userData.isEmpty) {
        await SecureTokenStorage.clearToken();
        await prefs.remove('userData');
        await prefs.remove('userId');
        return const _SplashBootstrapResult.unauthenticated();
      }

      await prefs.setString('userData', jsonEncode(userData));
      await prefs.setString(
        'userId',
        userData['id']?.toString() ?? userData['_id']?.toString() ?? '',
      );
      await prefs.setString('email', userData['email']?.toString() ?? '');
      await prefs.setString('name', userData['name']?.toString() ?? 'Patient');

      _setStatus('Warming up your vault...');

      unawaited(
        FCMService().registerToken().catchError((e) {
          debugPrint('FCM registration error: $e');
        }),
      );

      return _SplashBootstrapResult.authenticated(
        Map<String, dynamic>.from(userData),
      );
    } catch (e) {
      debugPrint('Splash bootstrap failed: $e');
      return const _SplashBootstrapResult.unauthenticated();
    }
  }

  void _setStatus(String value) {
    if (!mounted || _isDisposed) return;
    setState(() {
      _statusText = value;
    });
  }

  void _navigateToLoginSuccess(Map<String, dynamic> userData) {
    if (_didNavigate || !mounted || _isDisposed) return;
    _didNavigate = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: const RouteSettings(name: '/login_success'),
        transitionDuration: const Duration(milliseconds: 460),
        pageBuilder: (_, __, ___) => LoginSuccessScreen(
          userData: userData,
          title: 'Welcome Back',
          subtitle: 'Securing your dashboard...',
          clearStackOnComplete: true,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _navigateToWelcome() {
    if (_didNavigate || !mounted || _isDisposed) return;
    _didNavigate = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: const RouteSettings(name: '/welcome'),
        transitionDuration: const Duration(milliseconds: 460),
        pageBuilder: (_, __, ___) => widget.child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<bool> _handleUpdateGate() async {
    final checkResult =
        await _appUpdateService.checkForUpdate(ignoreSkipWindow: true);

    if (checkResult.error != null) {
      debugPrint('Update check skipped due to error: ${checkResult.error}');
      return true;
    }
    final info = checkResult.info;
    if (info == null || !checkResult.hasUpdate || !checkResult.shouldPrompt) {
      return true;
    }

    return _showUpdateDialog(
      checkResult: checkResult,
      info: info,
    );
  }

  Future<bool> _showUpdateDialog({
    required AppUpdateCheckResult checkResult,
    required AppUpdateInfo info,
  }) async {
    final l10n = context.l10n;
    final bool forceUpdate = checkResult.forceUpdate;
    bool downloading = false;
    double progress = 0;
    bool checksumVerified = false;
    String? statusText;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (dialogContext) {
        return PopScope(
          canPop: !forceUpdate,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  forceUpdate
                      ? l10n.t('update.dialog.requiredTitle')
                      : l10n.t('update.dialog.availableTitle'),
                ),
                content: SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${l10n.t('update.dialog.current')}: ${checkResult.currentVersion}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.t('update.dialog.latest')}: ${info.latestVersion}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (forceUpdate) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${l10n.t('update.dialog.minimum')}: ${info.minimumSupportedVersion}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          l10n.t('update.dialog.whatsNew'),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          info.releaseNotes.isEmpty
                              ? l10n.t('update.dialog.defaultNotes')
                              : info.releaseNotes,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (downloading) ...[
                          const SizedBox(height: 14),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 6),
                          Text(
                            l10n.format('update.dialog.downloading', {
                              'progress': (progress * 100).toStringAsFixed(0),
                            }),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (checksumVerified) ...[
                          const SizedBox(height: 6),
                          Text(
                            l10n.t('update.dialog.checksumVerified'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.green),
                          ),
                        ],
                        if (statusText != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            statusText!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  if (!forceUpdate)
                    TextButton(
                      onPressed: downloading
                          ? null
                          : () async {
                              await _appUpdateService.skipVersionFor24Hours(
                                info.latestVersion,
                              );
                              if (!mounted || !dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop(true);
                            },
                      child: Text(l10n.t('update.action.skip')),
                    ),
                  ElevatedButton(
                    onPressed: downloading
                        ? null
                        : () async {
                            setDialogState(() {
                              downloading = true;
                              progress = 0;
                              checksumVerified = false;
                              statusText = null;
                            });

                            final installResult = await _appUpdateService
                                .downloadAndInstallUpdate(
                              info: info,
                              onProgress: (value) {
                                if (!mounted) return;
                                setDialogState(() {
                                  progress = _clampUnit(value);
                                });
                              },
                            );

                            if (!mounted) return;

                            setDialogState(() {
                              downloading = false;
                              checksumVerified = installResult.checksumVerified;
                              statusText = installResult.message;
                            });

                            if (installResult.isSuccess) {
                              if (installResult.installCompleted) {
                                if (!dialogContext.mounted) return;
                                Navigator.of(dialogContext).pop(true);
                                await Future.delayed(
                                  const Duration(milliseconds: 250),
                                );
                                if (!_isDisposed) {
                                  SystemNavigator.pop();
                                }
                                return;
                              }

                              if (forceUpdate) {
                                if (!dialogContext.mounted) return;
                                Navigator.of(dialogContext).pop(false);
                                await Future.delayed(
                                  const Duration(milliseconds: 250),
                                );
                                if (!_isDisposed) {
                                  SystemNavigator.pop();
                                }
                                return;
                              }
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop(true);
                            }
                          },
                    child: Text(
                      downloading
                          ? '${l10n.t('update.action.updateNow')}...'
                          : l10n.t('update.action.updateNow'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (forceUpdate) {
      return proceed == true;
    }
    return proceed ?? true;
  }

  double _segment(double value, double start, double end) {
    if (value <= start) return 0;
    if (value >= end) return 1;
    return (value - start) / (end - start);
  }

  double _clampUnit(double value) => value.clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: StatusBarHelper.overlayStyleForBrightness(
        isDark ? Brightness.dark : Brightness.light,
        transparentStatusBar: true,
        transparentNavigationBar: true,
      ),
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _timelineController,
          builder: (context, child) {
            final t = _timelineController.value;

            final phaseOne =
                _clampUnit(Curves.easeOut.transform(_segment(t, 0.0, 0.30)));
            final phaseTwoRaw =
                Curves.easeOutBack.transform(_segment(t, 0.26, 0.70));
            final phaseTwoOpacity = _clampUnit(phaseTwoRaw);
            final phaseThree =
                _clampUnit(Curves.easeOut.transform(_segment(t, 0.66, 0.96)));

            final glowPulse = 0.94 + (math.sin(t * math.pi * 4) * 0.06);

            final topColor = Color.lerp(
              isDark ? const Color(0xFF060B1A) : const Color(0xFFECF5FF),
              isDark ? const Color(0xFF112244) : const Color(0xFFDCEEFF),
              0.45 + (math.sin(t * math.pi * 2) * 0.18),
            )!;
            final bottomColor = Color.lerp(
              isDark ? const Color(0xFF0B1732) : const Color(0xFFCEE8FF),
              isDark ? const Color(0xFF0E2649) : const Color(0xFFBFDFFF),
              0.5 + (math.cos(t * math.pi * 2) * 0.2),
            )!;

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final sweepProgress = Curves.easeInOut.transform(
                  _segment(t, 0.02, 0.36),
                );

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: phaseOne,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [topColor, bottomColor],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _SplashParticlesPainter(
                            progress: t,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: -200 + ((width + 280) * sweepProgress),
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.17 * phaseOne,
                          child: Container(
                            width: 180,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.60),
                                  Colors.white.withValues(alpha: 0),
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
                            Transform.rotate(
                              angle: (1 - phaseTwoRaw) * 0.08,
                              child: Transform.scale(
                                scale: 0.78 + (phaseTwoRaw * 0.22),
                                child: Opacity(
                                  opacity: phaseTwoOpacity,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Transform.scale(
                                        scale: glowPulse,
                                        child: Container(
                                          width: 136,
                                          height: 136,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withValues(
                                              alpha: isDark ? 0.09 : 0.22,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF5BD6FF)
                                                    .withValues(
                                                        alpha: isDark
                                                            ? 0.2
                                                            : 0.28),
                                                blurRadius: 30,
                                                spreadRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 108,
                                        height: 108,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          color: Colors.white
                                              .withValues(alpha: 0.14),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.32),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            child: Image.asset(
                                              'assets/icon/app_icon.png',
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) {
                                                return const Icon(
                                                  Icons
                                                      .health_and_safety_rounded,
                                                  color: Colors.white,
                                                  size: 46,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Opacity(
                              opacity: phaseTwoOpacity,
                              child: Text(
                                'Medical Vault',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Transform.translate(
                              offset: Offset(0, (1 - phaseThree) * 18),
                              child: Opacity(
                                opacity: phaseThree,
                                child: Text(
                                  'Your Health. Secured.',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.94),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            Opacity(
                              opacity: phaseThree,
                              child: Text(
                                _statusText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SplashParticlesPainter extends CustomPainter {
  _SplashParticlesPainter({
    required this.progress,
    required this.isDark,
  });

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor =
        isDark ? const Color(0xFF86C6FF) : const Color(0xFF49A7F5);

    for (var i = 0; i < 18; i++) {
      final baseX = ((i * 53) % 100) / 100;
      final baseY = ((i * 71) % 100) / 100;
      final driftX = math.sin((progress * math.pi * 2) + i) * 0.04;
      final travelY = (baseY + (progress * 0.26) + (i * 0.01)) % 1.0;
      final radius = 1.5 + ((i % 4) * 0.8);
      final alpha =
          (0.05 + ((math.sin((progress * math.pi * 2) + (i * 0.6)) + 1) * 0.04))
              .clamp(0.03, 0.16);

      final paint = Paint()..color = baseColor.withValues(alpha: alpha);

      canvas.drawCircle(
        Offset(
          (baseX + driftX).clamp(0.0, 1.0) * size.width,
          travelY * size.height,
        ),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

class _SplashBootstrapResult {
  const _SplashBootstrapResult._({
    required this.isAuthenticated,
    this.userData,
  });

  const _SplashBootstrapResult.unauthenticated()
      : this._(isAuthenticated: false);

  const _SplashBootstrapResult.authenticated(Map<String, dynamic> data)
      : this._(
          isAuthenticated: true,
          userData: data,
        );

  final bool isAuthenticated;
  final Map<String, dynamic>? userData;
}
