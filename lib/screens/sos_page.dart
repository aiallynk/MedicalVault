import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hello/api_service.dart';
import 'package:hello/models/user_profile.dart';
import 'package:hello/localization/app_localizations.dart';
import 'package:hello/services/offline/offline_storage_service.dart';
import 'package:hello/services/offline/sos_offline_service.dart';
import 'package:permission_handler/permission_handler.dart';

class SosPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SosPage({super.key, required this.userData});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  final List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _offlineEmergencyContacts = [];
  Map<String, dynamic> _effectiveUserData = <String, dynamic>{};
  String? _selectedProfileId;
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _mobileController;
  late TextEditingController _locationController;
  late TextEditingController _timeController;
  late TextEditingController _notesController;
  Timer? _timer;
  double? _currentLatitude;
  double? _currentLongitude;
  double? _currentAccuracyMeters;
  bool _isSending = false;
  String? _sosStatusMessage;
  UserProfile? _currentUser;
  String? _allergies;

  String? _safeSensitiveText(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return null;
    if (raw.toLowerCase().startsWith('enc:v')) return null;
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: (widget.userData['name'] ?? '').toString());
    _ageController = TextEditingController(
        text: _computeAgeFromDob(widget.userData['dateOfBirth']) ??
            (widget.userData['age']?.toString() ?? ''));
    _mobileController = TextEditingController(
        text: (widget.userData['mobile'] ?? '').toString());
    _locationController = TextEditingController(text: '');
    _timeController = TextEditingController(text: _formatNow());
    _notesController = TextEditingController();
    _effectiveUserData = Map<String, dynamic>.from(widget.userData);
    _currentUser = UserProfile.fromJson(widget.userData);
    _allergies = _safeSensitiveText(_currentUser?.allergies);
    unawaited(OfflineStorageService.instance.cacheUserData(widget.userData));
    unawaited(_seedEmergencyContactsIfMissing());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _timeController.text = _formatNow();
      setState(() {});
    });
    _loadCachedLocation();
    _loadOfflineEmergencyContacts();
    _loadProfiles();
    _refreshCurrentUser();
    _tryUpdateLocation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    _ageController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatNow() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(hour)}:${two(now.minute)}:${two(now.second)} $ampm';
  }

  String? _computeAgeFromDob(dynamic dobRaw) {
    try {
      if (dobRaw == null) return null;
      String s = dobRaw.toString();
      if (s.isEmpty) return null;
      // Normalize common formats
      s = s.trim();
      if (s.contains('T')) s = s.split('T').first; // 2000-01-02T...
      if (RegExp(r"^\d{10,13}").hasMatch(s)) {
        // epoch seconds/millis
        final ms = s.length > 10 ? int.parse(s) : (int.parse(s) * 1000);
        final dob = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        return _ageFrom(dob).toString();
      }
      DateTime dob;
      try {
        dob = DateTime.parse(s.replaceAll('/', '-'));
      } catch (_) {
        // Try DD-MM-YYYY or DD/MM/YYYY
        final m = RegExp(r"^(\d{1,2})[-\/]?(\d{1,2})[-\/]?(\d{4})$")
            .firstMatch(s.replaceAll(' ', ''));
        if (m != null) {
          final d = int.parse(m.group(1)!);
          final mo = int.parse(m.group(2)!);
          final y = int.parse(m.group(3)!);
          dob = DateTime(y, mo, d);
        } else {
          return null;
        }
      }
      final age = _ageFrom(dob);
      return age.toString();
    } catch (_) {
      return null;
    }
  }

  int _ageFrom(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  String _localizedProfileName(
      Map<String, dynamic> profile, AppLocalizations l10n) {
    final raw = profile['name']?.toString() ?? '';
    if (raw.isEmpty) return l10n.t('sos.profileFallback');
    if (raw == 'My Profile') return l10n.t('sos.myProfile');
    if (raw == 'Profile') return l10n.t('sos.profileFallback');
    return raw;
  }

  Future<void> _loadProfiles() async {
    try {
      final linked = await ApiService.getLinkedProfiles();
      if (!mounted) return;
      _profiles
        ..clear()
        ..add({
          'id': widget.userData['id'] ?? widget.userData['_id'] ?? 'me',
          'name': widget.userData['name'] ?? 'My Profile',
        })
        ..addAll(linked.map((p) => {
              'id': p['id'] ?? p['_id'] ?? p['email'] ?? UniqueKey().toString(),
              'name': p['name'] ?? 'Profile',
            }));
      _selectedProfileId = _profiles.first['id'].toString();
      setState(() {});
      // Initialize with selected profile details
      await _applyProfileSelection(_selectedProfileId!);
    } catch (e) {
      // Best-effort; show only self profile if loading fails
      if (_profiles.isEmpty) {
        _profiles.add({
          'id': widget.userData['id'] ?? 'me',
          'name': widget.userData['name'] ?? 'My Profile',
        });
        _selectedProfileId = _profiles.first['id'].toString();
      }
      setState(() {});
      if (_selectedProfileId != null) {
        await _applyProfileSelection(_selectedProfileId!);
      }
    }
  }

  Future<void> _refreshCurrentUser() async {
    try {
      final profile = await ApiService.me();
      if (!mounted) return;
      if (profile is Map<String, dynamic>) {
        await OfflineStorageService.instance.cacheUserData(profile);
        await OfflineStorageService.instance
            .cacheEmergencyContactsFromUserData(profile);
        final cachedContacts =
            await OfflineStorageService.instance.getEmergencyContacts();
        final parsed = UserProfile.fromJson(profile);
        setState(() {
          _effectiveUserData = Map<String, dynamic>.from(profile);
          _offlineEmergencyContacts = cachedContacts;
          _currentUser = parsed;
          _allergies = _safeSensitiveText(parsed.allergies);
        });
      }
    } catch (_) {
      // Silent failure – keep whatever data is already cached
    }
  }

  Future<void> _seedEmergencyContactsIfMissing() async {
    try {
      final existing =
          await OfflineStorageService.instance.getEmergencyContacts();
      if (existing.isNotEmpty) return;
      await OfflineStorageService.instance
          .cacheEmergencyContactsFromUserData(widget.userData);
      await _loadOfflineEmergencyContacts();
    } catch (_) {
      // Ignore cache write failures.
    }
  }

  Future<void> _loadOfflineEmergencyContacts() async {
    try {
      final contacts =
          await OfflineStorageService.instance.getEmergencyContacts();
      if (!mounted) return;
      setState(() {
        _offlineEmergencyContacts = contacts;
      });
    } catch (_) {
      // Ignore cache read issues and keep UI usable.
    }
  }

  Future<void> _loadCachedLocation() async {
    try {
      final cached =
          await OfflineStorageService.instance.getLastKnownLocation();
      if (cached == null || !mounted) return;

      final lat = double.tryParse((cached['latitude'] ?? '').toString());
      final lon = double.tryParse((cached['longitude'] ?? '').toString());
      if (lat == null || lon == null) return;
      final accuracy =
          double.tryParse((cached['accuracyMeters'] ?? '').toString());
      final locationText = (cached['locationText'] ?? '').toString().trim();

      setState(() {
        _currentLatitude = lat;
        _currentLongitude = lon;
        _currentAccuracyMeters = accuracy;
        _locationController.text = locationText.isNotEmpty
            ? locationText
            : '${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}';
      });
    } catch (_) {
      // Ignore local cache read failures.
    }
  }

  Future<void> _applyProfileSelection(String id) async {
    try {
      // If it's current user
      final selfId =
          (widget.userData['id'] ?? widget.userData['_id'] ?? 'me').toString();
      if (id == selfId || id == 'me') {
        _nameController.text = (widget.userData['name'] ?? '').toString();
        final computed = _computeAgeFromDob(widget.userData['dateOfBirth']);
        _ageController.text = computed ?? '';
        _mobileController.text = (widget.userData['mobile'] ?? '').toString();
        final rawAllergies =
            _currentUser?.allergies ?? widget.userData['allergies'];
        _allergies = _safeSensitiveText(rawAllergies);
        setState(() {});
        return;
      }

      // Find basic profile name from list
      final dynamic match = _profiles.firstWhere(
        (p) => p['id'].toString() == id,
        orElse: () => <String, dynamic>{},
      );
      if (match is Map && match.isNotEmpty) {
        _nameController.text = (match['name'] ?? '').toString();
      }

      // Fetch full profile to get DOB
      final user = await ApiService.fetchUserPublicProfile(id);
      final dob = user?['dateOfBirth'] ?? user?['dob'] ?? user?['birthDate'];
      final computed = _computeAgeFromDob(dob);
      _ageController.text = computed ?? '';
      _mobileController.text = (user?['mobile'] ?? '').toString();
      final rawAllergies = user?['allergies'];
      _allergies = _safeSensitiveText(rawAllergies);
      setState(() {});
    } catch (_) {
      // On error, leave age empty so it can be entered manually
      _ageController.text = '';
      setState(() {});
    }
  }

  // Removed map view and share actions as per requirement; only coordinates are shown

  Future<void> _tryUpdateLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return; // silently ignore; user can enable later
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high)
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos != null) {
        final lat = pos.latitude;
        final lon = pos.longitude;
        final latStr = lat.toStringAsFixed(6);
        final lonStr = lon.toStringAsFixed(6);
        final accuracy = pos.accuracy;
        if (!mounted) return;
        setState(() {
          _currentLatitude = lat;
          _currentLongitude = lon;
          _currentAccuracyMeters = accuracy.isFinite ? accuracy : null;
          _locationController.text = '$latStr,$lonStr';
        });
        await OfflineStorageService.instance.cacheLastKnownLocation(
          latitude: lat,
          longitude: lon,
          accuracyMeters: accuracy.isFinite ? accuracy : null,
          locationText: '$latStr,$lonStr',
          capturedAt: DateTime.now(),
        );
      }
    } catch (_) {
      // ignore errors; keep empty
    }
  }

  Widget _buildAllergiesInfo(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final allergiesText = (_allergies?.trim().isNotEmpty ?? false)
        ? _allergies!.trim()
        : l10n.t('sos.allergiesNone');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('sos.allergiesTitle'),
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.4),
            ),
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.25)
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
          ),
          child: Text(
            allergiesText,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyContactsInfo(BuildContext context) {
    final theme = Theme.of(context);
    final hasContacts = _offlineEmergencyContacts.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency Contacts (Offline SMS/Call)',
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.4),
            ),
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.25)
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
          ),
          child: hasContacts
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _offlineEmergencyContacts.map((contact) {
                    final name = (contact['name'] ?? 'Emergency Contact')
                        .toString()
                        .trim();
                    final phone = (contact['phone'] ?? '').toString().trim();
                    final relationship =
                        (contact['relationship'] ?? '').toString().trim();
                    final subtitle = relationship.isNotEmpty
                        ? '$phone ($relationship)'
                        : phone;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• $name: $subtitle',
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }).toList(growable: false),
                )
              : Text(
                  'No emergency contacts found. Add contacts in profile settings to enable offline SMS/Call fallback.',
                  style: theme.textTheme.bodyMedium,
                ),
        ),
      ],
    );
  }

  Future<bool> _confirmSosCountdown() async {
    if (!mounted) return false;
    final remaining = ValueNotifier<int>(3);
    Timer? countdownTimer;
    var closed = false;

    void closeWith(bool value, BuildContext dialogContext) {
      if (closed) return;
      closed = true;
      countdownTimer?.cancel();
      remaining.dispose();
      Navigator.of(dialogContext).pop(value);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
          final next = remaining.value - 1;
          if (next <= 0) {
            closeWith(true, dialogContext);
          } else {
            remaining.value = next;
          }
        });

        return AlertDialog(
          title: const Text('Send emergency SOS?'),
          content: ValueListenableBuilder<int>(
            valueListenable: remaining,
            builder: (context, seconds, _) {
              return Text(
                'SOS will be sent automatically in $seconds seconds.',
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => closeWith(false, dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => closeWith(true, dialogContext),
              child: const Text('Send now'),
            ),
          ],
        );
      },
    );

    countdownTimer?.cancel();
    if (!closed) {
      remaining.dispose();
    }
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('sos.title')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.t('sos.selectProfile'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedProfileId,
                decoration: _inputDecoration(isDark),
                items: _profiles
                    .map((p) => DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text(_localizedProfileName(p, l10n)),
                        ))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _selectedProfileId = v);
                  await _applyProfileSelection(v);
                },
              ),
              const SizedBox(height: 16),
              Text(l10n.t('sos.fullName'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration(isDark),
              ),
              const SizedBox(height: 16),
              Text(l10n.t('sos.mobileNumber'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(isDark)
                    .copyWith(hintText: l10n.t('sos.mobileHint')),
              ),
              const SizedBox(height: 16),
              Text(l10n.t('sos.age'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(isDark),
              ),
              const SizedBox(height: 16),
              Text(l10n.t('sos.currentLocation'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                readOnly: true,
                decoration: _inputDecoration(isDark).copyWith(
                  hintText: l10n.t('sos.locationHint'),
                  suffixIcon: IconButton(
                    onPressed: _tryUpdateLocation,
                    tooltip: l10n.t('sos.getLocation'),
                    icon: const Icon(Icons.gps_fixed),
                  ),
                ),
              ),
              if (_currentAccuracyMeters != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.format('sos.accuracyLabel', {
                      'meters': _currentAccuracyMeters!.toStringAsFixed(0),
                    }),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ),
              const SizedBox(height: 16),
              _buildAllergiesInfo(context),
              const SizedBox(height: 16),
              _buildEmergencyContactsInfo(context),
              const SizedBox(height: 16),
              Text(l10n.t('sos.currentTime'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _timeController,
                readOnly: true,
                decoration: _inputDecoration(isDark),
              ),
              const SizedBox(height: 16),
              Text(l10n.t('sos.notesTitle'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: _inputDecoration(isDark).copyWith(
                  hintText: l10n.t('sos.notesHint'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF20D0D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSending
                      ? null
                      : () async {
                          final confirmed = await _confirmSosCountdown();
                          if (!confirmed || !context.mounted) return;

                          setState(() {
                            _isSending = true;
                            _sosStatusMessage = 'Sending SOS...';
                          });

                          await _tryUpdateLocation();

                          final cachedLocation = await OfflineStorageService
                              .instance
                              .getLastKnownLocation();
                          final effectiveLat = _currentLatitude ??
                              double.tryParse(
                                (cachedLocation?['latitude'] ?? '').toString(),
                              );
                          final effectiveLon = _currentLongitude ??
                              double.tryParse(
                                (cachedLocation?['longitude'] ?? '').toString(),
                              );
                          final effectiveAccuracy = _currentAccuracyMeters ??
                              double.tryParse(
                                (cachedLocation?['accuracyMeters'] ?? '')
                                    .toString(),
                              );
                          final cachedLocationText =
                              (cachedLocation?['locationText'] ?? '')
                                  .toString()
                                  .trim();

                          if (!context.mounted) return;

                          final notes = _notesController.text.trim();
                          final result =
                              await SosOfflineService.instance.sendSos(
                            latitude: effectiveLat,
                            longitude: effectiveLon,
                            userData: _effectiveUserData,
                            accuracyMeters: effectiveAccuracy,
                            notes: notes.isEmpty ? null : notes,
                            allergies: (_allergies?.trim().isNotEmpty ?? false)
                                ? _allergies
                                : null,
                            name: _nameController.text.trim().isNotEmpty
                                ? _nameController.text.trim()
                                : null,
                            mobile: _mobileController.text.trim().isNotEmpty
                                ? _mobileController.text.trim()
                                : null,
                            age: _ageController.text.trim().isNotEmpty
                                ? _ageController.text.trim()
                                : null,
                            locationText:
                                _locationController.text.trim().isNotEmpty
                                    ? _locationController.text.trim()
                                    : (cachedLocationText.isNotEmpty
                                        ? cachedLocationText
                                        : null),
                            profileId: _selectedProfileId,
                          );

                          if (!context.mounted) return;

                          setState(() {
                            _isSending = false;
                            _sosStatusMessage = result.message;
                          });

                          if (result.success) {
                            String message;
                            final backend = result.backendResponse;
                            final bool massTriggered =
                                backend?['massIncidentTriggered'] == true;
                            if (result.openedSmsComposer ||
                                result.usedOfflineFallback) {
                              message = result.message;
                            } else {
                              message = massTriggered
                                  ? l10n.t('sos.sendSuccessMass')
                                  : l10n.t('sos.sendSuccess');
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          } else {
                            final error = result.message.isNotEmpty
                                ? result.message
                                : l10n.t('sos.sendFailed');
                            final snackBar = SnackBar(
                              content: Text(error),
                              action: result.smsPermissionPermanentlyDenied
                                  ? SnackBarAction(
                                      label: 'Settings',
                                      onPressed: openAppSettings,
                                    )
                                  : null,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              snackBar,
                            );
                          }
                        },
                  child: _isSending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          l10n.t('sos.sendButton'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              if (_sosStatusMessage != null &&
                  _sosStatusMessage!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _sosStatusMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
