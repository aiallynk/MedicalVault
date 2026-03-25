import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import '../Document_model.dart';
import '../api_service.dart';
import '../localization/app_localizations.dart';
import '../services/secure_token_storage.dart';

class ProfileName extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileName({super.key, required this.userData});

  @override
  State<ProfileName> createState() => _ProfileNameState();
}

class _ProfileNameState extends State<ProfileName> {
  late Map<String, dynamic> user;
  bool _loading = true;
  Map<String, List<dynamic>> medicalRecords = {
    "reports": [],
    "prescriptions": [],
    "bills": [],
    "insurance": [],
  };
  final ImagePicker _imagePicker = ImagePicker();
  File? _pendingProfileImage;
  bool _isUploadingProfileImage = false;
  bool _hasImageError = false;

  String _sanitizeSensitiveValue(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '';
    if (raw.toLowerCase().startsWith('enc:v')) return '';
    return raw;
  }

  Map<String, dynamic> _sanitizeUserPayload(Map<String, dynamic> incoming) {
    final sanitized = Map<String, dynamic>.from(incoming);

    final incomingAadhaar = _sanitizeSensitiveValue(sanitized['aadhaar']);
    final previousAadhaar = _sanitizeSensitiveValue(user['aadhaar']);
    sanitized['aadhaar'] =
        incomingAadhaar.isNotEmpty ? incomingAadhaar : previousAadhaar;

    final incomingAllergies = _sanitizeSensitiveValue(sanitized['allergies']);
    final previousAllergies = _sanitizeSensitiveValue(user['allergies']);
    sanitized['allergies'] =
        incomingAllergies.isNotEmpty ? incomingAllergies : previousAllergies;

    final incomingEmergency = sanitized['emergencyContact'];
    final incomingEmergencyMap = incomingEmergency is Map
        ? incomingEmergency.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    final previousEmergency = user['emergencyContact'];
    final previousEmergencyMap = previousEmergency is Map
        ? previousEmergency.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final mergedEmergency = <String, dynamic>{
      ...incomingEmergencyMap,
      'name': _sanitizeSensitiveValue(incomingEmergencyMap['name']).isNotEmpty
          ? _sanitizeSensitiveValue(incomingEmergencyMap['name'])
          : _sanitizeSensitiveValue(previousEmergencyMap['name']),
      'relationship':
          _sanitizeSensitiveValue(incomingEmergencyMap['relationship'])
                  .isNotEmpty
              ? _sanitizeSensitiveValue(incomingEmergencyMap['relationship'])
              : _sanitizeSensitiveValue(previousEmergencyMap['relationship']),
      'phone': _sanitizeSensitiveValue(incomingEmergencyMap['phone']).isNotEmpty
          ? _sanitizeSensitiveValue(incomingEmergencyMap['phone'])
          : _sanitizeSensitiveValue(previousEmergencyMap['phone']),
    };
    sanitized['emergencyContact'] = mergedEmergency;

    return sanitized;
  }

  @override
  void initState() {
    super.initState();
    user = widget.userData;
    _fetchProfile();
    _fetchMedicalRecords();
  }

