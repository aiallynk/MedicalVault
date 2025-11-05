import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hello/api_service.dart';

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
  Timer? _timer;

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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _timeController.text = _formatNow();
      setState(() {});
    });
    _loadProfiles();
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
        final lat = pos.latitude.toStringAsFixed(6);
        final lon = pos.longitude.toStringAsFixed(6);
        _locationController.text = '$lat,$lon';
        if (mounted) setState(() {});
      }
    } catch (_) {
      // ignore errors; keep empty
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Profile',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedProfileId,
                decoration: _inputDecoration(isDark),
                items: _profiles
                    .map((p) => DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text(p['name'].toString()),
                        ))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _selectedProfileId = v);
                  await _applyProfileSelection(v);
                },
              ),
              const SizedBox(height: 16),
              Text('Full Name',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration(isDark),
              ),
              const SizedBox(height: 16),
              Text('Mobile Number',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(isDark)
                    .copyWith(hintText: 'Mobile (auto-filled if available)'),
              ),
              const SizedBox(height: 16),
              Text('Age',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(isDark),
              ),
              const SizedBox(height: 16),
              Text('Current Location',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                readOnly: true,
                decoration: _inputDecoration(isDark).copyWith(
                  hintText: 'Location (empty)',
                  suffixIcon: IconButton(
                    onPressed: _tryUpdateLocation,
                    tooltip: 'Get location',
                    icon: const Icon(Icons.gps_fixed),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Current Time',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _timeController,
                readOnly: true,
                decoration: _inputDecoration(isDark),
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
                  onPressed: () async {
                    final ok = await ApiService.createSos(
                      profileId: _selectedProfileId,
                      name: _nameController.text.trim(),
                      age: _ageController.text.trim().isEmpty
                          ? ''
                          : _ageController.text.trim(),
                      location: _locationController.text.trim(),
                      mobile: _mobileController.text.trim(),
                    );
                    if (!mounted) return;
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SOS sent')),
                      );
                      // Return to Dashboard after successful SOS
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to send SOS')),
                      );
                    }
                  },
                  child: const Text(
                    'Send SOS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
