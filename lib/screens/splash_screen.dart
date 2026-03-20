import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hello/api_service.dart';
import 'package:hello/BottomNavigationBar/dashboard1.dart';
import 'package:hello/Notifications/fcm_service.dart';
import 'package:hello/core/theme/status_bar_helper.dart';
import 'package:hello/localization/app_localizations.dart';
import 'package:hello/services/app_update_service.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;

  const SplashScreen({
    super.key,
    required this.child,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final AppUpdateService _appUpdateService = AppUpdateService();
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _gradientController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _gradientAnimation;

  bool _isDisposed = false;
  bool _didNavigate = false;
  String _loadingText = 'Loading...';

  @override
  void initState() {
    super.initState();

    // Fade animation for text
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Scale animation for logo
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Gradient animation
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _gradientController,
        curve: Curves.easeInOut,
      ),
    );

    _startAnimations();
  }

  Future<bool> _checkAuthAndPrefetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');

      if (token == null || token.isEmpty) {
        // No token, go to welcome screen
        return false;
      }

      // Update loading text
      _setLoadingText('Checking authentication...');

      // Validate token by calling /me endpoint
      final userData = await ApiService.me();

      if (userData != null && mounted) {
        await prefs.setString('userData', jsonEncode(userData));
        await prefs.setString(
          'userId',
          userData['id']?.toString() ?? userData['_id']?.toString() ?? '',
        );
        await prefs.setString('email', userData['email']?.toString() ?? '');
        await prefs.setString(
            'name', userData['name']?.toString() ?? 'Patient');

        _setLoadingText('Loading doctors, alerts and ads...');
        await _warmupDashboardContent(userData);

        // Register FCM token in parallel so navigation is not delayed.
        FCMService().registerToken().catchError((e) {
          debugPrint('FCM registration error: $e');
        });

        if (!_isDisposed && mounted) {
          await Future.delayed(const Duration(milliseconds: 250));
          if (!_isDisposed && mounted) {
            _navigateToDashboard(userData);
            return true;
          }
        }
      } else {
        // Token invalid, clear auth data
        await prefs.remove('authToken');
        await prefs.remove('userData');
        await prefs.remove('userId');
      }
    } catch (e) {
      debugPrint('Auth check error: $e');
      // Clear potentially corrupted auth data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authToken');
      await prefs.remove('userData');
      await prefs.remove('userId');
    }
    return false;
  }

  Future<void> _warmupDashboardContent(Map<String, dynamic> userData) async {
    final userId =
        userData['id']?.toString() ?? userData['_id']?.toString() ?? '';

    final warmupTasks = <Future<void>>[
      _runWarmupTask('doctors', () => ApiService.fetchPastAppointments()),
      _runWarmupTask(
        'advertisements',
        () => ApiService.fetchAdvertisements(placement: 'APP_DASHBOARD'),
      ),
      _runWarmupTask('alerts', () => ApiService.fetchUiConfig()),
    ];

    if (userId.isNotEmpty) {
      warmupTasks.add(
        _runWarmupTask('documents', () => ApiService.fetchMyDocs(userId)),
      );
    }

    try {
      await Future.wait(warmupTasks, eagerError: false).timeout(
        const Duration(milliseconds: 1400),
        onTimeout: () => <void>[],
      );
    } catch (_) {
      // Continue to dashboard even if warmup misses SLA.
    }
  }

  Future<void> _runWarmupTask(
    String label,
    Future<dynamic> Function() task,
  ) async {
    try {
      await task().timeout(const Duration(seconds: 7));
      debugPrint('Warmup complete: $label');
    } catch (e) {
      debugPrint('Warmup skipped ($label): $e');
    }
  }

  void _setLoadingText(String value) {
    if (!mounted || _isDisposed) return;
    setState(() {
      _loadingText = value;
    });
  }

  void _navigateToDashboard(Map<String, dynamic> userData) {
    if (_didNavigate || !mounted || _isDisposed) return;
    _didNavigate = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: const RouteSettings(name: '/dashboard'),
        pageBuilder: (context, animation, secondaryAnimation) =>
            Dashboard1(userData: userData),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
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
        pageBuilder: (context, animation, secondaryAnimation) => widget.child,
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  Future<bool> _handleUpdateGate() async {
    _setLoadingText('Checking for updates...');
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
                              if (!mounted) return;
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
                                  progress = value;
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
                                Navigator.of(dialogContext).pop(false);
                                await Future.delayed(
                                    const Duration(milliseconds: 250));
                                if (!_isDisposed) {
                                  SystemNavigator.pop();
                                }
                                return;
                              }
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

  void _startAnimations() async {
    // Start scale animation
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_isDisposed) {
      _scaleController.forward();
    }

    // Start fade animation
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_isDisposed) {
      _fadeController.forward();
    }

    final canContinue = await _handleUpdateGate();
    if (!canContinue || _isDisposed || !mounted) {
      return;
    }

    // Check authentication and prefetch data
    final isAuthenticated = await _checkAuthAndPrefetch();
    if (isAuthenticated || _didNavigate) return;

    // If not authenticated, navigate to welcome screen after minimum splash duration
    if (!_isDisposed && mounted) {
      await Future.delayed(
          const Duration(milliseconds: 1500)); // Minimum splash duration
      if (!_isDisposed && mounted) {
        _navigateToWelcome();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _fadeController.dispose();
    _scaleController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

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
          animation: _gradientAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          // Dark theme gradient
                          Color.lerp(
                            const Color(0xFF0A0E27),
                            const Color(0xFF1A1F3A),
                            _gradientAnimation.value,
                          )!,
                          Color.lerp(
                            const Color(0xFF1A1F3A),
                            const Color(0xFF2D3561),
                            _gradientAnimation.value,
                          )!,
                          Color.lerp(
                            const Color(0xFF2D3561),
                            const Color(0xFF1A1F3A),
                            _gradientAnimation.value,
                          )!,
                        ]
                      : [
                          // Light theme gradient
                          Color.lerp(
                            const Color(0xFF4A90E2),
                            const Color(0xFF5BA3F5),
                            _gradientAnimation.value,
                          )!,
                          Color.lerp(
                            const Color(0xFF50E3C2),
                            const Color(0xFF6EF4D8),
                            _gradientAnimation.value,
                          )!,
                          Color.lerp(
                            const Color(0xFF6EF4D8),
                            const Color(0xFF50E3C2),
                            _gradientAnimation.value,
                          )!,
                        ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Logo/Icon with glow effect
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            // Main container
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.1),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.medical_services_rounded,
                                  size: 70,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Animated "Medical Vault" Text
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            // Text with gradient and shadow
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.white.withOpacity(0.9),
                                  Colors.white.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                stops: const [0.0, 0.5, 1.0],
                              ).createShader(bounds),
                              child: const Text(
                                'Medical Vault',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedBuilder(
                              animation: _fadeAnimation,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _fadeAnimation.value * 0.8,
                                  child: Text(
                                    'Your Health, Your Vault',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white.withOpacity(0.9),
                                      letterSpacing: 0.5,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Loading indicator with text
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.8),
                                ),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _loadingText,
                                key: ValueKey<String>(_loadingText),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
