import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'Login_Signup/SignUp.dart';
import 'Login_Signup/VerifyEmailPage.dart';
import 'Login_Signup/loginScreen.dart';
import 'Notifications/fcm_service.dart';
import 'Notifications/global_notification_handler.dart';
import 'api_service.dart';
import 'config/app_environment.dart';
import 'core/navigation/app_navigator.dart';
import 'core/navigation/app_route_observer.dart';
import 'core/theme/theme.dart';
import 'firebase_options.dart';
import 'localization/app_localizations.dart';
import 'providers/dashboard_prefetch_provider.dart';
import 'providers/language_provider.dart';
import 'providers/timezone_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/offline/offline_storage_service.dart';
import 'services/offline/offline_sync_engine.dart';
import 'services/session_conflict_service.dart';
import 'widgets/ai_floating_button.dart';

export 'core/theme/app_theme.dart';
export 'core/theme/status_bar_helper.dart';
export 'core/theme/theme_provider.dart';

final AppRouteObserver appRouteObserver = AppRouteObserver();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (error) {
    debugPrint('No .env file found, falling back to built-in defaults: $error');
  }
  tzdata.initializeTimeZones();
  await AppEnvironment.initialize();

  StatusBarHelper.configureSystemUiMode();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize encrypted offline storage + reconnect sync engine.
  try {
    await OfflineStorageService.instance.initialize();
    await OfflineSyncEngine.instance.initialize();
  } catch (error) {
    debugPrint('Offline engine init skipped: $error');
  }

  await FCMService().initialize();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final localThemeConfig = await ThemeProvider.loadThemeConfig();
  final hasSavedThemePreferences =
      await ThemeProvider.hasSavedThemePreferences();
  final initialLocale = await LanguageProvider.loadLocale();
  final initialTimeZone = await TimezoneProvider.loadTimeZone();
  final remoteUiConfig = await ApiService.fetchUiConfig().timeout(
    const Duration(seconds: 2),
    onTimeout: () => null,
  );

  int colorToValue(Color color) {
    final a = (color.a * 255).round() & 0xFF;
    final r = (color.r * 255).round() & 0xFF;
    final g = (color.g * 255).round() & 0xFF;
    final b = (color.b * 255).round() & 0xFF;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  final remotePrimary = ThemeProvider.parseHexColor(
    remoteUiConfig?['buttonColor'],
  );
  final remoteSecondary = ThemeProvider.parseHexColor(
    remoteUiConfig?['iconColor'],
  );
  final remoteThemeMode = ThemeProvider.parseThemeMode(
    remoteUiConfig?['themeMode'],
  );

  final useRemoteThemeAsDefault = !hasSavedThemePreferences;
  final remotePrimaryValue =
      remotePrimary != null ? colorToValue(remotePrimary) : null;
  final remoteSecondaryValue =
      remoteSecondary != null ? colorToValue(remoteSecondary) : null;
  final shouldUseRemotePalette =
      useRemoteThemeAsDefault && remotePrimaryValue != null;

  final themeConfig = ThemeProviderConfig(
    themeMode: useRemoteThemeAsDefault
        ? (remoteThemeMode ?? localThemeConfig.themeMode)
        : localThemeConfig.themeMode,
    palette: shouldUseRemotePalette
        ? AppThemePalette.custom
        : localThemeConfig.palette,
    customPrimaryColorValue: shouldUseRemotePalette
        ? remotePrimaryValue
        : localThemeConfig.customPrimaryColorValue,
    customSecondaryColorValue: shouldUseRemotePalette
        ? remoteSecondaryValue
        : localThemeConfig.customSecondaryColorValue,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(
            themeMode: themeConfig.themeMode,
            palette: themeConfig.palette,
            customPrimaryColorValue: themeConfig.customPrimaryColorValue,
            customSecondaryColorValue: themeConfig.customSecondaryColorValue,
          ),
        ),
        ChangeNotifierProvider(create: (_) => DashboardPrefetchProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider(initialLocale)),
        ChangeNotifierProvider(
          create: (_) => TimezoneProvider(initialTimeZone),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Health Vault',
          navigatorKey: appNavigatorKey,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          locale: languageProvider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale == null) return supportedLocales.first;
            for (final supported in supportedLocales) {
              if (supported.languageCode == locale.languageCode) {
                return supported;
              }
            }
            return supportedLocales.first;
          },
          navigatorObservers: [appRouteObserver],
          builder: (context, child) {
            final systemUiStyle = StatusBarHelper.overlayStyleForTheme(
              Theme.of(context),
              transparentStatusBar: true,
              transparentNavigationBar: false,
            );

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: systemUiStyle,
              child: DraggableAIAssistantOverlay(
                enabled: false,
                routeNameListenable: appRouteObserver.currentRouteName,
                visibleRouteNames: const {'/dashboard'},
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const SplashScreenWrapper(),
        );
      },
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late FirebaseMessaging messaging;

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.instance.getToken().then((token) {
      debugPrint('Firebase Messaging Token: $token');
    });

    messaging = FirebaseMessaging.instance;
    messaging.requestPermission(
      criticalAlert: true,
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              icon: const Icon(Icons.warning),
              title: Text(message.notification!.title ?? 'Notification'),
              content: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
          'Message clicked while app is in background: ${message.messageId}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: SvgPicture.asset(
                isDarkMode
                    ? 'assets/WelcomeDarkTheme.svg'
                    : 'assets/WelcomeLightTheme.svg',
                fit: BoxFit.cover,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 80),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        'Welcome to Medical Vault',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your health journey starts here. Track your progress, connect with professionals, and achieve your wellness goals.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 48),
                    FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/login'),
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Log in',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/signup'),
                            builder: (context) => const SignUpPage(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Sign up',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontSize: 18),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SplashScreenWrapper extends StatelessWidget {
  const SplashScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return SplashScreen(
      child: const NotificationWrapper(),
    );
  }
}

class NotificationWrapper extends StatefulWidget {
  const NotificationWrapper({super.key});

  @override
  State<NotificationWrapper> createState() => _NotificationWrapperState();
}

class _NotificationWrapperState extends State<NotificationWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalNotificationHandler.setGlobalContext(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AuthWrapper();
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _pendingToken;

  @override
  void initState() {
    super.initState();
    unawaited(SessionConflictService.instance.initialize());
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Intentionally kept lightweight for current routing setup.
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingToken != null) {
      return VerifyEmailPage(incomingToken: _pendingToken);
    }
    return const PremiumWelcomeScreen();
  }
}
