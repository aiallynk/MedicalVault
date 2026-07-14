import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hello/Login_Signup/login_success_screen.dart';
import 'package:hello/Notifications/fcm_service.dart';
import 'package:hello/api_service.dart';
import 'package:hello/core/theme/status_bar_helper.dart';
import 'package:hello/localization/app_localizations.dart';
import 'package:hello/providers/timezone_provider.dart';
import 'package:hello/screens/splash/premium_splash_visual.dart';
import 'package:hello/services/app_update_service.dart';
import 'package:hello/services/offline/offline_storage_service.dart';
import 'package:hello/services/secure_token_storage.dart';
import 'package:hello/services/session_conflict_service.dart';
import 'package:provider/provider.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _minSplashDuration = Duration(milliseconds: 3000);

  final AppUpdateService _appUpdateService = AppUpdateService();

  AnimationController? _timelineController;
  Completer<void>? _resumeSignal;
  bool _useStaticFallback = false;
  bool _didHapticPulse = false;

  bool _isDisposed = false;
  bool _didNavigate = false;
  String _statusText = 'Preparing secure experience...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(SessionConflictService.instance.initialize());
    _initializeTimelineAnimation();
    _startSplashFlow();
  }

  void _initializeTimelineAnimation() {
    try {
      final controller = AnimationController(
        vsync: this,
        duration: _minSplashDuration,
      );
      controller.addListener(_handleTimelineTick);
      controller.forward();
      _timelineController = controller;
    } catch (error) {
      debugPrint('Splash animation initialization failed: $error');
      _useStaticFallback = true;
    }
  }

  void _handleTimelineTick() {
    final controller = _timelineController;
    if (controller == null || _didHapticPulse) return;
    if (controller.value >= 0.58) {
      _didHapticPulse = true;
      unawaited(
        HapticFeedback.selectionClick().catchError((_) {}),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _resumeSignal?.complete();
    _resumeSignal = null;
    _timelineController?.removeListener(_handleTimelineTick);
    _timelineController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final signal = _resumeSignal;
    if (signal != null && !signal.isCompleted) {
      signal.complete();
    }
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
        const Duration(milliseconds: 5000),
        onTimeout: () => const _SplashBootstrapResult.unauthenticated(),
      );
    } catch (_) {
      bootstrap = const _SplashBootstrapResult.unauthenticated();
    }

    if (!mounted || _isDisposed || _didNavigate) {
      return;
    }

    if (bootstrap.userData != null) {
      try {
        await context.read<TimezoneProvider>().applyUserTimeZone(
              bootstrap.userData,
              fallbackToDefault: true,
            );
      } catch (_) {
        // Timezone sync should not block splash navigation.
      }
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

      var userData = await ApiService.me().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (userData == null || userData.isEmpty) {
        userData = await ApiService.me().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
      }

      await configFuture;

      Map<String, dynamic>? fallbackUserData;
      final cachedFromOffline =
          await OfflineStorageService.instance.getCachedUserData();
      if (cachedFromOffline != null && cachedFromOffline.isNotEmpty) {
        fallbackUserData = Map<String, dynamic>.from(cachedFromOffline);
      } else {
        final prefsRaw = prefs.getString('userData');
        if (prefsRaw != null && prefsRaw.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(prefsRaw);
            if (decoded is Map) {
              fallbackUserData = decoded.map(
                (key, value) => MapEntry(key.toString(), value),
              );
            }
          } catch (_) {
            // Ignore malformed cached payload.
          }
        }
      }

      final resolvedUserData = (userData != null && userData.isNotEmpty)
          ? Map<String, dynamic>.from(userData)
          : fallbackUserData;

      if (resolvedUserData == null || resolvedUserData.isEmpty) {
        final fallbackUserId = (prefs.getString('userId') ?? '').trim();
        if (fallbackUserId.isNotEmpty) {
          return _SplashBootstrapResult.authenticated({
            'id': fallbackUserId,
            'name': (prefs.getString('name') ?? 'Patient'),
            'email': (prefs.getString('email') ?? ''),
          });
        }
        return const _SplashBootstrapResult.unauthenticated();
      }

      final requiresVerification =
          resolvedUserData.containsKey('emailVerified') &&
              resolvedUserData['emailVerified'] != true;
      if (requiresVerification) {
        await SecureTokenStorage.clearToken();
        await prefs.remove('userData');
        await prefs.remove('userId');
        await prefs.remove('email');
        await prefs.remove('name');
        return const _SplashBootstrapResult.unauthenticated();
      }

      await prefs.setString('userData', jsonEncode(resolvedUserData));
      final fallbackUserId = (prefs.getString('userId') ?? '').trim();
      await prefs.setString(
        'userId',
        resolvedUserData['id']?.toString() ??
            resolvedUserData['_id']?.toString() ??
            fallbackUserId,
      );
      await prefs.setString(
        'email',
        resolvedUserData['email']?.toString() ?? '',
      );
      await prefs.setString(
        'name',
        resolvedUserData['name']?.toString() ?? 'Patient',
      );
      await OfflineStorageService.instance.cacheUserData(resolvedUserData);
      await OfflineStorageService.instance
          .cacheEmergencyContactsFromUserData(resolvedUserData);

      _setStatus('Warming up your vault...');

      unawaited(
        FCMService().registerToken().catchError((e) {
          debugPrint('FCM registration error: $e');
        }),
      );

      return _SplashBootstrapResult.authenticated(
        resolvedUserData,
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

  Future<void> _waitForResumeOrDelay(Duration timeout) async {
    if (!mounted || _isDisposed) return;
    final signal = Completer<void>();
    _resumeSignal = signal;
    try {
      await signal.future.timeout(timeout);
    } on TimeoutException {
      // Poll again even if Android did not send a lifecycle resume event.
    } finally {
      if (identical(_resumeSignal, signal)) {
        _resumeSignal = null;
      }
    }
  }

  Future<bool> _waitUntilUpdatedVersionInstalled(
    AppUpdateInfo info, {
    required ValueChanged<String> onStatus,
  }) async {
    if (!mounted || _isDisposed) return false;
    onStatus(
      'Installing version ${info.latestVersion}. Complete the Android installer prompt to continue.',
    );
    await _waitForResumeOrDelay(const Duration(seconds: 90));

    if (!mounted || _isDisposed) return false;
    try {
      final installedVersion = await _appUpdateService.getInstalledVersion();
      final installed = AppUpdateService.compareVersions(
            installedVersion,
            info.latestVersion,
          ) >=
          0;
      if (installed) {
        await _appUpdateService.clearPendingInstall();
      }
      return installed;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _showUpdateDialog({
    required AppUpdateCheckResult checkResult,
    required AppUpdateInfo info,
  }) async {
    final l10n = context.l10n;
    final bool forceUpdate = checkResult.forceUpdate;
    bool downloading = false;
    bool installing = false;
    double progress = 0;
    bool checksumVerified = false;
    bool readyToInstall = false;
    String? downloadedApkPath;
    String? statusText;

    final pendingInstall = await _appUpdateService.getPendingInstall();
    if (pendingInstall != null &&
        pendingInstall.targetVersion == info.latestVersion) {
      final alreadyInstalled =
          await _appUpdateService.isPendingInstallSatisfied(pendingInstall);
      if (alreadyInstalled) {
        return true;
      }
      final reusable = await _appUpdateService.isPendingApkReusable(
        pendingInstall,
      );
      if (reusable) {
        downloadedApkPath = pendingInstall.apkPath;
        checksumVerified = true;
        readyToInstall = true;
        statusText =
            'Installation not completed. Tap Install again to continue.';
      }
    }

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
                        if (installing) ...[
                          const SizedBox(height: 14),
                          const LinearProgressIndicator(),
                          const SizedBox(height: 6),
                          Text(
                            'Opening Android installer...',
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
                      onPressed: downloading || installing
                          ? null
                          : () => Navigator.of(dialogContext).pop(true),
                      child: Text(l10n.auto('Later')),
                    ),
                  if (!forceUpdate)
                    TextButton(
                      onPressed: downloading || installing
                          ? null
                          : () async {
                              await _appUpdateService.skipVersionFor24Hours(
                                info.latestVersion,
                                buildNumber: info.latestBuildNumber,
                              );
                              if (!mounted || !dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop(true);
                            },
                      child: Text(l10n.t('update.action.skip')),
                    ),
                  ElevatedButton(
                    onPressed: downloading || installing
                        ? null
                        : () async {
                            if (!readyToInstall || downloadedApkPath == null) {
                              setDialogState(() {
                                downloading = true;
                                progress = 0;
                                checksumVerified = false;
                                statusText = 'Downloading update...';
                              });

                              final downloadResult = await _appUpdateService
                                  .downloadAndVerifyUpdate(
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
                                checksumVerified =
                                    downloadResult.checksumVerified;
                                statusText = downloadResult.message;
                              });

                              if (!downloadResult.isReady) {
                                return;
                              }

                              setDialogState(() {
                                progress = 1;
                                readyToInstall = true;
                                downloadedApkPath = downloadResult.apkPath;
                                statusText =
                                    'Update verified. Tap Install to continue.';
                              });
                              return;
                            }

                            setDialogState(() {
                              installing = true;
                              progress = 1;
                              statusText = 'Opening Android installer...';
                            });

                            final installResult =
                                await _appUpdateService.launchInstallUpdate(
                              info: info,
                              apkPath: downloadedApkPath!,
                            );

                            if (!mounted) return;

                            if (!installResult.isSuccess) {
                              setDialogState(() {
                                installing = false;
                                checksumVerified =
                                    installResult.checksumVerified;
                                statusText = installResult.message;
                              });
                              return;
                            }

                            final installed =
                                await _waitUntilUpdatedVersionInstalled(
                              info,
                              onStatus: (message) {
                                if (!mounted || !dialogContext.mounted) return;
                                setDialogState(() {
                                  installing = true;
                                  progress = 1;
                                  statusText = message;
                                });
                              },
                            );

                            if (!mounted || !dialogContext.mounted) return;
                            if (installed) {
                              setDialogState(() {
                                installing = false;
                                statusText =
                                    'Update installed successfully. Reopening the app may be required.';
                              });
                              Navigator.of(dialogContext).pop(true);
                              return;
                            }

                            setDialogState(() {
                              installing = false;
                              statusText = forceUpdate
                                  ? 'Update was not completed. Install version ${info.latestVersion} to continue.'
                                  : 'Install was not completed. You can tap Later or Skip Version to continue without updating.';
                            });
                          },
                    child: Text(
                      downloading || installing
                          ? '${l10n.t('update.action.updateNow')}...'
                          : readyToInstall
                              ? 'Install'
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

  double _clampUnit(double value) => value.clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeline = _timelineController;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: StatusBarHelper.overlayStyleForBrightness(
        isDark ? Brightness.dark : Brightness.light,
        transparentStatusBar: true,
        transparentNavigationBar: true,
      ),
      child: Scaffold(
        body: (timeline == null || _useStaticFallback)
            ? StaticPremiumSplashFallback(
                statusText: _statusText,
                logoAssetPath: 'assets/icon/medical_vault_logo.svg',
              )
            : PremiumSplashVisual(
                progress: timeline,
                statusText: _statusText,
                logoAssetPath: 'assets/icon/medical_vault_logo.svg',
              ),
      ),
    );
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
