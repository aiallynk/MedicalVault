import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:hello/core/theme/theme.dart';

import 'QR.dart';
import 'MedicalCard.dart';
import 'package:hello/SettingPages/AccountSettingsPage.dart';
import 'package:hello/SettingPages/ChangePassword.dart';
import 'package:hello/SettingPages/ContactSupportPage.dart';
import 'package:hello/SettingPages/FaqPage.dart';
import 'package:hello/SettingPages/HealthAccessSettingsPage.dart';
import 'package:hello/SettingPages/NotificationsSettingsPage.dart';
import 'package:hello/SettingPages/PreferencesSettingsPage.dart';
import 'package:hello/SettingPages/AboutAppPage.dart';
import 'package:hello/SettingPages/PrivacyPolicyPage.dart';
import 'package:hello/SettingPages/PrivacyHelpSettingsPage.dart';
import 'package:hello/SettingPages/ProfilePageSetting.dart';
import 'package:hello/SettingPages/ProfileFamilySettingsPage.dart';
import 'package:hello/SettingPages/SecuritySettingsPage.dart';
import 'package:hello/SettingPages/ThemeSelectionPage.dart';
import 'package:hello/SettingPages/TermsOfServicesPage.dart';
import 'package:hello/SettingPages/settings_route.dart';
import 'package:hello/Login_Signup/loginScreen.dart';
import 'package:hello/screens/appointments_page.dart';
import 'package:hello/api_service.dart';
import 'package:hello/BottomNavigationBar/dashboard1.dart';
import 'package:hello/Notifications/notification_settings_service.dart';
import 'package:hello/Login_Signup/logout_service.dart';
import 'package:hello/localization/app_localizations.dart';
import 'package:hello/providers/language_provider.dart';
import 'package:hello/widgets/app_text.dart';
import 'package:hello/widgets/settings_primitives.dart';
import 'package:hello/widgets/ai_floating_button.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> userData; // 👈 full user data map

  const SettingsPage({super.key, required this.userData});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool sessionExpiring = true;
  bool reminders = true;
  bool systemNotifs = true;
  List<Map<String, dynamic>> linkedProfiles = [];
  bool isLoadingProfiles = false;
  bool isLoadingSettings = false;
  late Map<String, dynamic> _userData;
  final ValueNotifier<int> _sectionRefreshToken = ValueNotifier<int>(0);

  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  final LogoutService _logoutService = LogoutService();

  @override
  void initState() {
    super.initState();
    _userData = Map<String, dynamic>.from(widget.userData);
    _loadLinkedProfiles();
    _loadNotificationSettings();
    _refreshUserFromPrefs();
  }

  @override
  void dispose() {
    _sectionRefreshToken.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.userData, widget.userData)) {
      _userData = Map<String, dynamic>.from(widget.userData);
      _notifySectionRefresh();
    }
  }

  void _notifySectionRefresh() {
    _sectionRefreshToken.value++;
  }

  Future<void> _loadLinkedProfiles() async {
    if (!mounted) return;
    setState(() {
      isLoadingProfiles = true;
    });
    _notifySectionRefresh();
    try {
      final profiles = await ApiService.getLinkedProfiles();
      if (!mounted) return;
      setState(() {
        linkedProfiles = profiles;
      });
      _notifySectionRefresh();
    } catch (e) {
      print("Error loading profiles: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingProfiles = false;
      });
      _notifySectionRefresh();
    }
  }

  Future<void> _refreshUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('userData');
      if (stored == null) return;
      final decoded = jsonDecode(stored);
      if (decoded is Map<String, dynamic>) {
        if (!mounted) return;
        setState(() {
          _userData = Map<String, dynamic>.from(decoded);
        });
        _notifySectionRefresh();
      }
    } catch (e) {
      print("Error refreshing user data: $e");
    }
  }

  Future<void> _loadNotificationSettings() async {
    if (!mounted) return;
    setState(() {
      isLoadingSettings = true;
    });
    _notifySectionRefresh();
    try {
      final settings = await _settingsService.getNotificationSettings();
      if (!mounted) return;
      setState(() {
        sessionExpiring = settings['sessionExpiring'] ?? true;
        reminders = settings['reminders'] ?? true;
        systemNotifs = settings['system'] ?? true;
      });
      _notifySectionRefresh();
    } catch (e) {
      print("Error loading notification settings: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingSettings = false;
      });
      _notifySectionRefresh();
    }
  }

  Future<void> _updateNotificationSetting(String type, bool value) async {
    try {
      await _settingsService.updateNotificationSetting(type, value);
      setState(() {
        switch (type) {
          case 'sessionExpiring':
            sessionExpiring = value;
            break;
          case 'reminders':
            reminders = value;
            break;
          case 'system':
            systemNotifs = value;
            break;
        }
      });
      _notifySectionRefresh();

      // Show confirmation message
      final l10n = context.l10n;
      final label = switch (type) {
        'sessionExpiring' => l10n.auto('Session Expiring'),
        'reminders' => l10n.auto('Reminders'),
        'system' => l10n.auto('System'),
        _ => type,
      };
      final statusText = value
          ? l10n.t('notifications.status.enabled')
          : l10n.t('notifications.status.disabled');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label $statusText'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("Error updating notification setting: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "${context.l10n.t('notifications.status.updateFailure')} $e")),
      );
    }
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.auto('Logout')),
        content: Text(context.l10n.t('settings.logout.confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.auto('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.auto('Logout')),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Clear all session data
        await _logoutService.logout();

        // Close loading dialog
        Navigator.of(context).pop();

        // Navigate to login screen and clear entire navigation stack
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // Remove all previous routes
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.t('settings.logout.success')),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n
                  .format('settings.logout.failure', {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            SettingsTokens.pageHorizontal,
            SettingsTokens.pageTop,
            SettingsTokens.pageHorizontal,
            SettingsTokens.pageBottom,
          ),
          children: [
            SettingsPageHeader(
              title: l10n.auto('Settings'),
              subtitle: l10n.auto(
                'Manage privacy, linked profiles, app appearance, and updates in one place.',
              ),
              icon: Icons.settings_rounded,
            ),
            const SizedBox(height: SettingsTokens.sectionGap),
            SettingsSectionCard(
              icon: Icons.badge_outlined,
              title: l10n.auto('Profile & Family'),
              subtitle: l10n.auto('Manage your identity and linked profiles'),
              onTap: () => _openSettingsSection(
                ProfileFamilySettingsPage(
                  refreshListenable: _sectionRefreshToken,
                  title: l10n.auto('Profile & Family'),
                  subtitle:
                      l10n.auto('Manage your identity and linked profiles'),
                  contentBuilder: (sectionContext) {
                    final String name =
                        _userData['name']?.toString() ?? 'Your Name';
                    final String email =
                        _userData['email']?.toString() ?? 'youremail@gmail.com';
                    final String mobile =
                        _userData['mobile']?.toString() ?? 'N/A';
                    final String aadhaar =
                        _userData['aadhaar']?.toString() ?? 'N/A';
                    final String dob =
                        _userData['dateOfBirth']?.toString() ?? 'N/A';
                    return Column(
                      children: [
                        SettingsSection(
                          title: sectionContext.l10n.auto('Identity'),
                          subtitle: sectionContext.l10n.auto(
                            'Review your personal details and keep linked family profiles organized.',
                          ),
                          child: SettingsGroupCard(
                            child: Column(
                              children: [
                                _buildPersonalDetailsTile(
                                  sectionContext,
                                  name: name,
                                  email: email,
                                  mobile: mobile,
                                  aadhaar: aadhaar,
                                  dob: dob,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: SettingsTokens.sectionGap),
                        _buildSwitchProfileSection(sectionContext),
                      ],
                    );
                  },
                ),
              ),
            ),
            SettingsSectionCard(
              icon: Icons.lock_outline_rounded,
              title: l10n.auto('Security'),
              subtitle: l10n.auto('Keep your account protected'),
              onTap: () => _openSettingsSection(
                SecuritySettingsPage(
                  refreshListenable: _sectionRefreshToken,
                  title: l10n.auto('Security'),
                  subtitle: l10n.auto('Keep your account protected'),
                  contentBuilder: (sectionContext) {
                    return SettingsSection(
                      title: sectionContext.l10n.auto('Credentials'),
                      subtitle: sectionContext.l10n.auto(
                        'Update the core credentials that protect your account.',
                      ),
                      child: SettingsGroupCard(
                        child: Column(
                          children: [
                            _buildTile(
                              sectionContext,
                              Icons.lock,
                              l10n.auto('Password'),
                              l10n.auto('Change your account password'),
                              const ChangePasswordScreen(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SettingsSectionCard(
              icon: Icons.health_and_safety_outlined,
              title: l10n.auto('Health Access'),
              subtitle: l10n.auto('Appointments, QR sharing and medical card'),
              onTap: () => _openSettingsSection(
                HealthAccessSettingsPage(
                  refreshListenable: _sectionRefreshToken,
                  title: l10n.auto('Health Access'),
                  subtitle:
                      l10n.auto('Appointments, QR sharing and medical card'),
                  contentBuilder: (sectionContext) {
                    return SettingsSection(
                      title: sectionContext.l10n.auto('Access Tools'),
                      subtitle: sectionContext.l10n.auto(
                        'Open the tools you use to share, view, and manage care access.',
                      ),
                      child: SettingsGroupCard(
                        child: Column(
                          children: [
                            _buildTile(
                              sectionContext,
                              Icons.share,
                              l10n.auto('Sharing Controls'),
                              l10n.auto('Manage your QR sharing options'),
                              QRPage(),
                              showDivider: true,
                            ),
                            _buildTile(
                              sectionContext,
                              Icons.calendar_today,
                              l10n.auto('Appointments'),
                              l10n.auto('View and manage your appointments'),
                              const AppointmentsPage(),
                              showDivider: true,
                            ),
                            _buildMedicalCardTile(sectionContext),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SettingsSectionCard(
              icon: Icons.tune_rounded,
              title: l10n.auto('App Preferences'),
              subtitle: l10n.auto('Language, theme and app appearance'),
              onTap: () => _openSettingsSection(
                PreferencesSettingsPage(
                  refreshListenable: _sectionRefreshToken,
                  title: l10n.auto('App Preferences'),
                  subtitle: l10n.auto('Language, theme and app appearance'),
                  contentBuilder: (sectionContext) {
                    return Column(
                      children: [
                        _buildLanguageSection(sectionContext),
                        const SizedBox(height: SettingsTokens.sectionGap),
                        _buildThemePreferenceSection(sectionContext),
                        const SizedBox(height: SettingsTokens.sectionGap),
                        SettingsSection(
                          title: sectionContext.l10n.auto('Utilities'),
                          subtitle: sectionContext.l10n.auto(
                            'Quick actions for app metadata and assistant placement.',
                          ),
                          child: SettingsGroupCard(
                            child: Column(
                              children: [
                                _buildAboutAppTile(sectionContext),
                                _buildAIAssistantResetTile(sectionContext),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SettingsSectionCard(
              icon: Icons.notifications_active_outlined,
              title: l10n.auto('Notifications'),
              subtitle: l10n.auto('Choose what alerts you receive'),
              onTap: () => _openSettingsSection(
                NotificationsSettingsPage(
                  refreshListenable: _sectionRefreshToken,
                  title: l10n.auto('Notifications'),
                  subtitle: l10n.auto('Choose what alerts you receive'),
                  contentBuilder: (sectionContext) {
                    final scheme = Theme.of(sectionContext).colorScheme;
                    if (isLoadingSettings) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return SettingsSection(
                      title: sectionContext.l10n.auto('Alert Categories'),
                      subtitle: sectionContext.l10n.auto(
                        'Choose the moments when the app should interrupt you.',
                      ),
                      child: SettingsGroupCard(
                        child: Column(
                          children: [
                            _buildNotificationSwitchTile(
                              sectionContext,
                              l10n.auto('Session Expiring'),
                              l10n.auto(
                                'Get notified when your session with doctor is about to expire (last 30 seconds)',
                              ),
                              sessionExpiring,
                              Icons.timer,
                              scheme.primary,
                              (val) => _updateNotificationSetting(
                                  'sessionExpiring', val),
                              showDivider: true,
                            ),
                            _buildNotificationSwitchTile(
                              sectionContext,
                              l10n.auto('Reminders'),
                              l10n.auto(
                                'Receive appointment reminders and other important notifications',
                              ),
                              reminders,
                              Icons.notifications,
                              scheme.secondary,
                              (val) =>
                                  _updateNotificationSetting('reminders', val),
                              showDivider: true,
                            ),
                            _buildNotificationSwitchTile(
                              sectionContext,
                              l10n.auto('System'),
                              l10n.auto(
                                'Get system updates, advertisements, and instruction notifications',
                              ),
                              systemNotifs,
                              Icons.info,
                              scheme.tertiary,
                              (val) =>
                                  _updateNotificationSetting('system', val),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SettingsSectionCard(
              icon: Icons.verified_user_outlined,
              title: l10n.auto('Privacy & Help'),
              subtitle: l10n.auto('Policies, FAQs and support'),
              onTap: () => _openSettingsSection(
                PrivacyHelpSettingsPage(
                  refreshListenable: _sectionRefreshToken,
                  title: l10n.auto('Privacy & Help'),
                  subtitle: l10n.auto('Policies, FAQs and support'),
                  contentBuilder: (sectionContext) {
                    return SettingsSection(
                      title: sectionContext.l10n.auto('Help Resources'),
                      subtitle: sectionContext.l10n.auto(
                        'Policies, support documents, and direct help channels.',
                      ),
                      child: SettingsGroupCard(
                        child: Column(
                          children: [
                            _buildTile(
                              sectionContext,
                              Icons.privacy_tip,
                              l10n.auto('Privacy Policy'),
                              l10n.auto('Read how your data is handled'),
                              PrivacyPolicy(),
                              showDivider: true,
                            ),
                            _buildTile(
                              sectionContext,
                              Icons.description,
                              l10n.auto('Terms of Service'),
                              l10n.auto('Review terms and conditions'),
                              TermsOfService(),
                              showDivider: true,
                            ),
                            _buildTile(
                              sectionContext,
                              Icons.help_outline,
                              l10n.auto('FAQs'),
                              l10n.auto('Find answers to common questions'),
                              FAQs(),
                              showDivider: true,
                            ),
                            _buildTile(
                              sectionContext,
                              Icons.support_agent,
                              l10n.auto('Contact Support'),
                              l10n.auto('Get help from the support team'),
                              ContactSupportScreen(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SettingsSectionCard(
              icon: Icons.logout_rounded,
              title: l10n.auto('Account'),
              subtitle: l10n.auto('Sign out from your current account'),
              onTap: () => _openSettingsSection(
                AccountSettingsPage(
                  refreshListenable: _sectionRefreshToken,
                  title: l10n.auto('Account'),
                  subtitle: l10n.auto('Sign out from your current account'),
                  contentBuilder: (sectionContext) {
                    return SettingsSection(
                      title: sectionContext.l10n.auto('Session'),
                      subtitle: sectionContext.l10n.auto(
                        'End this session securely on the current device.',
                      ),
                      child: SettingsGroupCard(
                        child: Column(
                          children: [
                            _buildLogoutTile(sectionContext),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettingsSection(Widget page) async {
    await pushSettingsRoute(context, page);
    _notifySectionRefresh();
  }

  Widget _buildPersonalDetailsTile(
    BuildContext sectionContext, {
    required String name,
    required String email,
    required String mobile,
    required String aadhaar,
    required String dob,
  }) {
    return SettingsItemTile(
      icon: Icons.person_rounded,
      title: sectionContext.l10n.auto('Personal Details'),
      subtitle: sectionContext.l10n.auto('View and edit your personal details'),
      onTap: () async {
        final result = await pushSettingsRoute(
          sectionContext,
          ProfileName(
            userData: {
              "name": name,
              "email": email,
              "mobile": mobile,
              "aadhaar": aadhaar,
              "dateOfBirth": dob,
              "age": _userData["age"],
              "gender": _userData["gender"],
              "bloodType": _userData["bloodType"],
              "height": _userData["height"],
              "weight": _userData["weight"],
              "lastVisit": _userData["lastVisit"],
              "nextAppointment": _userData["nextAppointment"],
              "emergencyContact": _userData["emergencyContact"],
              "medicalHistory": _userData["medicalHistory"] ?? [],
              "medications": _userData["medications"] ?? [],
              "medicalRecords": _userData["medicalRecords"] ?? [],
              "profilePicture": _userData["profilePicture"],
              "profilePictureUrl": _userData["profilePictureUrl"],
            },
          ),
        );
        if (!mounted) return;
        if (result is Map<String, dynamic>) {
          setState(() {
            _userData = Map<String, dynamic>.from(result);
          });
          _notifySectionRefresh();
        } else {
          await _refreshUserFromPrefs();
        }
      },
    );
  }

  Widget _buildTile(
    BuildContext sectionContext,
    IconData icon,
    String title,
    String subtitle,
    Widget page, {
    bool showDivider = false,
  }) {
    return SettingsItemTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      showDivider: showDivider,
      onTap: () {
        pushSettingsRoute(sectionContext, page);
      },
    );
  }

  Widget _buildLanguageSection(BuildContext sectionContext) {
    final languageProvider = sectionContext.watch<LanguageProvider>();
    final l10n = sectionContext.l10n;
    final currentCode = languageProvider.locale.languageCode;
    final languages = [
      {'code': 'en', 'label': l10n.auto('English')},
      {'code': 'hi', 'label': l10n.auto('Hindi')},
      {'code': 'mr', 'label': l10n.auto('Marathi')},
      {'code': 'gu', 'label': l10n.auto('Gujarati')},
    ];
    final currentLabel = languages.firstWhere(
      (lang) => lang['code'] == currentCode,
      orElse: () => languages.first,
    )['label']!;

    return SettingsSection(
      title: l10n.t('settings.language.selectorTitle'),
      subtitle: l10n.t('settings.language.selectorSubtitle'),
      child: SettingsGroupCard(
        child: Column(
          children: [
            SettingsItemTile(
              icon: Icons.translate_rounded,
              title: l10n.auto('App Language'),
              subtitle: l10n.auto('Choose the language used across the app.'),
              onTap: () => _showLanguagePicker(
                sectionContext,
                languages: languages,
                currentCode: currentCode,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(sectionContext)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: AppText(
                      currentLabel,
                      variant: AppTextVariant.caption,
                      color: Theme.of(sectionContext).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: Theme.of(sectionContext)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.34),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalCardTile(BuildContext sectionContext) {
    return SettingsItemTile(
      icon: Icons.medical_services,
      title: sectionContext.l10n.auto('Medical Card'),
      subtitle:
          sectionContext.l10n.auto('View your permanent medical card QR code'),
      onTap: () {
        final medicalCardUserData = Map<String, dynamic>.from(_userData);
        medicalCardUserData.remove('profilePicture');
        medicalCardUserData.remove('profilePictureUrl');

        pushSettingsRoute(
          sectionContext,
          MedicalCardPage(userData: medicalCardUserData),
        );
      },
    );
  }

  Widget _buildNotificationSwitchTile(
    BuildContext sectionContext,
    String title,
    String subtitle,
    bool value,
    IconData icon,
    Color iconColor,
    ValueChanged<bool> onChanged, {
    bool showDivider = false,
  }) {
    return SettingsSwitchTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      accentColor: iconColor,
      showDivider: showDivider,
      onChanged: onChanged,
    );
  }

  Widget _buildThemePreferenceSection(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final currentAccent = themeProvider.customPrimaryColor ?? scheme.primary;
    final currentSecondary = themeProvider.customSecondaryColor;
    final paletteLabel = themeProvider.customPrimaryColor == null
        ? appThemePaletteLabel(themeProvider.palette)
        : themeProvider.hasCustomGradient
            ? l10n.auto('Custom Gradient')
            : l10n.auto('Custom Solid');
    final paletteSubtitle = themeProvider.customPrimaryColor == null
        ? l10n.auto('Using the built-in palette accent')
        : themeProvider.hasCustomGradient
            ? l10n.auto('Custom gradient accent active across the app')
            : l10n.auto('Custom solid accent active across the app');

    return SettingsSection(
      title: l10n.auto('Theme & Mode'),
      subtitle: l10n.auto(
        'Review the active palette, open the visual preview page, and set your preferred appearance mode.',
      ),
      child: Column(
        children: [
          SettingsGroupCard(
            child: Column(
              children: [
                SettingsItemTile(
                  icon: Icons.palette_outlined,
                  title: l10n.auto('Theme Style'),
                  subtitle: paletteLabel,
                  showDivider: true,
                  onTap: () => pushSettingsRoute(
                    context,
                    const ThemeSelectionPage(),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color:
                              currentSecondary == null ? currentAccent : null,
                          gradient: currentSecondary == null
                              ? null
                              : LinearGradient(
                                  colors: [currentAccent, currentSecondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.34),
                      ),
                    ],
                  ),
                ),
                SettingsItemTile(
                  icon: Icons.color_lens_outlined,
                  title: l10n.auto('Accent Color'),
                  subtitle: paletteSubtitle,
                  onTap: () => pushSettingsRoute(
                    context,
                    const ThemeSelectionPage(),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: currentAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: AppText(
                          paletteLabel,
                          variant: AppTextVariant.caption,
                          fontWeight: FontWeight.w700,
                          color: currentAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.34),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SegmentedModeSelector(
            selectedMode: themeProvider.themeMode,
            onChanged: themeProvider.setThemeMode,
            labels: {
              ThemeMode.light: l10n.auto('Light'),
              ThemeMode.dark: l10n.auto('Dark'),
              ThemeMode.system: l10n.auto('System'),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAIAssistantResetTile(BuildContext sectionContext) {
    return SettingsItemTile(
      icon: Icons.smart_toy_outlined,
      title: sectionContext.l10n.auto('Reset AI assistant position'),
      subtitle: sectionContext.l10n.auto(
        'Move the assistant bubble back to its default location',
      ),
      showDivider: false,
      onTap: () async {
        final messenger = ScaffoldMessenger.of(sectionContext);
        final message =
            sectionContext.l10n.auto('AI assistant position has been reset');
        await resetAIAssistantButtonPosition();
        if (!mounted) return;
        _notifySectionRefresh();
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
      },
      trailing: const Icon(Icons.restart_alt_rounded, size: 18),
    );
  }

  Widget _buildAboutAppTile(BuildContext sectionContext) {
    return SettingsItemTile(
      icon: Icons.info_outline_rounded,
      title: sectionContext.l10n.auto('About App'),
      subtitle: sectionContext.l10n.auto(
        'View app version, release notes and check for latest updates',
      ),
      showDivider: true,
      onTap: () {
        pushSettingsRoute(sectionContext, const AboutAppPage());
      },
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
    );
  }

  Future<void> _showLanguagePicker(
    BuildContext sectionContext, {
    required List<Map<String, String>> languages,
    required String currentCode,
  }) async {
    final languageProvider = sectionContext.read<LanguageProvider>();
    final l10n = sectionContext.l10n;

    await showModalBottomSheet<void>(
      context: sectionContext,
      backgroundColor: Theme.of(sectionContext).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsSectionHeader(
                  title: l10n.auto('Select Language'),
                  subtitle: l10n.auto(
                    'Choose the language that should be used throughout the app.',
                  ),
                ),
                const SizedBox(height: 12),
                SettingsGroupCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < languages.length; i++)
                        SettingsItemTile(
                          icon: Icons.language_rounded,
                          title: languages[i]['label']!,
                          subtitle: languages[i]['code'] == currentCode
                              ? l10n.auto('Currently selected')
                              : l10n.auto('Tap to switch to this language'),
                          showDivider: i != languages.length - 1,
                          trailing: languages[i]['code'] == currentCode
                              ? Icon(
                                  Icons.check_rounded,
                                  color: Theme.of(sectionContext)
                                      .colorScheme
                                      .primary,
                                )
                              : const SizedBox.shrink(),
                          onTap: () async {
                            final selectedCode = languages[i]['code']!;
                            final navigator = Navigator.of(bottomSheetContext);
                            await languageProvider.setLocale(
                              Locale(selectedCode),
                            );
                            if (!mounted) return;
                            if (bottomSheetContext.mounted) {
                              navigator.pop();
                            }
                            final updatedL10n = context.l10n;
                            final languageDisplay = switch (selectedCode) {
                              'hi' => updatedL10n.auto('Hindi'),
                              'mr' => updatedL10n.auto('Marathi'),
                              'gu' => updatedL10n.auto('Gujarati'),
                              _ => updatedL10n.auto('English'),
                            };
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  updatedL10n.format(
                                    'settings.language.changed',
                                    {'language': languageDisplay},
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwitchProfileSection(BuildContext sectionContext) {
    if (isLoadingProfiles) {
      return SettingsSection(
        title: sectionContext.l10n.auto('Linked Profiles'),
        subtitle: sectionContext.l10n.auto(
          'Switch between related profiles without losing access to shared settings.',
        ),
        child: const SettingsGroupCard(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final children = <Widget>[];
    if (linkedProfiles.isEmpty) {
      children.add(
        SettingsItemTile(
          icon: Icons.person_add_alt_rounded,
          title: sectionContext.l10n.auto('No linked profiles'),
          subtitle:
              sectionContext.l10n.auto('Add profiles to switch between them'),
          showDivider: true,
          onTap: _showAddProfileDialog,
        ),
      );
    } else {
      for (var i = 0; i < linkedProfiles.length; i++) {
        children.add(
          _buildProfileTile(
            sectionContext,
            linkedProfiles[i],
            showDivider: true,
          ),
        );
      }
    }
    children.add(
      SettingsItemTile(
        icon: Icons.add_rounded,
        title: sectionContext.l10n.auto('Add Profile'),
        subtitle:
            sectionContext.l10n.auto('Link an existing or create new profile'),
        onTap: _showAddProfileDialog,
      ),
    );

    return SettingsSection(
      title: sectionContext.l10n.auto('Linked Profiles'),
      subtitle: sectionContext.l10n.auto(
        'Switch between related profiles without losing access to shared settings.',
      ),
      child: SettingsGroupCard(
        child: Column(children: children),
      ),
    );
  }

  Widget _buildProfileTile(
    BuildContext sectionContext,
    Map<String, dynamic> profile, {
    bool showDivider = false,
  }) {
    final photoUrl =
        (profile['profilePictureUrl'] ?? profile['profilePicture'])?.toString();

    return SettingsItemTile(
      leading: CircleAvatar(
        radius: 21,
        backgroundColor: Theme.of(sectionContext).colorScheme.primary,
        child: (photoUrl != null && photoUrl.isNotEmpty)
            ? ClipOval(
                child: Image.network(
                  photoUrl,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.person,
                      color: Colors.white,
                    );
                  },
                ),
              )
            : const Icon(
                Icons.person,
                color: Colors.white,
              ),
      ),
      title: profile['name']?.toString() ?? sectionContext.l10n.auto('Unknown'),
      subtitle: profile['email']?.toString() ?? '',
      dense: true,
      showDivider: showDivider,
      onTap: () => _showSwitchProfileDialog(profile),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              Icons.swap_horiz_rounded,
              color: Theme.of(sectionContext).iconTheme.color,
            ),
            onPressed: () => _showSwitchProfileDialog(profile),
            tooltip: sectionContext.l10n.auto('Switch to this profile'),
          ),
          IconButton(
            icon: Icon(
              Icons.remove_circle_outline_rounded,
              color: Theme.of(sectionContext).colorScheme.error,
            ),
            onPressed: () => _showRemoveProfileDialog(profile),
            tooltip: sectionContext.l10n.auto('Remove profile'),
          ),
        ],
      ),
    );
  }

  void _showAddProfileDialog() {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(l10n.auto('Add Profile'),
            style: Theme.of(context).textTheme.titleLarge),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Email/Password section
              Text(
                l10n.auto('Email/Password'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.person,
                    color: Theme.of(context).iconTheme.color),
                title: Text(l10n.auto('Link Existing Profile'),
                    style: Theme.of(context).textTheme.bodyLarge),
                subtitle: Text(
                    l10n.auto('Link an existing email/password account'),
                    style: Theme.of(context).textTheme.bodySmall),
                onTap: () {
                  Navigator.pop(context);
                  _showLinkExistingProfileDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.person_add,
                    color: Theme.of(context).iconTheme.color),
                title: Text(l10n.auto('Create New Profile'),
                    style: Theme.of(context).textTheme.bodyLarge),
                subtitle: Text(l10n.auto('Create a new email/password profile'),
                    style: Theme.of(context).textTheme.bodySmall),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateNewProfileDialog();
                },
              ),
              const Divider(height: 24),
              // Google section
              Text(
                l10n.auto('Google Sign-In'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.g_mobiledata,
                    color: Theme.of(context).iconTheme.color, size: 32),
                title: Text(l10n.auto('Link with Google'),
                    style: Theme.of(context).textTheme.bodyLarge),
                subtitle: Text(l10n.auto('Link an existing Google account'),
                    style: Theme.of(context).textTheme.bodySmall),
                onTap: () {
                  Navigator.pop(context);
                  _handleLinkGoogleProfile();
                },
              ),
              ListTile(
                leading: Icon(Icons.g_mobiledata,
                    color: Theme.of(context).iconTheme.color, size: 32),
                title: Text(l10n.auto('Create with Google'),
                    style: Theme.of(context).textTheme.bodyLarge),
                subtitle: Text(l10n.auto('Create a new Google profile'),
                    style: Theme.of(context).textTheme.bodySmall),
                onTap: () {
                  Navigator.pop(context);
                  _handleCreateGoogleProfile();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.auto('Cancel'),
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color)),
          ),
        ],
      ),
    );
  }

  /// Handle linking a Google profile
  Future<void> _handleLinkGoogleProfile() async {
    try {
      setState(() {
        isLoadingProfiles = true;
      });
      _notifySectionRefresh();

      final result = await ApiService.linkGoogleProfile();

      if (result != null && result['success'] == true) {
        await _loadLinkedProfiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "✅ ${context.l10n.auto('Google profile linked successfully')}"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.auto('Failed to link Google profile')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingProfiles = false;
        });
        _notifySectionRefresh();
      }
    }
  }

  /// Handle creating a new Google profile
  Future<void> _handleCreateGoogleProfile() async {
    try {
      setState(() {
        isLoadingProfiles = true;
      });
      _notifySectionRefresh();

      final result = await ApiService.createGoogleProfile();

      if (result != null && result['success'] == true) {
        await _loadLinkedProfiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "✅ ${context.l10n.auto('Google profile created and linked successfully')}"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(context.l10n.auto('Failed to create Google profile')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingProfiles = false;
        });
        _notifySectionRefresh();
      }
    }
  }

  void _showLinkExistingProfileDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;
    bool isPasswordVisible = false;
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.auto('Link Existing Profile')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: l10n.auto('Email'),
                  hintText: l10n.auto('Enter email of existing profile'),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: l10n.auto('Password'),
                  hintText: l10n.auto('Enter password'),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !isPasswordVisible,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text(l10n.auto('Cancel'),
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() {
                        isLoading = true;
                      });
                      try {
                        await ApiService.addSelfProfile(
                          emailController.text.trim(),
                          passwordController.text.trim(),
                        );
                        await _loadLinkedProfiles();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text("✅ ${l10n.t('settings.linkSuccess')}"),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: ${e.toString()}")),
                        );
                      } finally {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.auto('Link')),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateNewProfileDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final mobileController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;
    bool isPasswordVisible = false;
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.auto('Create New Profile')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.auto('Name'),
                    hintText: l10n.auto('Enter full name'),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: l10n.auto('Email'),
                    hintText: l10n.auto('Enter email address'),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: mobileController,
                  decoration: InputDecoration(
                    labelText: l10n.auto('Mobile'),
                    hintText: l10n.auto('Enter mobile number'),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.auto('Password'),
                    hintText: l10n.auto('Enter password'),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !isPasswordVisible,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text(l10n.auto('Cancel'),
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() {
                        isLoading = true;
                      });
                      try {
                        await ApiService.addOtherProfile(
                          name: nameController.text.trim(),
                          email: emailController.text.trim(),
                          mobile: mobileController.text.trim(),
                          password: passwordController.text.trim(),
                        );
                        await _loadLinkedProfiles();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text("✅ ${l10n.t('settings.createSuccess')}"),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: ${e.toString()}")),
                        );
                      } finally {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.auto('Create')),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle profile switch based on login type
  Future<void> _showSwitchProfileDialog(Map<String, dynamic> profile) async {
    final loginType = profile['loginType']?.toString() ??
        (profile['googleId'] != null ? 'google' : 'email');

    if (loginType == 'google') {
      // Google profiles - no password needed, use Google Sign-In
      await _switchToGoogleProfile(profile);
    } else {
      // Email profiles - show password dialog
      await _showPasswordDialogAndSwitch(profile);
    }
  }

  /// Switch to Google profile using Google Sign-In (no password)
  Future<void> _switchToGoogleProfile(Map<String, dynamic> profile) async {
    setState(() {
      isLoadingProfiles = true;
    });
    _notifySectionRefresh();

    try {
      final result = await ApiService.switchProfile(profile);

      if (result != null && result['success'] == true) {
        // Get updated user data
        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('userData');
        final userData = userDataString != null
            ? jsonDecode(userDataString)
            : <String, dynamic>{};

        if (!mounted) return;

        // Navigate to dashboard with new profile
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: '/dashboard'),
            builder: (context) => Dashboard1(userData: userData),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ ${context.l10n.format('settings.switch.success', {
                    'name': profile['name']?.toString() ??
                        context.l10n.auto('Unknown')
                  })}",
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.t('settings.switch.failure')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingProfiles = false;
        });
        _notifySectionRefresh();
      }
    }
  }

  /// Show password dialog and switch to email/password profile
  Future<void> _showPasswordDialogAndSwitch(
      Map<String, dynamic> profile) async {
    final passwordController = TextEditingController();
    bool isLoading = false;
    bool isPasswordVisible = false;
    final l10n = context.l10n;
    final profileName = profile['name']?.toString() ?? l10n.auto('Unknown');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            l10n.format('settings.switch.dialogTitle', {'name': profileName}),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n
                    .auto('Enter password for {name}:')
                    .replaceAll('{name}', profileName),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: l10n.auto('Password'),
                  hintText: l10n.auto('Enter password'),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !isPasswordVisible,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text(l10n.auto('Cancel'),
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() {
                        isLoading = true;
                      });
                      try {
                        await ApiService.switchProfile(
                          profile,
                          password: passwordController.text.trim(),
                        );
                        Navigator.pop(context);
                        // Get updated user data and navigate to dashboard
                        final prefs = await SharedPreferences.getInstance();
                        final userDataString = prefs.getString('userData');
                        final userData = userDataString != null
                            ? jsonDecode(userDataString)
                            : <String, dynamic>{};

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/dashboard'),
                            builder: (context) =>
                                Dashboard1(userData: userData),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "✅ ${l10n.format('settings.switch.success', {
                                    'name': profileName
                                  })}",
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        final errorMessage =
                            e.toString().replaceAll('Exception: ', '');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } finally {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.auto('Switch')),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveProfileDialog(Map<String, dynamic> profile) {
    final l10n = context.l10n;
    final profileName = profile['name']?.toString() ?? l10n.auto('Unknown');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.auto('Remove Profile')),
        content: Text(
          l10n.format('settings.removeConfirm', {'name': profileName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.auto('Cancel'),
                style: Theme.of(context).textTheme.bodyLarge),
          ),
          TextButton(
            onPressed: () async {
              try {
                final success = await ApiService.removeLinkedProfile(
                    profile['_id'].toString());
                if (success) {
                  await _loadLinkedProfiles();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.format(
                            'settings.removeSuccess', {'name': profileName}),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.auto('Failed to remove profile')),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: ${e.toString()}")),
                );
              }
            },
            child: Text(l10n.auto('Remove')),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext sectionContext) {
    return SettingsItemTile(
      icon: Icons.logout_rounded,
      iconColor: Colors.red,
      title: sectionContext.l10n.auto('Logout'),
      subtitle: sectionContext.l10n.auto('Sign out of your account'),
      onTap: _handleLogout,
    );
  }
}
