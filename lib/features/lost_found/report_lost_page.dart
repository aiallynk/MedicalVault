import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../api_service.dart';
import '../../localization/app_localizations.dart';

enum _LostReportTarget { profile, other }

enum _PhotoSelection { vaultProfile, upload }

class ReportLostPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<Map<String, dynamic>> linkedProfiles;

  const ReportLostPage({
    super.key,
    required this.currentUser,
    required this.linkedProfiles,
  });

  @override
  State<ReportLostPage> createState() => _ReportLostPageState();
}

class _ReportLostPageState extends State<ReportLostPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _medicalNotesController = TextEditingController();
  final _ageController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  _LostReportTarget _target = _LostReportTarget.profile;
  _PhotoSelection _photoSelection = _PhotoSelection.vaultProfile;

  List<Map<String, dynamic>> _profileOptions = [];
  String? _selectedProfileId;
  String _selectedGender = "Unknown";
  DateTime _lastSeenTime = DateTime.now();
  Position? _lastSeenPosition;

  bool _isUploadingPhoto = false;
  bool _isSubmitting = false;

  String? _uploadedPhotoUrl;
  String? _uploadedPhotoName;

  @override
  void initState() {
    super.initState();
    _initialiseProfile();
  }

  void _initialiseProfile() {
    final options = _buildProfileOptions();
    if (options.isEmpty) {
      _profileOptions = options;
      _selectedProfileId = null;
      _target = _LostReportTarget.other;
      _photoSelection = _PhotoSelection.upload;
      return;
    }

    final first = options.first;
    _profileOptions = options;
    _selectedProfileId = _profileIdentifier(first);
    if (first['name'] != null && first['name'].toString().trim().isNotEmpty) {
      _nameController.text = first['name'].toString().trim();
    }
  }

  List<Map<String, dynamic>> _buildProfileOptions() {
    final List<Map<String, dynamic>> all = [];
    if (widget.currentUser.isNotEmpty) {
      all.add(Map<String, dynamic>.from(widget.currentUser));
    }
    all.addAll(widget.linkedProfiles.map((p) => Map<String, dynamic>.from(p)));
    return all;
  }

  Map<String, dynamic>? get _selectedProfile {
    if (_selectedProfileId == null) return null;
    try {
      return _profileOptions
          .firstWhere((p) => _profileIdentifier(p) == _selectedProfileId);
    } catch (_) {
      return null;
    }
  }

  String _localizedProfileName(
      Map<String, dynamic> profile, AppLocalizations l10n) {
    final raw = profile['name']?.toString() ?? '';
    if (raw.isEmpty) return l10n.t('sos.profileFallback');
    if (raw == 'My Profile') return l10n.t('sos.myProfile');
    if (raw == 'Profile') return l10n.t('sos.profileFallback');
    return raw;
  }

  String? _profileIdentifier(Map<String, dynamic> profile) {
    final preferredKeys = ['id', '_id', 'userId', 'profileId'];
    for (final key in preferredKeys) {
      final value = profile[key];
      if (value != null) {
        return value.toString();
      }
    }
    return profile.hashCode.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _medicalNotesController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final current = _lastSeenTime;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 14)),
      lastDate: DateTime.now(),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;

    setState(() {
      _lastSeenTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _useCurrentLocation() async {
    final l10n = context.l10n;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showMessage(
          l10n.t('sos.locationServicesDisabled'),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage(l10n.t('sos.locationPermissionDenied'));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          l10n.t('sos.locationPermissionForever'),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _lastSeenPosition = position);
    } catch (error) {
      _showMessage(l10n.format('sos.locationError', {'error': '$error'}));
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final l10n = context.l10n;
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;

      setState(() {
        _isUploadingPhoto = true;
      });

      final file = File(picked.path);
      final uploadedUrl = await ApiService.uploadLostFoundPhoto(file);
      if (!mounted) return;

      if (uploadedUrl == null) {
        setState(() {
          _isUploadingPhoto = false;
        });
        _showMessage(l10n.t('sos.photoUploadFailed'));
        return;
      }

      setState(() {
        _uploadedPhotoUrl = uploadedUrl;
        _uploadedPhotoName = picked.name;
        _isUploadingPhoto = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      _showMessage(
          l10n.format('sos.photoSelectionFailed', {'error': '$error'}));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (_target == _LostReportTarget.profile && _selectedProfile == null) {
      _showMessage(l10n.t('lostReport.profileRequired'));
      return;
    }

    if (_photoSelection == _PhotoSelection.vaultProfile) {
      final profilePhoto =
          _selectedProfile?['profilePicture']?.toString().trim();
      if (profilePhoto == null || profilePhoto.isEmpty) {
        _showMessage(
          l10n.t('lostReport.profileNeedsPhoto'),
        );
        return;
      }
    } else {
      if (_uploadedPhotoUrl == null) {
        _showMessage(l10n.t('lostReport.photoRequired'));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final double? lat = _lastSeenPosition?.latitude;
    final double? lng = _lastSeenPosition?.longitude;

    final payload = {
      "lostPersonUserId": _target == _LostReportTarget.profile
          ? (_selectedProfile?['id'] ??
              _selectedProfile?['_id'] ??
              _selectedProfile?['userId'])
          : null,
      "photoSource": _photoSelection == _PhotoSelection.vaultProfile
          ? "vault_profile"
          : "uploaded_family",
      "photoUrl":
          _photoSelection == _PhotoSelection.upload ? _uploadedPhotoUrl : null,
      "personName": _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      "approxAge": _ageController.text.trim().isEmpty
          ? null
          : int.tryParse(_ageController.text.trim()),
      "gender": _selectedGender,
      "description": _descriptionController.text.trim(),
      "lastSeenLat": lat,
      "lastSeenLng": lng,
      "lastSeenTime": _lastSeenTime.toUtc().toIso8601String(),
      "medicalNotes": _medicalNotesController.text.trim().isEmpty
          ? null
          : _medicalNotesController.text.trim(),
    };

    try {
      final response = await ApiService.createLostPersonReport(payload);
      if (!mounted) return;

      if (response["success"] == true) {
        _showMessage(l10n.t('lostReport.submitSuccess'));
        Navigator.of(context).pop(true);
      } else {
        _showMessage(
          response["message"]?.toString() ??
              l10n.t('lostReport.submitFailure'),
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        l10n.format('lostReport.submitError', {'error': '$error'}),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildProfileSelector() {
    final l10n = context.l10n;
    if (_target != _LostReportTarget.profile) return const SizedBox.shrink();

    if (_profileOptions.isEmpty) {
      return Text(l10n.t('lostReport.noProfiles'));
    }

    return DropdownButtonFormField<String>(
      value: _selectedProfileId,
      decoration: InputDecoration(
        labelText: l10n.t('lostReport.selectProfileLabel'),
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _selectedProfileId = value;
          final selected = _selectedProfile;
          if (selected != null &&
              (selected['name']?.toString().trim().isNotEmpty ?? false)) {
            _nameController.text =
                _localizedProfileName(selected, l10n);
          }
        });
      },
      items: _profileOptions
          .map((profile) {
            final id = _profileIdentifier(profile);
            if (id == null) return null;
            final name = _localizedProfileName(profile, l10n);
            return DropdownMenuItem<String>(
              value: id,
              child: Text(name),
            );
          })
          .whereType<DropdownMenuItem<String>>()
          .toList(),
    );
  }

  Widget _buildPhotoSection() {
    final l10n = context.l10n;
    final profilePhoto = _selectedProfile?['profilePicture']?.toString().trim();
    final showVaultOption = _target == _LostReportTarget.profile &&
        (profilePhoto?.isNotEmpty ?? false);

    final List<Widget> radios = [];
    if (showVaultOption) {
      radios.add(
        RadioListTile<_PhotoSelection>(
          value: _PhotoSelection.vaultProfile,
          groupValue: _photoSelection,
          onChanged: (value) {
            if (value != null) {
              setState(() => _photoSelection = value);
            }
          },
          title: Text(l10n.t('lostReport.photoUseProfile')),
          subtitle: profilePhoto != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(profilePhoto),
                  ),
                )
              : null,
        ),
      );
    }

    radios.add(
      RadioListTile<_PhotoSelection>(
        value: _PhotoSelection.upload,
        groupValue: _photoSelection,
        onChanged: (value) {
          if (value != null) {
            setState(() => _photoSelection = value);
          }
        },
        title: Text(l10n.t('lostReport.photoUploadOption')),
        subtitle: _buildUploadedPhotoPreview(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('lostReport.photoSectionTitle'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...radios,
        if (_photoSelection == _PhotoSelection.upload)
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isUploadingPhoto
                    ? null
                    : () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: Text(l10n.t('lostReport.photoCamera')),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isUploadingPhoto
                    ? null
                    : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: Text(l10n.t('lostReport.photoGallery')),
              ),
              if (_isUploadingPhoto) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildUploadedPhotoPreview() {
    final l10n = context.l10n;
    if (_uploadedPhotoUrl == null) {
      return Text(l10n.t('lostReport.noPhoto'));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _uploadedPhotoUrl!,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _uploadedPhotoName ?? l10n.t('lostReport.uploadedPhotoName'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLocation(Position? position) {
    if (position == null) return context.l10n.t('common.locationNotSet');
    return "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat("MMM d, yyyy • h:mm a");
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('lostReport.title')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('lostReport.who'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                RadioListTile<_LostReportTarget>(
                  value: _LostReportTarget.profile,
                  groupValue: _target,
                  onChanged: (value) {
                    if (value == null) return;
                    if (_profileOptions.isEmpty) {
                      _showMessage(l10n.t('lostReport.noProfiles'));
                      return;
                    }
                    setState(() {
                      _target = value;
                      if (_selectedProfileId == null &&
                          _profileOptions.isNotEmpty) {
                        final first = _profileOptions.first;
                        _selectedProfileId = _profileIdentifier(first);
                        if (first['name'] != null &&
                            first['name'].toString().trim().isNotEmpty) {
                          _nameController.text =
                              first['name'].toString().trim();
                        }
                      }
                      if (_photoSelection == _PhotoSelection.upload &&
                          (_selectedProfile?['profilePicture'] != null)) {
                        _photoSelection = _PhotoSelection.vaultProfile;
                      }
                    });
                  },
                  title: Text(l10n.t('lostReport.optionProfile')),
                ),
                RadioListTile<_LostReportTarget>(
                  value: _LostReportTarget.other,
                  groupValue: _target,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _target = value;
                      _photoSelection = _PhotoSelection.upload;
                    });
                  },
                  title: Text(l10n.t('lostReport.optionOther')),
                ),
                const SizedBox(height: 12),
                _buildProfileSelector(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.t('lostReport.nameLabel'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('lostReport.ageLabel'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final number = int.tryParse(value.trim());
                    if (number == null || number <= 0) {
                      return l10n.t('lostReport.ageValidation');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: InputDecoration(
                    labelText: l10n.t('lostReport.genderLabel'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedGender = value);
                    }
                  },
                  items: [
                    DropdownMenuItem(
                        value: "Male",
                        child: Text(l10n.t('lostReport.genderMale'))),
                    DropdownMenuItem(
                        value: "Female",
                        child: Text(l10n.t('lostReport.genderFemale'))),
                    DropdownMenuItem(
                        value: "Other",
                        child: Text(l10n.t('lostReport.genderOther'))),
                    DropdownMenuItem(
                        value: "Unknown",
                        child: Text(l10n.t('lostReport.genderUnknown'))),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.t('lostReport.descriptionLabel'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.t('lostReport.descriptionValidation');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _medicalNotesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.t('lostReport.medicalNotesLabel'),
                    hintText: l10n.t('lostReport.medicalNotesHint'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                _buildPhotoSection(),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.t('lostReport.lastSeenTime')),
                  subtitle: Text(formatter.format(_lastSeenTime)),
                  trailing: TextButton(
                    onPressed: _pickDateTime,
                    child: Text(l10n.t('lostReport.edit')),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.t('lostReport.lastSeenLocation')),
                  subtitle: Text(_formatLocation(_lastSeenPosition)),
                  trailing: ElevatedButton.icon(
                    onPressed: _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: Text(l10n.t('lostReport.useCurrent')),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(l10n.t('lostReport.submit')),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.t('lostReport.info'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
