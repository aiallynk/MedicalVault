import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../Document_model.dart';
import '../api_service.dart';
import '../localization/app_localizations.dart';

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

  @override
  void initState() {
    super.initState();
    user = widget.userData;
    _fetchProfile();
    _fetchMedicalRecords();
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("authToken");
      if (token == null) return;

      final response = await http.get(
        Uri.parse("https://backend-medicalvault.onrender.com/api/auth/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          user = body["data"]["user"];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      print("❌ Fetch error: $e");
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
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.t('profile.photo.camera')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
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
    final l10n = context.l10n;
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
          content: Text(l10n.t('profile.photo.updated')),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _pendingProfileImage = null;
      });
      final message = response == null
          ? l10n.t('profile.photo.uploadFailed')
          : (response['message']?.toString() ??
              l10n.t('profile.photo.updateFailed'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
    final profilePhotoUrl =
        (user['profilePictureUrl'] ?? user['profilePicture'] ?? '')
            .toString()
            .trim();
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
                                  : (profilePhotoUrl.isNotEmpty && !_hasImageError
                                      ? NetworkImage(profilePhotoUrl)
                                      : null),
                              onBackgroundImageError: (exception, stackTrace) {
                                if (mounted) {
                                  setState(() {
                                    _hasImageError = true;
                                  });
                                }
                              },
                              child: _pendingProfileImage == null &&
                                      (profilePhotoUrl.isEmpty || _hasImageError)
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
                // Sections
                _sectionTitle(l10n.t('profile.personalInfo')),
                _infoRow(Icons.phone, l10n.t('profile.mobile'),
                    user['mobile'] ?? ''),
                _infoRow(Icons.security, l10n.t('profile.aadhaar'),
                    user['aadhaar'] ?? ''),
                _infoRow(Icons.calendar_today, l10n.t('profile.dob'),
                    user['dateOfBirth']?.toString().split("T")[0] ?? ''),
                _sectionTitle(l10n.t('profile.healthInfo')),
                _infoRow(Icons.person, l10n.t('profile.gender'),
                    user['gender'] ?? ''),
                _infoRow(Icons.water_drop, l10n.t('profile.bloodType'),
                    user['bloodType'] ?? ''),
                _infoRow(Icons.healing, l10n.t('profile.allergies'),
                    (user['allergies'] ?? '').toString()),
                _infoRow(Icons.height, l10n.t('profile.height'),
                    user['height'] ?? ''),
                _infoRow(Icons.monitor_weight, l10n.t('profile.weight'),
                    user['weight'] ?? ''),
                _infoRow(Icons.calendar_month, l10n.t('profile.lastVisit'),
                    user['lastVisit']?.toString().split("T")[0] ?? ''),
                _infoRow(Icons.event, l10n.t('profile.nextAppointment'),
                    user['nextAppointment']?.toString().split("T")[0] ?? ''),
                _sectionTitle(l10n.t('profile.emergencyContact')),
                _infoRow(Icons.person, l10n.t('profile.emergencyName'),
                    user['emergencyContact']?['name'] ?? ''),
                _infoRow(Icons.people, l10n.t('profile.emergencyRelationship'),
                    user['emergencyContact']?['relationship'] ?? ''),
                _infoRow(Icons.phone, l10n.t('profile.emergencyPhone'),
                    user['emergencyContact']?['phone'] ?? ''),
                _sectionTitle(l10n.t('profile.medicalHistory')),
                _listSection(
                  user['medicalHistory'] ?? [],
                  (item) =>
                      "${item['condition']} (${item['status']}) - ${item['diagnosed']}",
                ),
                _sectionTitle(l10n.t('profile.medications')),
                _listSection(
                  user['medications'] ?? [],
                  (item) =>
                      "${item['name']} - ${item['dosage']} (${item['frequency']})",
                ),
                _medicalRecordsSection(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfilePage(userData: user),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          user = result;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      l10n.t('profile.editButton'),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
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

  Widget _infoRow(IconData icon, String label, String value) {
    final l10n = context.l10n;
    return Card(
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(value.isNotEmpty ? value : l10n.t('common.notAvailable'),
            style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  Widget _listSection(List items, String Function(dynamic) format) {
    final l10n = context.l10n;
    return items.isEmpty
        ? Text(l10n.t('profile.noData'),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).hintColor))
        : Column(
            children: items
                .map<Widget>((item) => Card(
                      color: Theme.of(context).cardColor,
                      child: ListTile(
                          title: Text(format(item),
                              style: Theme.of(context).textTheme.bodyMedium)),
                    ))
                .toList(),
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
    if (type.contains("pdf")) {
      return const Icon(Icons.picture_as_pdf, color: Colors.red);
    } else if (type.startsWith("image/")) {
      return const Icon(Icons.image, color: Colors.blue);
    } else if (type.contains("word")) {
      return const Icon(Icons.description, color: Colors.blue);
    } else {
      return const Icon(Icons.insert_drive_file, color: Colors.grey);
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
      if (field.startsWith("ec")) {
        String ecField = field.substring(2).toLowerCase();
        value = widget.userData["emergencyContact"]?[ecField]?.toString() ?? "";
      } else {
        value = widget.userData[field]?.toString() ?? "";
      }
      _controllers[field] = TextEditingController(text: value);
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
    final l10n = context.l10n;
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
    } else {
      final message =
          response?['message']?.toString() ?? l10n.t('profile.updateFailed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
