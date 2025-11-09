import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:hello/main.dart';

import 'QR.dart';
import 'package:hello/SettingPages/ChangePassword.dart';
import 'package:hello/SettingPages/ContactSupportPage.dart';
import 'package:hello/SettingPages/FaqPage.dart';
import 'package:hello/SettingPages/PrivacyPolicyPage.dart';
import 'package:hello/SettingPages/ProfilePageSetting.dart';
import 'package:hello/SettingPages/TermsOfServicesPage.dart';
import 'package:hello/Login_Signup/loginScreen.dart';
import 'package:hello/api_service.dart';
import 'package:hello/BottomNavigationBar/dashboard1.dart';
import 'package:hello/Notifications/notification_settings_service.dart';
import 'package:hello/Login_Signup/logout_service.dart';
import 'package:hello/localization/app_localizations.dart';
import 'package:hello/providers/language_provider.dart';

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

  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  final LogoutService _logoutService = LogoutService();

  @override
  void initState() {
    super.initState();
    _loadLinkedProfiles();
    _loadNotificationSettings();
  }

  Future<void> _loadLinkedProfiles() async {
    if (!mounted) return;
    setState(() {
      isLoadingProfiles = true;
    });
    try {
      final profiles = await ApiService.getLinkedProfiles();
      if (!mounted) return;
      setState(() {
        linkedProfiles = profiles;
      });
    } catch (e) {
      print("Error loading profiles: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingProfiles = false;
      });
    }
  }

  Future<void> _loadNotificationSettings() async {
    if (!mounted) return;
    setState(() {
      isLoadingSettings = true;
    });
    try {
      final settings = await _settingsService.getNotificationSettings();
      if (!mounted) return;
      setState(() {
        sessionExpiring = settings['sessionExpiring'] ?? true;
        reminders = settings['reminders'] ?? true;
        systemNotifs = settings['system'] ?? true;
      });
    } catch (e) {
      print("Error loading notification settings: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingSettings = false;
      });
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
    // Ensure status bar is configured
    StatusBarHelper.setStatusBarStyle(context);

    final l10n = context.l10n;
    final languageProvider = context.watch<LanguageProvider>();

    // 👇 safe values nikale
    final String name = widget.userData["name"]?.toString() ?? "Your Name";
    final String email =
        widget.userData["email"]?.toString() ?? "youremail@gmail.com";
    final String mobile = widget.userData["mobile"]?.toString() ?? "N/A";
    final String aadhaar = widget.userData["aadhaar"]?.toString() ?? "N/A";
    final String dob = widget.userData["dateOfBirth"]?.toString() ?? "N/A";

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            SectionTitle(l10n.auto('My Profile')),
            _buildTile(
              Icons.person,
              l10n.auto('Personal Details'),
              l10n.auto('View and edit your personal details'),
              ProfileName(
                userData: {
                  "name": name,
                  "email": email,
                  "mobile": mobile,
                  "aadhaar": aadhaar,
                  "dateOfBirth": dob,
                  "age": widget.userData["age"],
                  "gender": widget.userData["gender"],
                  "bloodType": widget.userData["bloodType"],
                  "height": widget.userData["height"],
                  "weight": widget.userData["weight"],
                  "lastVisit": widget.userData["lastVisit"],
                  "nextAppointment": widget.userData["nextAppointment"],
                  "emergencyContact": widget.userData["emergencyContact"],
                  "medicalHistory": widget.userData["medicalHistory"] ?? [],
                  "medications": widget.userData["medications"] ?? [],
                  "medicalRecords": widget.userData["medicalRecords"] ?? [],
                },
              ),
            ),
            SectionTitle(l10n.auto('Switch Profile')),
            _buildSwitchProfileSection(),
            SectionTitle(l10n.auto('Security')),
            _buildTile(
                Icons.lock, l10n.auto('Password'), '', ChangePasswordScreen()),
            SectionTitle(l10n.auto('QR & Sharing')),
            _buildTile(Icons.qr_code, l10n.auto('Regenerate QR'), "", QRPage()),
            _buildTile(Icons.share, l10n.auto('Sharing Controls'), "", QRPage()),
            SectionTitle(l10n.auto('Language')),
            _buildLanguageSection(languageProvider, l10n),
            SectionTitle(l10n.auto('Switch Themes')),
            _buildDarkModeRow(context),
            SectionTitle(l10n.auto('Notifications')),
            if (isLoadingSettings)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildNotificationSwitchTile(
                l10n.auto('Session Expiring'),
                l10n.auto(
                    'Get notified when your session with doctor is about to expire (last 30 seconds)'),
                sessionExpiring,
                Icons.timer,
                Colors.orange,
                (val) => _updateNotificationSetting('sessionExpiring', val),
              ),
              _buildNotificationSwitchTile(
                l10n.auto('Reminders'),
                l10n.auto(
                    'Receive appointment reminders and other important notifications'),
                reminders,
                Icons.notifications,
                Colors.blue,
                (val) => _updateNotificationSetting('reminders', val),
              ),
              _buildNotificationSwitchTile(
                l10n.auto('System'),
                l10n.auto(
                    'Get system updates, advertisements, and instruction notifications'),
                systemNotifs,
                Icons.info,
                Colors.green,
                (val) => _updateNotificationSetting('system', val),
              ),
            ],
            SectionTitle(l10n.auto('Privacy & Terms')),
            _buildTile(
                Icons.privacy_tip, l10n.auto('Privacy Policy'), "", PrivacyPolicy()),
            _buildTile(
                Icons.description, l10n.auto('Terms of Service'), "", TermsOfService()),
            SectionTitle(l10n.auto('Help & Support')),
            _buildTile(Icons.help_outline, l10n.auto('FAQs'), "", FAQs()),
            _buildTile(Icons.support_agent, l10n.auto('Contact Support'), "",
                ContactSupportScreen()),
            SectionTitle(l10n.auto('Account')),
            _buildLogoutTile(),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, String subtitle, Widget page) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).iconTheme.color),
      title: Text(title),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey))
          : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
    );
  }

  Widget _buildLanguageSection(
      LanguageProvider languageProvider, AppLocalizations l10n) {
    final currentCode = languageProvider.locale.languageCode;
    final languages = [
      {'code': 'en', 'label': l10n.auto('English')},
      {'code': 'hi', 'label': l10n.auto('Hindi')},
      {'code': 'mr', 'label': l10n.auto('Marathi')},
      {'code': 'gu', 'label': l10n.auto('Gujarati')},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(l10n.t('settings.language.selectorTitle')),
            subtitle: Text(l10n.t('settings.language.selectorSubtitle')),
          ),
          const Divider(height: 0),
          ...languages.map((lang) {
            return RadioListTile<String>(
              value: lang['code']!,
              groupValue: currentCode,
              title: Text(lang['label']!),
              onChanged: (value) async {
                if (value == null) return;
                await languageProvider.setLocale(Locale(value));
                if (!mounted) return;
                final updatedL10n = context.l10n;
                final languageDisplay = switch (value) {
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
                          {'language': languageDisplay}),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotificationSwitchTile(
    String title,
    String subtitle,
    bool value,
    IconData icon,
    Color iconColor,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              value ? iconColor.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
          width: value ? 2 : 1,
        ),
        boxShadow: value
            ? [
                BoxShadow(
                  color: iconColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value
                ? iconColor.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: value ? iconColor : Colors.grey,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: value
                ? iconColor
                : Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: iconColor,
        inactiveThumbColor: Colors.grey[400],
        inactiveTrackColor: Colors.grey[200],
      ),
    );
  }

  Widget _buildDarkModeRow(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    return ListTile(
      leading: Icon(Icons.dark_mode, color: Theme.of(context).iconTheme.color),
      title: Text(context.l10n.auto('Dark Mode')),
      trailing: Switch(
        value: isDark,
        onChanged: (_) => themeProvider.toggleTheme(),
      ),
    );
  }

  Widget _buildSwitchProfileSection() {
    return Column(
      children: [
        if (isLoadingProfiles)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          )
        else if (linkedProfiles.isEmpty)
          ListTile(
            leading: Icon(Icons.person_add,
                color: Theme.of(context).iconTheme.color),
            title: Text(context.l10n.auto('No linked profiles'),
                style: Theme.of(context).textTheme.bodyLarge),
            subtitle: Text(
                context.l10n.auto('Add profiles to switch between them'),
                style: Theme.of(context).textTheme.bodyMedium),
            trailing: Icon(Icons.arrow_forward_ios,
                color: Theme.of(context).iconTheme.color),
            onTap: _showAddProfileDialog,
          )
        else
          ...linkedProfiles.map((profile) => _buildProfileTile(profile)),
        ListTile(
          leading: Icon(Icons.add, color: Theme.of(context).iconTheme.color),
          title:
              Text(context.l10n.auto('Add Profile'), style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text(
              context.l10n.auto('Link an existing or create new profile'),
              style: Theme.of(context).textTheme.bodyMedium),
          trailing: Icon(Icons.arrow_forward_ios,
              color: Theme.of(context).iconTheme.color),
          onTap: _showAddProfileDialog,
        ),
      ],
    );
  }

  Widget _buildProfileTile(Map<String, dynamic> profile) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        child: profile['profilePicture'] != null
            ? ClipOval(
                child: Image.network(
                  profile['profilePicture'],
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.person,
                      color: Colors.white,
                    );
                  },
                ),
              )
            : Icon(
                Icons.person,
                color: Colors.white,
              ),
      ),
      title: Text(profile['name'] ?? context.l10n.auto('Unknown'),
          style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(profile['email'] ?? '',
          style: Theme.of(context).textTheme.bodyMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.swap_horiz,
                color: Theme.of(context).iconTheme.color),
            onPressed: () => _showSwitchProfileDialog(profile),
            tooltip: context.l10n.auto('Switch to this profile'),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline,
                color: Theme.of(context).colorScheme.error),
            onPressed: () => _showRemoveProfileDialog(profile),
            tooltip: context.l10n.auto('Remove profile'),
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
                subtitle: Text(
                    l10n.auto('Create a new email/password profile'),
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
                subtitle:
                    Text(l10n.auto('Link an existing Google account'),
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
      }
    }
  }

  /// Handle creating a new Google profile
  Future<void> _handleCreateGoogleProfile() async {
    try {
      setState(() {
        isLoadingProfiles = true;
      });

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
              content: Text(
                  context.l10n.auto('Failed to create Google profile')),
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
                          content: Text(
                              "✅ ${l10n.t('settings.linkSuccess')}"),
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
                        content: Text(
                            "✅ ${l10n.t('settings.createSuccess')}"),
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
            builder: (context) => Dashboard1(userData: userData),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ ${context.l10n.format('settings.switch.success', {'name': profile['name']?.toString() ?? context.l10n.auto('Unknown')})}",
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
                l10n.auto('Enter password for {name}:')
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
                            builder: (context) =>
                                Dashboard1(userData: userData),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "✅ ${l10n.format('settings.switch.success', {'name': profileName})}",
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
          l10n
              .format('settings.removeConfirm', {'name': profileName}),
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
                        l10n.format('settings.removeSuccess',
                            {'name': profileName}),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(l10n.auto('Failed to remove profile')),
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

  Widget _buildLogoutTile() {
    return ListTile(
      leading: Icon(Icons.logout, color: Colors.red),
      title: Text(context.l10n.auto('Logout')),
      subtitle: Text(context.l10n.auto('Sign out of your account')),
      onTap: _handleLogout,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }
}