  Future<void> _fetchProfile() async {
    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final response = await http.get(
        Uri.parse("${ApiService.authUrl}/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final rawUser = body["data"]?["user"];
        final userMap = rawUser is Map
            ? rawUser.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};
        final sanitizedUser = _sanitizeUserPayload(userMap);
        if (!mounted) return;
        setState(() {
          user = sanitizedUser;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (e) {
      print("❌ Fetch error: $e");
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchMedicalRecords() async {
    try {
      final email = user['email'];
      if (email == null) {
        print("❌ No email found in user data");
        return;
      }

      print("🔍 Fetching medical records for email: $email");

      // ✅ Use the new API service method
      final response = await ApiService.fetchGroupedDocsByEmail(email);

      print("📋 API Response: $response");

      if (response != null && response['success'] == true) {
        final records = response['records'];
        print("📁 Records structure: $records");

        if (records != null) {
          if (!mounted) return;
          setState(() {
            medicalRecords = {
              "reports":
                  List<Map<String, dynamic>>.from(records["reports"] ?? []),
              "prescriptions": List<Map<String, dynamic>>.from(
                  records["prescriptions"] ?? []),
              "bills": List<Map<String, dynamic>>.from(records["bills"] ?? []),
              "insurance":
                  List<Map<String, dynamic>>.from(records["insurance"] ?? []),
            };
          });

          print(
              "✅ Medical records loaded: Reports: ${medicalRecords["reports"]?.length ?? 0}, "
              "Prescriptions: ${medicalRecords["prescriptions"]?.length ?? 0}, "
              "Bills: ${medicalRecords["bills"]?.length ?? 0}, "
              "Insurance: ${medicalRecords["insurance"]?.length ?? 0}");
        } else {
          print("❌ Records is null in response");
        }
      } else {
        print("❌ Error fetching records - Response: $response");
        print("❌ Success flag: ${response?['success']}");
        print("❌ Error message: ${response?['msg']}");
      }
    } catch (e) {
      print("❌ Medical Records fetch error: $e");
      if (!mounted) return;
      setState(() {
        medicalRecords = {
          "reports": [],
          "prescriptions": [],
          "bills": [],
          "insurance": [],
        };
      });
    }
  }

  Future<ImageSource?> _showPhotoSourceSheet() async {
    final l10n = context.l10n;
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt,
                  color: Theme.of(context).iconTheme.color),
              title: Text(l10n.t('profile.photo.camera')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library,
                  color: Theme.of(context).iconTheme.color),
              title: Text(l10n.t('profile.photo.gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _changeProfilePhoto() async {
    if (_isUploadingProfileImage) return;
    final source = await _showPhotoSourceSheet();
    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (picked == null) return;

    final file = File(picked.path);
    if (!mounted) return;
    setState(() {
      _pendingProfileImage = file;
      _isUploadingProfileImage = true;
    });

    final response = await ApiService.uploadProfilePhoto(file);
    if (!mounted) return;

    if (response != null && response['success'] == true) {
      final updatedUserData =
          response['data']?['user'] as Map<String, dynamic>? ?? {};
      setState(() {
        if (updatedUserData.isNotEmpty) {
          user = updatedUserData;
        } else {
          user = {
            ...user,
            'profilePicture': response['data']?['user']?['profilePicture'] ??
                user['profilePicture'],
            'profilePictureUrl': response['data']?['photoUrl'] ??
                response['data']?['user']?['profilePictureUrl'] ??
                user['profilePictureUrl'],
          };
        }
        _pendingProfileImage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('profile.photo.updated')),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _pendingProfileImage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response == null
              ? context.l10n.t('profile.photo.uploadFailed')
              : context.l10n.t('profile.photo.updateFailed')),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _isUploadingProfileImage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Lottie.asset(
            'assets/twodotloading.json',
            width: 150,
            height: 150,
          ),
        ),
      );
    }

    final l10n = context.l10n;
    // Always prefer profilePictureUrl (signed URL) over profilePicture (S3 key)
    // If profilePictureUrl is not available or looks like an S3 key (doesn't start with http),
    // we should fetch a fresh signed URL from the backend
    String profilePhotoUrl = '';
    if (user['profilePictureUrl'] != null &&
        user['profilePictureUrl'].toString().trim().isNotEmpty &&
        user['profilePictureUrl'].toString().startsWith('http')) {
      profilePhotoUrl = user['profilePictureUrl'].toString().trim();
    } else if (user['profilePicture'] != null &&
        user['profilePicture'].toString().trim().isNotEmpty) {
      // If we only have the S3 key, fetch profile to get signed URL
      if (!_loading && !_hasImageError) {
        _fetchProfile();
      }
      profilePhotoUrl = ''; // Don't use S3 key directly
    }
    final nameForInitial = (user['name'] ?? '').toString().trim();
    final fallbackInitial =
        nameForInitial.isNotEmpty ? nameForInitial[0].toUpperCase() : '';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, user);
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Header
                Card(
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Theme.of(context).primaryColor,
                              backgroundImage: _pendingProfileImage != null
                                  ? FileImage(_pendingProfileImage!)
                                  : (profilePhotoUrl.isNotEmpty &&
                                          !_hasImageError
                                      ? NetworkImage(profilePhotoUrl)
                                      : null),
                              onBackgroundImageError:
                                  _pendingProfileImage != null ||
                                          (profilePhotoUrl.isNotEmpty &&
                                              !_hasImageError)
                                      ? (exception, stackTrace) {
                                          if (mounted) {
                                            // If it's a 403 error, refresh the profile to get a new signed URL
                                            if (exception
                                                    .toString()
                                                    .contains('403') ||
                                                exception
                                                    .toString()
                                                    .contains('Forbidden')) {
                                              _fetchProfile(); // Refresh to get new signed URL
                                            }
                                            setState(() {
                                              _hasImageError = true;
                                            });
                                          }
                                        }
                                      : null,
                              child: _pendingProfileImage == null &&
                                      (profilePhotoUrl.isEmpty ||
                                          _hasImageError)
                                  ? Text(
                                      fallbackInitial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 20,
                                      ),
                                    )
                                  : null,
                            ),
                            if (_isUploadingProfileImage)
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black45,
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Tooltip(
                                message: l10n.t('profile.photo.change'),
                                child: Material(
                                  color: Theme.of(context).primaryColor,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: _isUploadingProfileImage
                                        ? null
                                        : _changeProfilePhoto,
                                    customBorder: const CircleBorder(),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user['name'] ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user['email'] ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Theme.of(context).hintColor),
                        ),
                      ],
                    ),
                  ),
                ),
                // Sections with modern design
                _sectionTitle(l10n.t('profile.personalInfo')),
                _infoRow(Icons.phone, l10n.t('profile.mobile'),
                    user['mobile'] ?? '', 'mobile'),
                _infoRow(Icons.security, l10n.t('profile.aadhaar'),
                    user['aadhaar'] ?? '', 'aadhaar'),
                _infoRow(
                    Icons.calendar_today,
                    l10n.t('profile.dob'),
                    user['dateOfBirth']?.toString().split("T")[0] ?? '',
                    'dateOfBirth'),
                _sectionTitle(l10n.t('profile.healthInfo')),
                _infoRow(Icons.person, l10n.t('profile.gender'),
                    user['gender'] ?? '', 'gender'),
                _infoRow(Icons.water_drop, l10n.t('profile.bloodType'),
                    user['bloodType'] ?? '', 'bloodType'),
                _infoRow(Icons.healing, l10n.t('profile.allergies'),
                    (user['allergies'] ?? '').toString(), 'allergies'),
                _infoRow(Icons.height, l10n.t('profile.height'),
                    user['height'] ?? '', 'height'),
                _infoRow(Icons.monitor_weight, l10n.t('profile.weight'),
                    user['weight'] ?? '', 'weight'),
                _infoRow(
                    Icons.calendar_month,
                    l10n.t('profile.lastVisit'),
                    user['lastVisit']?.toString().split("T")[0] ?? '',
                    'lastVisit'),
                _infoRow(
                    Icons.event,
                    l10n.t('profile.nextAppointment'),
                    user['nextAppointment']?.toString().split("T")[0] ?? '',
                    'nextAppointment'),
                _sectionTitle(l10n.t('profile.emergencyContact')),
                _infoRow(
                    Icons.person,
                    l10n.t('profile.emergencyName'),
                    user['emergencyContact']?['name'] ?? '',
                    'emergencyContact.name'),
                _infoRow(
                    Icons.people,
                    l10n.t('profile.emergencyRelationship'),
                    user['emergencyContact']?['relationship'] ?? '',
                    'emergencyContact.relationship'),
                _infoRow(
                    Icons.phone,
                    l10n.t('profile.emergencyPhone'),
                    user['emergencyContact']?['phone'] ?? '',
                    'emergencyContact.phone'),
                _sectionTitle(l10n.t('profile.medicalHistory')),
                _listSection(
                  user['medicalHistory'] ?? [],
                  (item) =>
                      "${item['condition']} (${item['status']}) - ${item['diagnosed']?.toString().split("T")[0] ?? ''}",
                  'medicalHistory',
                ),
                if ((user['medicalHistory'] ?? []).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: _addMedicalHistory,
                      icon: Icon(Icons.add,
                          size: 18, color: Theme.of(context).iconTheme.color),
                      label: Text(l10n.t('profile.addMedicalHistory')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                _sectionTitle(l10n.t('profile.medications')),
                _listSection(
                  user['medications'] ?? [],
                  (item) =>
                      "${item['name']} - ${item['dosage']} (${item['frequency']})",
                  'medications',
                ),
                if ((user['medications'] ?? []).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: _addMedication,
                      icon: Icon(Icons.add,
                          size: 18, color: Theme.of(context).iconTheme.color),
                      label: Text(l10n.t('profile.addMedication')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                _medicalRecordsSection(),
                const SizedBox(height: 24),
                // Modern edit all button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfilePage(userData: user),
                        ),
                      );
                      if (result != null && mounted) {
                        setState(() {
                          user = result;
                        });
                        _fetchProfile(); // Refresh data
                      }
                    },
                    icon: const Icon(Icons.edit_note, color: Colors.white),
                    label: Text(
                      l10n.t('profile.editAll'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, String fieldKey) {
    final l10n = context.l10n;
    final sanitizedValue = _sanitizeSensitiveValue(value);
    final displayValue = sanitizedValue.isNotEmpty
        ? sanitizedValue
        : l10n.t('common.notAvailable');

    return Card(
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).iconTheme.color ?? Colors.white70
                    : Theme.of(context).primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                          fontSize: 12,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayValue,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.edit,
                size: 20,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).iconTheme.color ?? Colors.white70
                    : Theme.of(context).primaryColor,
              ),
              onPressed: () => _quickEditField(fieldKey, label, sanitizedValue),
              tooltip: l10n.t('profile.quickEdit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listSection(
      List items, String Function(dynamic) format, String sectionType) {
    final l10n = context.l10n;
    return items.isEmpty
        ? Card(
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  l10n.t('profile.noData'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ),
            ),
          )
        : Column(
            children: items.asMap().entries.map<Widget>((entry) {
              final index = entry.key;
              final item = entry.value;
              return Card(
                color: Theme.of(context).cardColor,
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    format(item),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          size: 20,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).iconTheme.color ??
                                  Colors.white70
                              : Theme.of(context).primaryColor,
                        ),
                        onPressed: () =>
                            _editListItem(sectionType, index, item),
                        tooltip: l10n.t('profile.quickEdit'),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: Colors.red),
                        onPressed: () =>
                            _deleteListItem(sectionType, index, item),
                        tooltip: l10n.t('common.delete'),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
  }

  Widget _medicalRecordsSection() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(l10n.t('profile.medicalRecords')),
        _recordCategoryTile(l10n.t('documents.category.reports'),
            medicalRecords["reports"] ?? []),
        _recordCategoryTile(l10n.t('documents.category.prescriptions'),
            medicalRecords["prescriptions"] ?? []),
        _recordCategoryTile(
            l10n.t('documents.category.bills'), medicalRecords["bills"] ?? []),
        _recordCategoryTile(l10n.t('documents.category.insurance'),
            medicalRecords["insurance"] ?? []),
      ],
    );
  }

  Widget _recordCategoryTile(String title, List items) {
    final l10n = context.l10n;
    return Card(
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        title: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        children: items.isEmpty
            ? [
                ListTile(
                    title: Text(l10n.t('profile.noRecords'),
                        style: Theme.of(context).textTheme.bodyMedium))
              ]
            : items.map<Widget>((item) {
                // ✅ Convert to Document object for consistent handling
                final document = Document.fromApi(item);

                return ListTile(
                  leading: _getFileIcon(document.fileType ?? ""),
                  title: Text(
                      document.title ?? l10n.t('documentDetail.untitled'),
                      style: Theme.of(context).textTheme.bodyLarge),
                  subtitle: Text(
                      "${document.date ?? l10n.t('profile.unknownDate')} • ${document.fileType ?? l10n.t('profile.unknownType')}",
                      style: Theme.of(context).textTheme.bodySmall),
                  // ✅ No onTap - just show metadata as requested
                );
              }).toList(),
      ),
    );
  }

  // ✅ Helper method to get appropriate file icon
  Widget _getFileIcon(String fileType) {
    final type = fileType.toLowerCase();
    final theme = Theme.of(context);
    final iconColor = theme.iconTheme.color ?? theme.colorScheme.onSurface;

    if (type.contains("pdf")) {
      return Icon(Icons.picture_as_pdf, color: Colors.red.shade700);
    } else if (type.startsWith("image/")) {
      return Icon(Icons.image,
          color: theme.brightness == Brightness.dark
              ? Colors.blue.shade300
              : Colors.blue.shade700);
    } else if (type.contains("word")) {
      return Icon(Icons.description,
          color: theme.brightness == Brightness.dark
              ? Colors.blue.shade300
              : Colors.blue.shade700);
    } else {
      return Icon(Icons.insert_drive_file, color: iconColor.withOpacity(0.7));
    }
  }

  // Quick edit field dialog
  Future<void> _quickEditField(
      String fieldKey, String label, String currentValue) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: currentValue);
    final isDateField = fieldKey == 'dateOfBirth' ||
        fieldKey == 'lastVisit' ||
        fieldKey == 'nextAppointment';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.t('profile.quickEdit.title')),
        content: isDateField
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.format(
                      'profile.quickEdit.fieldLabel', {'field': label})),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: label,
                      suffixIcon: Icon(Icons.calendar_today,
                          color: Theme.of(context).iconTheme.color),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(controller.text) ??
                            DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        controller.text =
                            picked.toIso8601String().split("T")[0];
                      }
                    },
                  ),
                ],
              )
            : TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                autofocus: true,
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'fieldKey': fieldKey,
                'value': controller.text,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(l10n.t('common.save')),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateField(result['fieldKey'], result['value']);
    }
  }

  // Update a single field (string value)
  Future<void> _updateField(String fieldKey, String value) async {
    try {
      final updatedUser = Map<String, dynamic>.from(user);

      if (fieldKey.contains('.')) {
        // Handle nested fields like emergencyContact.name
        final parts = fieldKey.split('.');
        if (parts.length == 2 && parts[0] == 'emergencyContact') {
          updatedUser['emergencyContact'] = {
            ...(user['emergencyContact'] as Map? ?? {}),
            parts[1]: value,
          };
        }
      } else {
        updatedUser[fieldKey] = value;
      }

      final response = await ApiService.updateProfile(updatedUser);
      if (!mounted) return;

      if (response != null && response['success'] == true) {
        setState(() {
          user = response['data'] as Map<String, dynamic>? ?? updatedUser;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.t('profile.updateSuccess')),
            backgroundColor: Colors.green,
          ),
        );
        _fetchProfile(); // Refresh to get latest data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.t('profile.updateFailed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('profile.updateFailed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Edit list item (medical history or medication)
  Future<void> _editListItem(
      String sectionType, int index, Map<String, dynamic> item) async {
    final l10n = context.l10n;

    if (sectionType == 'medicalHistory') {
      final conditionController =
          TextEditingController(text: item['condition'] ?? '');
      final statusController =
          TextEditingController(text: item['status'] ?? '');

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.t('profile.medicalHistory.editTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: conditionController,
                decoration: InputDecoration(
                  labelText: l10n.t('profile.medicalHistory.condition'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: statusController,
                decoration: InputDecoration(
                  labelText: l10n.t('profile.medicalHistory.status'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'condition': conditionController.text,
                  'status': statusController.text,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.t('common.save')),
            ),
          ],
        ),
      );

      if (result != null) {
        final updatedHistory =
            List<Map<String, dynamic>>.from(user['medicalHistory'] ?? []);
        updatedHistory[index] = {
          ...item,
          'condition': result['condition'],
          'status': result['status'],
        };
        await _updateFieldValue('medicalHistory', updatedHistory);
      }
    } else if (sectionType == 'medications') {
      final nameController = TextEditingController(text: item['name'] ?? '');
      final dosageController =
          TextEditingController(text: item['dosage'] ?? '');
      final freqController =
          TextEditingController(text: item['frequency'] ?? '');

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.t('profile.medications.editTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.t('profile.medications.nameLabel'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dosageController,
                decoration: InputDecoration(
                  labelText: l10n.t('profile.medications.dosageLabel'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: freqController,
                decoration: InputDecoration(
                  labelText: l10n.t('profile.medications.frequencyLabel'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'name': nameController.text,
                  'dosage': dosageController.text,
                  'frequency': freqController.text,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.t('common.save')),
            ),
          ],
        ),
      );

      if (result != null) {
        final updatedMedications =
            List<Map<String, dynamic>>.from(user['medications'] ?? []);
        updatedMedications[index] = {
          ...item,
          'name': result['name'],
          'dosage': result['dosage'],
          'frequency': result['frequency'],
        };
        await _updateFieldValue('medications', updatedMedications);
      }
    }
  }

  // Delete list item with confirmation
  Future<void> _deleteListItem(
      String sectionType, int index, Map<String, dynamic> item) async {
    final l10n = context.l10n;
    final itemName = sectionType == 'medicalHistory'
        ? item['condition']?.toString() ?? ''
        : item['name']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.t('profile.deleteItem.title')),
        content: Text(
          l10n.format('profile.deleteItem.message', {'itemName': itemName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.t('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updatedList = List<Map<String, dynamic>>.from(
        user[sectionType] ?? [],
      );
      updatedList.removeAt(index);

      final updatedUser = Map<String, dynamic>.from(user);
      updatedUser[sectionType] = updatedList;

      final response = await ApiService.updateProfile(updatedUser);
      if (!mounted) return;

      if (response != null && response['success'] == true) {
        setState(() {
          user = response['data'] as Map<String, dynamic>? ?? updatedUser;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.t('profile.deleteSuccess')),
            backgroundColor: Colors.green,
          ),
        );
        _fetchProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.t('profile.deleteFailed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add medical history
  void _addMedicalHistory() {
    final l10n = context.l10n;
    final conditionController = TextEditingController();
    final statusController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.t('profile.medicalHistory.dialogTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: conditionController,
              decoration: InputDecoration(
                labelText: l10n.t('profile.medicalHistory.condition'),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: statusController,
              decoration: InputDecoration(
                labelText: l10n.t('profile.medicalHistory.status'),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedHistory =
                  List<Map<String, dynamic>>.from(user['medicalHistory'] ?? []);
              updatedHistory.add({
                "condition": conditionController.text,
                "status": statusController.text,
                "diagnosed": DateTime.now().toIso8601String(),
              });

              final updatedUser = Map<String, dynamic>.from(user);
              updatedUser['medicalHistory'] = updatedHistory;

              final response = await ApiService.updateProfile(updatedUser);
              if (!mounted) return;

              if (response != null && response['success'] == true) {
                setState(() {
                  user =
                      response['data'] as Map<String, dynamic>? ?? updatedUser;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.t('profile.addSuccess')),
                    backgroundColor: Colors.green,
                  ),
                );
                _fetchProfile();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.t('profile.updateFailed')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.t('common.add')),
          ),
        ],
      ),
    );
  }

  // Add medication
  void _addMedication() {
    final l10n = context.l10n;
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final freqController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.t('profile.medications.dialogTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.t('profile.medications.nameLabel'),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dosageController,
              decoration: InputDecoration(
                labelText: l10n.t('profile.medications.dosageLabel'),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: freqController,
              decoration: InputDecoration(
                labelText: l10n.t('profile.medications.frequencyLabel'),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedMedications =
                  List<Map<String, dynamic>>.from(user['medications'] ?? []);
              updatedMedications.add({
                "name": nameController.text,
                "dosage": dosageController.text,
                "frequency": freqController.text,
              });

              final updatedUser = Map<String, dynamic>.from(user);
              updatedUser['medications'] = updatedMedications;

              final response = await ApiService.updateProfile(updatedUser);
              if (!mounted) return;

              if (response != null && response['success'] == true) {
                setState(() {
                  user =
                      response['data'] as Map<String, dynamic>? ?? updatedUser;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.t('profile.addSuccess')),
                    backgroundColor: Colors.green,
                  ),
                );
                _fetchProfile();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.t('profile.updateFailed')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.t('common.add')),
          ),
        ],
      ),
    );
  }

  // Helper to update field that accepts dynamic values (lists, etc.)
  Future<void> _updateFieldValue(String fieldKey, dynamic value) async {
    try {
      final updatedUser = Map<String, dynamic>.from(user);
      updatedUser[fieldKey] = value;

      final response = await ApiService.updateProfile(updatedUser);
      if (!mounted) return;

      if (response != null && response['success'] == true) {
        setState(() {
          user = response['data'] as Map<String, dynamic>? ?? updatedUser;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.t('profile.updateSuccess')),
            backgroundColor: Colors.green,
          ),
        );
        _fetchProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.t('profile.updateFailed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('profile.updateFailed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ================= Edit Profile Page =================

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfilePage({super.key, required this.userData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  List<Map<String, dynamic>> medicalHistory = [];
  List<Map<String, dynamic>> medications = [];

  String _sanitizeSensitiveValue(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '';
    if (raw.toLowerCase().startsWith('enc:v')) return '';
    return raw;
  }

  @override
  void initState() {
    super.initState();
    for (var field in [
      "name",
      "email",
      "mobile",
      "aadhaar",
      "dateOfBirth",
      "age",
      "gender",
      "bloodType",
      "height",
      "weight",
      "allergies",
      "lastVisit",
      "nextAppointment",
      "Emergency Contact Name",
      "Emergency Contact Relationship",
      "Emergency Contact Phone"
    ]) {
      String value = "";
      if (field.startsWith("Emergency Contact")) {
        String ecField = '';
        if (field == "Emergency Contact Name") ecField = 'name';
        if (field == "Emergency Contact Relationship") ecField = 'relationship';
        if (field == "Emergency Contact Phone") ecField = 'phone';
        value = widget.userData["emergencyContact"]?[ecField]?.toString() ?? "";
      } else {
        value = widget.userData[field]?.toString() ?? "";
      }
      _controllers[field] =
          TextEditingController(text: _sanitizeSensitiveValue(value));
    }

    medicalHistory = List<Map<String, dynamic>>.from(
        widget.userData["medicalHistory"] ?? []);
    medications =
        List<Map<String, dynamic>>.from(widget.userData["medications"] ?? []);
  }

  Future<void> _selectDate(BuildContext context, String fieldKey) async {
    DateTime initialDate =
        DateTime.tryParse(_controllers[fieldKey]!.text) ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _controllers[fieldKey]!.text = picked.toIso8601String().split("T")[0];
      });
    }
  }

  String _fieldLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case "name":
        return l10n.t('profile.field.name');
      case "email":
        return l10n.t('profile.field.email');
      case "mobile":
        return l10n.t('profile.field.mobile');
      case "aadhaar":
        return l10n.t('profile.field.aadhaar');
      case "dateOfBirth":
        return l10n.t('profile.field.dateOfBirth');
      case "age":
        return l10n.t('profile.field.age');
      case "gender":
        return l10n.t('profile.field.gender');
      case "bloodType":
        return l10n.t('profile.field.bloodType');
      case "height":
        return l10n.t('profile.field.height');
      case "weight":
        return l10n.t('profile.field.weight');
      case "allergies":
        return l10n.t('profile.field.allergies');
      case "lastVisit":
        return l10n.t('profile.field.lastVisit');
      case "nextAppointment":
        return l10n.t('profile.field.nextAppointment');
      case "Emergency Contact Name":
        return l10n.t('profile.field.emergencyName');
      case "Emergency Contact Relationship":
        return l10n.t('profile.field.emergencyRelationship');
      case "Emergency Contact Phone":
        return l10n.t('profile.field.emergencyPhone');
      default:
        return key;
    }
  }

  void _addMedicalHistory() {
    final conditionController = TextEditingController();
    final statusController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.t('profile.medicalHistory.dialogTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: conditionController,
                decoration: InputDecoration(
                    labelText:
                        context.l10n.t('profile.medicalHistory.condition'))),
            TextField(
                controller: statusController,
                decoration: InputDecoration(
                    labelText:
                        context.l10n.t('profile.medicalHistory.status'))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.t('common.cancel'))),
          ElevatedButton(
            onPressed: () {
              setState(() {
                medicalHistory.add({
                  "condition": conditionController.text,
                  "status": statusController.text,
                  "diagnosed": DateTime.now().toIso8601String(),
                });
              });
              Navigator.pop(context);
            },
            child: Text(context.l10n.t('common.add')),
          ),
        ],
      ),
    );
  }

  void _addMedication() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final freqController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.t('profile.medications.dialogTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: InputDecoration(
                    labelText:
                        context.l10n.t('profile.medications.nameLabel'))),
            TextField(
                controller: dosageController,
                decoration: InputDecoration(
                    labelText:
                        context.l10n.t('profile.medications.dosageLabel'))),
            TextField(
                controller: freqController,
                decoration: InputDecoration(
                    labelText:
                        context.l10n.t('profile.medications.frequencyLabel'))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.t('common.cancel'))),
          ElevatedButton(
            onPressed: () {
              setState(() {
                medications.add({
                  "name": nameController.text,
                  "dosage": dosageController.text,
                  "frequency": freqController.text,
                });
              });
              Navigator.pop(context);
            },
            child: Text(context.l10n.t('common.add')),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile(Map<String, dynamic> updatedUser) async {
    final response = await ApiService.updateProfile(updatedUser);
    if (!mounted) return;
    if (response != null && response['success'] == true) {
      final updatedData =
          response['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      Navigator.pop(
          context,
          updatedData.isNotEmpty
              ? updatedData
              : Map<String, dynamic>.from(widget.userData));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('profile.updateSuccess')),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('profile.updateFailed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('profile.editTitle'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              for (var field in _controllers.keys)
                Column(
                  children: [
                    TextFormField(
                      controller: _controllers[field],
                      readOnly: field == "dateOfBirth" ||
                          field == "lastVisit" ||
                          field == "nextAppointment",
                      onTap: (field == "dateOfBirth" ||
                              field == "lastVisit" ||
                              field == "nextAppointment")
                          ? () => _selectDate(context, field)
                          : null,
                      decoration: InputDecoration(
                        labelText: _fieldLabel(field, l10n),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Medical History
              Text(context.l10n.t('profile.medicalHistory'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              ...medicalHistory.asMap().entries.map((entry) {
                final index = entry.key;
                final mh = entry.value;
                return Dismissible(
                  key: Key("mh_$index"),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    setState(() {
                      medicalHistory.removeAt(index);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              context.l10n.t('profile.medicalHistoryDeleted'))),
                    );
                  },
                  child: ListTile(
                    title: Text(mh["condition"]),
                    subtitle: Text(mh["status"]),
                  ),
                );
              }),
              ElevatedButton(
                  onPressed: _addMedicalHistory,
                  child: Text(context.l10n.t('profile.addMedicalHistory'))),

              const SizedBox(height: 20),

              // Medications
              Text(context.l10n.t('profile.medications'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              ...medications.asMap().entries.map((entry) {
                final index = entry.key;
                final med = entry.value;
                return Dismissible(
                  key: Key("med_$index"),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    setState(() {
                      medications.removeAt(index);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              context.l10n.t('profile.medicationDeleted'))),
                    );
                  },
                  child: ListTile(
                    title: Text(med["name"]),
                    subtitle: Text("${med["dosage"]} - ${med["frequency"]}"),
                  ),
                );
              }),
              ElevatedButton(
                  onPressed: _addMedication,
                  child: Text(context.l10n.t('profile.addMedication'))),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final updatedUser = {
                      "name": _controllers["name"]!.text,
                      "email": _controllers["email"]!.text,
                      "mobile": _controllers["mobile"]!.text,
                      "aadhaar": _controllers["aadhaar"]!.text,
                      "dateOfBirth": _controllers["dateOfBirth"]!.text,
                      "age": int.tryParse(_controllers["age"]!.text),
                      "gender": _controllers["gender"]!.text,
                      "bloodType": _controllers["bloodType"]!.text,
                      "height": _controllers["height"]!.text,
                      "weight": _controllers["weight"]!.text,
                      "allergies": _controllers["allergies"]!.text,
                      "lastVisit": _controllers["lastVisit"]!.text,
                      "nextAppointment": _controllers["nextAppointment"]!.text,
                      "emergencyContact": {
                        "name": _controllers["Emergency Contact Name"]!.text,
                        "relationship":
                            _controllers["Emergency Contact Relationship"]!
                                .text,
                        "phone": _controllers["Emergency Contact Phone"]!.text,
                      },
                      "medicalHistory": medicalHistory,
                      "medications": medications,
                    };
                    await _saveProfile(updatedUser);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(context.l10n.t('profile.saveChanges'),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
