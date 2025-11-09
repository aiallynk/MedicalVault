import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hello/firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Login_Signup/SignUp.dart';
import 'Login_Signup/loginScreen.dart';
import 'Login_Signup/VerifyEmailPage.dart';
import 'Notifications/fcm_service.dart';
import 'Notifications/global_notification_handler.dart';
import 'localization/app_localizations.dart';
import 'providers/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system UI for status bar visibility
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize FCM service
  await FCMService().initialize();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final themeMode = await ThemeProvider.loadThemeMode();
  final initialLocale = await LanguageProvider.loadLocale();

  // Set initial status bar style
  if (themeMode == ThemeMode.dark) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  } else {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0x80000000), // Semi-transparent dark background
        statusBarIconBrightness:
            Brightness.light, // Light icons on dark background
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(themeMode)),
        ChangeNotifierProvider(create: (_) => LanguageProvider(initialLocale)),
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setStatusBarStyle(themeProvider.themeMode);
        });

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Health Vault',
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
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
          home: const NotificationWrapper(),
        );
      },
    );
  }

  void _setStatusBarStyle(ThemeMode themeMode) {
    if (themeMode == ThemeMode.dark) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      );
    } else {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );
    }
  }
}

// Helper class for status bar management
class StatusBarHelper {
  static void setStatusBarStyle(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      );
    } else {
      // For light mode, use a semi-transparent dark background to ensure light icons are visible
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Color(0x80000000), // Semi-transparent dark background
          statusBarIconBrightness:
              Brightness.light, // Light icons on dark background
          statusBarBrightness: Brightness.dark,
        ),
      );
    }
  }

  // Alternative method for better visibility in light mode
  static void setStatusBarStyleAlternative(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      );
    } else {
      // Alternative: Use a more opaque background for better contrast
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Color(0xCC000000), // More opaque dark background
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      );
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode'; // 'light' | 'dark'

  ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  ThemeProvider(this._themeMode) {
    // Set status bar style when provider is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_themeMode == ThemeMode.dark) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        );
      } else {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor:
                Color(0x80000000), // Semi-transparent dark background
            statusBarIconBrightness:
                Brightness.light, // Light icons on dark background
            statusBarBrightness: Brightness.dark,
          ),
        );
      }
    });
  }

  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey);
    if (saved == 'dark') return ThemeMode.dark;
    return ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _themeKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');

    // Update status bar style when theme changes
    if (_themeMode == ThemeMode.dark) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      );
    } else {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Color(0x80000000), // Semi-transparent dark background
          statusBarIconBrightness:
              Brightness.light, // Light icons on dark background
          statusBarBrightness: Brightness.dark,
        ),
      );
    }

    notifyListeners();
  }
}

class AppThemes {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue, brightness: Brightness.light),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0x1A2196F3),
        labelTextStyle:
            WidgetStatePropertyAll(TextStyle(color: Colors.black87)),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black87),
        bodyMedium: TextStyle(color: Colors.black87),
      ),
      cardColor: Colors.white,
      dialogBackgroundColor: Colors.white,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0.5,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Colors.lightBlueAccent,
        unselectedItemColor: Colors.white70,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        indicatorColor: Color(0x332196F3),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(color: Colors.white)),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
      ),
      cardColor: const Color(0xFF1E1E1E),
      dialogBackgroundColor: const Color(0xFF1E1E1E),
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
      print("Firebase Messaging Token: $token");
    });
    messaging = FirebaseMessaging.instance;
    // Request permission for receiving notifications
    messaging.requestPermission(
      criticalAlert: true,
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle incoming messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Show alert dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              icon: Icon(Icons.warning),
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

    // Handle notification taps while the app is in the background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked while app is in background: ${message.messageId}');
      // Navigate to appropriate screen based on the message
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        // Exit the app when back button is pressed on welcome screen
        return true;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Background SVG
            Positioned.fill(
              child: SvgPicture.asset(
                isDarkMode
                    ? 'assets/WelcomeDarkTheme.svg'
                    : 'assets/WelcomeLightTheme.svg',
                fit: BoxFit.cover,
              ),
            ),
            // Foreground Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 80), // Space from top
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
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
                          color: Colors.white, // Keep gradient text base
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
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => LoginScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignUpPage()),
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Theme.of(context).cardColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: !isDarkMode
                              ? const BorderSide(
                                  color: Colors.black12, width: 1)
                              : BorderSide.none,
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

class NotificationWrapper extends StatefulWidget {
  const NotificationWrapper({super.key});

  @override
  State<NotificationWrapper> createState() => _NotificationWrapperState();
}

class _NotificationWrapperState extends State<NotificationWrapper> {
  @override
  void initState() {
    super.initState();
    // Set the global context for notifications
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
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Lightweight deep link handler; if uni_links is configured, plug in here
    // For now, we rely on manual navigation to VerifyEmailPage if needed.
  }
  @override
  Widget build(BuildContext context) {
    // If a pending verification token exists (from future uni_links integration), route to VerifyEmailPage
    if (_pendingToken != null) {
      return VerifyEmailPage(incomingToken: _pendingToken);
    }
    return const WelcomeScreen();
  }
}
