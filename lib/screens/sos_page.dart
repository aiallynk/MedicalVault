import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hello/api_service.dart';
import 'package:hello/models/user_profile.dart';
import 'package:hello/localization/app_localizations.dart';

class SosPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SosPage({super.key, required this.userData});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  final List<Map<String, dynamic>> _profiles = [];
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
  UserProfile? _currentUser;
  String? _allergies;

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
    _currentUser = UserProfile.fromJson(widget.userData);
    _allergies = _currentUser?.allergies;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _timeController.text = _formatNow();
      setState(() {});
    });
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
    final two = (int n) => n.toString().padLeft(2, '0');
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

  String _localizedProfileName(Map<String, dynamic> profile,
      AppLocalizations l10n) {
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
        final parsed = UserProfile.fromJson(profile);
        setState(() {
          _currentUser = parsed;
          _allergies = parsed.allergies;
        });
      }
    } catch (_) {
      // Silent failure – keep whatever data is already cached
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
        _allergies = rawAllergies == null ? null : rawAllergies.toString();
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
      _allergies = rawAllergies == null ? null : rawAllergies.toString();
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
          _currentAccuracyMeters =
              accuracy.isFinite ? accuracy : null;
          _locationController.text = '$latStr,$lonStr';
        });
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.4),
            ),
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceVariant.withOpacity(0.25)
                : theme.colorScheme.surfaceVariant.withOpacity(0.6),
          ),
          child: Text(
            allergiesText,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
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
                      'meters': _currentAccuracyMeters!
                          .toStringAsFixed(0),
                    }),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ),
              const SizedBox(height: 16),
              _buildAllergiesInfo(context),
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
                          final lat = _currentLatitude;
                          final lon = _currentLongitude;

                          if (lat == null || lon == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.t('sos.locationMissing'),
                                ),
                              ),
                            );
                            await _tryUpdateLocation();
                            return;
                          }

                          setState(() => _isSending = true);
                          final notes = _notesController.text.trim();
                          final response = await ApiService.createSos(
                            latitude: lat,
                            longitude: lon,
                            accuracyMeters: _currentAccuracyMeters,
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
                                    : null,
                            profileId: _selectedProfileId,
                          );

                          if (!mounted) {
                            return;
                          }

                          setState(() => _isSending = false);

                          if (response != null && response['success'] == true) {
                            final bool massTriggered =
                                response['massIncidentTriggered'] == true;
                            final message = massTriggered
                                ? l10n.t('sos.sendSuccessMass')
                                : l10n.t('sos.sendSuccess');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                            Navigator.of(context).pop();
                          } else {
                            final error =
                                response?['message']?.toString() ??
                                    l10n.t('sos.sendFailed');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
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
