import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'QR.dart';
import 'MedicalCard.dart';
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
import 'package:hello/SettingPages/SecurityCompliancePage.dart';
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
import 'package:hello/providers/timezone_provider.dart';
import 'package:hello/widgets/app_text.dart';
import 'package:hello/widgets/settings_primitives.dart';

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
  bool allowMultipleSessions = false;
  bool isLoadingSessionPolicy = false;
  bool isUpdatingSessionPolicy = false;
  List<Map<String, dynamic>> linkedProfiles = [];
  bool isLoadingProfiles = false;
  bool isLoadingSettings = false;
  bool isLoadingDeviceSessions = false;
  List<Map<String, dynamic>> deviceSessions = [];
  late Map<String, dynamic> _userData;
  final ValueNotifier<int> _sectionRefreshToken = ValueNotifier<int>(0);
  bool _sectionRefreshQueued = false;

  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  final LogoutService _logoutService = LogoutService();

  @override
  void initState() {
    super.initState();
    _userData = Map<String, dynamic>.from(widget.userData);
    _syncSessionPolicyFromUserData(_userData);
    context.read<TimezoneProvider>().applyUserTimeZone(
          _userData,
          fallbackToDefault: true,
        );
    _loadLinkedProfiles();
    _loadNotificationSettings();
    _loadDeviceSessions();
    _loadSessionPolicy();
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
      _syncSessionPolicyFromUserData(_userData);
      _notifySectionRefresh();
    }
  }

  void _notifySectionRefresh() {
    if (!mounted || _sectionRefreshQueued) return;
    _sectionRefreshQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sectionRefreshQueued = false;
      if (!mounted) return;
      _sectionRefreshToken.value = _sectionRefreshToken.value + 1;
    });
  }

  bool? _parseBoolLike(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'on' ||
        normalized == 'enabled') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'off' ||
        normalized == 'disabled') {
      return false;
    }
    return null;
  }

  void _syncSessionPolicyFromUserData(Map<String, dynamic> source) {
    final parsed = _parseBoolLike(source['allowMultipleSessions']);
    if (parsed == null) return;
    allowMultipleSessions = parsed;
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
        await context.read<TimezoneProvider>().applyUserTimeZone(
              decoded,
              fallbackToDefault: true,
            );
        if (!mounted) return;
        setState(() {
          _userData = Map<String, dynamic>.from(decoded);
          _syncSessionPolicyFromUserData(_userData);
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

  Future<void> _loadDeviceSessions() async {
    if (!mounted) return;
    setState(() {
      isLoadingDeviceSessions = true;
    });
    _notifySectionRefresh();
    try {
      final sessions = await ApiService.fetchDeviceSessions();
      if (!mounted) return;
      setState(() {
        deviceSessions = sessions;
      });
      _notifySectionRefresh();
    } catch (e) {
      print("Error loading device sessions: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingDeviceSessions = false;
      });
      _notifySectionRefresh();
    }
  }

  Future<void> _loadSessionPolicy() async {
    if (!mounted) return;
    setState(() {
      isLoadingSessionPolicy = true;
    });
    _notifySectionRefresh();
    try {
      final policy = await ApiService.fetchSessionPolicy();
      if (!mounted) return;
      final parsed = _parseBoolLike(policy['allowMultipleSessions']);
      if (parsed == null) return;
      setState(() {
        allowMultipleSessions = parsed;
        _userData['allowMultipleSessions'] = parsed;
      });
      _notifySectionRefresh();
    } catch (e) {
      print("Error loading session policy: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingSessionPolicy = false;
      });
      _notifySectionRefresh();
    }
  }

  Future<void> _updateSessionPolicy(bool value) async {
    if (isUpdatingSessionPolicy) return;
    if (!mounted) return;
    setState(() {
      isUpdatingSessionPolicy = true;
    });
    _notifySectionRefresh();

    try {
      final response = await ApiService.updateSessionPolicy(
        allowMultipleSessions: value,
      );
      if (!mounted) return;

      if (response['success'] == true) {
        final parsed =
            _parseBoolLike(response['allowMultipleSessions']) ?? value;
        setState(() {
          allowMultipleSessions = parsed;
          _userData['allowMultipleSessions'] = parsed;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              parsed
                  ? context.l10n.auto('Multiple sessions enabled')
                  : context.l10n.auto('Single active session policy enabled'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (response['message'] ?? 'Unable to update session policy')
                  .toString(),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update session policy: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isUpdatingSessionPolicy = false;
      });
      _notifySectionRefresh();
    }
  }

  Future<void> _logoutDeviceSession(String id) async {
    final success = await ApiService.logoutDeviceSession(id);
    if (!mounted) return;
    if (success) {
      await _loadDeviceSessions();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.auto('Device logged out'))),
      );
    }
  }

  Future<void> _logoutAllDeviceSessions() async {
    final success = await ApiService.logoutAllDeviceSessions();
    if (!mounted) return;
    if (success) {
      await _loadDeviceSessions();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.auto('All devices logged out'))),
      );
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
                'Manage your account, appearance, privacy, and safety controls in one place.',
              ),
              icon: Icons.settings_rounded,
            ),
            const SizedBox(height: SettingsTokens.sectionGap),
            _buildSettingsGroupHeading(
              context,
              title: l10n.auto('Account'),
              subtitle: l10n.auto(
                'Profile, visual preferences, and privacy controls.',
              ),
            ),
            SettingsSectionCard(
              icon: Icons.badge_outlined,
              title: l10n.auto('Account'),
              subtitle: l10n.auto('Profile and linked family profiles'),
              onTap: () => _openSettingsSection(_buildAccountSectionPage()),
            ),
            SettingsSectionCard(
              icon: Icons.palette_outlined,
              title: l10n.auto('App Appearance'),
              subtitle: l10n.auto(
                'Theme Studio, app language, and timezone settings',
              ),
              onTap: () =>
                  _openSettingsSection(_buildAppAppearanceSectionPage()),
            ),
            SettingsSectionCard(
              icon: Icons.lock_outline_rounded,
              title: l10n.auto('Privacy & Security'),
              subtitle:
                  l10n.auto('Password, session policy, and active devices'),
              onTap: () =>
                  _openSettingsSection(_buildPrivacySecuritySectionPage()),
            ),
            const SizedBox(height: SettingsTokens.sectionGap),
            _buildSettingsGroupHeading(
              context,
              title: l10n.auto('Care & Safety'),
              subtitle: l10n.auto(
                'Emergency tools and alerts that keep care responsive.',
              ),
            ),
            SettingsSectionCard(
              icon: Icons.my_location_rounded,
              title: l10n.auto('Emergency & SOS'),
              subtitle:
                  l10n.auto('SOS, appointments, QR sharing, and medical card'),
              onTap: () =>
                  _openSettingsSection(_buildEmergencySosSectionPage()),
            ),
            SettingsSectionCard(
              icon: Icons.notifications_active_outlined,
              title: l10n.auto('Notifications'),
              subtitle: l10n.auto('Choose what alerts you receive'),
              onTap: () =>
                  _openSettingsSection(_buildNotificationsSectionPage()),
            ),
            const SizedBox(height: SettingsTokens.sectionGap),
            _buildSettingsGroupHeading(
              context,
              title: l10n.auto('Information'),
              subtitle: l10n.auto(
                'App details, legal documents, and compliance notes.',
              ),
            ),
            SettingsSectionCard(
              icon: Icons.info_outline_rounded,
              title: l10n.auto('About'),
              subtitle:
                  l10n.auto('App version, release info, and update status'),
              onTap: () => _openSettingsSection(const AboutAppPage()),
            ),
            SettingsSectionCard(
              icon: Icons.gavel_rounded,
              title: l10n.auto('Legal & Compliance'),
              subtitle:
                  l10n.auto('Privacy policy, terms, support, and compliance'),
              onTap: () =>
                  _openSettingsSection(_buildLegalComplianceSectionPage()),
            ),
            const SizedBox(height: 8),
            _buildRootLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettingsSection(Widget page) async {
    await pushSettingsRoute(context, page);
    _notifySectionRefresh();
  }

  Widget _buildSettingsGroupHeading(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            variant: AppTextVariant.subtitle,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 3),
          AppText(
            subtitle,
            variant: AppTextVariant.caption,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSectionPage() {
    final l10n = context.l10n;
    return ProfileFamilySettingsPage(
      refreshListenable: _sectionRefreshToken,
      title: l10n.auto('Account'),
      subtitle: l10n.auto('Manage your identity and linked profiles'),
      contentBuilder: (sectionContext) {
        final String name = _userData['name']?.toString() ?? 'Your Name';
        final String email =
            _userData['email']?.toString() ?? 'youremail@gmail.com';
        final String mobile = _userData['mobile']?.toString() ?? 'N/A';
        final String aadhaar = _userData['aadhaar']?.toString() ?? 'N/A';
        final String dob = _userData['dateOfBirth']?.toString() ?? 'N/A';
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
    );
  }

  Widget _buildPrivacySecuritySectionPage() {
    final l10n = context.l10n;
    return SecuritySettingsPage(
      refreshListenable: _sectionRefreshToken,
      title: l10n.auto('Privacy & Security'),
      subtitle: l10n.auto('Password, session policy, and active devices'),
      contentBuilder: (sectionContext) {
        return Column(
          children: [
            SettingsSection(
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
                      showDivider: true,
                    ),
                    SettingsItemTile(
                      icon: Icons.logout_rounded,
                      title: l10n.auto('Logout all devices'),
                      subtitle: l10n.auto('End all active device sessions'),
                      onTap: _logoutAllDeviceSessions,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SettingsTokens.sectionGap),
            _buildSessionPolicySection(sectionContext),
            const SizedBox(height: SettingsTokens.sectionGap),
            SettingsSection(
              title: sectionContext.l10n.auto('Active Devices'),
              subtitle: sectionContext.l10n.auto(
                'Review and revoke active sessions by device.',
              ),
              child: SettingsGroupCard(
                child: isLoadingDeviceSessions
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        children: deviceSessions.isEmpty
                            ? [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: AppText(
                                    sectionContext.l10n.auto(
                                      'No active device sessions found.',
                                    ),
                                    variant: AppTextVariant.caption,
                                  ),
                                ),
                              ]
                            : deviceSessions.map((session) {
                                final id = session['id']?.toString() ?? '';
                                final device = session['deviceInfo']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true
                                    ? session['deviceInfo'].toString()
                                    : (session['userAgent']?.toString() ??
                                        sectionContext.l10n
                                            .auto('Unknown device'));
                                final ip =
                                    session['ipAddress']?.toString() ?? 'N/A';
                                return SettingsItemTile(
                                  icon: Icons.devices_rounded,
                                  title: device,
                                  subtitle: sectionContext.l10n.auto('IP: $ip'),
                                  onTap: id.isEmpty
                                      ? null
                                      : () => _logoutDeviceSession(id),
                                  trailing: const Icon(Icons.logout, size: 16),
                                  showDivider: deviceSessions.last != session,
                                );
                              }).toList(),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmergencySosSectionPage() {
    final l10n = context.l10n;
    return HealthAccessSettingsPage(
      refreshListenable: _sectionRefreshToken,
      title: l10n.auto('Emergency & SOS'),
      subtitle: l10n.auto('SOS, appointments, QR sharing, and medical card'),
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
    );
  }

  Widget _buildAppAppearanceSectionPage() {
    final l10n = context.l10n;
    return PreferencesSettingsPage(
      refreshListenable: _sectionRefreshToken,
      title: l10n.auto('App Appearance'),
      subtitle: l10n.auto(
        'Open Theme Studio, choose the app language, and set the timezone used for dates and times.',
      ),
      contentBuilder: (sectionContext) {
        return Column(
          children: [
            _buildThemeStudioSection(sectionContext),
            const SizedBox(height: SettingsTokens.sectionGap),
            _buildLanguageSection(sectionContext),
            const SizedBox(height: SettingsTokens.sectionGap),
            _buildTimezoneSection(sectionContext),
          ],
        );
      },
    );
  }

  Widget _buildSessionPolicySection(BuildContext sectionContext) {
    return SettingsSection(
      title: sectionContext.l10n.auto('Session Policy'),
      subtitle: sectionContext.l10n.auto(
        'Choose whether your account allows simultaneous logins on multiple devices.',
      ),
      child: SettingsGroupCard(
        child: Column(
          children: [
            if (isLoadingSessionPolicy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.3),
                  ),
                ),
              )
            else
              SettingsSwitchTile(
                icon: Icons.phonelink_ring_rounded,
                title: sectionContext.l10n.auto('Allow Multiple Sessions'),
                subtitle: allowMultipleSessions
                    ? sectionContext.l10n.auto(
                        'Multiple devices can stay logged in at the same time.',
                      )
                    : sectionContext.l10n.auto(
                        'Only one active session is allowed. New logins require approval.',
                      ),
                value: allowMultipleSessions,
                onChanged: (value) {
                  if (isUpdatingSessionPolicy) return;
                  _updateSessionPolicy(value);
                },
              ),
            if (isUpdatingSessionPolicy)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeStudioSection(BuildContext sectionContext) {
    return SettingsSection(
      title: sectionContext.l10n.auto('Theme Studio'),
      subtitle: sectionContext.l10n.auto(
        'Change light, dark, or system mode and choose the accent style used across the app.',
      ),
      child: SettingsGroupCard(
        child: SettingsItemTile(
          icon: Icons.auto_awesome_rounded,
          title: sectionContext.l10n.auto('Theme Studio'),
          subtitle: sectionContext.l10n.auto(
            'Open the theme controls and preview how the app will look.',
          ),
          onTap: () => pushSettingsRoute(
            sectionContext,
            const ThemeSelectionPage(),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsSectionPage() {
    final l10n = context.l10n;
    return NotificationsSettingsPage(
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
                  (val) => _updateNotificationSetting('sessionExpiring', val),
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
                  (val) => _updateNotificationSetting('reminders', val),
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
                  (val) => _updateNotificationSetting('system', val),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegalComplianceSectionPage() {
    final l10n = context.l10n;
    return PrivacyHelpSettingsPage(
      refreshListenable: _sectionRefreshToken,
      title: l10n.auto('Legal & Compliance'),
      subtitle: l10n.auto('Policies, terms, support, and compliance'),
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
                  Icons.verified_user,
                  l10n.auto('Security & Compliance'),
                  l10n.auto('Review implemented security controls'),
                  const SecurityCompliancePage(),
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
    );
  }

  Widget _buildRootLogoutButton(BuildContext context) {
    final l10n = context.l10n;
    final errorColor = Theme.of(context).colorScheme.error;
    return OutlinedButton.icon(
      onPressed: _handleLogout,
      icon: Icon(Icons.logout_rounded, color: errorColor),
      label: Text(
        l10n.auto('Logout'),
        style: TextStyle(
          color: errorColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        side: BorderSide(color: errorColor.withValues(alpha: 0.42)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
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
      title: l10n.auto('App Language'),
      subtitle: l10n.auto(
        'Choose the language used across menus, buttons, and messages.',
      ),
      child: SettingsGroupCard(
        child: Column(
          children: [
            SettingsItemTile(
              icon: Icons.translate_rounded,
              title: l10n.auto('App Language'),
              subtitle: l10n.auto(
                'Choose the language used in menus, buttons, and messages.',
              ),
              onTap: () => _showLanguagePicker(
                sectionContext,
                languages: languages,
                currentCode: currentCode,
              ),
              trailing: _buildSelectionTrailing(
                context: sectionContext,
                label: currentLabel,
                maxWidth: 92,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimezoneSection(BuildContext sectionContext) {
    final timezoneProvider = sectionContext.watch<TimezoneProvider>();
    final l10n = sectionContext.l10n;
    final selected = timezoneProvider.selectedOption;

    return SettingsSection(
      title: l10n.auto('Time Zone'),
      subtitle: l10n.auto(
        'Choose the time zone used for appointments, reminders, and all date displays.',
      ),
      child: SettingsGroupCard(
        child: SettingsItemTile(
          icon: Icons.schedule_rounded,
          title: l10n.auto('Current Time Zone'),
          subtitle: l10n.auto(
            'Select the time zone the app should use when showing dates and times.',
          ),
          onTap: () => _showTimezonePicker(sectionContext),
          trailing: _buildSelectionTrailing(
            context: sectionContext,
            label: selected.label,
            maxWidth: 132,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionTrailing({
    required BuildContext context,
    required String label,
    double maxWidth = 120,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: AppText(
              label,
              variant: AppTextVariant.caption,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(
          Icons.arrow_forward_ios_rounded,
          size: 15,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.34),
        ),
      ],
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
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                20 + MediaQuery.of(bottomSheetContext).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsSectionHeader(
                    title: l10n.auto('Select Language'),
                    subtitle: l10n.auto(
                      'Choose the language that should be used throughout the app.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SettingsGroupCard(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: languages.length,
                        itemBuilder: (context, i) {
                          return SettingsItemTile(
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
                              final navigator =
                                  Navigator.of(bottomSheetContext);
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
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTimezonePicker(BuildContext sectionContext) async {
    final timezoneProvider = sectionContext.read<TimezoneProvider>();
    final l10n = sectionContext.l10n;
    final currentTimeZone = timezoneProvider.timeZoneId;

    await showModalBottomSheet<void>(
      context: sectionContext,
      backgroundColor: Theme.of(sectionContext).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsSectionHeader(
                    title: l10n.auto('Select Timezone'),
                    subtitle: l10n.auto(
                      'All date and time displays will follow this timezone.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SettingsGroupCard(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: TimezoneProvider.supportedTimeZones.length,
                        itemBuilder: (context, index) {
                          final zone =
                              TimezoneProvider.supportedTimeZones[index];
                          final isSelected = zone.id == currentTimeZone;

                          return SettingsItemTile(
                            icon: Icons.public_rounded,
                            title: zone.label,
                            subtitle: zone.id,
                            showDivider: index !=
                                TimezoneProvider.supportedTimeZones.length - 1,
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: Theme.of(sectionContext)
                                        .colorScheme
                                        .primary,
                                  )
                                : const SizedBox.shrink(),
                            onTap: () async {
                              await timezoneProvider.setTimeZone(zone.id);
                              if (!mounted) return;
                              if (bottomSheetContext.mounted) {
                                Navigator.of(bottomSheetContext).pop();
                              }
                              ScaffoldMessenger.of(sectionContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.auto(
                                      'Timezone switched to ${zone.label}',
                                    ),
                                  ),
                                ),
                              );
                              _notifySectionRefresh();
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
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
          content: SingleChildScrollView(
            child: Column(
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
          content: SingleChildScrollView(
            child: Column(
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
}
