import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../api_service.dart';

class ReportFoundPage extends StatefulWidget {
  const ReportFoundPage({super.key});

  @override
  State<ReportFoundPage> createState() => _ReportFoundPageState();
}

class _ReportFoundPageState extends State<ReportFoundPage> {
  final _formKey = GlobalKey<FormState>();

  final _ageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _conditionController = TextEditingController();
  final _hospitalController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  String _selectedGender = "Unknown";
  DateTime _foundTime = DateTime.now();
  Position? _currentLocation;

  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;

  String? _photoUrl;
  String? _photoName;

  @override
  void dispose() {
    _ageController.dispose();
    _descriptionController.dispose();
    _conditionController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _foundTime,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
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
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showMessage("Enable location services to capture current location.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage("Location permission denied.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          "Location permission permanently denied. Please enable from settings.",
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentLocation = position);
    } catch (error) {
      _showMessage("Failed to access location: $error");
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
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
        _showMessage("Photo upload failed. Please try again.");
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
      _showMessage("Unable to select photo: $error");
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_photoUrl == null) {
      _showMessage("A clear photo is required to help families match.");
      return;
    }
    if (_currentLocation == null) {
      _showMessage(
          "Please capture current location so teams can reach the facility.");
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
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
        _showMessage(
            "Found person report submitted. Matching engine will review.");
        Navigator.of(context).pop(true);
      } else {
        _showMessage(response["message"]?.toString() ??
            "Failed to submit found person report.");
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage("Unexpected error: $error");
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatLocation(Position? position) {
    if (position == null) return "Location not captured";
    return "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat("MMM d, yyyy • h:mm a");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Found Person"),
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
                  "Provide details to help families identify their loved one.",
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Approximate Age",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final number = int.tryParse(value.trim());
                    if (number == null || number <= 0) {
                      return "Enter a valid age";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: "Gender",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedGender = value);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: "Male", child: Text("Male")),
                    DropdownMenuItem(value: "Female", child: Text("Female")),
                    DropdownMenuItem(value: "Other", child: Text("Other")),
                    DropdownMenuItem(value: "Unknown", child: Text("Unknown")),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText:
                        "Description (clothing, distinguishing marks, accessories)",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please describe the person that was found.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _conditionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Current condition (optional)",
                    hintText: "Conscious, disoriented, unconscious, etc.",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hospitalController,
                  decoration: const InputDecoration(
                    labelText: "Current hospital / camp (optional)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Photo",
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
                          _photoName ?? "Uploaded photo",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                      "Upload a clear photo so families can confirm quickly."),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isUploadingPhoto
                          ? null
                          : () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Camera"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isUploadingPhoto
                          ? null
                          : () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Gallery"),
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
                  title: const Text("Found time"),
                  subtitle: Text(formatter.format(_foundTime)),
                  trailing: TextButton(
                    onPressed: _pickDateTime,
                    child: const Text("Edit"),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Current location"),
                  subtitle: Text(_formatLocation(_currentLocation)),
                  trailing: ElevatedButton.icon(
                    onPressed: _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text("Use current"),
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
                        : const Text("Submit Found Report"),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Suggested matches will appear for admins. Thank you for helping reconnect families.",
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

