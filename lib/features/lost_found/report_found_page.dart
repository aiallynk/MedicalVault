import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../api_service.dart';
import '../../localization/app_localizations.dart';
import '../../utils/timezone_utils.dart';
import 'location_picker_page.dart';

class ReportFoundPage extends StatefulWidget {
  const ReportFoundPage({super.key});

  @override
  State<ReportFoundPage> createState() => _ReportFoundPageState();
}

class _ReportFoundPageState extends State<ReportFoundPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _ageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _conditionController = TextEditingController();
  final _hospitalController = TextEditingController();

  Timer? _nameDebounce;
  List<String> _nameSuggestions = const <String>[];
  bool _loadingNameSuggestions = false;

  final ImagePicker _picker = ImagePicker();

  String _selectedGender = "Unknown";
  DateTime _foundTime = DateTime.now();
  Position? _currentLocation;
  String? _currentLocationAddress;

  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;

  String? _photoUrl;
  String? _photoName;

  @override
  void initState() {
    super.initState();
    _foundTime = nowForContextTimeZone(context);
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    _conditionController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _nameDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      if (_nameSuggestions.isNotEmpty || _loadingNameSuggestions) {
        setState(() {
          _nameSuggestions = const <String>[];
          _loadingNameSuggestions = false;
        });
      }
      return;
    }
    setState(() => _loadingNameSuggestions = true);
    // Debounce so we only query once typing settles.
    _nameDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results =
          await ApiService.searchLostPersonNameSuggestions(query);
      if (!mounted) return;
      // Hide the list if the field already exactly matches a suggestion.
      final current = _nameController.text.trim().toLowerCase();
      final filtered = results
          .where((name) => name.toLowerCase() != current)
          .toList(growable: false);
      setState(() {
        _nameSuggestions = filtered;
        _loadingNameSuggestions = false;
      });
    });
  }

  void _selectNameSuggestion(String name) {
    _nameDebounce?.cancel();
    _nameController
      ..text = name
      ..selection = TextSelection.collapsed(offset: name.length);
    setState(() {
      _nameSuggestions = const <String>[];
      _loadingNameSuggestions = false;
    });
    _nameFocusNode.unfocus();
  }

  Future<void> _pickDateTime() async {
    final l10n = context.l10n;
    final now = nowForContextTimeZone(context);
    final date = await showDatePicker(
      context: context,
      initialDate: _foundTime,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now,
      helpText: l10n.t('reportFound.datePicker.help'),
      cancelText: l10n.t('reportFound.datePicker.cancel'),
      confirmText: l10n.t('reportFound.datePicker.confirm'),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_foundTime),
    );
    if (time == null) return;

    setState(() {
      _foundTime = DateTime(
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
        _showMessage(l10n.t('reportFound.locationEnable'));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage(l10n.t('reportFound.locationPermissionDenied'));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(l10n.t('reportFound.locationPermissionForever'));
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentLocation = position);
      await _updateLocationAddress(position.latitude, position.longitude);
    } catch (error) {
      _showMessage(
          l10n.format('reportFound.locationError', {'error': '$error'}));
    }
  }

  Future<void> _showMapPicker() async {
    final picked = await Navigator.of(context).push<LostFoundPickedLocation>(
      MaterialPageRoute(
        builder: (_) => LostFoundLocationPickerPage(
          title: context.l10n.t('reportFound.currentLocation'),
          initialLatitude: _currentLocation?.latitude,
          initialLongitude: _currentLocation?.longitude,
          initialAddress: _currentLocationAddress,
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _currentLocation = _positionFromCoordinates(
        picked.latitude,
        picked.longitude,
      );
      _currentLocationAddress = picked.address?.trim().isNotEmpty == true
          ? picked.address!.trim()
          : null;
    });
    if (_currentLocationAddress == null) {
      await _updateLocationAddress(picked.latitude, picked.longitude);
    }
  }

  Position _positionFromCoordinates(double lat, double lng) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  Future<void> _updateLocationAddress(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (!mounted || placemarks.isEmpty) return;
      final place = placemarks.first;
      final address = [
        place.street,
        place.locality,
        place.administrativeArea,
        place.country,
      ].where((entry) => entry != null && entry.trim().isNotEmpty).join(', ');
      setState(() {
        _currentLocationAddress =
            address.trim().isEmpty ? null : address.trim();
      });
    } catch (_) {
      // Address is helpful but not required for matching or dispatch.
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
        setState(() => _isUploadingPhoto = false);
        _showMessage(l10n.t('reportFound.photoUploadFailed'));
        return;
      }

      setState(() {
        _photoUrl = uploadedUrl;
        _photoName = picked.name;
        _isUploadingPhoto = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      _showMessage(
          l10n.format('reportFound.photoSelectFailed', {'error': '$error'}));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final normalized = message.replaceFirst('Exception: ', '').trim();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(normalized.isEmpty ? message : normalized)));
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_photoUrl == null) {
      _showMessage(l10n.t('reportFound.photoRequired'));
      return;
    }
    if (_currentLocation == null) {
      _showMessage(l10n.t('reportFound.locationRequired'));
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      "personName": _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      "approxAge": _ageController.text.trim().isEmpty
          ? null
          : int.tryParse(_ageController.text.trim()),
      "gender": _selectedGender,
      "description": _descriptionController.text.trim(),
      "condition": _conditionController.text.trim().isEmpty
          ? null
          : _conditionController.text.trim(),
      "currentLat": _currentLocation?.latitude,
      "currentLng": _currentLocation?.longitude,
      "foundTime": _foundTime.toUtc().toIso8601String(),
      "currentHospitalId": _hospitalController.text.trim().isEmpty
          ? null
          : _hospitalController.text.trim(),
      "photoUrl": _photoUrl,
    };

    try {
      final response = await ApiService.createFoundPersonReport(payload);
      if (!mounted) return;

      if (response["success"] == true) {
        _showMessage(l10n.t('reportFound.submitSuccess'));
        Navigator.of(context).pop(true);
      } else {
        _showMessage(response["message"]?.toString() ??
            l10n.t('reportFound.submitFailure'));
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        l10n.format('reportFound.submitError', {'error': '$error'}),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatLocation(Position? position) {
    if (position == null) {
      return context.l10n.t('reportFound.locationNotCaptured');
    }
    final coords =
        "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
    if (_currentLocationAddress?.trim().isNotEmpty == true) {
      return "$coords\n${_currentLocationAddress!.trim()}";
    }
    return coords;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('reportFound.title')),
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
                  l10n.t('reportFound.help'),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  textCapitalization: TextCapitalization.words,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    labelText: l10n.t('reportFound.nameLabel'),
                    hintText: l10n.t('reportFound.nameHint'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.badge_outlined),
                    suffixIcon: _loadingNameSuggestions
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_nameController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: l10n.t('common.cancel'),
                                onPressed: () {
                                  _nameController.clear();
                                  _onNameChanged('');
                                },
                              )
                            : null),
                  ),
                ),
                if (_nameSuggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Material(
                      elevation: 1,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 8, 12, 4),
                              child: Text(
                                l10n.t('reportFound.nameSuggestionsTitle'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            ..._nameSuggestions.take(6).map(
                                  (name) => InkWell(
                                    onTap: () => _selectNameSuggestion(name),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.north_west,
                                              size: 16),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('reportFound.ageLabel'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final number = int.tryParse(value.trim());
                    if (number == null || number <= 0) {
                      return l10n.t('reportFound.ageValidation');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: InputDecoration(
                    labelText: l10n.t('reportFound.genderLabel'),
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
                        child: Text(l10n.t('reportFound.genderMale'))),
                    DropdownMenuItem(
                        value: "Female",
                        child: Text(l10n.t('reportFound.genderFemale'))),
                    DropdownMenuItem(
                        value: "Other",
                        child: Text(l10n.t('reportFound.genderOther'))),
                    DropdownMenuItem(
                        value: "Unknown",
                        child: Text(l10n.t('reportFound.genderUnknown'))),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.t('reportFound.descriptionLabel'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.t('reportFound.descriptionValidation');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _conditionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.t('reportFound.conditionLabel'),
                    hintText: l10n.t('reportFound.conditionHint'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hospitalController,
                  decoration: InputDecoration(
                    labelText: l10n.t('reportFound.hospitalLabel'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.t('reportFound.photoTitle'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_photoUrl != null)
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _photoUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _photoName ?? l10n.t('reportFound.photoUploadedName'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  Text(l10n.t('reportFound.photoPrompt')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isUploadingPhoto
                          ? null
                          : () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: Text(l10n.t('reportFound.camera')),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isUploadingPhoto
                          ? null
                          : () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: Text(l10n.t('reportFound.gallery')),
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
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.t('reportFound.foundTime')),
                  subtitle: Text(formatDateTimeForContext(context, _foundTime,
                      pattern: 'MMM d, yyyy - h:mm a')),
                  trailing: TextButton(
                    onPressed: _pickDateTime,
                    child: Text(l10n.t('reportFound.edit')),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('reportFound.currentLocation'),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(_formatLocation(_currentLocation)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _useCurrentLocation,
                              icon: const Icon(Icons.my_location),
                              label: Text(l10n.t('reportFound.useCurrent')),
                            ),
                            OutlinedButton.icon(
                              onPressed: _showMapPicker,
                              icon: const Icon(Icons.map_rounded),
                              label: Text(l10n.t('lostReport.pickOnMap')),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                        : Text(l10n.t('reportFound.submit')),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.t('reportFound.thankYou'),
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
